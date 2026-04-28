import 'package:meta/meta.dart';

import '../base_connector.dart';

/// YouTube operation mode.
///
/// Determines which YouTube features the connector monitors and interacts with.
enum YouTubeMode {
  /// Monitor and reply to video comments
  comments,

  /// Monitor and participate in live chat
  liveChat,

  /// Both modes
  both,
}

/// YouTube connector configuration.
///
/// Supports YouTube Data API v3 for both live chat and video comments.
/// OAuth2 credentials are required for write operations (sending messages,
/// deleting). Read-only operations can use an API key alone.
@immutable
class YouTubeConfig implements ConnectorConfig {
  const YouTubeConfig({
    required this.apiKey,
    this.channelId,
    this.liveChatId,
    this.mode = YouTubeMode.both,
    this.videoIds,
    this.commandPrefix,
    this.mentionsOnly = false,
    this.pollingInterval = const Duration(seconds: 30),
    this.credentials,
    this.quotaBudget = 10000,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  /// YouTube Data API v3 key (required for all API calls)
  final String apiKey;

  /// YouTube channel ID to monitor for comments
  final String? channelId;

  /// Live chat ID for live stream chat polling
  final String? liveChatId;

  /// Operation mode (comments, liveChat, or both)
  final YouTubeMode mode;

  /// Video IDs to monitor comments (for comments mode)
  final List<String>? videoIds;

  /// Command prefix for prefix-based commands (e.g., "!bot" or "@BotName")
  final String? commandPrefix;

  /// Only respond to mentions
  final bool mentionsOnly;

  /// Polling interval for fetching new messages/comments
  final Duration pollingInterval;

  /// OAuth2 credentials for write operations.
  ///
  /// Expected keys: 'clientId', 'clientSecret', 'refreshToken'.
  /// When provided, enables sending messages and deleting.
  final Map<String, String>? credentials;

  /// Daily API quota budget in units (default 10,000 units/day).
  ///
  /// YouTube Data API v3 has a default quota of 10,000 units per day.
  /// Each API method costs a different number of units. The connector
  /// tracks usage and stops making calls when the budget is exhausted.
  final int quotaBudget;

  @override
  final String channelType = 'youtube';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  /// Whether OAuth2 credentials are configured for write operations.
  bool get hasOAuth2Credentials =>
      credentials != null &&
      credentials!.containsKey('clientId') &&
      credentials!.containsKey('clientSecret') &&
      credentials!.containsKey('refreshToken');

  YouTubeConfig copyWith({
    String? apiKey,
    String? channelId,
    String? liveChatId,
    YouTubeMode? mode,
    List<String>? videoIds,
    String? commandPrefix,
    bool? mentionsOnly,
    Duration? pollingInterval,
    Map<String, String>? credentials,
    int? quotaBudget,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return YouTubeConfig(
      apiKey: apiKey ?? this.apiKey,
      channelId: channelId ?? this.channelId,
      liveChatId: liveChatId ?? this.liveChatId,
      mode: mode ?? this.mode,
      videoIds: videoIds ?? this.videoIds,
      commandPrefix: commandPrefix ?? this.commandPrefix,
      mentionsOnly: mentionsOnly ?? this.mentionsOnly,
      pollingInterval: pollingInterval ?? this.pollingInterval,
      credentials: credentials ?? this.credentials,
      quotaBudget: quotaBudget ?? this.quotaBudget,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
