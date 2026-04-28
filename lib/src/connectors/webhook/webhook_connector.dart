import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mcp_bundle/ports.dart';

import '../../core/policy/channel_policy.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/extended_channel_capabilities.dart';
import '../../core/port/send_result.dart';
import '../base_connector.dart';
import 'webhook_config.dart';

final _log = Logger('WebhookConnector');

/// Generic HTTP webhook connector.
///
/// Handles inbound webhooks (receiving events) and outbound webhooks
/// (sending responses). Supports API Key, Bearer, HMAC, and Basic auth.
/// Includes CORS support, synchronous response mode, and retry logic.
///
/// This connector does not run its own HTTP server. Instead, it provides
/// [handleRequest] to be called from an external HTTP server or framework.
class WebhookConnector extends BaseConnector {
  WebhookConnector({
    required this.config,
    ChannelPolicy? policy,
    http.Client? httpClient,
  })  : policy = policy ?? const ChannelPolicy(),
        _httpClient = httpClient ?? http.Client();

  @override
  final WebhookConfig config;

  @override
  final ChannelPolicy policy;

  final http.Client _httpClient;

  /// Pending response completers for synchronous response mode.
  ///
  /// Maps event IDs to their corresponding completers, which are completed
  /// when [completeResponse] is called with a matching event ID.
  final Map<String, Completer<ChannelResponse>> _pendingResponses = {};

  late final ExtendedChannelCapabilities _extendedCapabilities =
      config.capabilityConfig.buildCapabilities();

