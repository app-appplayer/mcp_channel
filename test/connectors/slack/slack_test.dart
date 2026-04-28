import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('SlackConfig', () {
    test('creates config with required fields', () {
      final config = SlackConfig(
        botToken: 'xoxb-test-token',
        signingSecret: 'test-secret',
      );

      expect(config.botToken, 'xoxb-test-token');
      expect(config.signingSecret, 'test-secret');
      expect(config.channelType, 'slack');
      expect(config.useSocketMode, isFalse);
      expect(config.scopes, isEmpty);
      expect(config.webhookPath, isNull);
      expect(config.autoReconnect, isTrue);
      expect(config.maxReconnectAttempts, 10);
    });

    test('creates config with all fields', () {
      final config = SlackConfig(
        botToken: 'xoxb-test',
        appToken: 'xapp-test',
        signingSecret: 'secret123',
        webhookPath: '/slack/events',
        workspaceId: 'T123',
        useSocketMode: true,
        scopes: const ['chat:write', 'channels:read'],
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 10),
        maxReconnectAttempts: 5,
      );

      expect(config.appToken, 'xapp-test');
      expect(config.signingSecret, 'secret123');
      expect(config.webhookPath, '/slack/events');
      expect(config.workspaceId, 'T123');
      expect(config.useSocketMode, isTrue);
      expect(config.scopes, ['chat:write', 'channels:read']);
      expect(config.autoReconnect, isFalse);
      expect(config.maxReconnectAttempts, 5);
    });

    test('copyWith creates new config with updated fields', () {
      final original = SlackConfig(
        botToken: 'xoxb-original',
        signingSecret: 'original-secret',
      );
      final copied = original.copyWith(
        botToken: 'xoxb-updated',
        workspaceId: 'T456',
        scopes: ['chat:write'],
        webhookPath: '/events',
      );

      expect(copied.botToken, 'xoxb-updated');
      expect(copied.workspaceId, 'T456');
      expect(copied.scopes, ['chat:write']);
      expect(copied.webhookPath, '/events');
      expect(copied.signingSecret, original.signingSecret);
      expect(copied.useSocketMode, original.useSocketMode);
    });

    group('validate', () {
      test('throws for Socket Mode without appToken', () {
        final config = SlackConfig(
          botToken: 'xoxb-test',
          signingSecret: 'secret',
          useSocketMode: true,
        );

        expect(
          () => config.validate(),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('appToken'),
          )),
        );
      });

      test('throws for HTTP mode without webhookPath', () {
        final config = SlackConfig(
          botToken: 'xoxb-test',
          signingSecret: 'secret',
          useSocketMode: false,
        );

        expect(
          () => config.validate(),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('webhookPath'),
          )),
        );
      });

      test('passes for valid Socket Mode config', () {
        final config = SlackConfig(
          botToken: 'xoxb-test',
          signingSecret: 'secret',
          appToken: 'xapp-test',
          useSocketMode: true,
        );

        expect(() => config.validate(), returnsNormally);
      });

      test('passes for valid HTTP mode config', () {
        final config = SlackConfig(
          botToken: 'xoxb-test',
          signingSecret: 'secret',
          webhookPath: '/slack/events',
          useSocketMode: false,
        );

        expect(() => config.validate(), returnsNormally);
      });
    });
  });

  group('SlackConnector', () {
    late SlackConnector connector;

    setUp(() {
      connector = SlackConnector(
        config: SlackConfig(
          botToken: 'xoxb-test',
          appToken: 'xapp-test',
          signingSecret: 'test-secret',
          workspaceId: 'T123',
        ),
      );
    });

    test('has correct channel type', () {
      expect(connector.channelType, 'slack');
    });

    test('has correct identity', () {
      expect(connector.identity.platform, 'slack');
      expect(connector.identity.channelId, 'T123');
    });

    test('has extended capabilities', () {
      final caps = connector.extendedCapabilities;
      expect(caps.text, isTrue);
      expect(caps.richMessages, isTrue);
      expect(caps.threads, isTrue);
      expect(caps.reactions, isTrue);
      expect(caps.supportsFiles, isTrue);
      expect(caps.supportsButtons, isTrue);
      expect(caps.supportsModals, isTrue);
      expect(caps.supportsEphemeral, isTrue);
      expect(caps.supportsCommands, isTrue);
      expect(caps.maxMessageLength, 40000);
    });

    test('capabilities is ExtendedChannelCapabilities', () {
      expect(connector.capabilities, isA<ExtendedChannelCapabilities>());
    });

    group('event parsing', () {
      test('parses message event', () {
        final payload = {
          'event': {
            'type': 'message',
            'text': 'Hello world',
            'user': 'U123',
            'channel': 'C456',
            'team': 'T789',
            'ts': '1234567890.123456',
          },
        };

        final event = connector.parseEvent(payload);

        expect(event.type, 'message');
        expect(event.text, 'Hello world');
        expect(event.userId, 'U123');
        expect(event.conversation.conversationId, 'C456');
      });

      test('parses mention event', () {
        final payload = {
          'event': {
            'type': 'app_mention',
            'text': '<@U_BOT> help',
            'user': 'U123',
            'channel': 'C456',
            'team': 'T789',
            'ts': '1234567890.123456',
          },
        };

        final event = connector.parseEvent(payload);

        expect(event.type, 'mention');
        expect(event.text, '<@U_BOT> help');
      });

      test('parses file share event', () {
        final payload = {
          'event': {
            'type': 'message',
            'subtype': 'file_share',
            'text': 'Uploaded a file',
            'user': 'U123',
            'channel': 'C456',
            'team': 'T789',
            'ts': '1234567890.123456',
            'files': [
              {
                'id': 'F123',
                'name': 'test.pdf',
                'url_private': 'https://files.slack.com/test.pdf',
                'mimetype': 'application/pdf',
                'size': 1024,
              }
            ],
          },
        };

        final event = connector.parseEvent(payload);

        expect(event.type, 'file');
        expect(event.attachments, isNotNull);
        expect(event.attachments!.first.filename, 'test.pdf');
        expect(event.attachments!.first.mimeType, 'application/pdf');
      });

      test('parses reaction event', () {
        final payload = {
          'event': {
            'type': 'reaction_added',
            'user': 'U123',
            'reaction': 'thumbsup',
            'event_ts': '1234567890.123456',
            'item': {
              'type': 'message',
              'channel': 'C456',
              'ts': '1234567889.000000',
            },
            'team': 'T789',
          },
        };

        final event = connector.parseEvent(payload);

        expect(event.type, 'reaction');
        expect(event.text, 'thumbsup');
      });

      test('parses join event', () {
        final payload = {
          'event': {
            'type': 'member_joined_channel',
            'user': 'U123',
            'channel': 'C456',
            'team': 'T789',
            'event_ts': '1234567890.123456',
          },
        };

        final event = connector.parseEvent(payload);

        expect(event.type, 'join');
        expect(event.userId, 'U123');
      });

      test('parses leave event', () {
        final payload = {
          'event': {
            'type': 'member_left_channel',
            'user': 'U123',
            'channel': 'C456',
            'team': 'T789',
            'event_ts': '1234567890.123456',
          },
        };

        final event = connector.parseEvent(payload);

        expect(event.type, 'leave');
      });

      test('parses unknown event', () {
        final payload = {
          'event': {
            'type': 'custom_event',
            'user': 'U123',
          },
        };

        final event = connector.parseEvent(payload);

        expect(event.type, 'unknown');
      });

      test('handles payload without event key', () {
        final payload = <String, dynamic>{
          'type': 'url_verification',
          'challenge': 'abc123',
        };

        final event = connector.parseEvent(payload);
        expect(event.type, 'unknown');
      });
    });

    group('interactive event handling', () {
      test('handleBlockAction emits button event', () async {
        final events = <ChannelEvent>[];
        final sub = connector.events.listen(events.add);

        final interaction = {
          'type': 'block_actions',
          'trigger_id': 'trigger-123',
          'user': {'id': 'U123', 'name': 'testuser'},
          'channel': {'id': 'C456'},
          'team': {'id': 'T789'},
          'message': {'ts': '1234567890.123456', 'thread_ts': '1234567889.000000'},
          'actions': [
            {
              'action_id': 'approve_btn',
              'value': 'approved',
              'type': 'button',
            }
          ],
        };

        connector.handleBlockAction(interaction);

        // Allow event to propagate
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first.type, 'button');
        expect(events.first.userId, 'U123');
        expect(events.first.metadata?['action_id'], isNull);

        await sub.cancel();
      });

      test('handleViewSubmission emits button event with values', () async {
        final events = <ChannelEvent>[];
        final sub = connector.events.listen(events.add);

        final interaction = {
          'type': 'view_submission',
          'trigger_id': 'trigger-456',
          'user': {'id': 'U123', 'name': 'testuser'},
          'team': {'id': 'T789'},
          'view': {
            'callback_id': 'feedback_modal',
            'private_metadata': 'C456',
            'state': {
              'values': {
                'block_1': {
                  'input_1': {
                    'type': 'plain_text_input',
                    'value': 'Some feedback',
                  },
                },
              },
            },
          },
        };

        connector.handleViewSubmission(interaction);

        // Allow event to propagate
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first.type, 'button');
        expect(events.first.userId, 'U123');

        await sub.cancel();
      });
    });

    group('message payload building', () {
      test('send rejects response without text or blocks', () async {
        final response = ChannelResponse(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'slack',
              channelId: 'T123',
            ),
            conversationId: 'C456',
          ),
          type: 'text',
        );

        expect(
          () => connector.send(response),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('sendWithResult returns failure for empty response', () async {
        final response = ChannelResponse(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'slack',
              channelId: 'T123',
            ),
            conversationId: 'C456',
          ),
          type: 'text',
        );

        final result = await connector.sendWithResult(response);
        expect(result.success, isFalse);
        expect(result.error?.code, ChannelErrorCode.invalidRequest);
      });
    });

    test('starts disconnected', () {
      expect(connector.isRunning, isFalse);
      expect(
        connector.currentConnectionState,
        ConnectionState.disconnected,
      );
    });

    tearDown(() async {
      await connector.dispose();
    });
  });

  group('ModalView', () {
    test('creates with required fields', () {
      final view = ModalView(
        callbackId: 'test_modal',
        title: 'Test Modal',
        blocks: [
          ContentBlock.section(text: 'Hello'),
        ],
      );

      expect(view.callbackId, 'test_modal');
      expect(view.title, 'Test Modal');
      expect(view.submitText, isNull);
      expect(view.privateMetadata, isNull);
      expect(view.blocks, hasLength(1));
    });

    test('creates with all fields', () {
      final view = ModalView(
        callbackId: 'feedback',
        title: 'Feedback Form',
        submitText: 'Submit',
        blocks: [
          ContentBlock.input(
            label: 'Your feedback',
            actionId: 'feedback_input',
          ),
        ],
        privateMetadata: 'C456',
      );

      expect(view.callbackId, 'feedback');
      expect(view.title, 'Feedback Form');
      expect(view.submitText, 'Submit');
      expect(view.privateMetadata, 'C456');
    });

    test('copyWith creates new view with updated fields', () {
      final original = ModalView(
        callbackId: 'original',
        title: 'Original',
        blocks: const [],
      );

      final copied = original.copyWith(
        title: 'Updated',
        submitText: 'Go',
      );

      expect(copied.callbackId, 'original');
      expect(copied.title, 'Updated');
      expect(copied.submitText, 'Go');
    });
  });

  // ===========================================================================
  // Additional SlackConfig coverage
  // ===========================================================================

  group('SlackConfig additional coverage', () {
    test('default reconnectDelay is 5 seconds', () {
      final config = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
      );
      expect(config.reconnectDelay, const Duration(seconds: 5));
    });

    test('default appToken is null', () {
      final config = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
      );
      expect(config.appToken, isNull);
    });

    test('default workspaceId is null', () {
      final config = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
      );
      expect(config.workspaceId, isNull);
    });

    test('scopes list preserves order', () {
      final config = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
        scopes: const ['channels:read', 'chat:write', 'users:read'],
      );
      expect(config.scopes, orderedEquals(['channels:read', 'chat:write', 'users:read']));
    });

    test('copyWith preserves all fields when no args given', () {
      final original = SlackConfig(
        botToken: 'xoxb-original',
        appToken: 'xapp-original',
        signingSecret: 'original-secret',
        webhookPath: '/events',
        workspaceId: 'W123',
        useSocketMode: true,
        scopes: const ['chat:write'],
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 20),
        maxReconnectAttempts: 7,
      );

      final copied = original.copyWith();

      expect(copied.botToken, original.botToken);
      expect(copied.appToken, original.appToken);
      expect(copied.signingSecret, original.signingSecret);
      expect(copied.webhookPath, original.webhookPath);
      expect(copied.workspaceId, original.workspaceId);
      expect(copied.useSocketMode, original.useSocketMode);
      expect(copied.scopes, original.scopes);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith can update appToken', () {
      final original = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
      );
      final copied = original.copyWith(appToken: 'xapp-new');
      expect(copied.appToken, 'xapp-new');
    });

    test('copyWith can update signingSecret', () {
      final original = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'old-secret',
      );
      final copied = original.copyWith(signingSecret: 'new-secret');
      expect(copied.signingSecret, 'new-secret');
    });

    test('copyWith can update useSocketMode', () {
      final original = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
      );
      final copied = original.copyWith(useSocketMode: true);
      expect(copied.useSocketMode, isTrue);
    });

    test('copyWith can update autoReconnect', () {
      final original = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
      );
      final copied = original.copyWith(autoReconnect: false);
      expect(copied.autoReconnect, isFalse);
    });

    test('copyWith can update reconnectDelay', () {
      final original = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
      );
      final copied = original.copyWith(
        reconnectDelay: const Duration(seconds: 30),
      );
      expect(copied.reconnectDelay, const Duration(seconds: 30));
    });

    test('copyWith can update maxReconnectAttempts', () {
      final original = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
      );
      final copied = original.copyWith(maxReconnectAttempts: 20);
      expect(copied.maxReconnectAttempts, 20);
    });

    test('validate passes when socketMode has appToken', () {
      final config = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
        useSocketMode: true,
        appToken: 'xapp-valid',
      );
      expect(() => config.validate(), returnsNormally);
    });

    test('validate passes when HTTP mode has webhookPath', () {
      final config = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
        useSocketMode: false,
        webhookPath: '/slack/events',
      );
      expect(() => config.validate(), returnsNormally);
    });

    test('channelType is always slack', () {
      final config1 = SlackConfig(
        botToken: 'xoxb-1',
        signingSecret: 'secret-1',
        useSocketMode: true,
        appToken: 'xapp-1',
      );
      final config2 = SlackConfig(
        botToken: 'xoxb-2',
        signingSecret: 'secret-2',
        useSocketMode: false,
        webhookPath: '/events',
      );
      expect(config1.channelType, 'slack');
      expect(config2.channelType, 'slack');
    });

    test('reconnectDelay can be customized', () {
      final config = SlackConfig(
        botToken: 'xoxb-test',
        signingSecret: 'secret',
        reconnectDelay: const Duration(seconds: 15),
      );
      expect(config.reconnectDelay, const Duration(seconds: 15));
    });
  });
}
