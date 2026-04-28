import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart';

import '../../core/port/extended_channel_capabilities.dart';
import '../base_connector.dart';

// =============================================================================
// Response Mode
// =============================================================================

/// Response delivery mode for webhook.
enum WebhookResponseMode {
  /// Send response to callback URL
  callback,

  /// Return response in same HTTP request (synchronous)
  synchronous,

  /// Both callback and synchronous
  both,
}

// =============================================================================
// Authentication
// =============================================================================

/// Base class for webhook authentication.
///
/// Provides validation of incoming requests and application of auth
/// credentials to outgoing requests.
@immutable
abstract class WebhookAuth {
  const WebhookAuth();

  /// Validate incoming request headers and body.
  bool validate(Map<String, String> headers, String body);

  /// Apply authentication to outgoing request headers.
  Map<String, String> applyHeaders(Map<String, String> headers);
}

/// API Key authentication.
///
/// Validates that the specified header contains the expected API key value.
@immutable
class ApiKeyAuth extends WebhookAuth {
  const ApiKeyAuth({
    this.headerName = 'X-API-Key',
    required this.apiKey,
  });

  /// Header name where the API key is expected.
  final String headerName;

  /// The expected API key value.
  final String apiKey;

  @override
  bool validate(Map<String, String> headers, String body) {
    final key = headers[headerName] ?? headers[headerName.toLowerCase()];
    return key == apiKey;
  }

  @override
  Map<String, String> applyHeaders(Map<String, String> headers) {
    return {...headers, headerName: apiKey};
  }
}

/// Bearer token authentication.
///
/// Validates the Authorization header contains the expected bearer token.
@immutable
class BearerAuth extends WebhookAuth {
  const BearerAuth({required this.token});

  /// The expected bearer token.
  final String token;

  @override
  bool validate(Map<String, String> headers, String body) {
    final auth = headers['authorization'] ?? headers['Authorization'];
    return auth == 'Bearer $token';
  }

  @override
  Map<String, String> applyHeaders(Map<String, String> headers) {
    return {...headers, 'Authorization': 'Bearer $token'};
  }
}

/// HMAC signature authentication.
///
/// Validates incoming requests by comparing the HMAC signature in the
/// specified header against a computed signature of the request body.
/// Supports sha256 and sha1 algorithms.
@immutable
class HmacAuth extends WebhookAuth {
  const HmacAuth({
    required this.secret,
    this.headerName = 'X-Signature',
    this.algorithm = 'sha256',
  });

  /// The HMAC secret key.
  final String secret;

  /// Header name where the signature is expected.
  final String headerName;

  /// Hash algorithm: 'sha256' or 'sha1'.
  final String algorithm;

  @override
  bool validate(Map<String, String> headers, String body) {
    final signature = headers[headerName] ?? headers[headerName.toLowerCase()];
    if (signature == null) return false;

    final expected = computeSignature(body);
    // Support both raw and prefixed signature formats
    return _secureCompare(signature, expected) ||
        _secureCompare(signature, 'sha256=$expected') ||
        _secureCompare(signature, 'sha1=$expected');
  }

  /// Compute the HMAC signature for the given body.
  String computeSignature(String body) {
    final hmac = Hmac(
      algorithm == 'sha1' ? sha1 : sha256,
      utf8.encode(secret),
    );
    return hmac.convert(utf8.encode(body)).toString();
  }

  @override
  Map<String, String> applyHeaders(Map<String, String> headers) {
    // Signature is computed per-request in the connector send method
    return headers;
  }

  /// Constant-time string comparison to prevent timing attacks.
  static bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

/// HTTP Basic authentication.
///
/// Validates the Authorization header contains valid Basic credentials.
@immutable
class BasicAuth extends WebhookAuth {
  const BasicAuth({
    required this.username,
    required this.password,
  });

  /// The expected username.
  final String username;

  /// The expected password.
  final String password;

  @override
  bool validate(Map<String, String> headers, String body) {
    final auth = headers['authorization'] ?? headers['Authorization'];
    if (auth == null || !auth.startsWith('Basic ')) return false;

    try {
      final credentials = utf8.decode(base64.decode(auth.substring(6)));
      return credentials == '$username:$password';
    } catch (_) {
      return false;
    }
  }

