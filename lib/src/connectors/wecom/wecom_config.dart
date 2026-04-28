import 'package:meta/meta.dart';

import '../base_connector.dart';

/// WeCom (WeChat Work) connector configuration.
///
/// Requires credentials from the WeCom admin console:
/// - [corpId]: Corporation ID from the admin dashboard
/// - [agentId]: Application Agent ID
/// - [agentSecret]: Application secret for access token retrieval
/// - [callbackToken]: Token for callback URL signature verification
/// - [encodingAesKey]: AES key for decrypting callback message payloads
/// - [callbackPath]: Callback URL path for receiving event notifications
/// - [apiBaseUrl]: WeCom API base URL (defaults to https://qyapi.weixin.qq.com)
@immutable
class WeComConfig implements ConnectorConfig {
  const WeComConfig({
    required this.corpId,
    required this.agentId,
    required this.agentSecret,
    required this.callbackToken,
    required this.encodingAesKey,
    required this.callbackPath,
    this.apiBaseUrl = 'https://qyapi.weixin.qq.com',
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  /// Corporation ID (WeCom Corp ID).
  final String corpId;

  /// Application Agent ID (WeCom AgentId).
  final int agentId;

  /// Agent Secret for obtaining access tokens (WeCom App Secret).
  final String agentSecret;

  /// Callback Token for callback URL signature verification (WeCom Callback Token).
  final String callbackToken;

  /// AES encoding key for message encryption/decryption (43 characters, Base64)
  final String encodingAesKey;

  /// Callback URL path for receiving event notifications
  final String callbackPath;

  /// WeCom API base URL
  final String apiBaseUrl;

  @override
  final String channelType = 'wecom';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  WeComConfig copyWith({
    String? corpId,
    int? agentId,
    String? agentSecret,
    String? callbackToken,
    String? encodingAesKey,
    String? callbackPath,
    String? apiBaseUrl,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return WeComConfig(
      corpId: corpId ?? this.corpId,
      agentId: agentId ?? this.agentId,
      agentSecret: agentSecret ?? this.agentSecret,
      callbackToken: callbackToken ?? this.callbackToken,
      encodingAesKey: encodingAesKey ?? this.encodingAesKey,
      callbackPath: callbackPath ?? this.callbackPath,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
