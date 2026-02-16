import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('IdempotencyGuard', () {
    late InMemoryIdempotencyStore store;
    late IdempotencyGuard guard;

    final conversation = ConversationKey(
      channelType: 'slack',
      tenantId: 'T123',
      roomId: 'C456',
    );

    final identity = ChannelIdentity.user(id: 'U123');

    setUp(() {
      store = InMemoryIdempotencyStore();
      guard = IdempotencyGuard(store);
    });

    test('processes new event successfully', () async {
      final event = ChannelEvent.message(
        eventId: 'evt_123',
        channelType: 'slack',
        identity: identity,
        conversation: conversation,
        text: 'Test',
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

    test('returns cached result for duplicate event', () async {
      final event = ChannelEvent.message(
        eventId: 'evt_123',
        channelType: 'slack',
        identity: identity,
        conversation: conversation,
        text: 'Test',
      );

      var callCount = 0;

      // First call
      await guard.process(event, () async {
        callCount++;
        return IdempotencyResult.success(
          response: ChannelResponse.text(
            conversation: conversation,
            text: 'Response',
          ),
        );
      });

      // Second call with same eventId
      await guard.process(event, () async {
        callCount++;
        return IdempotencyResult.success(
          response: ChannelResponse.text(
            conversation: conversation,
            text: 'Different response',
          ),
        );
      });

      // Processor should only be called once
      expect(callCount, 1);
    });

    test('handles processor failure', () async {
      final event = ChannelEvent.message(
        eventId: 'evt_fail',
        channelType: 'slack',
        identity: identity,
        conversation: conversation,
        text: 'Test',
      );

      final result = await guard.process(event, () async {
        throw Exception('Processing failed');
      });

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    tearDown(() {
      guard.dispose();
    });
  });

  group('IdempotencyResult', () {
    final conversation = ConversationKey(
      channelType: 'slack',
      tenantId: 'T123',
      roomId: 'C456',
    );

    test('success creates successful result', () {
      final response = ChannelResponse.text(
        conversation: conversation,
        text: 'Test',
      );

      final result = IdempotencyResult.success(response: response);

      expect(result.success, isTrue);
      expect(result.response, response);
      expect(result.error, isNull);
    });

    test('success without response is valid', () {
      final result = IdempotencyResult.success();

      expect(result.success, isTrue);
      expect(result.response, isNull);
    });

    test('failure creates failed result', () {
      final result = IdempotencyResult.failure(error: 'Something went wrong');

      expect(result.success, isFalse);
      expect(result.error, 'Something went wrong');
    });
  });
}