  @override
  String get channelType => 'webhook';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'webhook',
        channelId: config.inboundPath,
        displayName: 'Webhook Connector',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connected);
    onConnected();
    _log.info('Webhook connector ready at ${config.inboundPath}');
  }

  @override
  Future<void> doStop() async {
    // Complete any pending responses with an error
    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.completeError(const ConnectorException(
          'Connector stopped while waiting for response',
          code: 'connector_stopped',
        ));
      }
    }
    _pendingResponses.clear();
  }

  @override
  Future<void> send(ChannelResponse response) async {
    if (config.outboundUrl == null) {
      throw const ConnectorException(
        'No outbound URL configured',
        code: 'no_outbound_url',
      );
    }

    final body = config.format.builder(response);
    var headers = <String, String>{
      'Content-Type': config.format.contentType,
    };

    // Apply authentication headers
    if (config.auth != null) {
      headers = config.auth!.applyHeaders(headers);
    }

    // Apply HMAC signature if using HMAC auth
    if (config.auth is HmacAuth) {
      final hmacAuth = config.auth! as HmacAuth;
      final signature = hmacAuth.computeSignature(body);
      headers[hmacAuth.headerName] = signature;
    }

    // Apply custom headers
    if (config.customHeaders != null) {
      headers.addAll(config.customHeaders!);
    }

    final httpResponse = await _httpClient.post(
      Uri.parse(config.outboundUrl!),
      headers: headers,
      body: body,
    );

    if (httpResponse.statusCode >= 400) {
      throw ConnectorException(
        'Outbound webhook failed: ${httpResponse.statusCode}',
        code: 'outbound_failed',
      );
    }
  }

  /// Send a response with exponential backoff retry.
  ///
  /// Retries up to [maxRetries] times with exponential delay (1s, 2s, 4s, ...).
  Future<void> sendWithRetry(
    ChannelResponse response, {
    int maxRetries = 3,
  }) async {
    for (var i = 0; i < maxRetries; i++) {
      try {
        await send(response);
        return;
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        final delay = Duration(seconds: 1 << i);
        _log.warning(
          'Outbound webhook failed (attempt ${i + 1}/$maxRetries), '
          'retrying in ${delay.inSeconds}s',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    // Not supported for webhooks
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    throw UnsupportedError('Editing not supported by webhook connector');
  }

  @override
  Future<void> delete(String messageId) async {
    throw UnsupportedError('Deleting not supported by webhook connector');
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    throw UnsupportedError('Reactions not supported by webhook connector');
  }

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    try {
      await send(response);
      return SendResult.success(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (e) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.serverError,
          message: 'Webhook send failed: $e',
          retryable: _isRetryableError(e),
        ),
      );
    }
  }

  /// Complete a pending synchronous response for the given event ID.
  ///
  /// This should be called by the application when it has generated a
  /// response for an event received in synchronous or both response modes.
  void completeResponse(String eventId, ChannelResponse response) {
    final completer = _pendingResponses[eventId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  // =========================================================================
  // Inbound Request Handling
  // =========================================================================

  /// Handle an incoming webhook HTTP request.
  ///
  /// Call this from your HTTP server when a request arrives at
  /// [config.inboundPath].
  ///
  /// For CORS preflight (OPTIONS) requests, returns a 200 response with
  /// CORS headers. For actual requests, parses the body, validates auth,
  /// emits the event, and returns a response based on the configured
  /// response mode:
  ///
  /// - [WebhookResponseMode.callback]: Returns `{"status": "received"}`
  ///   immediately. The response is later delivered to [config.outboundUrl].
  /// - [WebhookResponseMode.synchronous]: Waits for [completeResponse] to
  ///   be called with the event ID, then returns the response payload.
  /// - [WebhookResponseMode.both]: Waits for [completeResponse] like
  ///   synchronous mode, and also delivers via callback.
  ///
  /// Returns a [WebhookHttpResponse] containing the status code, headers,
  /// and body to send back to the caller.
  Future<WebhookHttpResponse> handleRequest({
    required String method,
    required Map<String, String> headers,
    required String body,
  }) async {
    // CORS preflight handling
    if (method == 'OPTIONS' && config.enableCors) {
      return WebhookHttpResponse(
        statusCode: 200,
        headers: _corsHeaders(),
        body: '',
      );
    }

    // Verify authentication
    if (config.auth != null && !config.auth!.validate(headers, body)) {
      return const WebhookHttpResponse(
        statusCode: 403,
        headers: {},
        body: '{"error": "Unauthorized"}',
      );
    }

    // Parse body based on format content type
    Map<String, dynamic> data;
    try {
      if (config.format.contentType == 'application/json') {
        data = jsonDecode(body) as Map<String, dynamic>;
      } else if (config.format.contentType ==
          'application/x-www-form-urlencoded') {
        data = Uri.splitQueryString(body)
            .map((key, value) => MapEntry(key, value as dynamic));
      } else {
        data = <String, dynamic>{'raw': body};
      }
    } catch (e) {
      return const WebhookHttpResponse(
        statusCode: 400,
        headers: {},
        body: '{"error": "Invalid request format"}',
      );
    }

    // Parse to ChannelEvent
    final event = config.format.parser(data, headers);

    // Build response headers
    final responseHeaders = <String, String>{
      'Content-Type': config.format.contentType,
      ..._corsHeaders(),
      if (config.customHeaders != null) ...config.customHeaders!,
    };

    // For synchronous/both modes, register the completer BEFORE emitting
    // the event. This ensures that event listeners can call completeResponse()
    // synchronously and the completer is already in place.
    final needsResponse =
        config.responseMode == WebhookResponseMode.synchronous ||
            config.responseMode == WebhookResponseMode.both;

    if (needsResponse) {
      _registerPendingResponse(event.id);
    }

    emitEvent(event);

    // Handle response mode
    switch (config.responseMode) {
      case WebhookResponseMode.callback:
        return WebhookHttpResponse(
          statusCode: 200,
          headers: responseHeaders,
          body: '{"status": "received"}',
        );

      case WebhookResponseMode.synchronous:
        final response = await _awaitPendingResponse(event.id);
        return WebhookHttpResponse(
          statusCode: 200,
          headers: responseHeaders,
          body: config.format.builder(response),
        );

      case WebhookResponseMode.both:
        final response = await _awaitPendingResponse(event.id);
        // Also deliver via callback asynchronously
        _deliverCallback(response);
        return WebhookHttpResponse(
          statusCode: 200,
          headers: responseHeaders,
          body: config.format.builder(response),
        );
    }
  }

  /// Verify webhook request authentication.
  ///
  /// Convenience method for external callers to verify auth without
  /// processing the full request.
  bool verifySignature({
    required Map<String, String> headers,
    required String body,
  }) {
    if (config.auth == null) return true;
    return config.auth!.validate(headers, body);
  }

  // =========================================================================
  // Private: CORS
  // =========================================================================

  /// Build CORS headers based on configuration.
  Map<String, String> _corsHeaders() {
    if (!config.enableCors) return {};
    return {
      'Access-Control-Allow-Origin': config.corsOrigins?.join(',') ?? '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers':
          'Content-Type, Authorization, X-API-Key',
    };
  }

  // =========================================================================
  // Private: Synchronous Response
  // =========================================================================

  /// Register a pending response completer for the given event ID.
  ///
  /// Must be called before emitting the event so that synchronous
  /// listeners can call [completeResponse] immediately.
  void _registerPendingResponse(String eventId) {
    _pendingResponses[eventId] = Completer<ChannelResponse>();
  }

  /// Wait for a previously registered pending response to be completed.
  ///
  /// Waits up to [config.timeout] for [completeResponse] to be called.
  /// Cleans up the pending response entry on success or timeout.
  Future<ChannelResponse> _awaitPendingResponse(String eventId) async {
    final completer = _pendingResponses[eventId];
    if (completer == null) {
      throw const ConnectorException(
        'No pending response registered for event',
        code: 'no_pending_response',
      );
    }

    try {
      final response = await completer.future.timeout(config.timeout);
      _pendingResponses.remove(eventId);
      return response;
    } on TimeoutException {
      _pendingResponses.remove(eventId);
      throw const ConnectorException(
        'Response timeout waiting for synchronous response',
        code: 'response_timeout',
      );
    }
  }

  /// Deliver a response asynchronously via the callback URL.
  void _deliverCallback(ChannelResponse response) {
    // Fire and forget - errors are logged but not propagated
    sendWithRetry(response).catchError((Object e) {
      _log.warning('Failed to deliver callback response: $e');
    });
  }

  // =========================================================================
  // Private: Helpers
  // =========================================================================

  bool _isRetryableError(Object error) {
    if (error is ChannelError) return error.retryable;
    if (error is http.ClientException) return true;
    return false;
  }
}

/// Represents an HTTP response from webhook request handling.
///
/// Returned by [WebhookConnector.handleRequest] to allow the external
/// HTTP server to send back the appropriate response.
class WebhookHttpResponse {
  const WebhookHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  /// HTTP status code.
  final int statusCode;

  /// Response headers.
  final Map<String, String> headers;

  /// Response body.
  final String body;
}
