import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelResponse', () {
    final conversation = ConversationKey(
      channelType: 'slack',
      tenantId: 'T123',
      roomId: 'C456',
    );

    group('factory constructors', () {
      test('text creates text response', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello!',
        );

        expect(response.type, ChannelResponseType.text);
        expect(response.text, 'Hello!');
        expect(response.conversation, conversation);
        expect(response.attachments, isNull);
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

      test('file creates response with attachments', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          url: 'https://example.com/file.pdf',
          name: 'file.pdf',
        );

        final response = ChannelResponse.file(
          conversation: conversation,
          attachments: [attachment],
          text: 'See attached',
        );

        expect(response.type, ChannelResponseType.file);
        expect(response.attachments, hasLength(1));
        expect(response.attachments!.first.name, 'file.pdf');
        expect(response.text, 'See attached');
      });

      test('rich creates response with content blocks', () {
        final blocks = [
          ContentBlock.section(text: 'Section 1'),
        ];

        final response = ChannelResponse.rich(
          conversation: conversation,
          blocks: blocks,
        );

        expect(response.type, ChannelResponseType.rich);
        expect(response.blocks, hasLength(1));
        expect(response.blocks![0].type, ContentBlockType.section);
      });

      test('ephemeral creates ephemeral response', () {
        final response = ChannelResponse.ephemeral(
          conversation: conversation,
          userId: 'U123',
          text: 'Only you can see this',
        );

        expect(response.type, ChannelResponseType.ephemeral);
        expect(response.ephemeral, isTrue);
        expect(response.ephemeralUserId, 'U123');
      });

      test('update creates update response', () {
        final response = ChannelResponse.update(
          conversation: conversation,
          targetMessageId: 'msg_123',
          text: 'Updated text',
        );

        expect(response.type, ChannelResponseType.update);
        expect(response.targetMessageId, 'msg_123');
      });

      test('delete creates delete response', () {
        final response = ChannelResponse.delete(
          conversation: conversation,
          targetMessageId: 'msg_123',
        );

        expect(response.type, ChannelResponseType.delete);
        expect(response.targetMessageId, 'msg_123');
      });

      test('typing creates typing indicator response', () {
        final response = ChannelResponse.typing(
          conversation: conversation,
        );

        expect(response.type, ChannelResponseType.typing);
      });

      test('reaction creates reaction response', () {
        final response = ChannelResponse.reaction(
          conversation: conversation,
          targetMessageId: 'msg_123',
          reaction: 'thumbsup',
        );

        expect(response.type, ChannelResponseType.reaction);
        expect(response.reaction, 'thumbsup');
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = ChannelResponse.text(
          conversation: conversation,
          text: 'Original',
        );

        final copy = original.copyWith(text: 'Modified');

        expect(copy.text, 'Modified');
        expect(original.text, 'Original');
      });
    });

    group('toJson/fromJson', () {
      test('round-trip serialization works', () {
        final original = ChannelResponse.text(
          conversation: conversation,
          text: 'Test response',
        );

        final json = original.toJson();
        final restored = ChannelResponse.fromJson(json);

        expect(restored.type, original.type);
        expect(restored.text, original.text);
      });
    });
  });
}
