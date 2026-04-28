import 'package:meta/meta.dart';

import '../base_connector.dart';

/// Discord Gateway intents.
class DiscordIntents {
  DiscordIntents._();

  static const int guilds = 1 << 0;
  static const int guildMembers = 1 << 1;
  static const int guildMessages = 1 << 9;
  static const int guildMessageReactions = 1 << 10;
  static const int directMessages = 1 << 12;
  static const int directMessageReactions = 1 << 13;
  static const int messageContent = 1 << 15;

  /// Default intents for a messaging bot.
  static const int defaultBot =
      guilds | guildMessages | directMessages | messageContent;
}

/// Discord connector configuration.
@immutable
class DiscordConfig implements ConnectorConfig {
  const DiscordConfig({
    required this.botToken,
    required this.applicationId,
    this.intents = DiscordIntents.defaultBot,
    this.shardId,
    this.totalShards,
    this.apiVersion = 10,
    this.compress = true,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  /// Bot token
  final String botToken;

  /// Application ID (for interactions)
  final String applicationId;

  /// Gateway intents bitmask
  final int intents;

  /// Shard ID for large bots
  final int? shardId;

  /// Total number of shards
  final int? totalShards;

  /// API version
  final int apiVersion;

  /// Gateway compression
  final bool compress;

  @override
  final String channelType = 'discord';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  DiscordConfig copyWith({
    String? botToken,
    String? applicationId,
    int? intents,
    int? shardId,
    int? totalShards,
    int? apiVersion,
    bool? compress,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return DiscordConfig(
      botToken: botToken ?? this.botToken,
      applicationId: applicationId ?? this.applicationId,
      intents: intents ?? this.intents,
      shardId: shardId ?? this.shardId,
      totalShards: totalShards ?? this.totalShards,
      apiVersion: apiVersion ?? this.apiVersion,
      compress: compress ?? this.compress,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