  @override
  Map<String, String> applyHeaders(Map<String, String> headers) {
    final credentials = base64.encode(utf8.encode('$username:$password'));
    return {...headers, 'Authorization': 'Basic $credentials'};
  }
}

// =============================================================================
// Format
// =============================================================================

/// Function type for parsing incoming webhook payloads into channel events.
typedef WebhookEventParser = ChannelEvent Function(
  Map<String, dynamic> data,
  Map<String, String> headers,
);

/// Function type for building outbound response payloads.
typedef WebhookResponseBuilder = String Function(
  ChannelResponse response,
);

/// Webhook payload format configuration.
///
/// Defines how incoming requests are parsed and outgoing responses are
/// formatted. Supports JSON (default), form-urlencoded, and custom formats.
@immutable
class WebhookFormat {
  const WebhookFormat._({
    required this.contentType,
    required this.parser,
    required this.builder,
  });

  /// JSON format (default).
  const factory WebhookFormat.json() = _JsonFormat;

  /// Form URL-encoded format.
  const factory WebhookFormat.form() = _FormFormat;

  /// Custom format with user-provided parser and builder.
  factory WebhookFormat.custom({
    required String contentType,
    required WebhookEventParser parser,
    required WebhookResponseBuilder builder,
  }) {
    return WebhookFormat._(
      contentType: contentType,
      parser: parser,
      builder: builder,
    );
  }

  /// The HTTP content type for this format.
  final String contentType;

  /// Parser function to convert raw data into a ChannelEvent.
  final WebhookEventParser parser;

  /// Builder function to convert a ChannelResponse into a string payload.
  final WebhookResponseBuilder builder;
}

/// Default JSON format implementation.
class _JsonFormat extends WebhookFormat {
  const _JsonFormat()
      : super._(
          contentType: 'application/json',
          parser: _parseJsonEvent,
          builder: _buildJsonResponse,
        );
}

/// Default form URL-encoded format implementation.
class _FormFormat extends WebhookFormat {
  const _FormFormat()
      : super._(
          contentType: 'application/x-www-form-urlencoded',
          parser: _parseJsonEvent,
          builder: _buildJsonResponse,
        );
}

/// Default JSON event parser.
///
/// Extracts channel event fields from a JSON payload with flexible
/// field name mapping for compatibility with various webhook sources.
ChannelEvent _parseJsonEvent(
  Map<String, dynamic> data,
  Map<String, String> headers,
) {
  final eventId = data['id'] as String? ??
      data['eventId'] as String? ??
      data['event_id'] as String? ??
      DateTime.now().millisecondsSinceEpoch.toString();

  final userId = data['userId'] as String? ??
      data['user_id'] as String? ??
      data['user'] as String?;

  final channelId = data['channelId'] as String? ??
      data['tenantId'] as String? ??
      'default';

  final conversationId = data['conversationId'] as String? ??
      data['roomId'] as String? ??
      data['conversation_id'] as String? ??
      'default';

  final conversation = ConversationKey(
    channel: ChannelIdentity(
      platform: 'webhook',
      channelId: channelId,
    ),
    conversationId: conversationId,
    userId: userId,
  );

  return ChannelEvent(
    id: eventId,
    conversation: conversation,
    type: data['type'] as String? ?? 'message',
    text: data['text'] as String? ?? data['message'] as String?,
    userId: userId,
    userName: data['userName'] as String? ??
        data['user_name'] as String?,
    timestamp: data['timestamp'] != null
        ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
    metadata: data,
  );
}

/// Default JSON response builder.
///
/// Serializes a ChannelResponse to a JSON string for outbound delivery.
String _buildJsonResponse(ChannelResponse response) {
  return jsonEncode({
    'conversation': response.conversation.toJson(),
    if (response.text != null) 'text': response.text,
    if (response.blocks != null) 'blocks': response.blocks,
    if (response.replyTo != null) 'replyTo': response.replyTo,
    'timestamp': DateTime.now().toIso8601String(),
  });
}

// =============================================================================
// Capability Configuration
// =============================================================================

/// Configurable capability settings for webhook connectors.
///
/// Allows external systems to declare what features they support.
/// Defaults match typical simple webhook integrations.
@immutable
class WebhookCapabilityConfig {
  const WebhookCapabilityConfig({
    this.threads = false,
    this.reactions = false,
    this.files = false,
    this.maxFileSize,
    this.blocks = true,
    this.buttons = true,
    this.menus = false,
    this.modals = false,
    this.ephemeral = false,
    this.edit = false,
    this.delete = false,
    this.typing = false,
    this.commands = true,
    this.maxMessageLength,
  });

