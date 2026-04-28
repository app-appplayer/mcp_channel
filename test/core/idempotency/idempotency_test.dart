import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

/// A custom IdempotencyStore that wraps InMemoryIdempotencyStore but allows
/// injecting a record with a specific status for testing the expired status path.
class _TestableIdempotencyStore implements IdempotencyStore {
  final InMemoryIdempotencyStore _inner = InMemoryIdempotencyStore();
  IdempotencyRecord? _overrideRecord;

  void setOverrideRecord(IdempotencyRecord record) {
    _overrideRecord = record;
  }

  void clearOverride() {
    _overrideRecord = null;
  }

  @override
  Future<IdempotencyRecord?> get(String eventId) async {
    if (_overrideRecord != null && _overrideRecord!.eventId == eventId) {
      final record = _overrideRecord;
      // Clear after first get so subsequent calls go through normally
      _overrideRecord = null;
      return record;
    }
    return _inner.get(eventId);
  }

  @override
  Future<bool> tryAcquire(
    String eventId, {
    required String lockHolder,
    required Duration lockTimeout,
    required Duration recordTtl,
  }) {
    return _inner.tryAcquire(
      eventId,
      lockHolder: lockHolder,
      lockTimeout: lockTimeout,
      recordTtl: recordTtl,
    );
  }

  @override
  Future<void> complete(String eventId, IdempotencyResult result) {
    return _inner.complete(eventId, result);
  }

  @override
  Future<void> fail(String eventId, String error) {
    return _inner.fail(eventId, error);
  }

  @override
  Future<void> release(String eventId) {
    return _inner.release(eventId);
  }

  @override
  Future<int> cleanup() {
    return _inner.cleanup();
  }
}

