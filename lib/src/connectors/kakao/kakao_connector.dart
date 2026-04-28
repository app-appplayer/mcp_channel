import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mcp_bundle/ports.dart';

import '../../core/policy/channel_policy.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/extended_channel_capabilities.dart';
import '../../core/port/send_result.dart';
import '../base_connector.dart';
import 'kakao_config.dart';

final _log = Logger('KakaoConnector');

/// Kakao channel connector using the Kakao Skill (i-builder) webhook model.
///
/// Kakao chatbots operate on a synchronous request-response pattern:
/// 1. Kakao sends a Skill request to the webhook endpoint.
/// 2. The bot processes the request and must respond within 5 seconds.
/// 3. The response is formatted as a Kakao SkillResponse payload.
///
/// Because the platform drives communication via webhooks, there is no
/// polling loop or persistent connection. The connector bridges the
/// synchronous webhook model with the asynchronous [ChannelEvent] /
/// [ChannelResponse] contract by using a [Completer] per request.
///
/// Example usage:
/// ```dart
/// final connector = KakaoConnector(
///   config: KakaoConfig(botId: 'my-bot'),
/// );
///
/// await connector.start();
///
/// // In your HTTP server handler:
/// final responsePayload = await connector.handleSkillRequest(requestBody);
/// // Return responsePayload as JSON to Kakao
/// ```
class KakaoConnector extends BaseConnector {
  KakaoConnector({
    required this.config,
    ChannelPolicy? policy,
  }) : policy = policy ?? const ChannelPolicy();

  @override
  final KakaoConfig config;

  @override
  final ChannelPolicy policy;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.kakao();

  /// Pending response completers keyed by event ID.
  ///
  /// When a Skill request arrives, a [Completer] is created and stored here.
  /// The [send] method completes the matching completer so that
  /// [handleSkillRequest] can return the response synchronously.
  final Map<String, Completer<ChannelResponse>> _pendingRequests = {};

