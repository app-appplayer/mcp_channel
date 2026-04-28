import 'package:meta/meta.dart';

import '../base_connector.dart';

/// Microsoft Teams connector configuration.
///
/// Uses Azure Bot Framework for authentication and messaging.
/// Requires an Azure AD app registration with Bot Channel Registration.
@immutable
class TeamsConfig implements ConnectorConfig {
  const TeamsConfig({
    required this.appId,
    required this.appPassword,
    this.tenantId,
    this.serviceUrl = 'https://smba.trafficmanager.net/teams',
    this.graphScopes = const [],
    this.enableProactive = false,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  /// Azure AD application (client) ID.
  final String appId;

  /// Azure AD application password (client secret).
  final String appPassword;

  /// Azure AD tenant ID (null for multi-tenant apps).
  final String? tenantId;

  /// Bot Framework service URL for sending messages.
  final String serviceUrl;

  /// Graph API scopes (for extended features).
  final List<String> graphScopes;

  /// Enable proactive messaging.
  final bool enableProactive;

  @override
  final String channelType = 'teams';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  /// Whether this is a single-tenant app.
  bool get isSingleTenant => tenantId != null;

  /// Token endpoint URL.
  ///
  /// Uses the tenant-specific endpoint for single-tenant apps,
  /// or the Bot Framework endpoint for multi-tenant apps.
  String get tokenEndpoint => tenantId != null
      ? 'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token'
      : 'https://login.microsoftonline.com/botframework.com/oauth2/v2.0/token';

  TeamsConfig copyWith({
    String? appId,
    String? appPassword,
    String? tenantId,
    String? serviceUrl,
    List<String>? graphScopes,
    bool? enableProactive,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return TeamsConfig(
      appId: appId ?? this.appId,
      appPassword: appPassword ?? this.appPassword,
      tenantId: tenantId ?? this.tenantId,
      serviceUrl: serviceUrl ?? this.serviceUrl,
      graphScopes: graphScopes ?? this.graphScopes,
      enableProactive: enableProactive ?? this.enableProactive,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
