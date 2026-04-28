import 'package:mcp_channel/mcp_channel.dart';
import 'package:mcp_channel/src/core/port/channel_error.dart';
import 'package:test/test.dart';

// Import connector-specific types
import 'package:mcp_channel/src/connectors/telegram/telegram.dart';

void main() {
  group('TelegramConfig', () {
    test('creates config with required fields', () {
      final config = TelegramConfig(botToken: 'test-token');

      expect(config.botToken, 'test-token');
      expect(config.channelType, 'telegram');
      expect(config.pollingTimeout, 30);
      expect(config.autoReconnect, isTrue);
      expect(config.apiBaseUrl, 'https://api.telegram.org');
      expect(config.webhookSecret, isNull);
    });

    test('creates config with all fields', () {
      final config = TelegramConfig(
        botToken: 'test-token',
        webhookUrl: 'https://example.com/webhook',
        webhookSecret: 'my-secret',
        pollingTimeout: 60,
        allowedUpdates: const ['message'],
        apiBaseUrl: 'https://custom-api.example.com',
        autoReconnect: false,
        maxReconnectAttempts: 5,
      );

      expect(config.webhookUrl, 'https://example.com/webhook');
      expect(config.webhookSecret, 'my-secret');
      expect(config.pollingTimeout, 60);
      expect(config.allowedUpdates, ['message']);
      expect(config.apiBaseUrl, 'https://custom-api.example.com');
      expect(config.autoReconnect, isFalse);
    });

    test('copyWith creates updated config', () {
      final original = TelegramConfig(botToken: 'original');
      final copied = original.copyWith(
        pollingTimeout: 60,
        apiBaseUrl: 'https://test.example.com',
        webhookSecret: 'new-secret',
      );

      expect(copied.botToken, 'original');
      expect(copied.pollingTimeout, 60);
      expect(copied.apiBaseUrl, 'https://test.example.com');
      expect(copied.webhookSecret, 'new-secret');
    });

    test('isPolling is true when webhookUrl is null', () {
      final config = TelegramConfig(botToken: 'token');
      expect(config.isPolling, isTrue);
      expect(config.isWebhook, isFalse);
    });

    test('isWebhook is true when webhookUrl is set', () {
      final config = TelegramConfig(
        botToken: 'token',
        webhookUrl: 'https://example.com/webhook',
      );
      expect(config.isWebhook, isTrue);
      expect(config.isPolling, isFalse);
    });
  });

  group('TelegramConnector', () {
    late TelegramConnector connector;

    setUp(() {
      connector = TelegramConnector(
        config: TelegramConfig(botToken: 'test-bot-token'),
      );
    });

    test('has correct channel type', () {
      expect(connector.channelType, 'telegram');
    });

    test('has correct identity', () {
      expect(connector.identity.platform, 'telegram');
    });

    test('has telegram capabilities', () {
      final caps = connector.extendedCapabilities;
      expect(caps.text, isTrue);
      expect(caps.supportsButtons, isTrue);
      expect(caps.supportsModals, isFalse);
      expect(caps.supportsCommands, isTrue);
      expect(caps.maxMessageLength, 4096);
    });

    group('event parsing', () {
      test('parses text message update', () {
        final update = {
          'update_id': 123456,
          'message': {
            'message_id': 1,
            'from': {
              'id': 100,
              'first_name': 'Test',
              'username': 'testuser',
            },
            'chat': {
              'id': 200,
              'type': 'private',
            },
            'date': 1700000000,
            'text': 'Hello bot',
          },
        };

        final event = connector.handleWebhookUpdate(update);

        expect(event.id, '123456_1');
        expect(event.type, 'message');
        expect(event.text, 'Hello bot');
        expect(event.userId, '100');
        expect(event.conversation.conversationId, '200');
      });

      test('parses command message', () {
        final update = {
          'update_id': 123457,
          'message': {
            'message_id': 2,
            'from': {'id': 100, 'first_name': 'Test'},
            'chat': {'id': 200, 'type': 'private'},
            'date': 1700000000,
            'text': '/start hello',
            'entities': [
              {'type': 'bot_command', 'offset': 0, 'length': 6}
            ],
          },
        };

        final event = connector.handleWebhookUpdate(update);

        expect(event.id, '123457_2');
        expect(event.type, 'command');
        expect(event.text, '/start hello');
        expect(event.metadata?['command'], 'start');
      });

      test('parses callback query', () {
        final update = {
          'update_id': 123458,
          'callback_query': {
            'id': 'cb_123',
            'from': {'id': 100, 'first_name': 'Test'},
            'message': {
              'message_id': 5,
              'chat': {'id': 200, 'type': 'private'},
            },
            'data': 'button_value',
          },
        };

        final event = connector.handleWebhookUpdate(update);

        expect(event.id, '123458_5');
        expect(event.type, 'button');
        expect(event.text, 'button_value');
        expect(event.metadata?['action_value'], 'button_value');
      });

      test('parses message with photo attachment', () {
        final update = {
          'update_id': 123459,
          'message': {
            'message_id': 3,
            'from': {'id': 100, 'first_name': 'Test'},
            'chat': {'id': 200, 'type': 'private'},
            'date': 1700000000,
            'photo': [
              {
                'file_id': 'small_id',
                'file_size': 100,
                'width': 90,
                'height': 90
              },
              {
                'file_id': 'large_id',
                'file_size': 500,
                'width': 800,
                'height': 600
              },
            ],
          },
        };

        final event = connector.handleWebhookUpdate(update);

        expect(event.attachments, isNotNull);
        expect(event.attachments!.first.type, 'image');
        expect(event.attachments!.first.url, 'large_id');
      });

      test('parses unknown update', () {
        final update = {
          'update_id': 123460,
          'channel_post': {'text': 'channel message'},
        };

        final event = connector.handleWebhookUpdate(update);

        expect(event.id, '123460_123460');
        expect(event.type, 'unknown');
      });

      test('event ID matches design doc format: updateId_messageId', () {
        final update = {
          'update_id': 999,
          'message': {
            'message_id': 42,
            'from': {'id': 1, 'first_name': 'User'},
            'chat': {'id': 2, 'type': 'private'},
            'date': 1700000000,
            'text': 'test',
          },
        };

        final event = connector.handleWebhookUpdate(update);
        expect(event.id, '999_42');
      });
    });

    group('webhook secret validation', () {
      late TelegramConnector secretConnector;

      setUp(() {
        secretConnector = TelegramConnector(
          config: TelegramConfig(
            botToken: 'test-bot-token',
            webhookSecret: 'my-secret-token',
          ),
        );
      });

      test('accepts update with valid secret header', () {
        final update = {
          'update_id': 100,
          'message': {
            'message_id': 1,
            'from': {'id': 1, 'first_name': 'Test'},
            'chat': {'id': 2, 'type': 'private'},
            'date': 1700000000,
            'text': 'hello',
          },
        };

        final event = secretConnector.handleWebhookUpdate(
          update,
          headers: {'x-telegram-bot-api-secret-token': 'my-secret-token'},
        );

        expect(event.type, 'message');
        expect(event.text, 'hello');
      });

      test('rejects update with invalid secret header', () {
        final update = {
          'update_id': 101,
          'message': {
            'message_id': 1,
            'from': {'id': 1, 'first_name': 'Test'},
            'chat': {'id': 2, 'type': 'private'},
            'date': 1700000000,
            'text': 'hello',
          },
        };

        expect(
          () => secretConnector.handleWebhookUpdate(
            update,
            headers: {'x-telegram-bot-api-secret-token': 'wrong-secret'},
          ),
          throwsA(isA<ChannelError>().having(
            (e) => e.code,
            'code',
            ChannelErrorCode.permissionDenied,
          )),
        );
      });

      test('rejects update with missing secret header', () {
        final update = {
          'update_id': 102,
          'message': {
            'message_id': 1,
            'from': {'id': 1, 'first_name': 'Test'},
            'chat': {'id': 2, 'type': 'private'},
            'date': 1700000000,
            'text': 'hello',
          },
        };

        expect(
          () => secretConnector.handleWebhookUpdate(update),
          throwsA(isA<ChannelError>().having(
            (e) => e.code,
            'code',
            ChannelErrorCode.permissionDenied,
          )),
        );
      });

      test('skips validation when no secret configured', () {
        // connector has no webhookSecret configured
        final update = {
          'update_id': 103,
          'message': {
            'message_id': 1,
            'from': {'id': 1, 'first_name': 'Test'},
            'chat': {'id': 2, 'type': 'private'},
            'date': 1700000000,
            'text': 'hello',
          },
        };

        // Should not throw even without headers
        final event = connector.handleWebhookUpdate(update);
        expect(event.type, 'message');
      });

      tearDown(() async {
        await secretConnector.dispose();
      });
    });

    tearDown(() async {
      await connector.dispose();
    });
  });

  // ===========================================================================
  // Additional TelegramConfig coverage
  // ===========================================================================

  group('TelegramConfig additional coverage', () {
    test('default apiBaseUrl is telegram API', () {
      final config = TelegramConfig(botToken: 'test');
      expect(config.apiBaseUrl, 'https://api.telegram.org');
    });

    test('default webhookSecret is null', () {
      final config = TelegramConfig(botToken: 'test');
      expect(config.webhookSecret, isNull);
    });

    test('default pollingTimeout is 30', () {
      final config = TelegramConfig(botToken: 'test');
      expect(config.pollingTimeout, 30);
    });

    test('default allowedUpdates includes standard types', () {
      final config = TelegramConfig(botToken: 'test');
      expect(
        config.allowedUpdates,
        containsAll(['message', 'edited_message', 'callback_query', 'inline_query']),
      );
    });

    test('default reconnectDelay is 5 seconds', () {
      final config = TelegramConfig(botToken: 'test');
      expect(config.reconnectDelay, const Duration(seconds: 5));
    });

    test('default maxReconnectAttempts is 10', () {
      final config = TelegramConfig(botToken: 'test');
      expect(config.maxReconnectAttempts, 10);
    });

    test('default autoReconnect is true', () {
      final config = TelegramConfig(botToken: 'test');
      expect(config.autoReconnect, isTrue);
    });

    test('channelType is always telegram', () {
      final config = TelegramConfig(botToken: 'test');
      expect(config.channelType, 'telegram');
    });

    test('copyWith preserves all fields when no args given', () {
      final original = TelegramConfig(
        botToken: 'orig-token',
        webhookUrl: 'https://webhook.example.com',
        webhookSecret: 'orig-secret',
        pollingTimeout: 45,
        allowedUpdates: const ['message'],
        apiBaseUrl: 'https://custom-api.example.com',
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 10),
        maxReconnectAttempts: 5,
      );

      final copied = original.copyWith();

      expect(copied.botToken, original.botToken);
      expect(copied.webhookUrl, original.webhookUrl);
      expect(copied.webhookSecret, original.webhookSecret);
      expect(copied.pollingTimeout, original.pollingTimeout);
      expect(copied.allowedUpdates, original.allowedUpdates);
      expect(copied.apiBaseUrl, original.apiBaseUrl);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith can update botToken', () {
      final original = TelegramConfig(botToken: 'old');
      final copied = original.copyWith(botToken: 'new');
      expect(copied.botToken, 'new');
    });

    test('copyWith can update webhookUrl', () {
      final original = TelegramConfig(botToken: 'token');
      final copied = original.copyWith(
        webhookUrl: 'https://new-webhook.example.com',
      );
      expect(copied.webhookUrl, 'https://new-webhook.example.com');
    });

    test('copyWith can update allowedUpdates', () {
      final original = TelegramConfig(botToken: 'token');
      final copied = original.copyWith(
        allowedUpdates: ['message', 'channel_post'],
      );
      expect(copied.allowedUpdates, ['message', 'channel_post']);
    });

    test('copyWith can update autoReconnect', () {
      final original = TelegramConfig(botToken: 'token');
      final copied = original.copyWith(autoReconnect: false);
      expect(copied.autoReconnect, isFalse);
    });

    test('copyWith can update reconnectDelay', () {
      final original = TelegramConfig(botToken: 'token');
      final copied = original.copyWith(
        reconnectDelay: const Duration(seconds: 20),
      );
      expect(copied.reconnectDelay, const Duration(seconds: 20));
    });

    test('copyWith can update maxReconnectAttempts', () {
      final original = TelegramConfig(botToken: 'token');
      final copied = original.copyWith(maxReconnectAttempts: 15);
      expect(copied.maxReconnectAttempts, 15);
    });

    test('isPolling returns true when webhookUrl is null', () {
      final config = TelegramConfig(botToken: 'token');
      expect(config.isPolling, isTrue);
    });

    test('isWebhook returns true when webhookUrl is set', () {
      final config = TelegramConfig(
        botToken: 'token',
        webhookUrl: 'https://example.com/wh',
      );
      expect(config.isWebhook, isTrue);
    });

    test('isPolling and isWebhook are mutually exclusive', () {
      final polling = TelegramConfig(botToken: 'token');
      expect(polling.isPolling, isTrue);
      expect(polling.isWebhook, isFalse);

      final webhook = TelegramConfig(
        botToken: 'token',
        webhookUrl: 'https://example.com/wh',
      );
      expect(webhook.isPolling, isFalse);
      expect(webhook.isWebhook, isTrue);
    });

    test('long pollingTimeout can be customized', () {
      final config = TelegramConfig(
        botToken: 'token',
        pollingTimeout: 120,
      );
      expect(config.pollingTimeout, 120);
    });
  });
}