  @override
  String get channelType => 'kakao';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'kakao',
        channelId: config.botId,
        displayName: 'Kakao Bot',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connecting);
    // Webhook-based connector: mark as connected immediately.
    // The actual HTTP server is managed externally.
    _log.info('Kakao connector started (webhook mode on ${config.webhookPath})');
    onConnected();
  }

  @override
  Future<void> doStop() async {
    // Complete any pending requests with a fallback response so callers
    // do not hang indefinitely.
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(
          const ConnectorException(
            'Connector stopped while request was pending',
            code: 'connector_stopped',
          ),
        );
      }
    }
    _pendingRequests.clear();
  }

  // ===========================================================================
  // Skill request handling (webhook entry point)
  // ===========================================================================

  /// Handle an incoming Kakao Skill request.
  ///
  /// [payload] is the parsed JSON body of the Skill request from Kakao.
  /// Returns a Kakao SkillResponse payload as a [Map] that should be sent
  /// back as the HTTP response body.
  ///
  /// If [headers] is provided and [KakaoConfig.validationToken] is set,
  /// validates the `x-kakao-validation` header before processing.
  /// Throws [ChannelError] with [ChannelErrorCode.permissionDenied] if the
  /// validation token does not match.
  ///
  /// This method:
  /// 1. Validates the request token (if configured).
  /// 2. Parses the request into a [ChannelEvent] and emits it.
  /// 3. Waits for [send] to be called with a matching [ChannelResponse].
  /// 4. Converts the response into a Kakao SkillResponse format.
  /// 5. Returns the response map (caller serialises to JSON).
  Future<Map<String, dynamic>> handleSkillRequest(
    Map<String, dynamic> payload, {
    Map<String, String>? headers,
  }) async {
    // Validate request token if configured.
    if (config.validationToken != null) {
      final token = headers?['x-kakao-validation'];
      if (token != config.validationToken) {
        throw ChannelError.permissionDenied(
          message: 'Invalid Kakao validation token',
        );
      }
    }

    final event = _parseSkillRequest(payload);
    final eventId = event.id;

    if (config.debug) {
      _log.fine('Received Kakao Skill request: eventId=$eventId');
    }

    // Create a completer for the response.
    final completer = Completer<ChannelResponse>();
    _pendingRequests[eventId] = completer;

    // Emit the event so the application can process it.
    emitEvent(event);

    try {
      // Wait for the response with the configured timeout.
      final response = await completer.future.timeout(
        config.responseTimeout,
        onTimeout: () {
          _log.warning('Response timeout for event $eventId');
          // Return a fallback text response on timeout.
          return ChannelResponse.text(
            conversation: event.conversation,
            text: 'The request could not be processed in time.',
          );
        },
      );

      return _buildSkillResponse(response);
    } finally {
      _pendingRequests.remove(eventId);
    }
  }

  // ===========================================================================
  // Sending
  // ===========================================================================

  @override
  Future<void> send(ChannelResponse response) async {
    // Find the pending request for this conversation and complete it.
    final eventId = _findPendingEventId(response);
    if (eventId == null) {
      _log.warning(
        'No pending Skill request found for conversation '
        '${response.conversation.conversationId}',
      );
      return;
    }

    final completer = _pendingRequests[eventId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
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
          message: 'Failed to send Kakao response: $e',
        ),
      );
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    throw UnsupportedError(
      'Kakao Skill webhook does not support typing indicators',
    );
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    throw UnsupportedError(
      'Kakao Skill webhook does not support message editing',
    );
  }

  @override
  Future<void> delete(String messageId) async {
    throw UnsupportedError(
      'Kakao Skill webhook does not support message deletion',
    );
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    throw UnsupportedError(
      'Kakao Skill webhook does not support reactions',
    );
  }

  // ===========================================================================
  // Private: Skill request parsing
  // ===========================================================================

  /// Parse a Kakao Skill request payload into a [ChannelEvent].
  ///
  /// Kakao Skill request structure:
  /// ```json
  /// {
  ///   "intent": { "id": "...", "name": "..." },
  ///   "userRequest": {
  ///     "timezone": "Asia/Seoul",
  ///     "params": { "ignoreMe": "true" },
  ///     "block": { "id": "...", "name": "..." },
  ///     "utterance": "Hello",
  ///     "lang": "ko",
  ///     "user": {
  ///       "id": "...",
  ///       "type": "botUserKey",
  ///       "properties": {}
  ///     }
  ///   },
  ///   "bot": { "id": "...", "name": "..." },
  ///   "action": { "name": "...", "clientExtra": {}, "params": {}, ... },
  ///   "contexts": [ { "name": "...", "lifeSpan": 5, "params": {} } ]
  /// }
  /// ```
  ChannelEvent _parseSkillRequest(Map<String, dynamic> payload) {
    final userRequest =
        payload['userRequest'] as Map<String, dynamic>? ?? const {};
    final user = userRequest['user'] as Map<String, dynamic>? ?? const {};
    final block = userRequest['block'] as Map<String, dynamic>? ?? const {};
    final intent = payload['intent'] as Map<String, dynamic>? ?? const {};
    final action = payload['action'] as Map<String, dynamic>? ?? const {};
    final contexts = payload['contexts'] as List<dynamic>? ?? const [];

    final userId = user['id'] as String? ?? 'unknown';
    final utterance = userRequest['utterance'] as String? ?? '';
    final intentName = intent['name'] as String?;
    final actionParams = action['params'] as Map<String, dynamic>? ?? {};

    // Event ID format as specified in design doc:
    // '${userId}_${timestamp}'
    final eventId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';

    return ChannelEvent(
      id: eventId,
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'kakao',
          channelId: config.botId,
        ),
        conversationId: userId,
        userId: userId,
      ),
      type: 'message',
      text: utterance,
      userId: userId,
      timestamp: DateTime.now(),
      metadata: {
        if (intentName != null) 'intent': intentName,
        'params': actionParams,
        'contexts': contexts
            .map((c) => c is Map<String, dynamic> ? c : <String, dynamic>{})
            .toList(),
        'block': block,
        'user_properties': user['properties'] as Map<String, dynamic>? ?? {},
      },
    );
  }

  // ===========================================================================
  // Private: Response building
  // ===========================================================================

  /// Convert a [ChannelResponse] to a Kakao SkillResponse payload.
  ///
  /// The response follows the Kakao Skill Response v2.0 format.
  /// Quick replies and context values are included when provided
  /// via [ChannelResponse.options].
  Map<String, dynamic> _buildSkillResponse(ChannelResponse response) {
    final outputs = <Map<String, dynamic>>[];

    // Build outputs from blocks if present, otherwise use text.
    if (response.blocks != null && response.blocks!.isNotEmpty) {
      for (final block in response.blocks!) {
        final blockType = block['type'] as String?;
        switch (blockType) {
          case 'basicCard':
            outputs.add({
              'basicCard': _buildBasicCard(
                title: block['title'] as String?,
                description: block['description'] as String?,
                thumbnail: block['thumbnail'] as String?,
                buttons: block['buttons'] as List<dynamic>?,
              ),
            });
          case 'listCard':
            outputs.add({
              'listCard': _buildListCard(
                header: block['header'] as String? ?? '',
                items: block['items'] as List<dynamic>? ?? [],
              ),
            });
          default:
            // Fall back to simpleText for unknown block types.
            final text = block['text'] as String? ?? '';
            if (text.isNotEmpty) {
              outputs.add({'simpleText': _buildSimpleText(text)});
            }
        }
      }
    }

    // If no outputs were produced from blocks, use the text field.
    if (outputs.isEmpty && response.text != null) {
      outputs.add({'simpleText': _buildSimpleText(response.text!)});
    }

    // Ensure at least one output exists.
    if (outputs.isEmpty) {
      outputs.add({'simpleText': _buildSimpleText('')});
    }

    final template = <String, dynamic>{
      'outputs': outputs,
    };

    // Add quick replies from options if provided.
    final quickReplies = response.options?['quickReplies'] as List<dynamic>?;
    if (quickReplies != null && quickReplies.isNotEmpty) {
      template['quickReplies'] = quickReplies.map((qr) {
        final reply = qr as Map<String, dynamic>;
        return <String, dynamic>{
          'label': reply['label'] as String? ?? '',
          'action': reply['action'] as String? ?? 'message',
          if (reply['messageText'] != null) 'messageText': reply['messageText'],
          if (reply['blockId'] != null) 'blockId': reply['blockId'],
          if (reply['extra'] != null) 'extra': reply['extra'],
        };
      }).toList();
    }

    final result = <String, dynamic>{
      'version': '2.0',
      'template': template,
    };

    // Add context values from options if provided.
    final contexts = response.options?['contexts'] as List<dynamic>?;
    if (contexts != null && contexts.isNotEmpty) {
      result['context'] = {
        'values': contexts.map((c) {
          final ctx = c as Map<String, dynamic>;
          return <String, dynamic>{
            'name': ctx['name'] as String? ?? '',
            'lifeSpan': ctx['lifeSpan'] as int? ?? 0,
            if (ctx['params'] != null) 'params': ctx['params'],
            if (ctx['ttl'] != null) 'ttl': ctx['ttl'],
          };
        }).toList(),
      };
    }

    // Add data from options if provided.
    final data = response.options?['data'] as Map<String, dynamic>?;
    if (data != null) {
      result['data'] = data;
    }

    return result;
  }

  /// Build a Kakao simpleText template component.
  Map<String, dynamic> _buildSimpleText(String text) {
    return {'text': text};
  }

  /// Build a Kakao basicCard template component.
  Map<String, dynamic> _buildBasicCard({
    String? title,
    String? description,
    String? thumbnail,
    List<dynamic>? buttons,
  }) {
    return {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (thumbnail != null)
        'thumbnail': {'imageUrl': thumbnail},
      if (buttons != null && buttons.isNotEmpty)
        'buttons': buttons
            .map((b) {
              final btn = b as Map<String, dynamic>;
              final label = btn['label'] as String? ??
                  btn['text'] as String? ??
                  '';
              final action = btn['action'] as String? ?? 'message';
              return <String, dynamic>{
                'label': label,
                'action': action,
                if (btn['webLinkUrl'] != null)
                  'webLinkUrl': btn['webLinkUrl'],
                if (btn['messageText'] != null)
                  'messageText': btn['messageText'],
              };
            })
            .toList(),
    };
  }

  /// Build a Kakao listCard template component.
  Map<String, dynamic> _buildListCard({
    required String header,
    required List<dynamic> items,
  }) {
    return {
      'header': {'title': header},
      'items': items
          .map((item) {
            final i = item as Map<String, dynamic>;
            return <String, dynamic>{
              'title': i['title'] as String? ?? '',
              if (i['description'] != null) 'description': i['description'],
              if (i['imageUrl'] != null)
                'thumbnail': {'imageUrl': i['imageUrl']},
              if (i['link'] != null)
                'link': {'web': i['link']},
            };
          })
          .toList(),
    };
  }

  // ===========================================================================
  // Private: Helpers
  // ===========================================================================

  /// Find a pending event ID that matches the given response's conversation.
  ///
  /// Since Kakao Skill requests are 1:1 (one request per user per time),
  /// we match by the conversation ID (which is the user ID).
  String? _findPendingEventId(ChannelResponse response) {
    final conversationId = response.conversation.conversationId;
    for (final eventId in _pendingRequests.keys) {
      if (eventId.contains(conversationId)) {
        return eventId;
      }
    }
    // If no match by conversation ID, return the first pending request
    // (single-request scenarios).
    if (_pendingRequests.isNotEmpty) {
      return _pendingRequests.keys.first;
    }
    return null;
  }
}
