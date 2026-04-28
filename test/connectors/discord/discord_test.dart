import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

import 'package:mcp_channel/src/connectors/discord/discord.dart';

void main() {
  group('DiscordConfig', () {
    test('creates config with required fields', () {
      final config = DiscordConfig(
        botToken: 'test-token',
        applicationId: 'app-123',
      );

      expect(config.botToken, 'test-token');
      expect(config.applicationId, 'app-123');
      expect(config.channelType, 'discord');
      expect(config.intents, DiscordIntents.defaultBot);
      expect(config.apiVersion, 10);
      expect(config.compress, isTrue);
      expect(config.autoReconnect, isTrue);
    });

    test('creates config with all fields', () {
      final config = DiscordConfig(
        botToken: 'test-token',
        applicationId: 'app-123',
        intents: DiscordIntents.guilds | DiscordIntents.guildMessages,
        shardId: 0,
        totalShards: 2,
        apiVersion: 9,
        compress: false,
        autoReconnect: false,
        maxReconnectAttempts: 3,
      );

      expect(config.applicationId, 'app-123');
      expect(config.shardId, 0);
      expect(config.totalShards, 2);
      expect(config.apiVersion, 9);
      expect(config.compress, isFalse);
      expect(config.autoReconnect, isFalse);
    });

    test('default intents include required bits', () {
      expect(DiscordIntents.defaultBot & DiscordIntents.guilds, isNonZero);
      expect(DiscordIntents.defaultBot & DiscordIntents.guildMessages, isNonZero);
      expect(DiscordIntents.defaultBot & DiscordIntents.directMessages, isNonZero);
      expect(DiscordIntents.defaultBot & DiscordIntents.messageContent, isNonZero);
    });

    test('copyWith creates updated config', () {
      final original = DiscordConfig(
        botToken: 'original',
        applicationId: 'app-123',
      );
      final copied = original.copyWith(
        applicationId: 'app-456',
        apiVersion: 9,
        compress: false,
      );

      expect(copied.botToken, 'original');
      expect(copied.applicationId, 'app-456');
      expect(copied.apiVersion, 9);
      expect(copied.compress, isFalse);
    });
  });

  group('DiscordConnector', () {
    late DiscordConnector connector;

    setUp(() {
      connector = DiscordConnector(
        config: DiscordConfig(
          botToken: 'test-bot-token',
          applicationId: 'app-123',
        ),
      );
    });

    test('has correct channel type', () {
      expect(connector.channelType, 'discord');
    });

    test('has correct identity', () {
      expect(connector.identity.platform, 'discord');
      expect(connector.identity.channelId, 'app-123');
    });

    test('has discord capabilities', () {
      final caps = connector.extendedCapabilities;
      expect(caps.text, isTrue);
      expect(caps.richMessages, isTrue);
      expect(caps.supportsButtons, isTrue);
      expect(caps.supportsModals, isTrue);
      expect(caps.maxMessageLength, 2000);
      expect(caps.supportsEphemeral, isTrue);
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

  // ===========================================================================
  // Additional DiscordConfig coverage
  // ===========================================================================

  group('DiscordConfig additional coverage', () {
    test('apiVersion defaults to 10', () {
      final config = DiscordConfig(
        botToken: 'test-token',
        applicationId: 'app-1',
      );
      expect(config.apiVersion, 10);
    });

    test('compress defaults to true', () {
      final config = DiscordConfig(
        botToken: 'test-token',
        applicationId: 'app-1',
      );
      expect(config.compress, isTrue);
    });

    test('default reconnectDelay is 5 seconds', () {
      final config = DiscordConfig(
        botToken: 'test-token',
        applicationId: 'app-1',
      );
      expect(config.reconnectDelay, const Duration(seconds: 5));
    });

    test('default maxReconnectAttempts is 10', () {
      final config = DiscordConfig(
        botToken: 'test-token',
        applicationId: 'app-1',
      );
      expect(config.maxReconnectAttempts, 10);
    });

    test('default shardId and totalShards are null', () {
      final config = DiscordConfig(
        botToken: 'test-token',
        applicationId: 'app-1',
      );
      expect(config.shardId, isNull);
      expect(config.totalShards, isNull);
    });

    test('copyWith preserves all fields when no args given', () {
      final original = DiscordConfig(
        botToken: 'orig-token',
        applicationId: 'orig-app',
        intents: DiscordIntents.guilds,
        shardId: 1,
        totalShards: 4,
        apiVersion: 9,
        compress: false,
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 15),
        maxReconnectAttempts: 3,
      );

      final copied = original.copyWith();

      expect(copied.botToken, original.botToken);
      expect(copied.applicationId, original.applicationId);
      expect(copied.intents, original.intents);
      expect(copied.shardId, original.shardId);
      expect(copied.totalShards, original.totalShards);
      expect(copied.apiVersion, original.apiVersion);
      expect(copied.compress, original.compress);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith can update botToken', () {
      final original = DiscordConfig(
        botToken: 'old-token',
        applicationId: 'app-1',
      );
      final copied = original.copyWith(botToken: 'new-token');
      expect(copied.botToken, 'new-token');
      expect(copied.applicationId, original.applicationId);
    });

    test('copyWith can update intents', () {
      final original = DiscordConfig(
        botToken: 'token',
        applicationId: 'app-1',
      );
      final copied = original.copyWith(
        intents: DiscordIntents.guildMembers,
      );
      expect(copied.intents, DiscordIntents.guildMembers);
    });

    test('copyWith can update shardId and totalShards', () {
      final original = DiscordConfig(
        botToken: 'token',
        applicationId: 'app-1',
      );
      final copied = original.copyWith(shardId: 2, totalShards: 8);
      expect(copied.shardId, 2);
      expect(copied.totalShards, 8);
    });

    test('copyWith can update reconnectDelay', () {
      final original = DiscordConfig(
        botToken: 'token',
        applicationId: 'app-1',
      );
      final copied = original.copyWith(
        reconnectDelay: const Duration(seconds: 20),
      );
      expect(copied.reconnectDelay, const Duration(seconds: 20));
    });

    test('copyWith can update maxReconnectAttempts', () {
      final original = DiscordConfig(
        botToken: 'token',
        applicationId: 'app-1',
      );
      final copied = original.copyWith(maxReconnectAttempts: 7);
      expect(copied.maxReconnectAttempts, 7);
    });

    test('copyWith can update autoReconnect', () {
      final original = DiscordConfig(
        botToken: 'token',
        applicationId: 'app-1',
      );
      final copied = original.copyWith(autoReconnect: false);
      expect(copied.autoReconnect, isFalse);
    });

    test('intents can be combined with bitwise OR', () {
      final combined = DiscordIntents.guilds | DiscordIntents.guildMessages;
      expect(combined & DiscordIntents.guilds, isNonZero);
      expect(combined & DiscordIntents.guildMessages, isNonZero);
      expect(combined & DiscordIntents.directMessages, isZero);
    });

    test('individual intent values are correct bit positions', () {
      expect(DiscordIntents.guilds, 1 << 0);
      expect(DiscordIntents.guildMembers, 1 << 1);
      expect(DiscordIntents.guildMessages, 1 << 9);
      expect(DiscordIntents.guildMessageReactions, 1 << 10);
      expect(DiscordIntents.directMessages, 1 << 12);
      expect(DiscordIntents.directMessageReactions, 1 << 13);
      expect(DiscordIntents.messageContent, 1 << 15);
    });

    test('defaultBot includes all expected intents', () {
      final defaultBot = DiscordIntents.defaultBot;
      expect(
        defaultBot,
        DiscordIntents.guilds |
            DiscordIntents.guildMessages |
            DiscordIntents.directMessages |
            DiscordIntents.messageContent,
      );
    });

    test('channelType is always discord', () {
      final config = DiscordConfig(
        botToken: 'token',
        applicationId: 'app-1',
      );
      expect(config.channelType, 'discord');
    });
  });
}
