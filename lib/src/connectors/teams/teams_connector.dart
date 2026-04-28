import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mcp_bundle/ports.dart';

import '../../core/policy/channel_policy.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/conversation_info.dart';
import '../../core/port/extended_channel_capabilities.dart';
import '../../core/port/send_result.dart';
import '../../core/types/channel_identity_info.dart';
import '../../core/types/file_info.dart';
import '../base_connector.dart';
import 'teams_config.dart';

final _log = Logger('TeamsConnector');

/// Microsoft Teams channel connector via Bot Framework REST API.
///
/// Provides integration with Microsoft Teams using the Azure Bot Framework.
/// Authentication is handled via Azure AD OAuth2 client credentials flow.
///
/// Unlike WebSocket-based connectors (Slack Socket Mode, Discord Gateway),
/// the Teams connector operates in webhook mode. Incoming activities are
/// delivered to [handleActivity] by an external HTTP server, and outgoing
/// messages are sent via Bot Framework REST API calls.
///
/// Example usage:
/// ```dart
/// final connector = TeamsConnector(
///   config: TeamsConfig(
///     appId: 'your-app-id',
///     appPassword: 'your-app-password',
///   ),
/// );
///
/// await connector.start();
///
/// await for (final event in connector.events) {
///   // Handle events
/// }
/// ```
class TeamsConnector extends BaseConnector {
  TeamsConnector({
    required this.config,
    ChannelPolicy? policy,
    http.Client? httpClient,
  })  : policy = policy ?? ChannelPolicy.teams(),
        _httpClient = httpClient ?? http.Client();

  @override
  final TeamsConfig config;

  @override
  final ChannelPolicy policy;

  final http.Client _httpClient;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.teams();

  /// Cached OAuth2 access token.
  String? _accessToken;

  /// Token expiration time.
  DateTime? _tokenExpiry;

  /// Per-activity service URL override (Bot Framework may send different
  /// service URLs per conversation).
  final Map<String, String> _serviceUrls = {};

