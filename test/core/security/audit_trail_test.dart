import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('AuditAction', () {
    test('enum contains all expected values', () {
      expect(
        AuditAction.values,
        containsAll([
          AuditAction.messageSendReceive,
          AuditAction.authentication,
          AuditAction.authorization,
          AuditAction.contentModeration,
          AuditAction.sessionLifecycle,
          AuditAction.credentialOperation,
          AuditAction.inputValidation,
          AuditAction.configurationChange,
          AuditAction.securityEvent,
        ]),
      );
    });

    test('enum contains exactly nine values', () {
      expect(AuditAction.values, hasLength(9));
    });
  });

  group('AuditOutcome', () {
    test('enum contains all expected values', () {
      expect(
        AuditOutcome.values,
        containsAll([
          AuditOutcome.success,
          AuditOutcome.failure,
          AuditOutcome.denied,
          AuditOutcome.error,
        ]),
      );
    });

    test('enum contains exactly four values', () {
      expect(AuditOutcome.values, hasLength(4));
    });
  });

  group('AuditRecord', () {
    late DateTime timestamp;

    setUp(() {
      timestamp = DateTime.utc(2026, 1, 15, 10, 30);
    });

    test('construction with all fields', () {
      final record = AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: timestamp,
        context: const {'key': 'value'},
        correlationId: 'corr-123',
      );

      expect(record.actor, equals('user-1'));
      expect(record.action, equals(AuditAction.messageSendReceive));
      expect(record.resource, equals('channel/slack'));
      expect(record.outcome, equals(AuditOutcome.success));
      expect(record.timestamp, equals(timestamp));
      expect(record.context, equals({'key': 'value'}));
      expect(record.correlationId, equals('corr-123'));
    });

    test('construction with required fields only', () {
      final record = AuditRecord(
        actor: 'user-2',
        action: AuditAction.authentication,
        resource: 'auth/login',
        outcome: AuditOutcome.failure,
        timestamp: timestamp,
      );

      expect(record.actor, equals('user-2'));
      expect(record.action, equals(AuditAction.authentication));
      expect(record.resource, equals('auth/login'));
      expect(record.outcome, equals(AuditOutcome.failure));
      expect(record.timestamp, equals(timestamp));
      expect(record.context, isNull);
      expect(record.correlationId, isNull);
    });

    test('context can hold arbitrary metadata', () {
      final record = AuditRecord(
        actor: 'system',
        action: AuditAction.configurationChange,
        resource: 'config/rate-limit',
        outcome: AuditOutcome.success,
        timestamp: timestamp,
        context: const {
          'oldValue': 100,
          'newValue': 200,
          'changedBy': 'admin',
        },
      );

      expect(record.context, isA<Map<String, dynamic>>());
      expect(record.context!['oldValue'], equals(100));
      expect(record.context!['newValue'], equals(200));
    });
  });

  group('InMemoryAuditTrail', () {
    late InMemoryAuditTrail trail;

    setUp(() {
      trail = InMemoryAuditTrail();
    });

    test('recordEvent and retrieve via query', () async {
      final record = AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 10, 0),
      );

      await trail.recordEvent(record);

      final results = await trail.query();

      expect(results, hasLength(1));
      expect(results.first.actor, equals('user-1'));
    });

    test('records getter returns unmodifiable list', () async {
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.authentication,
        resource: 'auth/login',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 10, 0),
      ));

      final records = trail.records;

      expect(records, hasLength(1));
      expect(
        () => records.add(AuditRecord(
          actor: 'test',
          action: AuditAction.securityEvent,
          resource: 'test',
          outcome: AuditOutcome.success,
          timestamp: DateTime.now(),
        )),
        throwsUnsupportedError,
      );
    });

    test('query with actor filter', () async {
      await trail.recordEvent(AuditRecord(
        actor: 'alice',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 10, 0),
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'bob',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 11, 0),
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'alice',
        action: AuditAction.authentication,
        resource: 'auth/login',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 12, 0),
      ));

      final results = await trail.query(actor: 'alice');

      expect(results, hasLength(2));
      expect(results.every((r) => r.actor == 'alice'), isTrue);
    });

    test('query with action filter (string match against enum name)', () async {
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 10, 0),
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.authentication,
        resource: 'auth/login',
        outcome: AuditOutcome.failure,
        timestamp: DateTime.utc(2026, 1, 15, 11, 0),
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-2',
        action: AuditAction.messageSendReceive,
        resource: 'channel/telegram',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 12, 0),
      ));

      final results = await trail.query(action: 'messageSendReceive');

      expect(results, hasLength(2));
      expect(
        results.every((r) => r.action == AuditAction.messageSendReceive),
        isTrue,
      );
    });

    test('query with after time filter', () async {
      final t1 = DateTime.utc(2026, 1, 15, 8, 0);
      final t2 = DateTime.utc(2026, 1, 15, 12, 0);
      final t3 = DateTime.utc(2026, 1, 15, 16, 0);

      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t1,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t2,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t3,
      ));

      // Query records after 10:00
      final after = DateTime.utc(2026, 1, 15, 10, 0);
      final results = await trail.query(after: after);

      // t1 (08:00) is before the cutoff
      expect(results, hasLength(2));
    });

    test('query with before time filter', () async {
      final t1 = DateTime.utc(2026, 1, 15, 8, 0);
      final t2 = DateTime.utc(2026, 1, 15, 12, 0);
      final t3 = DateTime.utc(2026, 1, 15, 16, 0);

      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t1,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t2,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t3,
      ));

      // Query records before 14:00
      final before = DateTime.utc(2026, 1, 15, 14, 0);
      final results = await trail.query(before: before);

      // t3 (16:00) is after the cutoff
      expect(results, hasLength(2));
    });

    test('query with combined after and before time range', () async {
      final t1 = DateTime.utc(2026, 1, 15, 8, 0);
      final t2 = DateTime.utc(2026, 1, 15, 12, 0);
      final t3 = DateTime.utc(2026, 1, 15, 16, 0);
      final t4 = DateTime.utc(2026, 1, 15, 20, 0);

      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t1,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t2,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t3,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: t4,
      ));

      // Query records between 10:00 and 18:00
      final after = DateTime.utc(2026, 1, 15, 10, 0);
      final before = DateTime.utc(2026, 1, 15, 18, 0);
      final results = await trail.query(after: after, before: before);

      // t1 (08:00) is before range, t4 (20:00) is after range
      expect(results, hasLength(2));
    });

    test('query with limit parameter', () async {
      // Insert 5 records
      for (var i = 1; i <= 5; i++) {
        await trail.recordEvent(AuditRecord(
          actor: 'user-1',
          action: AuditAction.messageSendReceive,
          resource: 'channel/slack',
          outcome: AuditOutcome.success,
          timestamp: DateTime.utc(2026, 1, 15, i),
        ));
      }

      final results = await trail.query(limit: 3);

      expect(results, hasLength(3));
    });

    test('query default limit is 100', () async {
      // Insert more than 100 records
      for (var i = 0; i < 110; i++) {
        await trail.recordEvent(AuditRecord(
          actor: 'user-1',
          action: AuditAction.messageSendReceive,
          resource: 'channel/slack',
          outcome: AuditOutcome.success,
          timestamp: DateTime.utc(2026, 1, 15, 0, i),
        ));
      }

      final results = await trail.query();

      expect(results, hasLength(100));
    });

    test('results are sorted by timestamp descending', () async {
      final t1 = DateTime.utc(2026, 1, 15, 8, 0);
      final t2 = DateTime.utc(2026, 1, 15, 12, 0);
      final t3 = DateTime.utc(2026, 1, 15, 10, 0);

      // Insert out of order
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'res-a',
        outcome: AuditOutcome.success,
        timestamp: t1,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'res-b',
        outcome: AuditOutcome.success,
        timestamp: t2,
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'res-c',
        outcome: AuditOutcome.success,
        timestamp: t3,
      ));

      final results = await trail.query();

      // Should be: res-b (12:00), res-c (10:00), res-a (08:00)
      expect(results[0].resource, equals('res-b'));
      expect(results[1].resource, equals('res-c'));
      expect(results[2].resource, equals('res-a'));
    });

    test('query with multiple filters combined', () async {
      await trail.recordEvent(AuditRecord(
        actor: 'alice',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 10, 0),
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'alice',
        action: AuditAction.authentication,
        resource: 'auth/login',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 11, 0),
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'bob',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 12, 0),
      ));

      final results = await trail.query(
        actor: 'alice',
        action: 'messageSendReceive',
      );

      expect(results, hasLength(1));
      expect(results.first.actor, equals('alice'));
      expect(results.first.action, equals(AuditAction.messageSendReceive));
    });

    test('clear removes all records', () async {
      await trail.recordEvent(AuditRecord(
        actor: 'user-1',
        action: AuditAction.messageSendReceive,
        resource: 'channel/slack',
        outcome: AuditOutcome.success,
        timestamp: DateTime.utc(2026, 1, 15, 10, 0),
      ));
      await trail.recordEvent(AuditRecord(
        actor: 'user-2',
        action: AuditAction.authentication,
        resource: 'auth/login',
        outcome: AuditOutcome.failure,
        timestamp: DateTime.utc(2026, 1, 15, 11, 0),
      ));

      trail.clear();

      final results = await trail.query();
      expect(results, isEmpty);
      expect(trail.records, isEmpty);
    });
  });
}
