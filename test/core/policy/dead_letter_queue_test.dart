import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 30, 0);

  FailureRecord makeRecord({
    String eventId = 'evt-1',
    Map<String, dynamic> event = const {'type': 'message', 'text': 'hello'},
    String error = 'timeout',
    String stackTrace = 'stack trace here',
    int attemptCount = 3,
    DateTime? failedAt,
    String? conversationKey,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    return FailureRecord(
      eventId: eventId,
      event: event,
      error: error,
      stackTrace: stackTrace,
      failedAt: failedAt ?? now,
      attemptCount: attemptCount,
      conversationKey: conversationKey,
      userId: userId,
      metadata: metadata,
    );
  }

  group('FailureRecord', () {
    group('construction and field access', () {
      test('required fields are stored correctly', () {
        final record = makeRecord();

        expect(record.eventId, 'evt-1');
        expect(record.event, {'type': 'message', 'text': 'hello'});
        expect(record.error, 'timeout');
        expect(record.stackTrace, 'stack trace here');
        expect(record.failedAt, now);
        expect(record.attemptCount, 3);
        expect(record.conversationKey, isNull);
        expect(record.userId, isNull);
        expect(record.metadata, isNull);
      });

      test('optional fields are stored when provided', () {
        final record = makeRecord(
          conversationKey: 'conv-1',
          userId: 'u-123',
          metadata: {'source': 'slack'},
        );

        expect(record.conversationKey, 'conv-1');
        expect(record.userId, 'u-123');
        expect(record.metadata!['source'], 'slack');
      });
    });

    group('fromJson / toJson round-trip', () {
      test('round-trip without optional fields', () {
        final original = makeRecord();
        final json = original.toJson();
        final restored = FailureRecord.fromJson(json);

        expect(restored.eventId, original.eventId);
        expect(restored.event, original.event);
        expect(restored.error, original.error);
        expect(restored.stackTrace, original.stackTrace);
        expect(restored.failedAt, original.failedAt);
        expect(restored.attemptCount, original.attemptCount);
        expect(restored.conversationKey, isNull);
        expect(restored.userId, isNull);
        expect(restored.metadata, isNull);
      });

      test('round-trip with all optional fields', () {
        final original = makeRecord(
          conversationKey: 'conv-1',
          userId: 'u-1',
          metadata: {'channel': 'slack', 'retryCount': 5},
        );
        final json = original.toJson();
        final restored = FailureRecord.fromJson(json);

        expect(restored.eventId, original.eventId);
        expect(restored.conversationKey, 'conv-1');
        expect(restored.userId, 'u-1');
        expect(restored.metadata!['channel'], 'slack');
      });

      test('toJson omits optional fields when null', () {
        final record = makeRecord();
        final json = record.toJson();

        expect(json.containsKey('conversationKey'), isFalse);
        expect(json.containsKey('userId'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });
    });

    group('copyWith', () {
      test('no arguments returns equivalent record', () {
        final original = makeRecord(conversationKey: 'conv');
        final copied = original.copyWith();

        expect(copied.eventId, original.eventId);
        expect(copied.error, original.error);
        expect(copied.conversationKey, original.conversationKey);
      });

      test('overrides individual fields', () {
        final original = makeRecord();
        final copied = original.copyWith(
          eventId: 'evt-2',
          error: 'network_error',
          attemptCount: 5,
        );

        expect(copied.eventId, 'evt-2');
        expect(copied.error, 'network_error');
        expect(copied.attemptCount, 5);
        expect(copied.event, original.event);
      });
    });

    group('equality', () {
      test('records with same eventId are equal', () {
        final a = makeRecord(eventId: 'same', error: 'err-a');
        final b = makeRecord(eventId: 'same', error: 'err-b');

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('records with different eventIds are not equal', () {
        final a = makeRecord(eventId: 'id-1');
        final b = makeRecord(eventId: 'id-2');

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('contains eventId, attemptCount, and error', () {
        final record = makeRecord(
          eventId: 'evt-42',
          attemptCount: 7,
          error: 'rate_limited',
        );

        final str = record.toString();
        expect(str, contains('evt-42'));
        expect(str, contains('7'));
        expect(str, contains('rate_limited'));
      });
    });
  });

  group('InMemoryDeadLetterQueue', () {
    late InMemoryDeadLetterQueue dlq;

    setUp(() {
      dlq = InMemoryDeadLetterQueue();
    });

    group('enqueue()', () {
      test('stores a single record', () async {
        await dlq.enqueue(makeRecord(eventId: 'r-1'));
        expect(await dlq.count(), 1);
      });

      test('stores multiple records', () async {
        await dlq.enqueue(makeRecord(eventId: 'r-1'));
        await dlq.enqueue(makeRecord(eventId: 'r-2'));
        await dlq.enqueue(makeRecord(eventId: 'r-3'));

        expect(await dlq.count(), 3);
      });
    });

    group('peek()', () {
      test('returns empty list when queue is empty', () async {
        final results = await dlq.peek();
        expect(results, isEmpty);
      });

      test('returns records with default limit', () async {
        await dlq.enqueue(makeRecord(eventId: 'r-1'));
        await dlq.enqueue(makeRecord(eventId: 'r-2'));

        final results = await dlq.peek();
        expect(results, hasLength(2));
      });

      test('respects limit parameter', () async {
        await dlq.enqueue(makeRecord(eventId: 'r-1'));
        await dlq.enqueue(makeRecord(eventId: 'r-2'));
        await dlq.enqueue(makeRecord(eventId: 'r-3'));

        final results = await dlq.peek(limit: 2);
        expect(results, hasLength(2));
      });

      test('filters by conversationKey', () async {
        await dlq.enqueue(
            makeRecord(eventId: 'r-1', conversationKey: 'conv-a'));
        await dlq.enqueue(
            makeRecord(eventId: 'r-2', conversationKey: 'conv-b'));
        await dlq.enqueue(
            makeRecord(eventId: 'r-3', conversationKey: 'conv-a'));

        final results = await dlq.peek(conversationKey: 'conv-a');
        expect(results, hasLength(2));
        expect(results.every((r) => r.conversationKey == 'conv-a'), isTrue);
      });
    });

    group('remove()', () {
      test('removes record by eventId', () async {
        await dlq.enqueue(makeRecord(eventId: 'r-1'));
        await dlq.enqueue(makeRecord(eventId: 'r-2'));

        await dlq.remove('r-1');
        expect(await dlq.count(), 1);
      });

      test('does nothing when eventId not found', () async {
        await dlq.enqueue(makeRecord(eventId: 'r-1'));

        await dlq.remove('non-existent');
        expect(await dlq.count(), 1);
      });
    });

    group('count()', () {
      test('returns 0 for empty queue', () async {
        expect(await dlq.count(), 0);
      });

      test('returns correct count', () async {
        await dlq.enqueue(makeRecord(eventId: 'r-1'));
        await dlq.enqueue(makeRecord(eventId: 'r-2'));

        expect(await dlq.count(), 2);
      });
    });

    group('cleanup()', () {
      test('removes records older than specified duration', () async {
        await dlq.enqueue(makeRecord(
          eventId: 'old',
          failedAt: DateTime.now().subtract(const Duration(days: 10)),
        ));
        await dlq.enqueue(makeRecord(
          eventId: 'recent',
          failedAt: DateTime.now(),
        ));

        final removed = await dlq.cleanup(olderThan: const Duration(days: 5));
        expect(removed, 1);
        expect(await dlq.count(), 1);
      });

      test('returns 0 when no records are old enough', () async {
        await dlq.enqueue(makeRecord(
          eventId: 'recent',
          failedAt: DateTime.now(),
        ));

        final removed =
            await dlq.cleanup(olderThan: const Duration(days: 30));
        expect(removed, 0);
        expect(await dlq.count(), 1);
      });
    });
  });

  group('FailureHandler typedef', () {
    test('can be assigned and invoked', () async {
      FailureRecord? captured;
      Future<void> handler(FailureRecord record) async {
        captured = record;
      }

      final record = makeRecord(eventId: 'handler-test');
      await handler(record);

      expect(captured, isNotNull);
      expect(captured!.eventId, 'handler-test');
    });
  });
}
