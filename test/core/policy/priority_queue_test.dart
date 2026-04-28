import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Helper to create a mock ChannelResponse
  ChannelResponse makeResponse(String text) {
    return ChannelResponse(
      conversation: const ConversationKey(
        channel: ChannelIdentity(platform: 'test', channelId: 'ch1'),
        conversationId: 'conv1',
      ),
      type: 'text',
      text: text,
    );
  }

  group('MessagePriority', () {
    test('has all expected values', () {
      expect(MessagePriority.values, hasLength(4));
      expect(MessagePriority.critical, isNotNull);
      expect(MessagePriority.high, isNotNull);
      expect(MessagePriority.normal, isNotNull);
      expect(MessagePriority.low, isNotNull);
    });

    test('numeric values match priority ordering', () {
      expect(MessagePriority.critical.value, 0);
      expect(MessagePriority.high.value, 1);
      expect(MessagePriority.normal.value, 2);
      expect(MessagePriority.low.value, 3);
    });

    test('lower value means higher priority', () {
      expect(
        MessagePriority.critical.value < MessagePriority.high.value,
        isTrue,
      );
      expect(
        MessagePriority.high.value < MessagePriority.normal.value,
        isTrue,
      );
      expect(
        MessagePriority.normal.value < MessagePriority.low.value,
        isTrue,
      );
    });
  });

  group('QueuedMessage', () {
    test('constructor sets all fields', () {
      final now = DateTime(2024, 1, 1);
      final response = makeResponse('hello');
      final deadline = DateTime(2024, 1, 2);
      final msg = QueuedMessage(
        response: response,
        priority: MessagePriority.high,
        enqueuedAt: now,
        conversationKey: 'conv-1',
        userId: 'u-1',
        deadline: deadline,
      );

      expect(msg.response, response);
      expect(msg.priority, MessagePriority.high);
      expect(msg.enqueuedAt, now);
      expect(msg.conversationKey, 'conv-1');
      expect(msg.userId, 'u-1');
      expect(msg.deadline, deadline);
    });

    test('optional fields default to null', () {
      final msg = QueuedMessage(
        response: makeResponse('hello'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime(2024, 1, 1),
      );

      expect(msg.conversationKey, isNull);
      expect(msg.userId, isNull);
      expect(msg.deadline, isNull);
    });

    test('isExpired returns false when no deadline', () {
      final msg = QueuedMessage(
        response: makeResponse('hello'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime(2024, 1, 1),
      );

      expect(msg.isExpired, isFalse);
    });

    test('isExpired returns true when deadline passed', () {
      final msg = QueuedMessage(
        response: makeResponse('hello'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime(2024, 1, 1),
        deadline: DateTime(2020, 1, 1),
      );

      expect(msg.isExpired, isTrue);
    });

    test('isExpired returns false when deadline in future', () {
      final msg = QueuedMessage(
        response: makeResponse('hello'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime(2024, 1, 1),
        deadline: DateTime(2099, 1, 1),
      );

      expect(msg.isExpired, isFalse);
    });

    test('toString contains priority name', () {
      final msg = QueuedMessage(
        response: makeResponse('hello'),
        priority: MessagePriority.critical,
        enqueuedAt: DateTime(2024, 1, 1),
      );

      expect(msg.toString(), contains('critical'));
    });
  });

  group('PriorityMessageQueue - basic operations', () {
    late PriorityMessageQueue queue;

    setUp(() {
      queue = PriorityMessageQueue();
    });

    test('newly created queue is empty', () {
      expect(queue.isEmpty, isTrue);
      expect(queue.length, 0);
    });

    test('enqueue and dequeue single message', () {
      queue.enqueue(QueuedMessage(
        response: makeResponse('hello'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
      ));

      expect(queue.length, 1);
      expect(queue.isEmpty, isFalse);

      final result = queue.dequeue();
      expect(result, isNotNull);
      expect(result!.response.text, 'hello');
    });

    test('dequeue removes the message from the queue', () {
      queue.enqueue(QueuedMessage(
        response: makeResponse('msg'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
      ));
      expect(queue.length, 1);

      queue.dequeue();
      expect(queue.length, 0);
      expect(queue.isEmpty, isTrue);
    });

    test('dequeue returns null when empty', () {
      expect(queue.dequeue(), isNull);
    });
  });

  group('PriorityMessageQueue - priority ordering', () {
    late PriorityMessageQueue queue;

    setUp(() {
      queue = PriorityMessageQueue();
    });

    test('critical priority dequeues before high', () {
      queue.enqueue(QueuedMessage(
        response: makeResponse('high-msg'),
        priority: MessagePriority.high,
        enqueuedAt: DateTime.now(),
      ));
      queue.enqueue(QueuedMessage(
        response: makeResponse('critical-msg'),
        priority: MessagePriority.critical,
        enqueuedAt: DateTime.now(),
      ));

      final result = queue.dequeue();
      expect(result!.response.text, 'critical-msg');
    });

    test('full priority order: critical > high > normal > low', () {
      queue.enqueue(QueuedMessage(
        response: makeResponse('low'),
        priority: MessagePriority.low,
        enqueuedAt: DateTime.now(),
      ));
      queue.enqueue(QueuedMessage(
        response: makeResponse('normal'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
      ));
      queue.enqueue(QueuedMessage(
        response: makeResponse('high'),
        priority: MessagePriority.high,
        enqueuedAt: DateTime.now(),
      ));
      queue.enqueue(QueuedMessage(
        response: makeResponse('critical'),
        priority: MessagePriority.critical,
        enqueuedAt: DateTime.now(),
      ));

      expect(queue.dequeue()!.response.text, 'critical');
      expect(queue.dequeue()!.response.text, 'high');
      expect(queue.dequeue()!.response.text, 'normal');
      expect(queue.dequeue()!.response.text, 'low');
    });

    test('FIFO within same priority', () {
      queue.enqueue(QueuedMessage(
        response: makeResponse('first'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
      ));
      queue.enqueue(QueuedMessage(
        response: makeResponse('second'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
      ));
      queue.enqueue(QueuedMessage(
        response: makeResponse('third'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
      ));

      expect(queue.dequeue()!.response.text, 'first');
      expect(queue.dequeue()!.response.text, 'second');
      expect(queue.dequeue()!.response.text, 'third');
    });
  });

  group('PriorityMessageQueue - expiration handling', () {
    late PriorityMessageQueue queue;

    setUp(() {
      queue = PriorityMessageQueue();
    });

    test('dequeue skips expired messages', () {
      // Expired message
      queue.enqueue(QueuedMessage(
        response: makeResponse('expired'),
        priority: MessagePriority.critical,
        enqueuedAt: DateTime(2020, 1, 1),
        deadline: DateTime(2020, 1, 2),
      ));
      // Valid message
      queue.enqueue(QueuedMessage(
        response: makeResponse('valid'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
      ));

      final result = queue.dequeue();
      expect(result!.response.text, 'valid');
    });

    test('purgeExpired removes expired messages', () {
      queue.enqueue(QueuedMessage(
        response: makeResponse('expired-1'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime(2020, 1, 1),
        deadline: DateTime(2020, 1, 2),
      ));
      queue.enqueue(QueuedMessage(
        response: makeResponse('expired-2'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime(2020, 1, 1),
        deadline: DateTime(2020, 1, 3),
      ));
      queue.enqueue(QueuedMessage(
        response: makeResponse('valid'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
      ));

      final purged = queue.purgeExpired();
      expect(purged, 2);
      expect(queue.length, 1);
    });

    test('purgeExpired returns 0 when no expired messages', () {
      queue.enqueue(QueuedMessage(
        response: makeResponse('valid'),
        priority: MessagePriority.normal,
        enqueuedAt: DateTime.now(),
        deadline: DateTime(2099, 1, 1),
      ));

      final purged = queue.purgeExpired();
      expect(purged, 0);
      expect(queue.length, 1);
    });
  });
}
