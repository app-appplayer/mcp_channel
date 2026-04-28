import 'dart:async';

import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Shared test fixtures
  const channel1 = ChannelIdentity(platform: 'test', channelId: 'ch1');
  const channel2 = ChannelIdentity(platform: 'test', channelId: 'ch2');

  const convKey1 = ConversationKey(
    channel: channel1,
    conversationId: 'conv1',
  );

  const convKey2 = ConversationKey(
    channel: channel1,
    conversationId: 'conv2',
  );

  const convKeyDifferentChannel = ConversationKey(
    channel: channel2,
    conversationId: 'conv1',
  );

  // =========================================================================
  // ConversationLock
  // =========================================================================
  group('ConversationLock', () {
    late ConversationLock lock;

    setUp(() {
      lock = ConversationLock();
    });

    group('withLock', () {
      test('executes single operation and returns result', () async {
        final result = await lock.withLock(convKey1, () async => 42);

        expect(result, 42);
      });

      test('sequential execution for same conversation', () async {
        // Two operations on the same conversation must execute sequentially.
        // We verify this by ensuring op2 does not start until op1 completes.
        final executionOrder = <String>[];
        final op1Started = Completer<void>();
        final op1Proceed = Completer<void>();

        // Start op1 but hold it until we explicitly release
        final future1 = lock.withLock(convKey1, () async {
          executionOrder.add('op1-start');
          op1Started.complete();
          await op1Proceed.future;
          executionOrder.add('op1-end');
          return 'first';
        });

        // Wait for op1 to actually start
        await op1Started.future;

        // Start op2 on the same conversation key
        final future2 = lock.withLock(convKey1, () async {
          executionOrder.add('op2-start');
          executionOrder.add('op2-end');
          return 'second';
        });

        // At this point op2 should be waiting because op1 holds the lock.
        // Give the event loop a chance to run.
        await Future<void>.delayed(Duration.zero);
        expect(executionOrder, ['op1-start']);

        // Release op1
        op1Proceed.complete();

        final result1 = await future1;
        final result2 = await future2;

        expect(result1, 'first');
        expect(result2, 'second');
        expect(executionOrder, [
          'op1-start',
          'op1-end',
          'op2-start',
          'op2-end',
        ]);
      });

      test('parallel execution for different conversations', () async {
        // Two operations on different conversations can execute concurrently.
        final op1Started = Completer<void>();
        final op2Started = Completer<void>();
        final op1Proceed = Completer<void>();
        final op2Proceed = Completer<void>();

        final future1 = lock.withLock(convKey1, () async {
          op1Started.complete();
          await op1Proceed.future;
          return 'conv1-result';
        });

        final future2 = lock.withLock(convKey2, () async {
          op2Started.complete();
          await op2Proceed.future;
          return 'conv2-result';
        });

        // Both operations should start without waiting for each other
        await op1Started.future;
        await op2Started.future;

        // Both are running concurrently; release them
        op1Proceed.complete();
        op2Proceed.complete();

        final result1 = await future1;
        final result2 = await future2;

        expect(result1, 'conv1-result');
        expect(result2, 'conv2-result');
      });

      test('parallel execution for different channel identities', () async {
        // Even if conversationId is the same, different channels are independent
        final op1Started = Completer<void>();
        final op2Started = Completer<void>();
        final op1Proceed = Completer<void>();
        final op2Proceed = Completer<void>();

        final future1 = lock.withLock(convKey1, () async {
          op1Started.complete();
          await op1Proceed.future;
          return 'channel1-result';
        });

        final future2 = lock.withLock(convKeyDifferentChannel, () async {
          op2Started.complete();
          await op2Proceed.future;
          return 'channel2-result';
        });

        // Both should start concurrently
        await op1Started.future;
        await op2Started.future;

        op1Proceed.complete();
        op2Proceed.complete();

        final result1 = await future1;
        final result2 = await future2;

        expect(result1, 'channel1-result');
        expect(result2, 'channel2-result');
      });

      test('lock released and error propagated when operation throws',
          () async {
        // First operation throws an error
        final error = StateError('test error');

        expect(
          () => lock.withLock(convKey1, () async => throw error),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            'test error',
          )),
        );

        // After the error, the lock should be released and a subsequent
        // operation on the same conversation should succeed
        final result = await lock.withLock(convKey1, () async => 'recovered');

        expect(result, 'recovered');
      });

      test('error in first operation does not block second operation',
          () async {
        final executionOrder = <String>[];
        final op1Started = Completer<void>();

        // op1: throws after starting
        final future1 = lock.withLock(convKey1, () async {
          executionOrder.add('op1-start');
          op1Started.complete();
          throw FormatException('op1 failed');
        });

        await op1Started.future;

        // op2: should execute after op1 releases the lock (even though op1 threw)
        final future2 = lock.withLock(convKey1, () async {
          executionOrder.add('op2-start');
          executionOrder.add('op2-end');
          return 'success';
        });

        // Await op1 and expect the error
        await expectLater(future1, throwsA(isA<FormatException>()));

        final result2 = await future2;

        expect(result2, 'success');
        expect(executionOrder, ['op1-start', 'op2-start', 'op2-end']);
      });

      test('multiple queued operations execute in order', () async {
        final executionOrder = <int>[];
        final op1Proceed = Completer<void>();

        // Hold op1 to queue up op2 and op3
        final future1 = lock.withLock(convKey1, () async {
          await op1Proceed.future;
          executionOrder.add(1);
          return 1;
        });

        final future2 = lock.withLock(convKey1, () async {
          executionOrder.add(2);
          return 2;
        });

        final future3 = lock.withLock(convKey1, () async {
          executionOrder.add(3);
          return 3;
        });

        // Release op1
        op1Proceed.complete();

        final results = await Future.wait([future1, future2, future3]);

        expect(results, [1, 2, 3]);
        expect(executionOrder, [1, 2, 3]);
      });
    });
  });
}
