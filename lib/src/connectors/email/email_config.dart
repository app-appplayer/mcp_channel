import 'package:meta/meta.dart';

import '../base_connector.dart';

/// Supported email providers.
enum EmailProvider {
  /// Generic IMAP/SMTP
  imap,

  /// Google Gmail (Gmail REST API)
  gmail,

  /// Microsoft Outlook (Microsoft Graph API)
  outlook,

  /// Inbound webhook (SendGrid, Mailgun, etc.)
  webhook,
}

/// IMAP server configuration for generic IMAP access.
@immutable
class ImapConfig {
  const ImapConfig({
    required this.host,
    this.port = 993,
    this.useSsl = true,
    required this.username,
    required this.password,
    this.folder = 'INBOX',
  });

  factory ImapConfig.fromJson(Map<String, dynamic> json) {
    return ImapConfig(
      host: json['host'] as String,
      port: json['port'] as int? ?? 993,
      useSsl: json['useSsl'] as bool? ?? true,
      username: json['username'] as String,
      password: json['password'] as String,
      folder: json['folder'] as String? ?? 'INBOX',
    );
  }

  /// IMAP server hostname.
  final String host;

  /// IMAP server port.
  final int port;

  /// Whether to use SSL/TLS.
  final bool useSsl;

  /// Login username.
  final String username;

  /// Login password.
  final String password;

  /// Mailbox folder to monitor.
  final String? folder;

  ImapConfig copyWith({
    String? host,
    int? port,
    bool? useSsl,
    String? username,
    String? password,
    String? folder,
  }) {
    return ImapConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useSsl: useSsl ?? this.useSsl,
      username: username ?? this.username,
      password: password ?? this.password,
      folder: folder ?? this.folder,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'useSsl': useSsl,
        'username': username,
        'password': password,
        if (folder != null) 'folder': folder,
      };
}

/// SMTP server configuration for sending emails.
@immutable
class SmtpConfig {
  const SmtpConfig({
    required this.host,
    this.port = 587,
    this.useSsl = true,
    required this.username,
    required this.password,
  });

  factory SmtpConfig.fromJson(Map<String, dynamic> json) {
    return SmtpConfig(
      host: json['host'] as String,
      port: json['port'] as int? ?? 587,
      useSsl: json['useSsl'] as bool? ?? true,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }

  /// SMTP server hostname.
  final String host;

  /// SMTP server port.
  final int port;

  /// Whether to use SSL/TLS.
  final bool useSsl;

  /// Login username.
  final String username;

  /// Login password.
  final String password;

  SmtpConfig copyWith({
    String? host,
    int? port,
    bool? useSsl,
    String? username,
    String? password,
  }) {
    return SmtpConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useSsl: useSsl ?? this.useSsl,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'useSsl': useSsl,
        'username': username,
        'password': password,
      };
}

/// Gmail API configuration using OAuth2 credentials.
@immutable
class GmailConfig {
  const GmailConfig({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    this.labelFilter = const ['INBOX'],
    this.useWatch = false,
  });

  factory GmailConfig.fromJson(Map<String, dynamic> json) {
    return GmailConfig(
      clientId: json['clientId'] as String,
      clientSecret: json['clientSecret'] as String,
      refreshToken: json['refreshToken'] as String,
      labelFilter: json['labelFilter'] != null
          ? List<String>.from(json['labelFilter'] as List)
          : const ['INBOX'],
      useWatch: json['useWatch'] as bool? ?? false,
    );
  }

  /// OAuth2 client ID.
  final String clientId;

  /// OAuth2 client secret.
  final String clientSecret;

  /// OAuth2 refresh token for offline access.
  final String refreshToken;

  /// Gmail label filter for incoming messages.
  final List<String> labelFilter;

  /// Whether to use Gmail Push Notifications (Pub/Sub).
  final bool useWatch;

  GmailConfig copyWith({
    String? clientId,
    String? clientSecret,
    String? refreshToken,
    List<String>? labelFilter,
    bool? useWatch,
  }) {
    return GmailConfig(
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      refreshToken: refreshToken ?? this.refreshToken,
      labelFilter: labelFilter ?? this.labelFilter,
      useWatch: useWatch ?? this.useWatch,
    );
  }

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'refreshToken': refreshToken,
        'labelFilter': labelFilter,
        'useWatch': useWatch,
      };
}

/// Outlook / Microsoft Graph API configuration.
///
/// Placeholder for future Microsoft Graph API integration.
@immutable
class OutlookConfig {
  const OutlookConfig({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    this.tenantId,
  });

  factory OutlookConfig.fromJson(Map<String, dynamic> json) {
    return OutlookConfig(
      clientId: json['clientId'] as String,
      clientSecret: json['clientSecret'] as String,
      refreshToken: json['refreshToken'] as String,
      tenantId: json['tenantId'] as String?,
    );
  }

  /// OAuth2 client ID.
  final String clientId;

  /// OAuth2 client secret.
  final String clientSecret;

  /// OAuth2 refresh token for offline access.
  final String refreshToken;

  /// Azure AD tenant ID (null for common/multi-tenant).
  final String? tenantId;

