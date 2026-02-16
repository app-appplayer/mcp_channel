import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelResponse (from mcp_bundle)', () {
    final channelIdentity = ChannelIdentity(
      platform: 'slack',
      channelId: 'T123',
    );

    final conversation = ConversationKey(
      channel: channelIdentity,
      conversationId: 'C456',
    );

    group('factory constructors', () {
      test('text creates text response', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello!',
        );

        expect(response.type, 'text');
        expect(response.text, 'Hello!');
        expect(response.conversation, conversation);
      });

      test('text with replyTo creates reply response', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Reply text',
          replyTo: 'msg_123',
        );

        expect(response.replyTo, 'msg_123');
        expect(response.text, 'Reply text');
      });

      test('text with options passes platform-specific data', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello!',
          options: {'unfurl_links': false},
        );

        expect(response.options?['unfurl_links'], false);
      });

      test('rich creates response with blocks', () {
        final blocks = [
          {'type': 'section', 'text': {'type': 'mrkdwn', 'text': 'Hello'}},
        ];

        final response = ChannelResponse.rich(
          conversation: conversation,
          blocks: blocks,
          text: 'Fallback text',
        );

        expect(response.type, 'rich');
        expect(response.blocks, hasLength(1));
        expect(response.blocks![0]['type'], 'section');
        expect(response.text, 'Fallback text');
      });
    });

    group('direct constructor', () {
      test('creates response with attachments', () {
        const attachment = ChannelAttachment(
          type: 'file',
          url: 'https://example.com/file.pdf',
          filename: 'document.pdf',
          mimeType: 'application/pdf',
          size: 1024,
        );

        final response = ChannelResponse(
          conversation: conversation,
          type: 'file',
          text: 'See attached',
          attachments: [attachment],
        );

        expect(response.type, 'file');
        expect(response.attachments, hasLength(1));
        expect(response.attachments![0].filename, 'document.pdf');
      });

      test('creates ephemeral-like response via options', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Only you can see this',
          options: {
            'response_type': 'ephemeral',
            'user': 'U123',
          },
        );

        expect(response.options?['response_type'], 'ephemeral');
        expect(response.options?['user'], 'U123');
      });
    });

    group('toJson/fromJson', () {
      test('round-trip serialization works for text response', () {
        final original = ChannelResponse.text(
          conversation: conversation,
          text: 'Test response',
        );

        final json = original.toJson();
        final restored = ChannelResponse.fromJson(json);

        expect(restored.type, original.type);
        expect(restored.text, original.text);
      });

      test('round-trip serialization works for rich response', () {
        final blocks = [
          {'type': 'section', 'text': {'type': 'plain_text', 'text': 'Hello'}},
        ];

        final original = ChannelResponse.rich(
          conversation: conversation,
          blocks: blocks,
        );

        final json = original.toJson();
        final restored = ChannelResponse.fromJson(json);

        expect(restored.type, original.type);
        expect(restored.blocks, isNotNull);
        expect(restored.blocks![0]['type'], 'section');
      });

      test('serialization preserves conversation', () {
        final original = ChannelResponse.text(
          conversation: conversation,
          text: 'Test',
        );

        final json = original.toJson();
        final restored = ChannelResponse.fromJson(json);

        expect(
          restored.conversation.channel.platform,
          original.conversation.channel.platform,
        );
        expect(
          restored.conversation.conversationId,
          original.conversation.conversationId,
        );
      });

      test('serialization preserves attachments', () {
        const attachment = ChannelAttachment(
          type: 'image',
          url: 'https://example.com/image.png',
          filename: 'image.png',
        );

        final original = ChannelResponse(
          conversation: conversation,
          type: 'file',
          attachments: [attachment],
        );

        final json = original.toJson();
        final restored = ChannelResponse.fromJson(json);

        expect(restored.attachments, hasLength(1));
        expect(restored.attachments![0].url, attachment.url);
      });
    });
  });
}
