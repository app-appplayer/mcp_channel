import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

import 'package:mcp_channel/src/connectors/youtube/youtube.dart';

void main() {
  group('YouTubeMode', () {
    test('has comments value', () {
      expect(YouTubeMode.comments.name, 'comments');
    });

    test('has liveChat value', () {
      expect(YouTubeMode.liveChat.name, 'liveChat');
    });

    test('has both value', () {
      expect(YouTubeMode.both.name, 'both');
    });

    test('has exactly 3 values', () {
      expect(YouTubeMode.values.length, 3);
    });
  });

  group('YouTubeConfig', () {
    test('creates config with required fields only', () {
      final config = YouTubeConfig(apiKey: 'AIza-test-key');

      expect(config.apiKey, 'AIza-test-key');
      expect(config.channelType, 'youtube');
      expect(config.channelId, isNull);
      expect(config.liveChatId, isNull);
      expect(config.mode, YouTubeMode.both);
      expect(config.videoIds, isNull);
      expect(config.commandPrefix, isNull);
      expect(config.mentionsOnly, isFalse);
      expect(config.credentials, isNull);
      expect(config.pollingInterval, const Duration(seconds: 30));
      expect(config.quotaBudget, 10000);
      expect(config.autoReconnect, isTrue);
      expect(config.maxReconnectAttempts, 10);
      expect(config.reconnectDelay, const Duration(seconds: 5));
    });

    test('creates config with all fields', () {
      final config = YouTubeConfig(
        apiKey: 'AIza-test-key',
        channelId: 'UC-test-channel',
        liveChatId: 'Cg0KC-test-chat',
        mode: YouTubeMode.comments,
        videoIds: ['VIDEO_ID_1', 'VIDEO_ID_2'],
        commandPrefix: '!bot',
        mentionsOnly: true,
        pollingInterval: const Duration(minutes: 1),
        credentials: {
          'clientId': 'test-client-id',
          'clientSecret': 'test-client-secret',
          'refreshToken': 'test-refresh-token',
        },
        quotaBudget: 5000,
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 15),
        maxReconnectAttempts: 3,
      );

      expect(config.apiKey, 'AIza-test-key');
      expect(config.channelId, 'UC-test-channel');
      expect(config.liveChatId, 'Cg0KC-test-chat');
      expect(config.mode, YouTubeMode.comments);
      expect(config.videoIds, ['VIDEO_ID_1', 'VIDEO_ID_2']);
      expect(config.commandPrefix, '!bot');
      expect(config.mentionsOnly, isTrue);
      expect(config.pollingInterval, const Duration(minutes: 1));
      expect(config.credentials, isNotNull);
      expect(config.credentials!['clientId'], 'test-client-id');
      expect(config.credentials!['clientSecret'], 'test-client-secret');
      expect(config.credentials!['refreshToken'], 'test-refresh-token');
      expect(config.quotaBudget, 5000);
      expect(config.autoReconnect, isFalse);
      expect(config.reconnectDelay, const Duration(seconds: 15));
      expect(config.maxReconnectAttempts, 3);
    });

    test('copyWith creates new config with updated fields', () {
      final original = YouTubeConfig(
        apiKey: 'AIza-original',
        channelId: 'UC-original',
      );
      final copied = original.copyWith(
        apiKey: 'AIza-updated',
        liveChatId: 'Cg0KC-new-chat',
        mode: YouTubeMode.liveChat,
        videoIds: ['VID_1'],
        commandPrefix: '!cmd',
        mentionsOnly: true,
        quotaBudget: 8000,
      );

      expect(copied.apiKey, 'AIza-updated');
      expect(copied.channelId, 'UC-original');
      expect(copied.liveChatId, 'Cg0KC-new-chat');
      expect(copied.mode, YouTubeMode.liveChat);
      expect(copied.videoIds, ['VID_1']);
      expect(copied.commandPrefix, '!cmd');
      expect(copied.mentionsOnly, isTrue);
      expect(copied.quotaBudget, 8000);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.pollingInterval, original.pollingInterval);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith preserves all fields when none specified', () {
      final original = YouTubeConfig(
        apiKey: 'AIza-test',
        channelId: 'UC-test',
        liveChatId: 'Cg0KC-test',
        mode: YouTubeMode.comments,
        videoIds: ['VID_A', 'VID_B'],
        commandPrefix: '!bot',
        mentionsOnly: true,
        pollingInterval: const Duration(seconds: 20),
        credentials: {'clientId': 'id', 'clientSecret': 'secret', 'refreshToken': 'token'},
        quotaBudget: 7000,
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 30),
        maxReconnectAttempts: 5,
      );
      final copied = original.copyWith();

      expect(copied.apiKey, original.apiKey);
      expect(copied.channelId, original.channelId);
      expect(copied.liveChatId, original.liveChatId);
      expect(copied.mode, original.mode);
      expect(copied.videoIds, original.videoIds);
      expect(copied.commandPrefix, original.commandPrefix);
      expect(copied.mentionsOnly, original.mentionsOnly);
      expect(copied.pollingInterval, original.pollingInterval);
      expect(copied.credentials, original.credentials);
      expect(copied.quotaBudget, original.quotaBudget);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('hasOAuth2Credentials returns true with all required keys', () {
      final config = YouTubeConfig(
        apiKey: 'AIza-test',
        credentials: {
          'clientId': 'test-client-id',
          'clientSecret': 'test-client-secret',
          'refreshToken': 'test-refresh-token',
        },
      );

      expect(config.hasOAuth2Credentials, isTrue);
    });

    test('hasOAuth2Credentials returns false when credentials are null', () {
      final config = YouTubeConfig(apiKey: 'AIza-test');

      expect(config.hasOAuth2Credentials, isFalse);
    });

    test('hasOAuth2Credentials returns false when missing clientId', () {
      final config = YouTubeConfig(
        apiKey: 'AIza-test',
        credentials: {
          'clientSecret': 'test-client-secret',
          'refreshToken': 'test-refresh-token',
        },
      );

      expect(config.hasOAuth2Credentials, isFalse);
    });

    test('hasOAuth2Credentials returns false when missing clientSecret', () {
      final config = YouTubeConfig(
        apiKey: 'AIza-test',
        credentials: {
          'clientId': 'test-client-id',
          'refreshToken': 'test-refresh-token',
        },
      );

      expect(config.hasOAuth2Credentials, isFalse);
    });

    test('hasOAuth2Credentials returns false when missing refreshToken', () {
      final config = YouTubeConfig(
        apiKey: 'AIza-test',
        credentials: {
          'clientId': 'test-client-id',
          'clientSecret': 'test-client-secret',
        },
      );

      expect(config.hasOAuth2Credentials, isFalse);
    });

    test('hasOAuth2Credentials returns false with empty credentials map', () {
      final config = YouTubeConfig(
        apiKey: 'AIza-test',
        credentials: {},
      );

      expect(config.hasOAuth2Credentials, isFalse);
    });

    test('default polling interval is 30 seconds', () {
      final config = YouTubeConfig(apiKey: 'AIza-test');

      expect(config.pollingInterval, const Duration(seconds: 30));
    });

    test('default mode is both', () {
      final config = YouTubeConfig(apiKey: 'AIza-test');

      expect(config.mode, YouTubeMode.both);
    });

    test('default mentionsOnly is false', () {
      final config = YouTubeConfig(apiKey: 'AIza-test');

      expect(config.mentionsOnly, isFalse);
    });

    test('default quota budget is 10000', () {
      final config = YouTubeConfig(apiKey: 'AIza-test');

      expect(config.quotaBudget, 10000);
    });
  });

  group('YouTubeConnector', () {
    late YouTubeConnector connector;

    setUp(() {
      connector = YouTubeConnector(
        config: YouTubeConfig(
          apiKey: 'AIza-test-key',
          channelId: 'UC-test-channel',
        ),
      );
    });

    test('has correct channel type', () {
      expect(connector.channelType, 'youtube');
    });

    test('has correct identity with channelId', () {
      expect(connector.identity.platform, 'youtube');
      expect(connector.identity.channelId, 'UC-test-channel');
    });

    test('has correct identity with liveChatId when no channelId', () {
      final chatConnector = YouTubeConnector(
        config: YouTubeConfig(
          apiKey: 'AIza-test-key',
          liveChatId: 'Cg0KC-test-chat',
        ),
      );

      expect(chatConnector.identity.platform, 'youtube');
      expect(chatConnector.identity.channelId, 'Cg0KC-test-chat');
    });

    test('has correct identity with default when no channelId or liveChatId', () {
      final defaultConnector = YouTubeConnector(
        config: YouTubeConfig(apiKey: 'AIza-test-key'),
      );

      expect(defaultConnector.identity.platform, 'youtube');
      expect(defaultConnector.identity.channelId, 'default');
    });

    test('identity prefers channelId over liveChatId', () {
      final bothConnector = YouTubeConnector(
        config: YouTubeConfig(
          apiKey: 'AIza-test-key',
          channelId: 'UC-channel',
          liveChatId: 'Cg0KC-chat',
        ),
      );

      expect(bothConnector.identity.channelId, 'UC-channel');
    });

    test('has youtube capabilities', () {
      final caps = connector.extendedCapabilities;
      expect(caps.text, isTrue);
      expect(caps.richMessages, isFalse);
      expect(caps.attachments, isFalse);
      expect(caps.reactions, isFalse);
      expect(caps.threads, isTrue);
      expect(caps.editing, isTrue);
      expect(caps.deleting, isTrue);
      expect(caps.typingIndicator, isFalse);
      expect(caps.maxMessageLength, 10000);
      expect(caps.supportsFiles, isFalse);
      expect(caps.supportsButtons, isFalse);
      expect(caps.supportsMenus, isFalse);
      expect(caps.supportsModals, isFalse);
      expect(caps.supportsEphemeral, isFalse);
      expect(caps.supportsCommands, isTrue);
    });

    test('capabilities is ExtendedChannelCapabilities', () {
      expect(connector.capabilities, isA<ExtendedChannelCapabilities>());
    });

    test('capabilities custom includes liveChatMaxLength', () {
      final caps = connector.extendedCapabilities;
      expect(caps.custom, isNotNull);
      expect(caps.custom!['liveChatMaxLength'], 200);
      expect(caps.custom!['isPublic'], true);
      expect(caps.custom!['requiresOAuth'], true);
      expect(caps.custom!['quotaLimited'], true);
    });

    group('quota tracking', () {
      test('starts with zero quota used', () {
        expect(connector.quotaUsed, 0);
        expect(connector.quotaRemaining, 10000);
      });

      test('quotaRemaining reflects config budget', () {
        final customConnector = YouTubeConnector(
          config: YouTubeConfig(
            apiKey: 'AIza-test',
            quotaBudget: 5000,
          ),
        );

        expect(customConnector.quotaRemaining, 5000);
      });

      test('resetQuota resets quota used to zero', () {
        connector.resetQuota();
        expect(connector.quotaUsed, 0);
        expect(connector.quotaRemaining, 10000);
      });

      test('canUseQuota returns true when within budget', () {
        expect(connector.canUseQuota(100), isTrue);
      });

      test('canUseQuota returns false when exceeding budget', () {
        expect(connector.canUseQuota(10001), isFalse);
      });
    });

    group('command parsing', () {
      late YouTubeConnector cmdConnector;
      late ConversationKey testConversation;

      setUp(() {
        cmdConnector = YouTubeConnector(
          config: YouTubeConfig(
            apiKey: 'AIza-test-key',
            channelId: 'UC-test-channel',
            commandPrefix: '!bot',
          ),
        );
        testConversation = ConversationKey(
          channel: ChannelIdentity(
            platform: 'youtube',
            channelId: 'UC-test-channel',
          ),
          conversationId: 'video123',
        );
      });

      test('returns null when no prefix configured', () {
        final noPrefixConnector = YouTubeConnector(
          config: YouTubeConfig(
            apiKey: 'AIza-test-key',
            channelId: 'UC-test-channel',
          ),
        );

        final result = noPrefixConnector.parseCommand(
          '!bot help',
          testConversation,
        );
        expect(result, isNull);
      });

      test('returns null when text does not match prefix', () {
        final result = cmdConnector.parseCommand(
          'hello world',
          testConversation,
        );
        expect(result, isNull);
      });

      test('returns null when only prefix with no command', () {
        final result = cmdConnector.parseCommand(
          '!bot',
          testConversation,
        );
        expect(result, isNull);
      });

      test('parses command with no arguments', () {
        final result = cmdConnector.parseCommand(
          '!bot help',
          testConversation,
          userId: 'user123',
          userName: 'TestUser',
        );

        expect(result, isNotNull);
        expect(result!.eventType, ChannelEventType.command);
        expect(result.command, 'help');
        expect(result.commandArgs, isEmpty);
        expect(result.userId, 'user123');
        expect(result.userName, 'TestUser');
      });

      test('parses command with arguments', () {
        final result = cmdConnector.parseCommand(
          '!bot search flutter dart',
          testConversation,
        );

        expect(result, isNotNull);
        expect(result!.command, 'search');
        expect(result.commandArgs, ['flutter', 'dart']);
      });

      test('parses command with extra whitespace', () {
        final result = cmdConnector.parseCommand(
          '!bot  search  flutter',
          testConversation,
        );

        expect(result, isNotNull);
        expect(result!.command, 'search');
      });
    });

    test('starts disconnected', () {
      expect(connector.isRunning, isFalse);
      expect(
        connector.currentConnectionState,
        ConnectionState.disconnected,
      );
    });

    test('liveChatMaxLength constant is 200', () {
      expect(YouTubeConnector.liveChatMaxLength, 200);
    });

    tearDown(() async {
      await connector.dispose();
    });
  });
}
