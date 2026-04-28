import 'package:meta/meta.dart';

import '../base_connector.dart';

/// Telegram connector configuration.
@immutable
class TelegramConfig implements ConnectorConfig {
  const TelegramConfig({
    required this.botToken,
    this.webhookUrl,
    this.webhookSecret,
    this.pollingTimeout = 30,
    this.allowedUpdates = const [
      'message',
      'edited_message',
      'callback_query',
      'inline_query',
    ],
    this.apiBaseUrl = 'https://api.telegram.org',
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  /// Bot API token from @BotFather
  final String botToken;

  /// Webhook URL (if null, uses long polling)
  final String? webhookUrl;

  /// Webhook secret token for verification
  final String? webhookSecret;

  /// Long polling timeout in seconds
  final int pollingTimeout;

  /// Allowed update types
  final List<String> allowedUpdates;

  /// API base URL (for testing)
  final String apiBaseUrl;

  @override
  final String channelType = 'telegram';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  /// Whether this config uses polling mode.
  bool get isPolling => webhookUrl == null;

  /// Whether this config uses webhook mode.
  bool get isWebhook => webhookUrl != null;

  TelegramConfig copyWith({
    String? botToken,
    String? webhookUrl,
    String? webhookSecret,
    int? pollingTimeout,
    List<String>? allowedUpdates,
    String? apiBaseUrl,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return TelegramConfig(
      botToken: botToken ?? this.botToken,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      webhookSecret: webhookSecret ?? this.webhookSecret,
      pollingTimeout: pollingTimeout ?? this.pollingTimeout,
      allowedUpdates: allowedUpdates ?? this.allowedUpdates,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
