import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelEvent', () {
    final identity = ChannelIdentity.user(
      id: 'U123',
      displayName: 'Test User',
    );

    final conversation = ConversationKey(
      channelType: 'slack',
      tenantId: 'T123',
      roomId: 'C456',
    );

    group('factory constructors', () {
      test('message creates message event', () {
        final event = ChannelEvent.message(
          eventId: 'evt_123',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          text: 'Hello, world!',
        );

        expect(event.type, ChannelEventType.message);
        expect(event.eventId, 'evt_123');
        expect(event.channelType, 'slack');
        expect(event.text, 'Hello, world!');
        expect(event.identity.displayName, 'Test User');
      });

      test('mention creates mention event', () {
        final event = ChannelEvent.mention(
          eventId: 'evt_456',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          text: '<@BOT> help',
        );

        expect(event.type, ChannelEventType.mention);
        expect(event.text, '<@BOT> help');
      });

      test('command creates command event', () {
        final event = ChannelEvent.command(
          eventId: 'evt_789',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          command: '/help',
          args: ['topic'],
        );

        expect(event.type, ChannelEventType.command);
        expect(event.command, '/help');
        expect(event.commandArgs, ['topic']);
      });

      test('reaction creates reaction event', () {
        final event = ChannelEvent.reaction(
          eventId: 'evt_react',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          reaction: 'thumbsup',
          targetMessageId: 'msg_123',
        );

        expect(event.type, ChannelEventType.reaction);
        expect(event.reaction, 'thumbsup');
        expect(event.targetMessageId, 'msg_123');
      });

      test('file creates file event', () {
        final fileInfo = FileInfo(
          id: 'F123',
          name: 'document.pdf',
          mimeType: 'application/pdf',
          size: 1024,
        );

        final event = ChannelEvent.file(
          eventId: 'evt_file',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          file: fileInfo,
        );

        expect(event.type, ChannelEventType.file);
        expect(event.file, isNotNull);
        expect(event.file!.name, 'document.pdf');
      });

      test('join creates join event', () {
        final event = ChannelEvent.join(
          eventId: 'evt_join',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
        );

        expect(event.type, ChannelEventType.join);
      });

      test('leave creates leave event', () {
        final event = ChannelEvent.leave(
          eventId: 'evt_leave',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
        );

        expect(event.type, ChannelEventType.leave);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = ChannelEvent.message(
          eventId: 'evt_123',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          text: 'Original text',
        );

        final copy = original.copyWith(text: 'Modified text');

        expect(copy.eventId, original.eventId);
        expect(copy.text, 'Modified text');
        expect(original.text, 'Original text');
      });
    });

    group('toJson/fromJson', () {
      test('round-trip serialization works', () {
        final original = ChannelEvent.message(
          eventId: 'evt_123',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          text: 'Test message',
        );

        final json = original.toJson();
        final restored = ChannelEvent.fromJson(json);

        expect(restored.eventId, original.eventId);
        expect(restored.type, original.type);
        expect(restored.channelType, original.channelType);
        expect(restored.text, original.text);
      });
    });

    group('equality', () {
      test('events with same eventId are equal', () {
        final event1 = ChannelEvent.message(
          eventId: 'evt_123',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          text: 'Test 1',
        );

        final event2 = ChannelEvent.message(
          eventId: 'evt_123',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          text: 'Test 2',
        );

        expect(event1, equals(event2));
        expect(event1.hashCode, equals(event2.hashCode));
      });

      test('events with different eventId are not equal', () {
        final event1 = ChannelEvent.message(
          eventId: 'evt_123',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          text: 'Test',
        );

        final event2 = ChannelEvent.message(
          eventId: 'evt_456',
          channelType: 'slack',
          identity: identity,
          conversation: conversation,
          text: 'Test',
        );

        expect(event1, isNot(equals(event2)));
      });
    });
  });
}
