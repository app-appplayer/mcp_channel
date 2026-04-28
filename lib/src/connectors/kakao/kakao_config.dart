import 'package:meta/meta.dart';

import '../base_connector.dart';

/// Kakao Skill channel connector configuration.
///
/// Kakao chatbots use a synchronous webhook-based model where the platform
/// sends a Skill request and expects a response within [responseTimeout].
/// Since the platform drives the connection via webhooks, [autoReconnect]
/// defaults to `false`.
@immutable
class KakaoConfig implements ConnectorConfig {
  const KakaoConfig({
    required this.botId,
    this.webhookPath = '/kakao/skill',
    this.validationToken,
    this.responseTimeout = const Duration(seconds: 5),
    this.debug = false,
    this.autoReconnect = false,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 0,
  });

  /// Kakao bot (skill) identifier.
  final String botId;

  /// Webhook path for receiving Kakao Skill requests.
  final String webhookPath;

  /// Validation token for request authentication (optional).
  ///
  /// When set, incoming requests must include an `x-kakao-validation` header
  /// whose value matches this token. Requests with a missing or mismatched
  /// token are rejected with a [ChannelError.permissionDenied].
  final String? validationToken;

  /// Maximum time to wait for a response before returning a timeout reply.
  ///
  /// Kakao enforces a strict 5-second limit on Skill responses.
  final Duration responseTimeout;

  /// Enable debug logging.
  final bool debug;

  @override
  final String channelType = 'kakao';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  KakaoConfig copyWith({
    String? botId,
    String? webhookPath,
    String? validationToken,
    Duration? responseTimeout,
    bool? debug,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return KakaoConfig(
      botId: botId ?? this.botId,
      webhookPath: webhookPath ?? this.webhookPath,
      validationToken: validationToken ?? this.validationToken,
      responseTimeout: responseTimeout ?? this.responseTimeout,
      debug: debug ?? this.debug,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
