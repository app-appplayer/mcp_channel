import 'package:meta/meta.dart';

import '../base_connector.dart';

/// Slack connector configuration.
@immutable
class SlackConfig implements ConnectorConfig {
  const SlackConfig({
    required this.botToken,
    this.appToken,
    this.signingSecret,
    this.workspaceId,
    this.useSocketMode = true,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  /// Bot token (xoxb-...)
  final String botToken;

  /// App token for Socket Mode (xapp-...)
  final String? appToken;

  /// Signing secret for verifying requests
  final String? signingSecret;

  /// Workspace ID for channel identification
  final String? workspaceId;

  /// Whether to use Socket Mode
  final bool useSocketMode;

  @override
  final String channelType = 'slack';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  SlackConfig copyWith({
    String? botToken,
    String? appToken,
    String? signingSecret,
    String? workspaceId,
    bool? useSocketMode,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return SlackConfig(
      botToken: botToken ?? this.botToken,
      appToken: appToken ?? this.appToken,
      signingSecret: signingSecret ?? this.signingSecret,
      workspaceId: workspaceId ?? this.workspaceId,
      useSocketMode: useSocketMode ?? this.useSocketMode,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
