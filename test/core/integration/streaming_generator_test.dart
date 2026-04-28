import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  const channelIdentity = ChannelIdentity(
    platform: 'test',
    channelId: 'C1',
  );

  const conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'conv-1',
    userId: 'U1',
  );

  /// Helper to create a minimal session for testing.
  Session createTestSession() {
    final now = DateTime.now();
    return Session(
      id: 'session-1',
      conversation: conversation,
      principal: Principal.basic(
        identity: ChannelIdentityInfo.user(
          id: 'U1',
          displayName: 'Test User',
        ),
        tenantId: 'C1',
        expiresAt: now.add(const Duration(hours: 24)),
      ),
      state: SessionState.active,
      createdAt: now,
      lastActivityAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      history: const [],
    );
  }

  // ---------------------------------------------------------------------------
  // TC-053: StreamingDeliveryStrategy enum
  // ---------------------------------------------------------------------------
  group('StreamingDeliveryStrategy', () {
    test('TC-053.1: has exactly three values', () {
      expect(StreamingDeliveryStrategy.values, hasLength(3));
    });

    test('TC-053.2: contains editInPlace, typingThenSend, and appendMessages',
        () {
      expect(
        StreamingDeliveryStrategy.values,
        containsAll([
          StreamingDeliveryStrategy.editInPlace,
          StreamingDeliveryStrategy.typingThenSend,
          StreamingDeliveryStrategy.appendMessages,
        ]),
      );
    });

    test('TC-053.3: values have correct names', () {
      expect(StreamingDeliveryStrategy.editInPlace.name, 'editInPlace');
      expect(
          StreamingDeliveryStrategy.typingThenSend.name, 'typingThenSend');
      expect(
          StreamingDeliveryStrategy.appendMessages.name, 'appendMessages');
    });
  });

  // ---------------------------------------------------------------------------
  // TC-061: StreamCancellation
  // ---------------------------------------------------------------------------
  group('StreamCancellation', () {
    test('TC-061.1: default state is not cancelled', () {
      final cancellation = StreamCancellation();
      expect(cancellation.isCancelled, isFalse);
    });

    test('TC-061.2: cancel() sets isCancelled to true', () {
      final cancellation = StreamCancellation();
      cancellation.cancel();
      expect(cancellation.isCancelled, isTrue);
    });

    test('TC-061.3: cancel() is idempotent', () {
      final cancellation = StreamCancellation();
      cancellation.cancel();
      cancellation.cancel();
      expect(cancellation.isCancelled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-151: EchoStreamingGenerator
  // ---------------------------------------------------------------------------
  group('EchoStreamingGenerator', () {
    late EchoStreamingGenerator generator;
    late Session session;

    setUp(() {
      generator = const EchoStreamingGenerator();
      session = createTestSession();
    });

    test('TC-151.1: streams text character by character', () async {
      final event = ChannelEvent.message(
        id: 'evt-1',
        conversation: conversation,
        text: 'Hi',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      // 'Hi' = 2 characters -> first chunk ('H') + delta ('i') + complete
      expect(chunks, hasLength(3));

      // First character as first chunk
      expect(chunks[0].textDelta, 'H');
      // Second character as delta chunk
      expect(chunks[1].textDelta, 'i');
      // Final complete chunk
      expect(chunks[2].isComplete, isTrue);
    });

    test('TC-151.2: first chunk has sequenceNumber 0', () async {
      final event = ChannelEvent.message(
        id: 'evt-2',
        conversation: conversation,
        text: 'ABC',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      expect(chunks.first.sequenceNumber, 0);
    });

    test('TC-151.3: last chunk has isComplete true', () async {
      final event = ChannelEvent.message(
        id: 'evt-3',
        conversation: conversation,
        text: 'OK',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      expect(chunks.last.isComplete, isTrue);
    });

    test('TC-151.4: middle chunks have sequential sequenceNumbers', () async {
      final event = ChannelEvent.message(
        id: 'evt-4',
        conversation: conversation,
        text: 'Hello',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      // 'Hello' -> first(0), delta(1), delta(2), delta(3), delta(4), complete(5)
      expect(chunks, hasLength(6));
      for (var i = 0; i < chunks.length; i++) {
        expect(chunks[i].sequenceNumber, i);
      }
    });

    test('TC-151.5: first chunk is not complete', () async {
      final event = ChannelEvent.message(
        id: 'evt-5',
        conversation: conversation,
        text: 'AB',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      expect(chunks.first.isComplete, isFalse);
    });

    test('TC-151.6: empty text event emits first, then complete', () async {
      final event = ChannelEvent.message(
        id: 'evt-6',
        conversation: conversation,
        text: '',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      // Empty string: first chunk (empty textDelta, seq 0) + complete (seq 0)
      expect(chunks, hasLength(2));
      expect(chunks[0].textDelta, '');
      expect(chunks[0].isComplete, isFalse);
      expect(chunks[0].sequenceNumber, 0);
      expect(chunks[1].isComplete, isTrue);
      expect(chunks[1].sequenceNumber, 0);
    });

    test('TC-151.7: cancellation stops stream early and emits complete chunk',
        () async {
      final event = ChannelEvent.message(
        id: 'evt-7',
        conversation: conversation,
        text: 'ABCDEFGH',
        userId: 'U1',
      );

      final cancellation = StreamCancellation();

      final chunks = <ChannelResponseChunk>[];
      await for (final chunk
          in generator.generateStream(event, session,
              cancellation: cancellation)) {
        chunks.add(chunk);
        // Cancel after the first chunk is received
        if (chunks.length == 1) {
          cancellation.cancel();
        }
      }

      // Should have: first chunk ('A') + complete chunk (cancelled)
      expect(chunks, hasLength(2));
      expect(chunks[0].textDelta, 'A');
      expect(chunks[0].isComplete, isFalse);
      expect(chunks.last.isComplete, isTrue);
    });

    test('TC-151.8: null text event defaults to "[no text]"', () async {
      final event = ChannelEvent(
        id: 'evt-8',
        conversation: conversation,
        type: 'reaction',
        timestamp: DateTime.now(),
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      // '[no text]' is 9 characters -> first + 8 deltas + complete = 10
      expect(chunks, hasLength(10));

      // Reconstruct text from chunks
      final buffer = StringBuffer();
      for (final chunk in chunks) {
        if (chunk.textDelta != null) {
          buffer.write(chunk.textDelta);
        }
      }
      expect(buffer.toString(), '[no text]');
    });

    test('TC-151.9: stream completes after final chunk', () async {
      final event = ChannelEvent.message(
        id: 'evt-9',
        conversation: conversation,
        text: 'X',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      // toList() only returns after the stream is done, proving completion
      expect(chunks, isNotEmpty);
      expect(chunks.last.isComplete, isTrue);

      // Verify no chunks arrive after the complete chunk
      final allComplete =
          chunks.where((c) => c.isComplete).toList();
      expect(allComplete, hasLength(1));
      expect(allComplete.single, chunks.last);
    });

    test('TC-151.10: all chunks reference the same conversation', () async {
      final event = ChannelEvent.message(
        id: 'evt-10',
        conversation: conversation,
        text: 'Test',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      for (final chunk in chunks) {
        expect(chunk.conversation, conversation);
      }
    });

    test('TC-151.11: single character text produces three chunks', () async {
      final event = ChannelEvent.message(
        id: 'evt-11',
        conversation: conversation,
        text: 'Z',
        userId: 'U1',
      );

      final chunks =
          await generator.generateStream(event, session).toList();

      // 'Z' -> first('Z', seq=0), complete(seq=1)
      expect(chunks, hasLength(2));
      expect(chunks[0].textDelta, 'Z');
      expect(chunks[0].sequenceNumber, 0);
      expect(chunks[0].isComplete, isFalse);
      expect(chunks[1].sequenceNumber, 1);
      expect(chunks[1].isComplete, isTrue);
    });
  });
}
