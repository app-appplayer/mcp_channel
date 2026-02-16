import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelEvent (from mcp_bundle)', () {
    final channelIdentity = ChannelIdentity(
      platform: 'slack',
      channelId: 'T123',
    );

    final conversation = ConversationKey(
      channel: channelIdentity,
      conversationId: 'C456',
      userId: 'U123',
    );

    group('factory constructors', () {
      test('message creates message event', () {
        final event = ChannelEvent.message(
          id: 'evt_123',
          conversation: conversation,
          text: 'Hello, world!',
          userId: 'U123',
          userName: 'Test User',
        );

        expect(event.type, 'message');
        expect(event.id, 'evt_123');
        expect(event.text, 'Hello, world!');
        expect(event.userId, 'U123');
        expect(event.userName, 'Test User');
      });

      test('creates event with attachments', () {
        const attachment = ChannelAttachment(
          type: 'file',
          url: 'https://example.com/file.pdf',
          filename: 'document.pdf',
          mimeType: 'application/pdf',
          size: 1024,
        );

        final event = ChannelEvent.message(
          id: 'evt_file',
          conversation: conversation,
          text: 'Check this file',
          attachments: [attachment],
        );

        expect(event.attachments, hasLength(1));
        expect(event.attachments![0].filename, 'document.pdf');
      });

      test('creates event with metadata', () {
        final event = ChannelEvent.message(
          id: 'evt_meta',
          conversation: conversation,
          text: 'Test message',
          metadata: {'thread_ts': '12345.6789'},
        );

        expect(event.metadata?['thread_ts'], '12345.6789');
      });
    });

    group('toJson/fromJson', () {
      test('round-trip serialization works', () {
        final original = ChannelEvent.message(
          id: 'evt_123',
          conversation: conversation,
          text: 'Test message',
          userId: 'U123',
          userName: 'Test User',
        );

        final json = original.toJson();
        final restored = ChannelEvent.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.text, original.text);
        expect(restored.userId, original.userId);
        expect(restored.userName, original.userName);
      });

      test('serialization preserves conversation', () {
        final original = ChannelEvent.message(
          id: 'evt_123',
          conversation: conversation,
          text: 'Test',
        );

        final json = original.toJson();
        final restored = ChannelEvent.fromJson(json);

        expect(
          restored.conversation.channel.platform,
          original.conversation.channel.platform,
        );
        expect(
          restored.conversation.conversationId,
          original.conversation.conversationId,
        );
      });
    });

    group('custom event types', () {
      test('can create custom type event', () {
        final event = ChannelEvent(
          id: 'evt_react',
          conversation: conversation,
          type: 'reaction',
          timestamp: DateTime.now(),
          metadata: {
            'reaction': 'thumbsup',
            'target_message_id': 'msg_123',
          },
        );

        expect(event.type, 'reaction');
        expect(event.metadata?['reaction'], 'thumbsup');
      });

      test('can create join event', () {
        final event = ChannelEvent(
          id: 'evt_join',
          conversation: conversation,
          type: 'join',
          userId: 'U456',
          timestamp: DateTime.now(),
        );

        expect(event.type, 'join');
        expect(event.userId, 'U456');
      });

      test('can create leave event', () {
        final event = ChannelEvent(
          id: 'evt_leave',
          conversation: conversation,
          type: 'leave',
          userId: 'U456',
          timestamp: DateTime.now(),
        );

        expect(event.type, 'leave');
        expect(event.userId, 'U456');
      });
    });
  });
}