  OutlookConfig copyWith({
    String? clientId,
    String? clientSecret,
    String? refreshToken,
    String? tenantId,
  }) {
    return OutlookConfig(
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      refreshToken: refreshToken ?? this.refreshToken,
      tenantId: tenantId ?? this.tenantId,
    );
  }

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'refreshToken': refreshToken,
        if (tenantId != null) 'tenantId': tenantId,
      };
}

/// Inbound webhook configuration for services like SendGrid or Mailgun.
@immutable
class InboundWebhookConfig {
  const InboundWebhookConfig({
    required this.path,
    this.secret,
  });

  factory InboundWebhookConfig.fromJson(Map<String, dynamic> json) {
    return InboundWebhookConfig(
      path: json['path'] as String,
      secret: json['secret'] as String?,
    );
  }

  /// Webhook endpoint path (e.g., '/webhooks/email').
  final String path;

  /// Secret for verifying webhook signatures.
  final String? secret;

  InboundWebhookConfig copyWith({
    String? path,
    String? secret,
  }) {
    return InboundWebhookConfig(
      path: path ?? this.path,
      secret: secret ?? this.secret,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        if (secret != null) 'secret': secret,
      };
}

/// Email connector configuration.
///
/// Supports IMAP/SMTP, Gmail API, Outlook/Graph API, and inbound webhooks
/// for sending and receiving emails.
///
/// Example usage:
/// ```dart
/// final config = EmailConfig(
///   provider: EmailProvider.imap,
///   imap: ImapConfig(
///     host: 'imap.gmail.com',
///     username: 'bot@example.com',
///     password: 'app-password',
///   ),
///   smtp: SmtpConfig(
///     host: 'smtp.gmail.com',
///     username: 'bot@example.com',
///     password: 'app-password',
///   ),
///   botEmail: 'bot@example.com',
///   subjectCommandPrefix: '/mcp',
/// );
/// ```
@immutable
class EmailConfig implements ConnectorConfig {
  const EmailConfig({
    required this.provider,
    required this.botEmail,
    this.credentials = const {},
    this.imap,
    this.smtp,
    this.gmailConfig,
    this.outlookConfig,
    this.inboundWebhook,
    this.pollingInterval = const Duration(seconds: 60),
    this.subjectCommandPrefix,
    this.fromName,
    this.autoReconnect = false,
    this.reconnectDelay = const Duration(seconds: 30),
    this.maxReconnectAttempts = 3,
  });

  /// Email provider mode.
  final EmailProvider provider;

  /// Bot email address used as the sender.
  final String botEmail;

  /// OAuth2 credentials (for Gmail/Outlook API modes).
  ///
  /// Required keys for API modes:
  /// - `clientId`: OAuth2 client ID
  /// - `clientSecret`: OAuth2 client secret
  /// - `refreshToken`: OAuth2 refresh token for offline access
  ///
  /// Optional keys:
  /// - `accessToken`: Current access token (will be refreshed automatically)
  /// - `tokenEndpoint`: Custom token endpoint URL
  final Map<String, String> credentials;

  /// IMAP configuration (for generic IMAP provider).
  final ImapConfig? imap;

  /// SMTP configuration (for generic SMTP sending).
  final SmtpConfig? smtp;

  /// Gmail API configuration.
  final GmailConfig? gmailConfig;

  /// Outlook / Microsoft Graph API configuration.
  final OutlookConfig? outlookConfig;

  /// Inbound webhook configuration (SendGrid, Mailgun, etc.).
  final InboundWebhookConfig? inboundWebhook;

  /// Polling interval for checking new emails.
  ///
  /// Defaults to 60 seconds. Lower values increase API usage.
  final Duration pollingInterval;

  /// Command prefix in subject line (e.g., "/mcp").
  ///
  /// When set, emails with subjects starting with this prefix
  /// are parsed as command events instead of message events.
  final String? subjectCommandPrefix;

  /// Sender display name.
  ///
  /// If not specified, the authenticated user's name is used.
  final String? fromName;

  @override
  final String channelType = 'email';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  EmailConfig copyWith({
    EmailProvider? provider,
    String? botEmail,
    Map<String, String>? credentials,
    ImapConfig? imap,
    SmtpConfig? smtp,
    GmailConfig? gmailConfig,
    OutlookConfig? outlookConfig,
    InboundWebhookConfig? inboundWebhook,
    Duration? pollingInterval,
    String? subjectCommandPrefix,
    String? fromName,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return EmailConfig(
      provider: provider ?? this.provider,
      botEmail: botEmail ?? this.botEmail,
      credentials: credentials ?? this.credentials,
      imap: imap ?? this.imap,
      smtp: smtp ?? this.smtp,
      gmailConfig: gmailConfig ?? this.gmailConfig,
      outlookConfig: outlookConfig ?? this.outlookConfig,
      inboundWebhook: inboundWebhook ?? this.inboundWebhook,
      pollingInterval: pollingInterval ?? this.pollingInterval,
      subjectCommandPrefix: subjectCommandPrefix ?? this.subjectCommandPrefix,
      fromName: fromName ?? this.fromName,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
