import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Shared fixtures
  final channelIdentity = const ChannelIdentity(
    platform: 'slack',
    channelId: 'T123',
  );

  final conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'C456',
    userId: 'U123',
  );

  final fixedTimestamp = DateTime(2024, 1, 1);

  group('ChannelEventType', () {
    test('has all 10 values', () {
      expect(ChannelEventType.values, hasLength(10));
      expect(ChannelEventType.values, contains(ChannelEventType.message));
      expect(ChannelEventType.values, contains(ChannelEventType.command));
      expect(ChannelEventType.values, contains(ChannelEventType.button));
      expect(ChannelEventType.values, contains(ChannelEventType.file));
      expect(ChannelEventType.values, contains(ChannelEventType.reaction));
      expect(ChannelEventType.values, contains(ChannelEventType.mention));
      expect(ChannelEventType.values, contains(ChannelEventType.webhook));
      expect(ChannelEventType.values, contains(ChannelEventType.join));
      expect(ChannelEventType.values, contains(ChannelEventType.leave));
      expect(ChannelEventType.values, contains(ChannelEventType.unknown));
    });
  });

  group('ExtendedChannelEvent', () {
    group('constructor', () {
      test('creates with required fields and defaults', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );

        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.base, baseEvent);
        expect(event.extendedConversation, isNull);
        expect(event.identityInfo, isNull);
        expect(event.eventType, ChannelEventType.message);
        expect(event.command, isNull);
        expect(event.commandArgs, isNull);
        expect(event.actionId, isNull);
        expect(event.actionValue, isNull);
        expect(event.file, isNull);
        expect(event.reaction, isNull);
        expect(event.targetMessageId, isNull);
        expect(event.rawPayload, isNull);
      });

      test('creates with all optional parameters', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
        );
        final identityInfo = ChannelIdentityInfo.user(id: 'U123');
        const fileInfo = FileInfo(id: 'f1', name: 'doc.pdf');
        final rawPayload = {'key': 'value'};

        final event = ExtendedChannelEvent(
          base: baseEvent,
          extendedConversation: extConv,
          identityInfo: identityInfo,
          eventType: ChannelEventType.command,
          command: 'help',
          commandArgs: ['topic1'],
          actionId: 'act-1',
          actionValue: 'val-1',
          file: fileInfo,
          reaction: 'thumbsup',
          targetMessageId: 'msg-99',
          rawPayload: rawPayload,
        );

        expect(event.extendedConversation, extConv);
        expect(event.identityInfo, identityInfo);
        expect(event.eventType, ChannelEventType.command);
        expect(event.command, 'help');
        expect(event.commandArgs, ['topic1']);
        expect(event.actionId, 'act-1');
        expect(event.actionValue, 'val-1');
        expect(event.file, fileInfo);
        expect(event.reaction, 'thumbsup');
        expect(event.targetMessageId, 'msg-99');
        expect(event.rawPayload, rawPayload);
      });
    });

    group('fromBase', () {
      test('creates from base event with all optional params', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          userId: 'U123',
          userName: 'Test User',
          timestamp: fixedTimestamp,
          metadata: {'source': 'test'},
        );
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );
        final identityInfo = ChannelIdentityInfo.user(id: 'U123');
        const fileInfo = FileInfo(id: 'f1', name: 'doc.pdf');

        final event = ExtendedChannelEvent.fromBase(
          baseEvent,
          extendedConversation: extConv,
          identityInfo: identityInfo,
          eventType: ChannelEventType.file,
          command: 'upload',
          commandArgs: ['file1'],
          actionId: 'act-1',
          actionValue: 'val-1',
          file: fileInfo,
          reaction: 'heart',
          targetMessageId: 'msg-1',
          rawPayload: {'custom': 'data'},
        );

        expect(event.base, baseEvent);
        expect(event.extendedConversation, extConv);
        expect(event.identityInfo, identityInfo);
        expect(event.eventType, ChannelEventType.file);
        expect(event.command, 'upload');
        expect(event.commandArgs, ['file1']);
        expect(event.actionId, 'act-1');
        expect(event.actionValue, 'val-1');
        expect(event.file, fileInfo);
        expect(event.reaction, 'heart');
        expect(event.targetMessageId, 'msg-1');
        expect(event.rawPayload, {'custom': 'data'});
      });

      test('parses known event type from base type', () {
        final baseEvent = ChannelEvent(
          id: 'evt-1',
          conversation: conversation,
          type: 'command',
          timestamp: fixedTimestamp,
        );

        final event = ExtendedChannelEvent.fromBase(baseEvent);

        expect(event.eventType, ChannelEventType.command);
      });

      test('parses unknown event type to unknown', () {
        final baseEvent = ChannelEvent(
          id: 'evt-1',
          conversation: conversation,
          type: 'custom_type_xyz',
          timestamp: fixedTimestamp,
        );

        final event = ExtendedChannelEvent.fromBase(baseEvent);

        expect(event.eventType, ChannelEventType.unknown);
      });

      test('uses metadata as rawPayload when rawPayload not provided', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
          metadata: {'thread_ts': '12345'},
        );

        final event = ExtendedChannelEvent.fromBase(baseEvent);

        expect(event.rawPayload, {'thread_ts': '12345'});
      });
    });

    group('message factory', () {
      test('creates text message event', () {
        final event = ExtendedChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'Hello!',
          userId: 'U123',
          userName: 'Test User',
          timestamp: fixedTimestamp,
        );

        expect(event.eventType, ChannelEventType.message);
        expect(event.id, 'evt-1');
        expect(event.text, 'Hello!');
        expect(event.userId, 'U123');
        expect(event.userName, 'Test User');
        expect(event.timestamp, fixedTimestamp);
      });

      test('creates message with replyTo and rawPayload', () {
        final event = ExtendedChannelEvent.message(
          id: 'evt-2',
          conversation: conversation,
          text: 'Reply',
          replyTo: 'msg-99',
          rawPayload: {'source': 'slack'},
        );

        expect(event.targetMessageId, 'msg-99');
        expect(event.rawPayload, {'source': 'slack'});
      });

      test('creates message with extendedConversation and identityInfo', () {
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          threadId: 'thread-1',
        );
        final identity = ChannelIdentityInfo.user(
          id: 'U123',
          displayName: 'Alice',
        );

        final event = ExtendedChannelEvent.message(
          id: 'evt-3',
          conversation: conversation,
          text: 'Hi',
          extendedConversation: extConv,
          identityInfo: identity,
        );

        expect(event.extendedConversation, extConv);
        expect(event.identityInfo, identity);
      });
    });

    group('command factory', () {
      test('creates command event', () {
        final event = ExtendedChannelEvent.command(
          id: 'evt-cmd',
          conversation: conversation,
          command: 'help',
          userId: 'U123',
          userName: 'Test User',
          timestamp: fixedTimestamp,
        );

        expect(event.eventType, ChannelEventType.command);
        expect(event.command, 'help');
        expect(event.base.type, 'command');
        expect(event.text, '/help');
      });

      test('creates command with args joined in text', () {
        final event = ExtendedChannelEvent.command(
          id: 'evt-cmd-2',
          conversation: conversation,
          command: 'search',
          commandArgs: ['hello', 'world'],
          timestamp: fixedTimestamp,
        );

        expect(event.command, 'search');
        expect(event.commandArgs, ['hello', 'world']);
        expect(event.text, '/search hello world');
      });

      test('creates command without args', () {
        final event = ExtendedChannelEvent.command(
          id: 'evt-cmd-3',
          conversation: conversation,
          command: 'ping',
          timestamp: fixedTimestamp,
        );

        expect(event.commandArgs, isNull);
        expect(event.text, '/ping');
      });

      test('creates command with extendedConversation and identityInfo', () {
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );
        final identity = ChannelIdentityInfo.bot(id: 'B001');

        final event = ExtendedChannelEvent.command(
          id: 'evt-cmd-4',
          conversation: conversation,
          command: 'status',
          extendedConversation: extConv,
          identityInfo: identity,
          rawPayload: {'trigger_id': 'trig-1'},
        );

        expect(event.extendedConversation, extConv);
        expect(event.identityInfo, identity);
        expect(event.rawPayload, {'trigger_id': 'trig-1'});
      });
    });

    group('button factory', () {
      test('creates button click event', () {
        final event = ExtendedChannelEvent.button(
          id: 'evt-btn',
          conversation: conversation,
          actionId: 'btn-approve',
          actionValue: 'yes',
          userId: 'U123',
          userName: 'Test User',
          timestamp: fixedTimestamp,
        );

        expect(event.eventType, ChannelEventType.button);
        expect(event.actionId, 'btn-approve');
        expect(event.actionValue, 'yes');
        expect(event.base.type, 'button');
      });

      test('creates button with targetMessageId', () {
        final event = ExtendedChannelEvent.button(
          id: 'evt-btn-2',
          conversation: conversation,
          actionId: 'btn-delete',
          targetMessageId: 'msg-100',
          timestamp: fixedTimestamp,
        );

        expect(event.targetMessageId, 'msg-100');
      });

      test('creates button with extendedConversation and identityInfo', () {
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );
        final identity = ChannelIdentityInfo.user(id: 'U999');

        final event = ExtendedChannelEvent.button(
          id: 'evt-btn-3',
          conversation: conversation,
          actionId: 'btn-3',
          extendedConversation: extConv,
          identityInfo: identity,
          rawPayload: {'response_url': 'https://hooks.slack.com/abc'},
        );

        expect(event.extendedConversation, extConv);
        expect(event.identityInfo, identity);
        expect(event.rawPayload?['response_url'], 'https://hooks.slack.com/abc');
      });
    });

    group('fromJson', () {
      test('deserializes with all optional fields', () {
        final baseEventJson = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          userId: 'U123',
          userName: 'TestUser',
          timestamp: fixedTimestamp,
        ).toJson();

        final extConvJson = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
        ).toJson();

        final identityJson = ChannelIdentityInfo.user(
          id: 'U123',
          displayName: 'Alice',
        ).toJson();

        const fileInfo = FileInfo(id: 'f1', name: 'doc.pdf');

        final json = {
          'base': baseEventJson,
          'extendedConversation': extConvJson,
          'identityInfo': identityJson,
          'eventType': 'command',
          'command': 'help',
          'commandArgs': ['topic1', 'topic2'],
          'actionId': 'act-1',
          'actionValue': 'val-1',
          'file': fileInfo.toJson(),
          'reaction': 'thumbsup',
          'targetMessageId': 'msg-99',
          'rawPayload': {'key': 'value'},
        };

        final event = ExtendedChannelEvent.fromJson(json);

        expect(event.id, 'evt-1');
        expect(event.extendedConversation, isNotNull);
        expect(event.extendedConversation!.tenantId, 'T001');
        expect(event.extendedConversation!.threadId, 'thread-1');
        expect(event.identityInfo, isNotNull);
        expect(event.identityInfo!.id, 'U123');
        expect(event.eventType, ChannelEventType.command);
        expect(event.command, 'help');
        expect(event.commandArgs, ['topic1', 'topic2']);
        expect(event.actionId, 'act-1');
        expect(event.actionValue, 'val-1');
        expect(event.file, isNotNull);
        expect(event.file!.id, 'f1');
        expect(event.reaction, 'thumbsup');
        expect(event.targetMessageId, 'msg-99');
        expect(event.rawPayload, {'key': 'value'});
      });

      test('deserializes with minimal fields', () {
        final baseEventJson = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        ).toJson();

        final json = {
          'base': baseEventJson,
          'eventType': 'message',
        };

        final event = ExtendedChannelEvent.fromJson(json);

        expect(event.id, 'evt-1');
        expect(event.eventType, ChannelEventType.message);
        expect(event.extendedConversation, isNull);
        expect(event.identityInfo, isNull);
        expect(event.command, isNull);
        expect(event.commandArgs, isNull);
        expect(event.actionId, isNull);
        expect(event.actionValue, isNull);
        expect(event.file, isNull);
        expect(event.reaction, isNull);
        expect(event.targetMessageId, isNull);
        expect(event.rawPayload, isNull);
      });

      test('deserializes unknown event type as unknown', () {
        final baseEventJson = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        ).toJson();

        final json = {
          'base': baseEventJson,
          'eventType': 'nonexistent_type',
        };

        final event = ExtendedChannelEvent.fromJson(json);

        expect(event.eventType, ChannelEventType.unknown);
      });
    });

    group('delegating getters', () {
      test('id delegates to base', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-42',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.id, 'evt-42');
      });

      test('type delegates to base', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.type, 'message');
      });

      test('text delegates to base', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'Hello there!',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.text, 'Hello there!');
      });

      test('userId delegates to base', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          userId: 'U999',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.userId, 'U999');
      });

      test('userName delegates to base', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          userName: 'Bob',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.userName, 'Bob');
      });

      test('timestamp delegates to base', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.timestamp, fixedTimestamp);
      });

      test('conversation delegates to base', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.conversation, conversation);
      });

      test('channelType returns platform from base conversation', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.channelType, 'slack');
      });

      test('metadata delegates to base', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
          metadata: {'key': 'val'},
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.metadata, {'key': 'val'});
      });
    });

    group('toBase', () {
      test('returns the wrapped base event', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        expect(event.toBase(), baseEvent);
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: baseEvent);

        final newBase = ChannelEvent.message(
          id: 'evt-2',
          conversation: conversation,
          text: 'bye',
          timestamp: fixedTimestamp,
        );
        final extConv = ExtendedConversationKey.create(
          platform: 'discord',
          channelId: 'D456',
          conversationId: 'dc-1',
        );
        final identity = ChannelIdentityInfo.bot(id: 'B001');
        const fileInfo = FileInfo(id: 'f2', name: 'new.pdf');

        final copy = event.copyWith(
          base: newBase,
          extendedConversation: extConv,
          identityInfo: identity,
          eventType: ChannelEventType.file,
          command: 'upload',
          commandArgs: ['arg1'],
          actionId: 'act-new',
          actionValue: 'val-new',
          file: fileInfo,
          reaction: 'star',
          targetMessageId: 'msg-new',
          rawPayload: {'new': 'payload'},
        );

        expect(copy.base, newBase);
        expect(copy.extendedConversation, extConv);
        expect(copy.identityInfo, identity);
        expect(copy.eventType, ChannelEventType.file);
        expect(copy.command, 'upload');
        expect(copy.commandArgs, ['arg1']);
        expect(copy.actionId, 'act-new');
        expect(copy.actionValue, 'val-new');
        expect(copy.file, fileInfo);
        expect(copy.reaction, 'star');
        expect(copy.targetMessageId, 'msg-new');
        expect(copy.rawPayload, {'new': 'payload'});
      });

      test('copies with no fields changed preserves values', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(
          base: baseEvent,
          eventType: ChannelEventType.message,
          command: 'test',
        );

        final copy = event.copyWith();

        expect(copy.base, event.base);
        expect(copy.eventType, event.eventType);
        expect(copy.command, event.command);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
        );
        final identity = ChannelIdentityInfo.user(id: 'U123');
        const fileInfo = FileInfo(id: 'f1', name: 'doc.pdf');

        final event = ExtendedChannelEvent(
          base: baseEvent,
          extendedConversation: extConv,
          identityInfo: identity,
          eventType: ChannelEventType.command,
          command: 'help',
          commandArgs: ['arg1'],
          actionId: 'act-1',
          actionValue: 'val-1',
          file: fileInfo,
          reaction: 'thumbsup',
          targetMessageId: 'msg-99',
          rawPayload: {'key': 'value'},
        );

        final json = event.toJson();

        expect(json['base'], isNotNull);
        expect(json['extendedConversation'], isNotNull);
        expect(json['identityInfo'], isNotNull);
        expect(json['eventType'], 'command');
        expect(json['command'], 'help');
        expect(json['commandArgs'], ['arg1']);
        expect(json['actionId'], 'act-1');
        expect(json['actionValue'], 'val-1');
        expect(json['file'], isNotNull);
        expect(json['reaction'], 'thumbsup');
        expect(json['targetMessageId'], 'msg-99');
        expect(json['rawPayload'], {'key': 'value'});
      });

      test('omits null optional fields', () {
        final baseEvent = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );

        final event = ExtendedChannelEvent(base: baseEvent);
        final json = event.toJson();

        expect(json['base'], isNotNull);
        expect(json['eventType'], 'message');
        expect(json.containsKey('extendedConversation'), isFalse);
        expect(json.containsKey('identityInfo'), isFalse);
        expect(json.containsKey('command'), isFalse);
        expect(json.containsKey('commandArgs'), isFalse);
        expect(json.containsKey('actionId'), isFalse);
        expect(json.containsKey('actionValue'), isFalse);
        expect(json.containsKey('file'), isFalse);
        expect(json.containsKey('reaction'), isFalse);
        expect(json.containsKey('targetMessageId'), isFalse);
        expect(json.containsKey('rawPayload'), isFalse);
      });
    });

    group('equality', () {
      test('equal when same base.id', () {
        final base1 = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final base2 = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'different text',
          timestamp: fixedTimestamp,
        );

        final a = ExtendedChannelEvent(base: base1);
        final b = ExtendedChannelEvent(base: base2);

        expect(a == b, isTrue);
      });

      test('not equal when different base.id', () {
        final base1 = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final base2 = ChannelEvent.message(
          id: 'evt-2',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );

        final a = ExtendedChannelEvent(base: base1);
        final b = ExtendedChannelEvent(base: base2);

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        final base = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: base);

        expect(event == event, isTrue);
      });

      test('not equal to different type object', () {
        final base = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: base);

        expect(event == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        final base1 = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'hello',
          timestamp: fixedTimestamp,
        );
        final base2 = ChannelEvent.message(
          id: 'evt-1',
          conversation: conversation,
          text: 'world',
          timestamp: fixedTimestamp,
        );

        final a = ExtendedChannelEvent(base: base1);
        final b = ExtendedChannelEvent(base: base2);

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains id, eventType name, and channelType', () {
        final base = ChannelEvent.message(
          id: 'evt-99',
          conversation: conversation,
          text: 'test',
          timestamp: fixedTimestamp,
        );
        final event = ExtendedChannelEvent(base: base);

        final str = event.toString();

        expect(str, contains('evt-99'));
        expect(str, contains('message'));
        expect(str, contains('slack'));
      });
    });

    group('_parseEventType', () {
      test('parses all known types correctly via fromBase', () {
        for (final eventType in ChannelEventType.values) {
          if (eventType == ChannelEventType.unknown) continue;

          final base = ChannelEvent(
            id: 'evt-parse',
            conversation: conversation,
            type: eventType.name,
            timestamp: fixedTimestamp,
          );

          final event = ExtendedChannelEvent.fromBase(base);
          expect(event.eventType, eventType);
        }
      });

      test('parses unknown type string to ChannelEventType.unknown', () {
        final base = ChannelEvent(
          id: 'evt-parse',
          conversation: conversation,
          type: 'totally_custom',
          timestamp: fixedTimestamp,
        );

        final event = ExtendedChannelEvent.fromBase(base);
        expect(event.eventType, ChannelEventType.unknown);
      });
    });
  });
}
