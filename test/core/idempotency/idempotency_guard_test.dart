import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  final channelIdentity = ChannelIdentity(
    platform: 'slack',
    channelId: 'T123',
  );

  final conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'C456',
    userId: 'U123',
  );

  ChannelEvent makeEvent({String id = 'evt_1'}) {
    return ChannelEvent.message(
      id: id,
      conversation: conversation,
      text: 'hello',
      userId: 'U123',
    );
  }

  late InMemoryIdempotencyStore store;
  late IdempotencyGuard guard;

  setUp(() {
    store = InMemoryIdempotencyStore();
    guard = IdempotencyGuard(store, instanceId: 'instance_1');
  });

  tearDown(() {
    guard.dispose();
  });

  group('IdempotencyGuard', () {
    test('instanceId is set', () {
      expect(guard.instanceId, 'instance_1');
    });

    test('auto-generates instanceId if not provided', () {
      final g = IdempotencyGuard(store);
      expect(g.instanceId, isNotEmpty);
      g.dispose();
    });

    group('process', () {
      test('processes new event successfully', () async {
        final result = await guard.process(
          makeEvent(),
          () async => IdempotencyResult.success(data: {'count': 1}),
        );

        expect(result.success, true);
        expect(result.data?['count'], 1);
      });

      test('returns cached result for completed event', () async {
        // First processing
        await guard.process(
          makeEvent(),
          () async => IdempotencyResult.success(data: {'first': true}),
        );

        // Second attempt - should return cached
        var processorCalled = false;
        final result = await guard.process(
          makeEvent(),
          () async {
            processorCalled = true;
            return IdempotencyResult.success(data: {'second': true});
          },
        );

        expect(processorCalled, false);
        expect(result.success, true);
        expect(result.data?['first'], true);
      });

      test('stores failure when processor throws', () async {
        final result = await guard.process(
          makeEvent(),
          () async => throw Exception('boom'),
        );

        expect(result.success, false);
        expect(result.error, contains('boom'));
      });
    });

    group('processWithKey', () {
      test('uses custom key', () async {
        final result = await guard.processWithKey(
          'custom_key_1',
          () async => IdempotencyResult.success(),
        );
        expect(result.success, true);

        // Same custom key returns cached
        var called = false;
        final cached = await guard.processWithKey(
          'custom_key_1',
          () async {
            called = true;
            return IdempotencyResult.success();
          },
        );
        expect(called, false);
        expect(cached.success, true);
      });
    });

    group('failed event handling', () {
      test('returns failure for previously failed event (retryFailed=false)',
          () async {
        // First: fail
        await guard.process(
          makeEvent(),
          () async => throw Exception('fail'),
        );

        // Second: should not retry
        final result = await guard.process(
          makeEvent(),
          () async => IdempotencyResult.success(),
        );

        expect(result.success, false);
        expect(result.error, contains('previously failed'));
      });

      test('retries failed event when retryFailed=true', () async {
        final retryGuard = IdempotencyGuard(
          store,
          config: const IdempotencyConfig(retryFailed: true),
          instanceId: 'inst_retry',
        );

        // First: fail
        await retryGuard.process(
          makeEvent(),
          () async => throw Exception('fail'),
        );

        // Second: retry should succeed
        final result = await retryGuard.process(
          makeEvent(),
          () async => IdempotencyResult.success(data: {'retried': true}),
        );

        expect(result.success, true);
        expect(result.data?['retried'], true);
        retryGuard.dispose();
      });
    });

    group('lock handling', () {
      test('rejects when lock held by another instance', () async {
        // Acquire lock from different instance
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'other_instance',
          lockTimeout: const Duration(minutes: 5),
          recordTtl: const Duration(hours: 24),
        );

        final result = await guard.process(
          makeEvent(),
          () async => IdempotencyResult.success(),
        );

        expect(result.success, false);
        expect(result.error, contains('being processed'));
      });

      test('retries when lock expired', () async {
        // Acquire lock with already-expired timeout
        await store.tryAcquire(
          'evt_1',
          lockHolder: 'other_instance',
          lockTimeout: Duration.zero,
          recordTtl: const Duration(hours: 24),
        );

        // Wait briefly for lock to expire
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final result = await guard.process(
          makeEvent(),
          () async => IdempotencyResult.success(data: {'recovered': true}),
        );

        expect(result.success, true);
      });
    });

    group('isProcessed', () {
      test('returns false for unknown event', () async {
        expect(await guard.isProcessed('unknown'), false);
      });

      test('returns true for completed event', () async {
        await guard.processWithKey(
          'evt_done',
          () async => IdempotencyResult.success(),
        );
        expect(await guard.isProcessed('evt_done'), true);
      });

      test('returns false for failed event', () async {
        await guard.processWithKey(
          'evt_fail',
          () async => throw Exception('fail'),
        );
        expect(await guard.isProcessed('evt_fail'), false);
      });
    });

    group('getResult', () {
      test('returns null for unknown event', () async {
        expect(await guard.getResult('unknown'), isNull);
      });

      test('returns result for completed event', () async {
        await guard.processWithKey(
          'evt_1',
          () async => IdempotencyResult.success(data: {'x': 1}),
        );
        final result = await guard.getResult('evt_1');
        expect(result, isNotNull);
        expect(result!.data?['x'], 1);
      });

      test('returns null for failed event', () async {
        await guard.processWithKey(
          'evt_1',
          () async => throw Exception('fail'),
        );
        expect(await guard.getResult('evt_1'), isNull);
      });
    });

    group('cleanup', () {
      test('delegates to store', () async {
        // Add record and expire it
        await store.tryAcquire(
          'old_evt',
          lockHolder: 'x',
          lockTimeout: Duration.zero,
          recordTtl: Duration.zero,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final removed = await guard.cleanup();
        expect(removed, 1);
      });

      test('startCleanup and stopCleanup manage timer', () {
        guard.startCleanup();
        guard.stopCleanup();
      });
    });
  });
}