  /// Full capabilities (for testing).
  const WebhookCapabilityConfig.full()
      : this(
          threads: true,
          reactions: true,
          files: true,
          maxFileSize: 100 * 1024 * 1024,
          blocks: true,
          buttons: true,
          menus: true,
          modals: true,
          ephemeral: true,
          edit: true,
          delete: true,
          typing: true,
          commands: true,
        );

  /// Support threaded conversations
  final bool threads;

  /// Support message reactions
  final bool reactions;

  /// Support file uploads
  final bool files;

  /// Maximum file size in bytes
  final int? maxFileSize;

  /// Support rich message blocks
  final bool blocks;

  /// Support interactive buttons
  final bool buttons;

  /// Support select menus
  final bool menus;

  /// Support modals/dialogs
  final bool modals;

  /// Support ephemeral messages
  final bool ephemeral;

  /// Support message editing
  final bool edit;

  /// Support message deletion
  final bool delete;

  /// Support typing indicators
  final bool typing;

  /// Support slash commands
  final bool commands;

  /// Maximum message length in characters
  final int? maxMessageLength;

  /// Build extended capabilities from this configuration.
  ExtendedChannelCapabilities buildCapabilities() {
    return ExtendedChannelCapabilities(
      text: true,
      richMessages: blocks,
      attachments: files,
      reactions: reactions,
      threads: threads,
      editing: edit,
      deleting: delete,
      typingIndicator: typing,
      maxMessageLength: maxMessageLength,
      supportsFiles: files,
      maxFileSize: maxFileSize,
      supportsButtons: buttons,
      supportsMenus: menus,
      supportsModals: modals,
      supportsEphemeral: ephemeral,
      supportsCommands: commands,
    );
  }
}

// =============================================================================
// Webhook Config
// =============================================================================

/// Webhook connector configuration.
///
/// Supports inbound webhook reception, outbound callback delivery,
/// multiple authentication methods, flexible payload formats,
/// CORS configuration, and custom headers.
@immutable
class WebhookConfig implements ConnectorConfig {
  const WebhookConfig({
    this.inboundPath = '/webhook',
    this.outboundUrl,
    this.auth,
    this.format = const WebhookFormat.json(),
    this.responseMode = WebhookResponseMode.callback,
    this.enableCors = false,
    this.corsOrigins,
    this.customHeaders,
    this.timeout = const Duration(seconds: 30),
    this.capabilityConfig = const WebhookCapabilityConfig(),
    this.autoReconnect = false,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 3,
  });

  /// URL path for receiving inbound webhooks.
  final String inboundPath;

  /// URL for sending outbound webhook responses.
  final String? outboundUrl;

  /// Authentication configuration.
  final WebhookAuth? auth;

  /// Request/response format configuration.
  final WebhookFormat format;

  /// Response delivery mode.
  final WebhookResponseMode responseMode;

  /// Enable CORS headers for browser clients.
  final bool enableCors;

  /// Allowed origins for CORS. Null means allow all ('*').
  final List<String>? corsOrigins;

  /// Custom headers to include in responses.
  final Map<String, String>? customHeaders;

  /// Request timeout duration.
  final Duration timeout;

  /// Capability configuration for this webhook instance.
  final WebhookCapabilityConfig capabilityConfig;

  @override
  String get channelType => 'webhook';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;

  WebhookConfig copyWith({
    String? inboundPath,
    String? outboundUrl,
    WebhookAuth? auth,
    WebhookFormat? format,
    WebhookResponseMode? responseMode,
    bool? enableCors,
    List<String>? corsOrigins,
    Map<String, String>? customHeaders,
    Duration? timeout,
    WebhookCapabilityConfig? capabilityConfig,
    bool? autoReconnect,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  }) {
    return WebhookConfig(
      inboundPath: inboundPath ?? this.inboundPath,
      outboundUrl: outboundUrl ?? this.outboundUrl,
      auth: auth ?? this.auth,
      format: format ?? this.format,
      responseMode: responseMode ?? this.responseMode,
      enableCors: enableCors ?? this.enableCors,
      corsOrigins: corsOrigins ?? this.corsOrigins,
      customHeaders: customHeaders ?? this.customHeaders,
      timeout: timeout ?? this.timeout,
      capabilityConfig: capabilityConfig ?? this.capabilityConfig,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    );
  }
}