  @override
  String get channelType => 'teams';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'teams',
        channelId: config.appId,
        displayName: 'Teams Bot',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connecting);

    try {
      // Validate credentials by acquiring a token
      await _getAccessToken();
      _log.info('Teams connector started in webhook mode');
      onConnected();
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  @override
  Future<void> doStop() async {
    _accessToken = null;
    _tokenExpiry = null;
    _serviceUrls.clear();
  }

  @override
  Future<void> send(ChannelResponse response) async {
    if (response.text == null && response.blocks == null) {
      throw ArgumentError('Response must have text or blocks');
    }

    final activity = _buildActivity(response);
    final serviceUrl = _resolveServiceUrl(response.conversation.conversationId);
    await _sendActivity(serviceUrl, response.conversation, activity);
  }

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    if (response.text == null && response.blocks == null) {
      return SendResult.failure(
        error: const ChannelError(
          code: ChannelErrorCode.invalidRequest,
          message: 'Response must have text or blocks',
        ),
      );
    }

    try {
      final activity = _buildActivity(response);
      final serviceUrl =
          _resolveServiceUrl(response.conversation.conversationId);
      final result =
          await _sendActivity(serviceUrl, response.conversation, activity);

      return SendResult.success(
        messageId: result['id'] as String? ?? '',
        platformData: result,
      );
    } catch (e) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.serverError,
          message: 'Failed to send Teams message: $e',
          retryable: _isRetryableError(e),
        ),
      );
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    final serviceUrl = _resolveServiceUrl(conversation.conversationId);
    final activity = <String, dynamic>{
      'type': 'typing',
    };
    await _sendActivity(serviceUrl, conversation, activity);
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    final activity = _buildActivity(response);
    activity['id'] = messageId;
    final serviceUrl =
        _resolveServiceUrl(response.conversation.conversationId);
    await _updateActivity(
        serviceUrl, response.conversation, messageId, activity);
  }

  @override
  Future<void> delete(String messageId) async {
    // messageId format: "conversationId:activityId"
    final parts = messageId.split(':');
    if (parts.length == 2) {
      final conversationId = parts[0];
      final activityId = parts[1];
      final serviceUrl = _resolveServiceUrl(conversationId);
      await _deleteActivity(serviceUrl, conversationId, activityId);
    }
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    // Teams does not expose a public REST API for adding reactions
    // as a bot. This is a known platform limitation.
    _log.fine('Reaction API not available for Teams bots: $reaction');
  }

  @override
  Future<FileInfo?> uploadFile({
    required ConversationKey conversation,
    required String name,
    required Uint8List data,
    String? mimeType,
  }) async {
    // Teams file uploads go through SharePoint / OneDrive via Graph API,
    // which requires additional permissions. For inline attachments, we
    // encode the content as a base64 data URI within a message activity.
    try {
      final base64Content = base64Encode(data);
      final contentType = mimeType ?? 'application/octet-stream';
      final dataUri = 'data:$contentType;base64,$base64Content';

      final activity = <String, dynamic>{
        'type': 'message',
        'attachments': [
          {
            'contentType': contentType,
            'contentUrl': dataUri,
            'name': name,
          }
        ],
      };

      final serviceUrl = _resolveServiceUrl(conversation.conversationId);
      final result = await _sendActivity(serviceUrl, conversation, activity);

      return FileInfo(
        id: result['id'] as String? ?? name,
        name: name,
        mimeType: contentType,
        size: data.length,
      );
    } catch (e) {
      _log.warning('File upload failed: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> downloadFile(String fileId) async {
    // Teams file downloads require Graph API access.
    // fileId is expected to be a direct download URL.
    try {
      final token = await _getAccessToken();
      final response = await _httpClient.get(
        Uri.parse(fileId),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (e) {
      _log.warning('File download failed: $e');
      return null;
    }
  }

  @override
  Future<ChannelIdentityInfo?> getIdentityInfo(String userId) async {
    try {
      // Use Bot Framework connector API to get member info.
      // This requires a known conversation ID; we iterate cached service URLs
      // to find an appropriate one.
      if (_serviceUrls.isEmpty) {
        _log.fine('No cached service URLs, cannot look up identity: $userId');
        return null;
      }

      final serviceUrl = _serviceUrls.values.first;
      final conversationId = _serviceUrls.keys.first;
      final result = await _apiCall(
        'GET',
        '$serviceUrl/v3/conversations/$conversationId/members/$userId',
      );

      return ChannelIdentityInfo.user(
        id: userId,
        displayName: result['name'] as String?,
        email: result['email'] as String?,
        platformData: result,
      );
    } catch (e) {
      _log.warning('Failed to get identity info for $userId: $e');
      return null;
    }
  }

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) async {
    try {
      final serviceUrl = _resolveServiceUrl(key.conversationId);
      final result = await _apiCall(
        'GET',
        '$serviceUrl/v3/conversations/${key.conversationId}',
      );

      final conversationType =
          result['conversationType'] as String? ?? 'personal';

      return ConversationInfo(
        key: key,
        name: result['name'] as String?,
        topic: result['topic'] as String?,
        isPrivate: conversationType == 'personal',
        isGroup: conversationType == 'groupChat' ||
            conversationType == 'channel',
        memberCount: result['members'] != null
            ? (result['members'] as List<dynamic>).length
            : null,
        platformData: result,
      );
    } catch (e) {
      _log.warning('Failed to get conversation info: $e');
      return null;
    }
  }

  // =========================================================================
  // Public: Incoming activity handling
  // =========================================================================

  /// Handle an incoming Bot Framework activity.
  ///
  /// This should be called by an external HTTP server that receives
  /// POST requests from the Bot Framework. The [activity] parameter
  /// is the parsed JSON body of the request.
  ///
  /// Optionally, [serviceUrl] can be provided from the activity's
  /// `serviceUrl` field to cache for outgoing messages.
  ChannelEvent handleActivity(
    Map<String, dynamic> activity, {
    String? serviceUrl,
  }) {
    // Cache service URL for this conversation
    final conversationId = _extractConversationId(activity);
    if (serviceUrl != null && conversationId != null) {
      _serviceUrls[conversationId] = serviceUrl;
    }

    return _parseActivity(activity);
  }

  /// Send a proactive message to a conversation using a stored reference.
  ///
  /// Proactive messaging requires the bot to have previously received a
  /// message in the target conversation so that a conversation reference
  /// can be stored. The [reference] must contain at minimum the
  /// `serviceUrl`, `conversation.id`, `bot`, and `user` fields.
  ///
  /// The connector's [config] must have [TeamsConfig.enableProactive]
  /// set to `true`.
  Future<void> sendProactiveMessage({
    required Map<String, dynamic> reference,
    required ChannelResponse response,
  }) async {
    if (!config.enableProactive) {
      throw const ConnectorException(
        'Proactive messaging is not enabled in config',
        code: 'proactive_disabled',
      );
    }

    final token = await _getAccessToken();
    final serviceUrl = reference['serviceUrl'] as String? ?? config.serviceUrl;
    final conversationData =
        reference['conversation'] as Map<String, dynamic>? ?? {};
    final conversationId = conversationData['id'] as String? ?? '';
    final bot = reference['bot'] as Map<String, dynamic>? ?? {};
    final user = reference['user'] as Map<String, dynamic>? ?? {};

    final activity = <String, dynamic>{
      'type': 'message',
      'conversation': conversationData,
      'from': bot,
      'recipient': user,
      if (response.text != null) 'text': response.text,
      if (response.blocks != null)
        'attachments': _blocksToAdaptiveCards(response.blocks!),
    };

    await _httpClient.post(
      Uri.parse(
          '$serviceUrl/v3/conversations/$conversationId/activities'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(activity),
    );
  }

  /// Open a task module (modal dialog) in response to an invoke activity.
  ///
  /// The [activity] should be the original invoke activity that triggered
  /// the task module request (e.g., task/fetch). The [definition] map
  /// should contain `title`, optional `height`, optional `width`, and
  /// `card` (the Adaptive Card content to display).
  Future<void> openTaskModule({
    required Map<String, dynamic> activity,
    required Map<String, dynamic> definition,
  }) async {
    final serviceUrl = activity['serviceUrl'] as String? ?? config.serviceUrl;
    final conversationData =
        activity['conversation'] as Map<String, dynamic>? ?? {};
    final conversationId = conversationData['id'] as String? ?? '';
    final activityId = activity['id'] as String? ?? '';

    final invokeResponse = <String, dynamic>{
      'status': 200,
      'body': {
        'task': {
          'type': 'continue',
          'value': {
            'title': definition['title'] ?? '',
            'height': definition['height'] ?? 'medium',
            'width': definition['width'] ?? 'medium',
            'card': definition['card'],
          },
        },
      },
    };

    final token = await _getAccessToken();
    await _httpClient.post(
      Uri.parse(
          '$serviceUrl/v3/conversations/$conversationId/activities/$activityId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(invokeResponse),
    );
  }

  /// Handle a task module submit activity.
  ///
  /// Parses the submitted data from a task/submit invoke activity and
  /// emits a button-type [ChannelEvent] with the submitted values in
  /// metadata.
  void handleTaskSubmit(Map<String, dynamic> activity) {
    final from = activity['from'] as Map<String, dynamic>? ?? {};
    final conversation =
        activity['conversation'] as Map<String, dynamic>? ?? {};
    final conversationId = conversation['id'] as String? ?? 'unknown';
    final tenantId =
        (activity['channelData'] as Map<String, dynamic>?)?['tenant']
                ?['id'] as String? ??
            config.tenantId ??
            'unknown';
    final data =
        (activity['value'] as Map<String, dynamic>?)?['data']
            as Map<String, dynamic>? ??
        {};

    final event = ChannelEvent(
      id: activity['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'teams',
          channelId: tenantId,
        ),
        conversationId: conversationId,
        userId: from['id'] as String?,
      ),
      type: 'button',
      text: null,
      userId: from['id'] as String?,
      userName: from['name'] as String?,
      timestamp: activity['timestamp'] != null
          ? DateTime.tryParse(activity['timestamp'] as String) ??
              DateTime.now()
          : DateTime.now(),
      metadata: {
        ...activity,
        'action_id': 'task_submit',
        'values': data,
      },
    );

    emitEvent(event);
  }

  // =========================================================================
  // Private: OAuth2 token management
  // =========================================================================

  /// Get a valid access token, refreshing if necessary.
  Future<String> _getAccessToken() async {
    // Refresh token 5 minutes before expiry to avoid edge cases
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(
            _tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _accessToken!;
    }

    final tokenUrl = Uri.parse(config.tokenEndpoint);

    final response = await _httpClient.post(
      tokenUrl,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
        'client_id': config.appId,
        'client_secret': config.appPassword,
        'scope': 'https://api.botframework.com/.default',
      },
    );

    if (response.statusCode != 200) {
      throw ConnectorException(
        'Failed to acquire Azure AD token: ${response.statusCode} '
        '${response.body}',
        code: 'token_acquisition_failed',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = body['access_token'] as String;
    final expiresIn = body['expires_in'] as int? ?? 3600;

    _tokenExpiry = DateTime.now().add(
      Duration(seconds: expiresIn),
    );

    _log.fine('Acquired new Azure AD access token, expires in ${expiresIn}s');
    return _accessToken!;
  }

  // =========================================================================
  // Private: Bot Framework REST API
  // =========================================================================

  /// Generic Bot Framework API call with authentication.
  Future<Map<String, dynamic>> _apiCall(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
    };

    http.Response response;
    switch (method) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _httpClient.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await _httpClient.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    // Handle rate limiting (HTTP 429)
    if (response.statusCode == 429) {
      final retryAfter =
          int.tryParse(response.headers['retry-after'] ?? '') ?? 1;
      throw ChannelError.rateLimited(
        retryAfter: Duration(seconds: retryAfter),
        platformData: {'url': url},
      );
    }

    // Handle server errors
    if (response.statusCode >= 500) {
      throw ChannelError.serverError(
        message: 'Bot Framework API $method returned ${response.statusCode}',
        platformData: {'url': url, 'statusCode': response.statusCode},
      );
    }

    // Handle 204 No Content
    if (response.statusCode == 204 || response.body.isEmpty) {
      return {};
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    // Handle client errors
    if (response.statusCode >= 400) {
      final errorCode =
          responseBody['error']?['code'] as String? ?? 'unknown';
      final errorMessage =
          responseBody['error']?['message'] as String? ??
              'HTTP ${response.statusCode}';
      throw ConnectorException(
        'Bot Framework API error: $errorMessage',
        code: errorCode,
      );
    }

    return responseBody;
  }

  /// Send an activity to a conversation.
  Future<Map<String, dynamic>> _sendActivity(
    String serviceUrl,
    ConversationKey conversation,
    Map<String, dynamic> activity,
  ) async {
    final conversationId = conversation.conversationId;
    final url =
        '$serviceUrl/v3/conversations/$conversationId/activities';

    return _apiCall('POST', url, body: activity);
  }

  /// Update (edit) an existing activity.
  Future<Map<String, dynamic>> _updateActivity(
    String serviceUrl,
    ConversationKey conversation,
    String activityId,
    Map<String, dynamic> activity,
  ) async {
    final conversationId = conversation.conversationId;
    final url =
        '$serviceUrl/v3/conversations/$conversationId/activities/$activityId';

    return _apiCall('PUT', url, body: activity);
  }

  /// Delete an existing activity.
  Future<void> _deleteActivity(
    String serviceUrl,
    String conversationId,
    String activityId,
  ) async {
    final url =
        '$serviceUrl/v3/conversations/$conversationId/activities/$activityId';

    await _apiCall('DELETE', url);
  }

  /// Resolve the service URL for a given conversation.
  String _resolveServiceUrl(String conversationId) {
    return _serviceUrls[conversationId] ?? config.serviceUrl;
  }

  // =========================================================================
  // Private: Activity building
  // =========================================================================

  /// Build a Bot Framework activity from a ChannelResponse.
  Map<String, dynamic> _buildActivity(ChannelResponse response) {
    final activity = <String, dynamic>{
      'type': 'message',
    };

    if (response.text != null) {
      activity['text'] = response.text;
    }

    if (response.blocks != null) {
      activity['attachments'] = _blocksToAdaptiveCards(response.blocks!);
    }

    if (response.replyTo != null) {
      activity['replyToId'] = response.replyTo;
    }

    if (response.options != null) {
      activity.addAll(response.options!);
    }

    return activity;
  }

  /// Convert generic blocks to Teams Adaptive Card attachments.
  List<Map<String, dynamic>> _blocksToAdaptiveCards(
    List<Map<String, dynamic>> blocks,
  ) {
    final cardBody = <Map<String, dynamic>>[];

    for (final block in blocks) {
      final type = block['type'] as String?;
      switch (type) {
        case 'section':
          cardBody.add({
            'type': 'TextBlock',
            'text': block['text'] ?? '',
            'wrap': true,
          });
          break;
        case 'header':
          cardBody.add({
            'type': 'TextBlock',
            'text': block['text'] ?? '',
            'size': 'Large',
            'weight': 'Bolder',
            'wrap': true,
          });
          break;
        case 'image':
          cardBody.add({
            'type': 'Image',
            'url': block['url'] ?? '',
            'altText': block['altText'] ?? '',
          });
          break;
        case 'actions':
          final actions = block['elements'] as List<dynamic>? ?? [];
          cardBody.add({
            'type': 'ActionSet',
            'actions': _translateActions(actions),
          });
          break;
        case 'divider':
          cardBody.add({
            'type': 'TextBlock',
            'text': '---',
            'separator': true,
          });
          break;
      }
    }

    return [
      {
        'contentType': 'application/vnd.microsoft.card.adaptive',
        'content': {
          'type': 'AdaptiveCard',
          r'$schema': 'http://adaptivecards.io/schemas/adaptive-card.json',
          'version': '1.5',
          'body': cardBody,
        },
      }
    ];
  }

  /// Translate action elements to Adaptive Card actions.
  ///
  /// Button actions with HTTP URLs are mapped to Action.OpenUrl,
  /// while other buttons are mapped to Action.Submit with action/value data.
  List<Map<String, dynamic>> _translateActions(List<dynamic> elements) {
    return elements.map((e) {
      final element = e as Map<String, dynamic>;
      final value = element['value'] as String?;

      // URL buttons open the link directly
      if (value != null && value.startsWith('http')) {
        return <String, dynamic>{
          'type': 'Action.OpenUrl',
          'title': element['text'] ?? '',
          'url': value,
        };
      }

      // All other buttons submit action data
      return <String, dynamic>{
        'type': 'Action.Submit',
        'title': element['text'] ?? '',
        'data': {
          'action': element['actionId'] ?? '',
          'value': value ?? '',
        },
      };
    }).toList();
  }

  // =========================================================================
  // Private: Activity parsing
  // =========================================================================

  /// Extract the conversation ID from a raw activity.
  String? _extractConversationId(Map<String, dynamic> activity) {
    final conversation =
        activity['conversation'] as Map<String, dynamic>?;
    return conversation?['id'] as String?;
  }

  /// Parse an incoming Bot Framework activity to a ChannelEvent.
  ChannelEvent _parseActivity(Map<String, dynamic> activity) {
    final activityType = activity['type'] as String?;

    switch (activityType) {
      case 'message':
        return _parseMessageActivity(activity);
      case 'invoke':
        return _parseInvokeActivity(activity);
      case 'messageReaction':
        return _parseReactionActivity(activity);
      case 'conversationUpdate':
        return _parseConversationUpdateActivity(activity);
      default:
        return _parseUnknownActivity(activity);
    }
  }

  ChannelEvent _parseMessageActivity(Map<String, dynamic> activity) {
    final from = activity['from'] as Map<String, dynamic>? ?? {};
    final conversation =
        activity['conversation'] as Map<String, dynamic>? ?? {};
    final conversationId = conversation['id'] as String? ?? 'unknown';
    final tenantId =
        (activity['channelData'] as Map<String, dynamic>?)?['tenant']
                ?['id'] as String? ??
            config.tenantId ??
            'unknown';

    return ChannelEvent.message(
      id: activity['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'teams',
          channelId: tenantId,
        ),
        conversationId: conversationId,
        userId: from['id'] as String?,
      ),
      text: activity['text'] as String? ?? '',
      userId: from['id'] as String?,
      userName: from['name'] as String?,
      timestamp: activity['timestamp'] != null
          ? DateTime.tryParse(activity['timestamp'] as String) ??
              DateTime.now()
          : DateTime.now(),
      attachments: _parseAttachments(activity),
      metadata: activity,
    );
  }

  ChannelEvent _parseInvokeActivity(Map<String, dynamic> activity) {
    final from = activity['from'] as Map<String, dynamic>? ?? {};
    final conversation =
        activity['conversation'] as Map<String, dynamic>? ?? {};
    final conversationId = conversation['id'] as String? ?? 'unknown';
    final tenantId =
        (activity['channelData'] as Map<String, dynamic>?)?['tenant']
                ?['id'] as String? ??
            config.tenantId ??
            'unknown';

    final invokeName = activity['name'] as String? ?? '';
    final invokeValue = activity['value'] as Map<String, dynamic>? ?? {};

    // Map invoke name to event type per design doc:
    //   composeExtension → command
    //   task/fetch → button
    //   task/submit → button
    //   actionableMessage → button (default for other invoke names)
    final String eventType;
    if (invokeName.startsWith('composeExtension')) {
      eventType = 'command';
    } else {
      eventType = 'button';
    }

    return ChannelEvent(
      id: activity['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'teams',
          channelId: tenantId,
        ),
        conversationId: conversationId,
        userId: from['id'] as String?,
      ),
      type: eventType,
      text: '/$invokeName',
      userId: from['id'] as String?,
      userName: from['name'] as String?,
      timestamp: activity['timestamp'] != null
          ? DateTime.tryParse(activity['timestamp'] as String) ??
              DateTime.now()
          : DateTime.now(),
      metadata: {
        ...activity,
        'command': invokeName,
        'invoke_value': invokeValue,
      },
    );
  }

  ChannelEvent _parseReactionActivity(Map<String, dynamic> activity) {
    final from = activity['from'] as Map<String, dynamic>? ?? {};
    final conversation =
        activity['conversation'] as Map<String, dynamic>? ?? {};
    final conversationId = conversation['id'] as String? ?? 'unknown';
    final tenantId =
        (activity['channelData'] as Map<String, dynamic>?)?['tenant']
                ?['id'] as String? ??
            config.tenantId ??
            'unknown';

    final reactionsAdded =
        activity['reactionsAdded'] as List<dynamic>? ?? [];
    final reactionType = reactionsAdded.isNotEmpty
        ? (reactionsAdded.first as Map<String, dynamic>)['type'] as String?
        : null;

    return ChannelEvent(
      id: activity['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'teams',
          channelId: tenantId,
        ),
        conversationId: conversationId,
        userId: from['id'] as String?,
      ),
      type: 'reaction',
      text: reactionType,
      userId: from['id'] as String?,
      userName: from['name'] as String?,
      timestamp: activity['timestamp'] != null
          ? DateTime.tryParse(activity['timestamp'] as String) ??
              DateTime.now()
          : DateTime.now(),
      metadata: {
        ...activity,
        'target_message_id': activity['replyToId'] as String?,
        'reactions_added': reactionsAdded,
      },
    );
  }

  ChannelEvent _parseConversationUpdateActivity(
      Map<String, dynamic> activity) {
    final from = activity['from'] as Map<String, dynamic>? ?? {};
    final conversation =
        activity['conversation'] as Map<String, dynamic>? ?? {};
    final conversationId = conversation['id'] as String? ?? 'unknown';
    final tenantId =
        (activity['channelData'] as Map<String, dynamic>?)?['tenant']
                ?['id'] as String? ??
            config.tenantId ??
            'unknown';

    final membersAdded =
        activity['membersAdded'] as List<dynamic>? ?? [];
    final membersRemoved =
        activity['membersRemoved'] as List<dynamic>? ?? [];

    String eventType;
    if (membersAdded.isNotEmpty) {
      eventType = 'join';
    } else if (membersRemoved.isNotEmpty) {
      eventType = 'leave';
    } else {
      eventType = 'conversation_update';
    }

    return ChannelEvent(
      id: activity['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'teams',
          channelId: tenantId,
        ),
        conversationId: conversationId,
        userId: from['id'] as String?,
      ),
      type: eventType,
      userId: from['id'] as String?,
      userName: from['name'] as String?,
      timestamp: activity['timestamp'] != null
          ? DateTime.tryParse(activity['timestamp'] as String) ??
              DateTime.now()
          : DateTime.now(),
      metadata: {
        ...activity,
        'members_added': membersAdded,
        'members_removed': membersRemoved,
      },
    );
  }

  ChannelEvent _parseUnknownActivity(Map<String, dynamic> activity) {
    final from = activity['from'] as Map<String, dynamic>? ?? {};
    final conversation =
        activity['conversation'] as Map<String, dynamic>? ?? {};
    final conversationId = conversation['id'] as String? ?? 'unknown';

    return ChannelEvent(
      id: activity['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'teams',
          channelId: config.appId,
        ),
        conversationId: conversationId,
        userId: from['id'] as String?,
      ),
      type: 'unknown',
      userId: from['id'] as String?,
      userName: from['name'] as String?,
      timestamp: DateTime.now(),
      metadata: activity,
    );
  }

  /// Parse attachments from a Bot Framework activity.
  List<ChannelAttachment>? _parseAttachments(Map<String, dynamic> activity) {
    final attachments = activity['attachments'] as List<dynamic>?;
    if (attachments == null || attachments.isEmpty) return null;

    return attachments
        .cast<Map<String, dynamic>>()
        .map((a) {
          final contentType = a['contentType'] as String? ?? '';
          String attachmentType;
          if (contentType.startsWith('image/')) {
            attachmentType = 'image';
          } else if (contentType.startsWith('video/')) {
            attachmentType = 'video';
          } else if (contentType.startsWith('audio/')) {
            attachmentType = 'audio';
          } else {
            attachmentType = 'file';
          }

          return ChannelAttachment(
            type: attachmentType,
            url: a['contentUrl'] as String? ?? '',
            filename: a['name'] as String?,
            mimeType: contentType.isNotEmpty ? contentType : null,
          );
        })
        .toList();
  }

  bool _isRetryableError(Object error) {
    if (error is ChannelError) return error.retryable;
    if (error is http.ClientException) return true;
    return false;
  }
}