void main() {
  // Shared test fixtures
  final channelIdentity = ChannelIdentity(
    platform: 'slack',
    channelId: 'T123',
  );

  final conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'C456',
    userId: 'U123',
  );

  // ---------------------------------------------------------------------------
  // IdempotencyStatus
  // ---------------------------------------------------------------------------
  group('IdempotencyStatus', () {
    test('has all 4 values', () {
      expect(IdempotencyStatus.values, hasLength(4));
      expect(IdempotencyStatus.values, contains(IdempotencyStatus.processing));
      expect(IdempotencyStatus.values, contains(IdempotencyStatus.completed));
      expect(IdempotencyStatus.values, contains(IdempotencyStatus.failed));
      expect(IdempotencyStatus.values, contains(IdempotencyStatus.expired));
    });

    test('name returns correct string for each value', () {
      expect(IdempotencyStatus.processing.name, 'processing');
      expect(IdempotencyStatus.completed.name, 'completed');
      expect(IdempotencyStatus.failed.name, 'failed');
      expect(IdempotencyStatus.expired.name, 'expired');
    });
  });

  // ---------------------------------------------------------------------------
  // IdempotencyConfig
  // ---------------------------------------------------------------------------
  group('IdempotencyConfig', () {
    test('constructor with defaults', () {
      const config = IdempotencyConfig();
      expect(config.recordTtl, const Duration(hours: 24));
      expect(config.lockTimeout, const Duration(minutes: 5));
      expect(config.retryFailed, isFalse);
      expect(config.cleanupInterval, const Duration(hours: 1));
    });

    test('constructor with custom values', () {
      final config = IdempotencyConfig(
        recordTtl: const Duration(hours: 1),
        lockTimeout: const Duration(seconds: 30),
        retryFailed: true,
        cleanupInterval: const Duration(minutes: 10),
      );
      expect(config.recordTtl, const Duration(hours: 1));
      expect(config.lockTimeout, const Duration(seconds: 30));
      expect(config.retryFailed, isTrue);
      expect(config.cleanupInterval, const Duration(minutes: 10));
    });

    test('copyWith all fields', () {
      const config = IdempotencyConfig();
      final copied = config.copyWith(
        recordTtl: const Duration(hours: 2),
        lockTimeout: const Duration(minutes: 10),
        retryFailed: true,
        cleanupInterval: const Duration(minutes: 30),
      );
      expect(copied.recordTtl, const Duration(hours: 2));
      expect(copied.lockTimeout, const Duration(minutes: 10));
      expect(copied.retryFailed, isTrue);
      expect(copied.cleanupInterval, const Duration(minutes: 30));
    });

    test('copyWith no fields preserves original', () {
      final config = IdempotencyConfig(
        recordTtl: const Duration(hours: 5),
        lockTimeout: const Duration(minutes: 3),
        retryFailed: true,
        cleanupInterval: const Duration(minutes: 20),
      );
      final copied = config.copyWith();
      expect(copied.recordTtl, config.recordTtl);
      expect(copied.lockTimeout, config.lockTimeout);
      expect(copied.retryFailed, config.retryFailed);
      expect(copied.cleanupInterval, config.cleanupInterval);
    });

    test('copyWith individual fields', () {
      const config = IdempotencyConfig();

      final withRecordTtl =
          config.copyWith(recordTtl: const Duration(hours: 48));
      expect(withRecordTtl.recordTtl, const Duration(hours: 48));
      expect(withRecordTtl.lockTimeout, config.lockTimeout);

      final withLockTimeout =
          config.copyWith(lockTimeout: const Duration(minutes: 1));
      expect(withLockTimeout.lockTimeout, const Duration(minutes: 1));
      expect(withLockTimeout.recordTtl, config.recordTtl);

      final withRetryFailed = config.copyWith(retryFailed: true);
      expect(withRetryFailed.retryFailed, isTrue);
      expect(withRetryFailed.cleanupInterval, config.cleanupInterval);

      final withCleanupInterval =
          config.copyWith(cleanupInterval: const Duration(minutes: 5));
      expect(withCleanupInterval.cleanupInterval, const Duration(minutes: 5));
      expect(withCleanupInterval.retryFailed, config.retryFailed);
    });
  });

  // ---------------------------------------------------------------------------
  // IdempotencyRecord
  // ---------------------------------------------------------------------------
  group('IdempotencyRecord', () {
    final now = DateTime.now();
    final future = now.add(const Duration(hours: 1));
    final past = now.subtract(const Duration(hours: 1));

    test('constructor sets all required fields', () {
      final record = IdempotencyRecord(
        eventId: 'evt-1',
        status: IdempotencyStatus.processing,
        createdAt: now,
        expiresAt: future,
      );
      expect(record.eventId, 'evt-1');
      expect(record.status, IdempotencyStatus.processing);
      expect(record.result, isNull);
      expect(record.createdAt, now);
      expect(record.completedAt, isNull);
      expect(record.expiresAt, future);
      expect(record.lockHolder, isNull);
      expect(record.lockExpiresAt, isNull);
    });

    test('constructor with all optional fields', () {
      final result = IdempotencyResult.success();
      final lockExpiry = now.add(const Duration(minutes: 5));
      final record = IdempotencyRecord(
        eventId: 'evt-2',
        status: IdempotencyStatus.completed,
        result: result,
        createdAt: now,
        completedAt: now,
        expiresAt: future,
        lockHolder: 'instance-1',
        lockExpiresAt: lockExpiry,
      );
      expect(record.result, result);
      expect(record.completedAt, now);
      expect(record.lockHolder, 'instance-1');
      expect(record.lockExpiresAt, lockExpiry);
    });

    group('fromJson', () {
      test('with all fields', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final result =
            IdempotencyResult.success(response: response);
        final json = {
          'eventId': 'evt-100',
          'status': 'completed',
          'result': result.toJson(),
          'createdAt': now.toIso8601String(),
          'completedAt': now.toIso8601String(),
          'expiresAt': future.toIso8601String(),
          'lockHolder': 'instance-A',
          'lockExpiresAt': future.toIso8601String(),
        };

        final record = IdempotencyRecord.fromJson(json);
        expect(record.eventId, 'evt-100');
        expect(record.status, IdempotencyStatus.completed);
        expect(record.result, isNotNull);
        expect(record.result!.success, isTrue);
        expect(record.createdAt.toIso8601String(), now.toIso8601String());
        expect(record.completedAt, isNotNull);
        expect(record.expiresAt.toIso8601String(), future.toIso8601String());
        expect(record.lockHolder, 'instance-A');
        expect(record.lockExpiresAt, isNotNull);
      });

      test('with minimal fields', () {
        final json = {
          'eventId': 'evt-200',
          'status': 'processing',
          'createdAt': now.toIso8601String(),
          'expiresAt': future.toIso8601String(),
        };

        final record = IdempotencyRecord.fromJson(json);
        expect(record.eventId, 'evt-200');
        expect(record.status, IdempotencyStatus.processing);
        expect(record.result, isNull);
        expect(record.completedAt, isNull);
        expect(record.lockHolder, isNull);
        expect(record.lockExpiresAt, isNull);
      });

      test('with unknown status falls back to expired', () {
        final json = {
          'eventId': 'evt-300',
          'status': 'unknown_status_xyz',
          'createdAt': now.toIso8601String(),
          'expiresAt': future.toIso8601String(),
        };

        final record = IdempotencyRecord.fromJson(json);
        expect(record.status, IdempotencyStatus.expired);
      });

      test('parses all 4 DateTime fields', () {
        final createdAt = DateTime(2025, 1, 1, 10, 0, 0);
        final completedAt = DateTime(2025, 1, 1, 10, 1, 0);
        final expiresAt = DateTime(2025, 1, 2, 10, 0, 0);
        final lockExpiresAt = DateTime(2025, 1, 1, 10, 5, 0);

        final json = {
          'eventId': 'evt-400',
          'status': 'completed',
          'createdAt': createdAt.toIso8601String(),
          'completedAt': completedAt.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
          'lockExpiresAt': lockExpiresAt.toIso8601String(),
        };

        final record = IdempotencyRecord.fromJson(json);
        expect(record.createdAt, createdAt);
        expect(record.completedAt, completedAt);
        expect(record.expiresAt, expiresAt);
        expect(record.lockExpiresAt, lockExpiresAt);
      });

      test('with result parsing', () {
        final json = {
          'eventId': 'evt-500',
          'status': 'completed',
          'result': {
            'success': true,
          },
          'createdAt': now.toIso8601String(),
          'expiresAt': future.toIso8601String(),
        };

        final record = IdempotencyRecord.fromJson(json);
        expect(record.result, isNotNull);
        expect(record.result!.success, isTrue);
      });

      test('with null result', () {
        final json = {
          'eventId': 'evt-600',
          'status': 'processing',
          'result': null,
          'createdAt': now.toIso8601String(),
          'expiresAt': future.toIso8601String(),
        };

        final record = IdempotencyRecord.fromJson(json);
        expect(record.result, isNull);
      });
    });

    group('toJson', () {
      test('with all optional fields present', () {
        final result = IdempotencyResult.success();
        final lockExpiry = now.add(const Duration(minutes: 5));
        final record = IdempotencyRecord(
          eventId: 'evt-700',
          status: IdempotencyStatus.completed,
          result: result,
          createdAt: now,
          completedAt: now,
          expiresAt: future,
          lockHolder: 'holder-1',
          lockExpiresAt: lockExpiry,
        );

        final json = record.toJson();
        expect(json['eventId'], 'evt-700');
        expect(json['status'], 'completed');
        expect(json['result'], isNotNull);
        expect(json['createdAt'], now.toIso8601String());
        expect(json['completedAt'], now.toIso8601String());
        expect(json['expiresAt'], future.toIso8601String());
        expect(json['lockHolder'], 'holder-1');
        expect(json['lockExpiresAt'], lockExpiry.toIso8601String());
      });

      test('without optional fields', () {
        final record = IdempotencyRecord(
          eventId: 'evt-800',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
        );

        final json = record.toJson();
        expect(json['eventId'], 'evt-800');
        expect(json['status'], 'processing');
        expect(json.containsKey('result'), isFalse);
        expect(json.containsKey('completedAt'), isFalse);
        expect(json.containsKey('lockHolder'), isFalse);
        expect(json.containsKey('lockExpiresAt'), isFalse);
      });
    });

    group('isLockValid', () {
      test('returns true when lockExpiresAt is in the future', () {
        final record = IdempotencyRecord(
          eventId: 'evt-lock1',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
          lockExpiresAt: now.add(const Duration(hours: 2)),
        );
        expect(record.isLockValid, isTrue);
      });

      test('returns false when lockExpiresAt is in the past', () {
        final record = IdempotencyRecord(
          eventId: 'evt-lock2',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
          lockExpiresAt: past,
        );
        expect(record.isLockValid, isFalse);
      });

      test('returns false when lockExpiresAt is null', () {
        final record = IdempotencyRecord(
          eventId: 'evt-lock3',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
        );
        expect(record.isLockValid, isFalse);
      });
    });

    group('isExpired', () {
      test('returns true when expiresAt is in the past', () {
        final record = IdempotencyRecord(
          eventId: 'evt-exp1',
          status: IdempotencyStatus.processing,
          createdAt: past,
          expiresAt: past,
        );
        expect(record.isExpired, isTrue);
      });

      test('returns false when expiresAt is in the future', () {
        final record = IdempotencyRecord(
          eventId: 'evt-exp2',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
        );
        expect(record.isExpired, isFalse);
      });
    });

    group('copyWith', () {
      test('copies all fields', () {
        final original = IdempotencyRecord(
          eventId: 'evt-cw1',
          status: IdempotencyStatus.processing,
          createdAt: now,
          expiresAt: future,
        );

        final newResult = IdempotencyResult.success();
        final copied = original.copyWith(
          eventId: 'evt-cw2',
          status: IdempotencyStatus.completed,
          result: newResult,
          createdAt: past,
          completedAt: now,
          expiresAt: future.add(const Duration(hours: 1)),
          lockHolder: 'new-holder',
          lockExpiresAt: future,
        );

        expect(copied.eventId, 'evt-cw2');
        expect(copied.status, IdempotencyStatus.completed);
        expect(copied.result, newResult);
        expect(copied.createdAt, past);
        expect(copied.completedAt, now);
        expect(copied.expiresAt, future.add(const Duration(hours: 1)));
        expect(copied.lockHolder, 'new-holder');
        expect(copied.lockExpiresAt, future);
      });

      test('preserves original when no fields provided', () {
        final original = IdempotencyRecord(
          eventId: 'evt-cw3',
          status: IdempotencyStatus.failed,
          result: IdempotencyResult.failure(error: 'err'),
          createdAt: now,
          completedAt: now,
          expiresAt: future,
          lockHolder: 'holder-orig',
          lockExpiresAt: future,
        );

        final copied = original.copyWith();
        expect(copied.eventId, original.eventId);
        expect(copied.status, original.status);
        expect(copied.result, original.result);
        expect(copied.createdAt, original.createdAt);
        expect(copied.completedAt, original.completedAt);
        expect(copied.expiresAt, original.expiresAt);
        expect(copied.lockHolder, original.lockHolder);
        expect(copied.lockExpiresAt, original.lockExpiresAt);
      });
    });

    test('toString returns correct format', () {
      final record = IdempotencyRecord(
        eventId: 'evt-ts',
        status: IdempotencyStatus.completed,
        createdAt: now,
        expiresAt: future,
      );
      expect(
        record.toString(),
        'IdempotencyRecord(eventId: evt-ts, status: completed)',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // IdempotencyResult
  // ---------------------------------------------------------------------------
  group('IdempotencyResult', () {
    test('constructor with required success field', () {
      const result = IdempotencyResult(success: true);
      expect(result.success, isTrue);
      expect(result.response, isNull);
      expect(result.error, isNull);
      expect(result.data, isNull);
    });

    test('constructor with all fields', () {
      final response = ChannelResponse.text(
        conversation: conversation,
        text: 'Test',
      );
      final result = IdempotencyResult(
        success: true,
        response: response,
        error: 'some-error',
        data: {'key': 'value'},
      );
      expect(result.success, isTrue);
      expect(result.response, response);
      expect(result.error, 'some-error');
      expect(result.data, {'key': 'value'});
    });

    group('success factory', () {
      test('without arguments', () {
        final result = IdempotencyResult.success();
        expect(result.success, isTrue);
        expect(result.response, isNull);
        expect(result.data, isNull);
      });

      test('with response', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Test',
        );
        final result = IdempotencyResult.success(response: response);
        expect(result.success, isTrue);
        expect(result.response, response);
      });

      test('with data', () {
        final result = IdempotencyResult.success(
          data: {'foo': 'bar'},
        );
        expect(result.success, isTrue);
        expect(result.data, {'foo': 'bar'});
      });

      test('with response and data', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Test',
        );
        final result = IdempotencyResult.success(
          response: response,
          data: {'key': 42},
        );
        expect(result.success, isTrue);
        expect(result.response, response);
        expect(result.data, {'key': 42});
      });
    });

    group('failure factory', () {
      test('with error only', () {
        final result = IdempotencyResult.failure(error: 'Something broke');
        expect(result.success, isFalse);
        expect(result.error, 'Something broke');
        expect(result.data, isNull);
      });

      test('with error and data', () {
        final result = IdempotencyResult.failure(
          error: 'broken',
          data: {'detail': 'info'},
        );
        expect(result.success, isFalse);
        expect(result.error, 'broken');
        expect(result.data, {'detail': 'info'});
      });
    });

    group('fromJson', () {
      test('with success and no optional fields', () {
        final json = {'success': true};
        final result = IdempotencyResult.fromJson(json);
        expect(result.success, isTrue);
        expect(result.response, isNull);
        expect(result.error, isNull);
        expect(result.data, isNull);
      });

      test('with success and response', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final json = {
          'success': true,
          'response': response.toJson(),
        };
        final result = IdempotencyResult.fromJson(json);
        expect(result.success, isTrue);
        expect(result.response, isNotNull);
        expect(result.response!.text, 'Hello');
      });

      test('with failure and error', () {
        final json = {
          'success': false,
          'error': 'Something failed',
        };
        final result = IdempotencyResult.fromJson(json);
        expect(result.success, isFalse);
        expect(result.error, 'Something failed');
      });

      test('with data', () {
        final json = {
          'success': true,
          'data': {'metric': 100},
        };
        final result = IdempotencyResult.fromJson(json);
        expect(result.success, isTrue);
        expect(result.data, {'metric': 100});
      });

      test('with all fields', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Full',
        );
        final json = {
          'success': false,
          'response': response.toJson(),
          'error': 'partial error',
          'data': {'extra': true},
        };
        final result = IdempotencyResult.fromJson(json);
        expect(result.success, isFalse);
        expect(result.response, isNotNull);
        expect(result.error, 'partial error');
        expect(result.data, {'extra': true});
      });
    });

    group('toJson', () {
      test('with success only', () {
        final result = IdempotencyResult.success();
        final json = result.toJson();
        expect(json['success'], isTrue);
        expect(json.containsKey('response'), isFalse);
        expect(json.containsKey('error'), isFalse);
        expect(json.containsKey('data'), isFalse);
      });

      test('with all optional fields', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'resp',
        );
        final result = IdempotencyResult(
          success: false,
          response: response,
          error: 'err',
          data: {'k': 'v'},
        );
        final json = result.toJson();
        expect(json['success'], isFalse);
        expect(json['response'], isNotNull);
        expect(json['error'], 'err');
        expect(json['data'], {'k': 'v'});
      });
    });

    group('toString', () {
      test('success case', () {
        final result = IdempotencyResult.success();
        expect(result.toString(), 'IdempotencyResult.success()');
      });

      test('failure case', () {
        final result = IdempotencyResult.failure(error: 'bad input');
        expect(
          result.toString(),
          'IdempotencyResult.failure(error: bad input)',
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // InMemoryIdempotencyStore
  // ---------------------------------------------------------------------------
  group('InMemoryIdempotencyStore', () {
    late InMemoryIdempotencyStore store;

    setUp(() {
      store = InMemoryIdempotencyStore();
    });

    group('get', () {
      test('returns null for non-existing event', () async {
        final result = await store.get('non-existent');
        expect(result, isNull);
      });

      test('returns record for existing event', () async {
        await store.tryAcquire(
          'evt-1',
          lockHolder: 'holder-1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        final result = await store.get('evt-1');
        expect(result, isNotNull);
        expect(result!.eventId, 'evt-1');
        expect(result.status, IdempotencyStatus.processing);
      });

      test('returns null and removes expired record', () async {
        // Acquire with very short TTL
        await store.tryAcquire(
          'evt-expire',
          lockHolder: 'holder-1',
          lockTimeout: const Duration(milliseconds: 1),
          recordTtl: const Duration(milliseconds: 1),
        );

        // Wait for expiration
        await Future.delayed(const Duration(milliseconds: 10));

        final result = await store.get('evt-expire');
        expect(result, isNull);

        // Verify it was removed
        expect(store.count, 0);
      });
    });

    group('tryAcquire', () {
      test('returns true for new event', () async {
        final acquired = await store.tryAcquire(
          'new-evt',
          lockHolder: 'holder-1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        expect(acquired, isTrue);
        expect(store.count, 1);
      });

      test('returns false when processing with valid lock', () async {
        await store.tryAcquire(
          'busy-evt',
          lockHolder: 'holder-1',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );

        final secondAttempt = await store.tryAcquire(
          'busy-evt',
          lockHolder: 'holder-2',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );
        expect(secondAttempt, isFalse);
      });

      test('returns true when processing with expired lock', () async {
        await store.tryAcquire(
          'stale-evt',
          lockHolder: 'holder-1',
          lockTimeout: const Duration(milliseconds: 1),
          recordTtl: const Duration(hours: 24),
        );

        // Wait for lock to expire
        await Future.delayed(const Duration(milliseconds: 10));

        final secondAttempt = await store.tryAcquire(
          'stale-evt',
          lockHolder: 'holder-2',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );
        expect(secondAttempt, isTrue);

        final record = await store.get('stale-evt');
        expect(record!.lockHolder, 'holder-2');
      });
    });

    group('complete', () {
      test('completes existing record', () async {
        await store.tryAcquire(
          'evt-c',
          lockHolder: 'h1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );

        final result = IdempotencyResult.success();
        await store.complete('evt-c', result);

        final record = await store.get('evt-c');
        expect(record, isNotNull);
        expect(record!.status, IdempotencyStatus.completed);
        expect(record.result, isNotNull);
        expect(record.result!.success, isTrue);
        expect(record.completedAt, isNotNull);
      });

      test('no-op for non-existing event', () async {
        // Should not throw
        await store.complete('non-existent', IdempotencyResult.success());
        expect(store.count, 0);
      });
    });

    group('fail', () {
      test('marks existing record as failed', () async {
        await store.tryAcquire(
          'evt-f',
          lockHolder: 'h1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );

        await store.fail('evt-f', 'Something went wrong');

        final record = await store.get('evt-f');
        expect(record, isNotNull);
        expect(record!.status, IdempotencyStatus.failed);
        expect(record.result, isNotNull);
        expect(record.result!.success, isFalse);
        expect(record.result!.error, 'Something went wrong');
        expect(record.completedAt, isNotNull);
      });

      test('no-op for non-existing event', () async {
        await store.fail('non-existent', 'error');
        expect(store.count, 0);
      });
    });

    group('release', () {
      test('removes existing record', () async {
        await store.tryAcquire(
          'evt-r',
          lockHolder: 'h1',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );
        expect(store.count, 1);

        await store.release('evt-r');
        expect(store.count, 0);
        expect(await store.get('evt-r'), isNull);
      });
    });

    group('cleanup', () {
      test('removes expired records and returns count', () async {
        // Create record that will expire quickly
        await store.tryAcquire(
          'evt-x1',
          lockHolder: 'h1',
          lockTimeout: const Duration(milliseconds: 1),
          recordTtl: const Duration(milliseconds: 1),
        );
        await store.tryAcquire(
          'evt-x2',
          lockHolder: 'h1',
          lockTimeout: const Duration(milliseconds: 1),
          recordTtl: const Duration(milliseconds: 1),
        );
        // Create record that will NOT expire
        await store.tryAcquire(
          'evt-valid',
          lockHolder: 'h1',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );

        expect(store.count, 3);

        // Wait for expiration
        await Future.delayed(const Duration(milliseconds: 10));

        final removed = await store.cleanup();
        expect(removed, 2);
        expect(store.count, 1);
      });

      test('returns 0 when no expired records', () async {
        await store.tryAcquire(
          'evt-live',
          lockHolder: 'h1',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );

        final removed = await store.cleanup();
        expect(removed, 0);
        expect(store.count, 1);
      });
    });

    group('clear', () {
      test('removes all records', () async {
        await store.tryAcquire(
          'a',
          lockHolder: 'h1',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );
        await store.tryAcquire(
          'b',
          lockHolder: 'h1',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );
        expect(store.count, 2);

        store.clear();
        expect(store.count, 0);
      });
    });

    group('count', () {
      test('returns correct count', () async {
        expect(store.count, 0);

        await store.tryAcquire(
          'x1',
          lockHolder: 'h',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );
        expect(store.count, 1);

        await store.tryAcquire(
          'x2',
          lockHolder: 'h',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );
        expect(store.count, 2);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // IdempotencyGuard
  // ---------------------------------------------------------------------------
  group('IdempotencyGuard', () {
    late InMemoryIdempotencyStore store;
    late IdempotencyGuard guard;

    setUp(() {
      store = InMemoryIdempotencyStore();
      guard = IdempotencyGuard(store);
    });

    tearDown(() {
      guard.dispose();
    });

    test('instanceId getter returns a string', () {
      expect(guard.instanceId, isA<String>());
      expect(guard.instanceId.isNotEmpty, isTrue);
    });

    test('custom instanceId is used', () {
      final customGuard = IdempotencyGuard(
        store,
        instanceId: 'my-instance',
      );
      expect(customGuard.instanceId, 'my-instance');
      customGuard.dispose();
    });

    group('process', () {
      test('delegates to processWithKey with event.id', () async {
        final event = ChannelEvent.message(
          id: 'evt_123',
          conversation: conversation,
          text: 'Test',
          userId: 'U123',
        );

        var processorCalled = false;

        final result = await guard.process(event, () async {
          processorCalled = true;
          return IdempotencyResult.success(
            response: ChannelResponse.text(
              conversation: conversation,
              text: 'Response',
            ),
          );
        });

        expect(processorCalled, isTrue);
        expect(result.success, isTrue);
        expect(result.response, isNotNull);
      });
    });

    group('processWithKey', () {
      test('new event: acquires lock, processes, completes', () async {
        final result = await guard.processWithKey('key-new', () async {
          return IdempotencyResult.success(
            response: ChannelResponse.text(
              conversation: conversation,
              text: 'Done',
            ),
          );
        });

        expect(result.success, isTrue);
        expect(result.response!.text, 'Done');

        // Verify stored as completed
        final record = await store.get('key-new');
        expect(record!.status, IdempotencyStatus.completed);
      });

      test('completed event: returns cached result immediately', () async {
        // First call
        await guard.processWithKey('key-cached', () async {
          return IdempotencyResult.success(
            response: ChannelResponse.text(
              conversation: conversation,
              text: 'Original',
            ),
          );
        });

        // Second call - processor should not be called
        var secondProcessorCalled = false;
        final result = await guard.processWithKey('key-cached', () async {
          secondProcessorCalled = true;
          return IdempotencyResult.success(
            response: ChannelResponse.text(
              conversation: conversation,
              text: 'Different',
            ),
          );
        });

        expect(secondProcessorCalled, isFalse);
        expect(result.success, isTrue);
        expect(result.response!.text, 'Original');
      });

      test('failed event with retryFailed=false: returns failure', () async {
        final failGuard = IdempotencyGuard(
          store,
          config: const IdempotencyConfig(retryFailed: false),
        );

        // First call - fails
        await failGuard.processWithKey('key-fail', () async {
          throw Exception('Boom');
        });

        // Second call - should return failure without processing
        var secondCalled = false;
        final result = await failGuard.processWithKey('key-fail', () async {
          secondCalled = true;
          return IdempotencyResult.success();
        });

        expect(secondCalled, isFalse);
        expect(result.success, isFalse);
        expect(result.error, contains('Event previously failed'));

        failGuard.dispose();
      });

      test('failed event with retryFailed=true: allows reprocessing', () async {
        final retryGuard = IdempotencyGuard(
          store,
          config: const IdempotencyConfig(retryFailed: true),
        );

        // First call - fails
        await retryGuard.processWithKey('key-retry', () async {
          throw Exception('Fail first');
        });

        // Second call - should retry
        var secondCalled = false;
        final result = await retryGuard.processWithKey('key-retry', () async {
          secondCalled = true;
          return IdempotencyResult.success();
        });

        expect(secondCalled, isTrue);
        expect(result.success, isTrue);

        retryGuard.dispose();
      });

      test('processing event with valid lock: returns "being processed" failure',
          () async {
        // Manually acquire lock with long timeout
        await store.tryAcquire(
          'key-locked',
          lockHolder: 'other-instance',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );

        final result = await guard.processWithKey('key-locked', () async {
          return IdempotencyResult.success();
        });

        expect(result.success, isFalse);
        expect(result.error, contains('being processed'));
      });

      test('processing event with expired lock: allows reprocessing', () async {
        // Manually acquire lock with very short timeout
        await store.tryAcquire(
          'key-stale-lock',
          lockHolder: 'other-instance',
          lockTimeout: const Duration(milliseconds: 1),
          recordTtl: const Duration(hours: 24),
        );

        // Wait for lock to expire
        await Future.delayed(const Duration(milliseconds: 10));

        var processed = false;
        final result = await guard.processWithKey('key-stale-lock', () async {
          processed = true;
          return IdempotencyResult.success();
        });

        expect(processed, isTrue);
        expect(result.success, isTrue);
      });

      test('expired event: allows reprocessing', () async {
        // Use a testable store that can inject a record with expired status
        // but a future expiresAt (so get() does not auto-remove it).
        final testStore = _TestableIdempotencyStore();
        final expiredGuard = IdempotencyGuard(testStore);

        // Inject a record with IdempotencyStatus.expired and expiresAt in future
        testStore.setOverrideRecord(IdempotencyRecord(
          eventId: 'key-expired',
          status: IdempotencyStatus.expired,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ));

        var processed = false;
        final result =
            await expiredGuard.processWithKey('key-expired', () async {
          processed = true;
          return IdempotencyResult.success();
        });

        expect(processed, isTrue);
        expect(result.success, isTrue);

        expiredGuard.dispose();
      });

      test('lock acquisition failure: returns failure', () async {
        // First acquire with valid lock
        await store.tryAcquire(
          'key-acq-fail',
          lockHolder: 'other',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );

        // Guard tries to get, sees processing with valid lock, returns failure
        final result = await guard.processWithKey('key-acq-fail', () async {
          return IdempotencyResult.success();
        });

        expect(result.success, isFalse);
        expect(result.error, contains('being processed'));
      });

      test('processor throws exception: stores failure, returns failure',
          () async {
        final result = await guard.processWithKey('key-throw', () async {
          throw Exception('Processing failed');
        });

        expect(result.success, isFalse);
        expect(result.error, contains('Processing error'));
        expect(result.error, contains('Processing failed'));

        // Verify stored as failed
        final record = await store.get('key-throw');
        expect(record!.status, IdempotencyStatus.failed);
      });
    });

    group('isProcessed', () {
      test('returns true for completed event', () async {
        await guard.processWithKey('key-done', () async {
          return IdempotencyResult.success();
        });

        final processed = await guard.isProcessed('key-done');
        expect(processed, isTrue);
      });

      test('returns false for non-completed event', () async {
        // Still processing (acquired but not completed)
        await store.tryAcquire(
          'key-processing',
          lockHolder: 'h',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );

        final processed = await guard.isProcessed('key-processing');
        expect(processed, isFalse);
      });

      test('returns false for non-existing event', () async {
        final processed = await guard.isProcessed('key-unknown');
        expect(processed, isFalse);
      });
    });

    group('getResult', () {
      test('returns result for completed event', () async {
        await guard.processWithKey('key-res', () async {
          return IdempotencyResult.success(
            response: ChannelResponse.text(
              conversation: conversation,
              text: 'Result',
            ),
          );
        });

        final result = await guard.getResult('key-res');
        expect(result, isNotNull);
        expect(result!.success, isTrue);
        expect(result.response!.text, 'Result');
      });

      test('returns null for non-completed event', () async {
        await store.tryAcquire(
          'key-nc',
          lockHolder: 'h',
          lockTimeout: const Duration(hours: 1),
          recordTtl: const Duration(hours: 24),
        );

        final result = await guard.getResult('key-nc');
        expect(result, isNull);
      });

      test('returns null for non-existing event', () async {
        final result = await guard.getResult('key-missing');
        expect(result, isNull);
      });
    });

    group('cleanup lifecycle', () {
      test('startCleanup creates periodic timer', () async {
        guard.startCleanup();
        // No exception means success; cleanup should be running

        // Call again to test the cancel-before-create path
        guard.startCleanup();

        guard.stopCleanup();
      });

      test('stopCleanup cancels timer', () {
        guard.startCleanup();
        guard.stopCleanup();
        // Should not throw if called again
        guard.stopCleanup();
      });

      test('cleanup delegates to store', () async {
        await store.tryAcquire(
          'cleanup-evt',
          lockHolder: 'h',
          lockTimeout: const Duration(milliseconds: 1),
          recordTtl: const Duration(milliseconds: 1),
        );

        await Future.delayed(const Duration(milliseconds: 10));

        final removed = await guard.cleanup();
        expect(removed, 1);
      });

      test('dispose stops cleanup', () {
        guard.startCleanup();
        guard.dispose();
        // Should not throw; dispose calls stopCleanup
      });
    });
  });

  // ---------------------------------------------------------------------------
  // IdempotencyGuard with custom config
  // ---------------------------------------------------------------------------
  group('IdempotencyGuard with custom config', () {
    test('uses provided config', () {
      final store = InMemoryIdempotencyStore();
      final config = IdempotencyConfig(
        recordTtl: const Duration(hours: 2),
        lockTimeout: const Duration(seconds: 30),
        retryFailed: true,
        cleanupInterval: const Duration(minutes: 10),
      );
      final guard = IdempotencyGuard(store, config: config);
      expect(guard.instanceId, isA<String>());
      guard.dispose();
    });
  });
}
