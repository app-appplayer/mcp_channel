import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  final mockConversation = ConversationKey(
    channel: ChannelIdentity(platform: 'test', channelId: 'ch1'),
    conversationId: 'conv1',
    userId: 'u1',
  );

  group('ChannelResponseChunk', () {
    group('first factory', () {
      test('creates first chunk with correct defaults', () {
        final chunk = ChannelResponseChunk.first(
          conversation: mockConversation,
          textDelta: 'Hello',
        );

        expect(chunk.conversation, mockConversation);
        expect(chunk.textDelta, 'Hello');
        expect(chunk.isComplete, isFalse);
        expect(chunk.messageId, isNull);
        expect(chunk.sequenceNumber, 0);
        expect(chunk.metadata, isNull);
      });

      test('creates first chunk with metadata', () {
        final chunk = ChannelResponseChunk.first(
          conversation: mockConversation,
          textDelta: 'Hi',
          metadata: {'model': 'gpt-4'},
        );

        expect(chunk.metadata, {'model': 'gpt-4'});
        expect(chunk.sequenceNumber, 0);
        expect(chunk.isComplete, isFalse);
      });

      test('creates first chunk without textDelta', () {
        final chunk = ChannelResponseChunk.first(
          conversation: mockConversation,
        );

        expect(chunk.textDelta, isNull);
        expect(chunk.sequenceNumber, 0);
        expect(chunk.isComplete, isFalse);
      });
    });

    group('delta factory', () {
      test('creates delta chunk with required fields', () {
        final chunk = ChannelResponseChunk.delta(
          conversation: mockConversation,
          textDelta: ' world',
          messageId: 'msg-123',
          sequenceNumber: 5,
        );

        expect(chunk.conversation, mockConversation);
        expect(chunk.textDelta, ' world');
        expect(chunk.isComplete, isFalse);
        expect(chunk.messageId, 'msg-123');
        expect(chunk.sequenceNumber, 5);
      });

      test('creates delta chunk with metadata', () {
        final chunk = ChannelResponseChunk.delta(
          conversation: mockConversation,
          textDelta: '!',
          messageId: 'msg-123',
          sequenceNumber: 10,
          metadata: {'tokens': 42},
        );

        expect(chunk.metadata, {'tokens': 42});
      });
    });

    group('complete factory', () {
      test('creates complete chunk', () {
        final chunk = ChannelResponseChunk.complete(
          conversation: mockConversation,
          messageId: 'msg-123',
          sequenceNumber: 15,
        );

        expect(chunk.isComplete, isTrue);
        expect(chunk.messageId, 'msg-123');
        expect(chunk.sequenceNumber, 15);
        expect(chunk.textDelta, isNull);
      });

      test('creates complete chunk with final textDelta', () {
        final chunk = ChannelResponseChunk.complete(
          conversation: mockConversation,
          textDelta: '.',
          messageId: 'msg-123',
          sequenceNumber: 20,
        );

        expect(chunk.isComplete, isTrue);
        expect(chunk.textDelta, '.');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final chunk = ChannelResponseChunk(
          conversation: mockConversation,
          textDelta: 'Hello',
          isComplete: false,
          messageId: 'msg-123',
          sequenceNumber: 3,
          metadata: {'key': 'value'},
        );

        final json = chunk.toJson();

        expect(json['conversation'], isA<Map<String, dynamic>>());
        expect(json['textDelta'], 'Hello');
        expect(json['isComplete'], isFalse);
        expect(json['messageId'], 'msg-123');
        expect(json['sequenceNumber'], 3);
        expect(json['metadata'], {'key': 'value'});
      });

      test('omits null optional fields', () {
        final chunk = ChannelResponseChunk.first(
          conversation: mockConversation,
        );

        final json = chunk.toJson();

        expect(json.containsKey('textDelta'), isFalse);
        expect(json.containsKey('messageId'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
        expect(json['isComplete'], isFalse);
        expect(json['sequenceNumber'], 0);
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final json = {
          'conversation': {
            'channel': {'platform': 'test', 'channelId': 'ch1'},
            'conversationId': 'conv1',
            'userId': 'u1',
          },
          'textDelta': 'Hello',
          'isComplete': false,
          'messageId': 'msg-123',
          'sequenceNumber': 3,
          'metadata': {'key': 'value'},
        };

        final chunk = ChannelResponseChunk.fromJson(json);

        expect(chunk.conversation.conversationId, 'conv1');
        expect(chunk.textDelta, 'Hello');
        expect(chunk.isComplete, isFalse);
        expect(chunk.messageId, 'msg-123');
        expect(chunk.sequenceNumber, 3);
        expect(chunk.metadata, {'key': 'value'});
      });

      test('deserializes with null optional fields', () {
        final json = {
          'conversation': {
            'channel': {'platform': 'test', 'channelId': 'ch1'},
            'conversationId': 'conv1',
          },
          'isComplete': true,
          'sequenceNumber': 0,
        };

        final chunk = ChannelResponseChunk.fromJson(json);

        expect(chunk.textDelta, isNull);
        expect(chunk.messageId, isNull);
        expect(chunk.metadata, isNull);
        expect(chunk.isComplete, isTrue);
      });
    });

    group('round-trip serialization', () {
      test('toJson then fromJson preserves data', () {
        final original = ChannelResponseChunk(
          conversation: mockConversation,
          textDelta: 'Hello world',
          isComplete: false,
          messageId: 'msg-456',
          sequenceNumber: 7,
          metadata: {'tokens': 10},
        );

        final restored = ChannelResponseChunk.fromJson(original.toJson());

        expect(restored.conversation.conversationId,
            original.conversation.conversationId);
        expect(restored.textDelta, original.textDelta);
        expect(restored.isComplete, original.isComplete);
        expect(restored.messageId, original.messageId);
        expect(restored.sequenceNumber, original.sequenceNumber);
        expect(restored.metadata, original.metadata);
      });

      test('round-trip with null fields', () {
        final original = ChannelResponseChunk.first(
          conversation: mockConversation,
        );

        final restored = ChannelResponseChunk.fromJson(original.toJson());

        expect(restored.textDelta, isNull);
        expect(restored.messageId, isNull);
        expect(restored.metadata, isNull);
        expect(restored.sequenceNumber, 0);
        expect(restored.isComplete, isFalse);
      });
    });

    group('copyWith', () {
      test('copies with isComplete changed', () {
        final original = ChannelResponseChunk.first(
          conversation: mockConversation,
          textDelta: 'Hello',
        );

        final copy = original.copyWith(isComplete: true);

        expect(copy.isComplete, isTrue);
        expect(copy.textDelta, 'Hello');
        expect(copy.sequenceNumber, 0);
      });

      test('copies with messageId added', () {
        final original = ChannelResponseChunk.first(
          conversation: mockConversation,
          textDelta: 'Hi',
        );

        final copy = original.copyWith(messageId: 'msg-new');

        expect(copy.messageId, 'msg-new');
        expect(copy.textDelta, 'Hi');
      });

      test('copies with no changes preserves values', () {
        final original = ChannelResponseChunk.delta(
          conversation: mockConversation,
          textDelta: 'text',
          messageId: 'msg-1',
          sequenceNumber: 3,
        );

        final copy = original.copyWith();

        expect(copy.textDelta, 'text');
        expect(copy.messageId, 'msg-1');
        expect(copy.sequenceNumber, 3);
        expect(copy.isComplete, isFalse);
      });
    });

    group('equality', () {
      test('equal when same conversation and sequenceNumber', () {
        final a = ChannelResponseChunk.first(
          conversation: mockConversation,
          textDelta: 'Hello',
        );
        final b = ChannelResponseChunk(
          conversation: mockConversation,
          isComplete: true,
          sequenceNumber: 0,
        );

        expect(a == b, isTrue);
      });

      test('not equal when sequenceNumber differs', () {
        final a = ChannelResponseChunk(
          conversation: mockConversation,
          isComplete: false,
          sequenceNumber: 0,
        );
        final b = ChannelResponseChunk(
          conversation: mockConversation,
          isComplete: false,
          sequenceNumber: 1,
        );

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        final a = ChannelResponseChunk.first(
          conversation: mockConversation,
        );
        expect(a == a, isTrue);
      });

      test('not equal to different type object', () {
        final a = ChannelResponseChunk.first(
          conversation: mockConversation,
        );
        expect(a == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        final a = ChannelResponseChunk.first(
          conversation: mockConversation,
          textDelta: 'A',
        );
        final b = ChannelResponseChunk(
          conversation: mockConversation,
          isComplete: true,
          sequenceNumber: 0,
          textDelta: 'B',
        );

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains sequenceNumber, isComplete, and textDelta', () {
        final chunk = ChannelResponseChunk.delta(
          conversation: mockConversation,
          textDelta: 'world',
          messageId: 'msg-1',
          sequenceNumber: 3,
        );

        final str = chunk.toString();

        expect(str, contains('3'));
        expect(str, contains('false'));
        expect(str, contains('world'));
      });
    });
  });
}
