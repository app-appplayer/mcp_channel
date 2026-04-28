import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2025, 1, 15, 10, 0, 0);
  final future = DateTime.utc(2025, 1, 16, 10, 0, 0);
  final past = DateTime.utc(2025, 1, 14, 10, 0, 0);

  group('IdempotencyRecord', () {
    test('creates with required fields', () {
      final record = IdempotencyRecord(
        eventId: 'evt_1',
        status: IdempotencyStatus.processing,
        createdAt: now,
        expiresAt: future,
      );

      expect(record.eventId, 'evt_1');
      expect(record.status, IdempotencyStatus.processing);
      expect(record.createdAt, now);
      expect(record.expiresAt, future);
      expect(record.result, isNull);
      expect(record.completedAt, isNull);
      expect(record.lockHolder, isNull);
      expect(record.lockExpiresAt, isNull);
    });

    test('creates with all fields', () {
      final result = IdempotencyResult.success();
      final record = IdempotencyRecord(
        eventId: 'evt_1',
        status: IdempotencyStatus.completed,
        result: result,
        createdAt: now,
        completedAt: now,
        expiresAt: future,
        lockHolder: 'inst_1',
        lockExpiresAt: future,
      );

      expect(record.result, isNotNull);
      expect(record.completedAt, now);
      expect(record.lockHolder, 'inst_1');
      expect(record.lockExpiresAt, future);
    });

    group('isLockValid', () {
      test('returns true when lock not expired', () {
        final record = IdempotencyRecord(
          eventId: 'evt_1',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
          lockHolder: 'inst_1',
          lockExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(record.isLockValid, true);
      });

      test('returns false when lock expired', () {
        final record = IdempotencyRecord(
          eventId: 'evt_1',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
          lockHolder: 'inst_1',
          lockExpiresAt: past,
        );
        expect(record.isLockValid, false);
      });

      test('returns false when no lock', () {
        final record = IdempotencyRecord(
          eventId: 'evt_1',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
        );
        expect(record.isLockValid, false);
      });
    });

    group('isExpired', () {
      test('returns true when expired', () {
        final record = IdempotencyRecord(
          eventId: 'evt_1',
          status: IdempotencyStatus.completed,
          createdAt: past,
          expiresAt: past,
        );
        expect(record.isExpired, true);
      });

      test('returns false when not expired', () {
        final record = IdempotencyRecord(
          eventId: 'evt_1',
          status: IdempotencyStatus.completed,
          createdAt: now,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(record.isExpired, false);
      });
    });

    test('copyWith creates modified copy', () {
      final record = IdempotencyRecord(
        eventId: 'evt_1',
        status: IdempotencyStatus.processing,
        createdAt: now,
        expiresAt: future,
      );
      final copy = record.copyWith(
        status: IdempotencyStatus.completed,
        completedAt: now,
      );

      expect(copy.status, IdempotencyStatus.completed);
      expect(copy.completedAt, now);
      expect(copy.eventId, 'evt_1');
    });

    group('JSON serialization', () {
      test('serializes to JSON with required fields', () {
        final record = IdempotencyRecord(
          eventId: 'evt_1',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
        );
        final json = record.toJson();
        expect(json['eventId'], 'evt_1');
        expect(json['status'], 'processing');
        expect(json.containsKey('result'), isFalse);
        expect(json.containsKey('completedAt'), isFalse);
        expect(json.containsKey('lockHolder'), isFalse);
      });

      test('serializes to JSON with all fields', () {
        final record = IdempotencyRecord(
          eventId: 'evt_1',
          status: IdempotencyStatus.completed,
          result: IdempotencyResult.success(),
          createdAt: now,
          completedAt: now,
          expiresAt: future,
          lockHolder: 'inst_1',
          lockExpiresAt: future,
        );
        final json = record.toJson();
        expect(json['result'], isNotNull);
        expect(json['completedAt'], isNotNull);
        expect(json['lockHolder'], 'inst_1');
        expect(json['lockExpiresAt'], isNotNull);
      });

      test('deserializes from JSON', () {
        final record = IdempotencyRecord.fromJson({
          'eventId': 'evt_1',
          'status': 'completed',
          'result': {'success': true},
          'createdAt': now.toIso8601String(),
          'completedAt': now.toIso8601String(),
          'expiresAt': future.toIso8601String(),
          'lockHolder': 'inst_1',
          'lockExpiresAt': future.toIso8601String(),
        });

        expect(record.eventId, 'evt_1');
        expect(record.status, IdempotencyStatus.completed);
        expect(record.result!.success, true);
        expect(record.lockHolder, 'inst_1');
      });

      test('deserializes unknown status defaults to expired', () {
        final record = IdempotencyRecord.fromJson({
          'eventId': 'evt_1',
          'status': 'unknown_status',
          'createdAt': now.toIso8601String(),
          'expiresAt': future.toIso8601String(),
        });
        expect(record.status, IdempotencyStatus.expired);
      });

      test('round-trip serialization', () {
        final original = IdempotencyRecord(
          eventId: 'evt_1',
          status: IdempotencyStatus.completed,
          result: IdempotencyResult.success(data: {'x': 1}),
          createdAt: now,
          completedAt: now,
          expiresAt: future,
          lockHolder: 'inst_1',
          lockExpiresAt: future,
        );
        final restored = IdempotencyRecord.fromJson(original.toJson());
        expect(restored.eventId, original.eventId);
        expect(restored.status, original.status);
        expect(restored.result!.data?['x'], 1);
        expect(restored.lockHolder, original.lockHolder);
      });
    });

    test('toString contains event ID and status', () {
      final record = IdempotencyRecord(
        eventId: 'evt_1',
        status: IdempotencyStatus.processing,
        createdAt: now,
        expiresAt: future,
      );
      final str = record.toString();
      expect(str, contains('evt_1'));
      expect(str, contains('processing'));
    });
  });

  group('IdempotencyResult', () {
    test('success factory', () {
      final result = IdempotencyResult.success(data: {'count': 5});
      expect(result.success, true);
      expect(result.error, isNull);
      expect(result.data?['count'], 5);
    });

    test('failure factory', () {
      final result = IdempotencyResult.failure(error: 'timeout');
      expect(result.success, false);
      expect(result.error, 'timeout');
    });

    test('serializes to JSON', () {
      final result = IdempotencyResult.success(data: {'k': 'v'});
      final json = result.toJson();
      expect(json['success'], true);
      expect(json['data'], {'k': 'v'});
      expect(json.containsKey('error'), isFalse);
    });

    test('serializes failure to JSON', () {
      final result = IdempotencyResult.failure(error: 'err');
      final json = result.toJson();
      expect(json['success'], false);
      expect(json['error'], 'err');
    });

    test('deserializes from JSON', () {
      final result = IdempotencyResult.fromJson({
        'success': true,
        'data': {'k': 'v'},
      });
      expect(result.success, true);
      expect(result.data?['k'], 'v');
    });

    test('round-trip serialization', () {
      final original = IdempotencyResult.failure(
        error: 'test',
        data: {'retry': true},
      );
      final restored = IdempotencyResult.fromJson(original.toJson());
      expect(restored.success, original.success);
      expect(restored.error, original.error);
      expect(restored.data?['retry'], true);
    });

    test('toString for success', () {
      final result = IdempotencyResult.success();
      expect(result.toString(), contains('success'));
    });

    test('toString for failure', () {
      final result = IdempotencyResult.failure(error: 'boom');
      expect(result.toString(), contains('boom'));
    });
  });

  group('IdempotencyConfig', () {
    test('has correct defaults', () {
      const config = IdempotencyConfig();
      expect(config.recordTtl, const Duration(hours: 24));
      expect(config.lockTimeout, const Duration(minutes: 5));
      expect(config.retryFailed, false);
      expect(config.cleanupInterval, const Duration(hours: 1));
    });

    test('copyWith overrides values', () {
      const config = IdempotencyConfig();
      final copy = config.copyWith(
        recordTtl: const Duration(hours: 1),
        retryFailed: true,
      );
      expect(copy.recordTtl, const Duration(hours: 1));
      expect(copy.retryFailed, true);
      expect(copy.lockTimeout, const Duration(minutes: 5));
      expect(copy.cleanupInterval, const Duration(hours: 1));
    });
  });

  group('IdempotencyStatus', () {
    test('has all expected values', () {
      expect(IdempotencyStatus.values, hasLength(4));
      expect(IdempotencyStatus.values, contains(IdempotencyStatus.processing));
      expect(IdempotencyStatus.values, contains(IdempotencyStatus.completed));
      expect(IdempotencyStatus.values, contains(IdempotencyStatus.failed));
      expect(IdempotencyStatus.values, contains(IdempotencyStatus.expired));
    });
  });
}
