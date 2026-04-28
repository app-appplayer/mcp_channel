import 'package:meta/meta.dart';

import '../base_connector.dart';

/// Slack connector configuration.
@immutable
class SlackConfig implements ConnectorConfig {
  const SlackConfig({
    required this.botToken,
    this.appToken,
    required this.signingSecret,
    this.webhookPath,
    this.workspaceId,
    this.useSocketMode = false,
    this.scopes = const [],
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  /// Bot token (xoxb-...)
  final String botToken;

  /// App token for Socket Mode (xapp-...)
  final String? appToken;

  /// Signing secret for verifying requests
  final String signingSecret;

  /// Webhook endpoint (for Events API HTTP mode)
  final String? webhookPath;

  /// Workspace ID for channel identification
  final String? workspaceId;

  /// Whether to use Socket Mode
  final bool useSocketMode;

  /// OAuth scopes
  final List<String> scopes;

  @override
  final String channelType = 'slack';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  /// Validate configuration.
  ///
  /// Throws [ArgumentError] if the configuration is invalid:
  /// - Socket Mode requires appToken
  /// - HTTP mode requires webhookPath
  void validate() {
    if (useSocketMode && appToken == null) {
      throw ArgumentError('appToken required for Socket Mode');
    }
    if (!useSocketMode && webhookPath == null) {
      throw ArgumentError('webhookPath required for HTTP mode');
    }
  }

  SlackConfig copyWith({
    String? botToken,
    String? appToken,
    String? signingSecret,
    String? webhookPath,
    String? workspaceId,
    bool? useSocketMode,
    List<String>? scopes,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return SlackConfig(
      botToken: botToken ?? this.botToken,
      appToken: appToken ?? this.appToken,
      signingSecret: signingSecret ?? this.signingSecret,
      webhookPath: webhookPath ?? this.webhookPath,
      workspaceId: workspaceId ?? this.workspaceId,
      useSocketMode: useSocketMode ?? this.useSocketMode,
      scopes: scopes ?? this.scopes,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
