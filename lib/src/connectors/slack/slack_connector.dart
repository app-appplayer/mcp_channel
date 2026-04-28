import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/policy/channel_policy.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/conversation_info.dart';
import '../../core/port/extended_channel_capabilities.dart';
import '../../core/port/send_result.dart';
import '../../core/types/channel_identity_info.dart';
import '../../core/types/content_block.dart';
import '../../core/types/extended_channel_event.dart';
import '../../core/types/extended_conversation_key.dart';
import '../../core/types/file_info.dart';
import '../base_connector.dart';
import 'slack_config.dart';

final _log = Logger('SlackConnector');

/// Modal view definition for Slack modals.
@immutable
class ModalView {
  const ModalView({
    required this.callbackId,
    required this.title,
    this.submitText,
    required this.blocks,
    this.privateMetadata,
  });

  /// Callback ID for identifying the modal submission
  final String callbackId;

  /// Modal title text
  final String title;

  /// Submit button text (null hides the submit button)
  final String? submitText;

  /// Content blocks for the modal body
  final List<ContentBlock> blocks;

  /// Private metadata passed through the modal lifecycle
  final String? privateMetadata;

  ModalView copyWith({
    String? callbackId,
    String? title,
    String? submitText,
    List<ContentBlock>? blocks,
    String? privateMetadata,
  }) {
    return ModalView(
      callbackId: callbackId ?? this.callbackId,
      title: title ?? this.title,
      submitText: submitText ?? this.submitText,
      blocks: blocks ?? this.blocks,
      privateMetadata: privateMetadata ?? this.privateMetadata,
    );
  }
}

/// Slack channel connector.
///
/// Provides integration with Slack's messaging platform via Socket Mode
/// or HTTP webhooks.
///
/// Example usage:
/// ```dart
/// final connector = SlackConnector(
///   config: SlackConfig(
///     botToken: 'xoxb-...',
///     appToken: 'xapp-...',
///     signingSecret: 'secret',
///   ),
/// );
///
/// await connector.start();
///
/// await for (final event in connector.events) {
///   // Handle events
/// }
/// ```
class SlackConnector extends BaseConnector {
  SlackConnector({
    required this.config,
    ChannelPolicy? policy,
    http.Client? httpClient,
  })  : policy = policy ?? ChannelPolicy.slack(),
        _httpClient = httpClient ?? http.Client();

  @override
  final SlackConfig config;

  @override
  final ChannelPolicy policy;

  final http.Client _httpClient;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.slack();

  static const String _apiBase = 'https://slack.com/api';

  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;

  @override
  String get channelType => 'slack';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'slack',
        channelId: config.workspaceId ?? 'default',
        displayName: 'Slack Connector',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connecting);

    try {
      if (config.useSocketMode && config.appToken != null) {
        await _startSocketMode();
      } else {
        await _startHttpMode();
      }
      onConnected();
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  @override
  Future<void> doStop() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
  }

  @override
  Future<void> send(ChannelResponse response) async {
    if (response.text == null && response.blocks == null) {
      throw ArgumentError('Response must have text or blocks');
    }

    final payload = _buildMessagePayload(response);

    // Check for ephemeral message support
    final isEphemeral = response.options?['ephemeral'] == true;
    final ephemeralUserId = response.options?['ephemeralUserId'] as String?;

    if (isEphemeral && ephemeralUserId != null) {
      payload['user'] = ephemeralUserId;
      payload['channel'] = response.conversation.conversationId;
      await _apiCall('chat.postEphemeral', payload);
    } else {
      await _postMessage(response.conversation.conversationId, payload);
    }
  }

  /// Send with result wrapper.
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
      final payload = _buildMessagePayload(response);

      // Check for ephemeral message support
      final isEphemeral = response.options?['ephemeral'] == true;
      final ephemeralUserId = response.options?['ephemeralUserId'] as String?;

      final Map<String, dynamic> result;

      if (isEphemeral && ephemeralUserId != null) {
        payload['user'] = ephemeralUserId;
        payload['channel'] = response.conversation.conversationId;
        result = await _apiCall('chat.postEphemeral', payload);
      } else {
        result = await _postMessage(
          response.conversation.conversationId,
          payload,
        );
      }

      return SendResult.success(
        messageId: result['ts'] as String? ??
            result['message_ts'] as String? ??
            '',
        platformData: result,
      );
    } catch (e) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.serverError,
          message: 'Failed to send message: $e',
          retryable: _isRetryableError(e),
        ),
      );
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    // Slack doesn't have a built-in typing indicator API for bots
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    final payload = _buildMessagePayload(response);
    payload['ts'] = messageId;
    await _updateMessage(response.conversation.conversationId, payload);
  }

  @override
  Future<void> delete(String messageId) async {
    await _apiCall('chat.delete', {
      'ts': messageId,
    });
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    // Remove colons if present (e.g., ":thumbsup:" -> "thumbsup")
    final emoji = reaction.replaceAll(':', '');
    await _apiCall('reactions.add', {
      'name': emoji,
      'timestamp': messageId,
    });
  }

  @override
  Future<FileInfo?> uploadFile({
    required ConversationKey conversation,
    required String name,
    required Uint8List data,
    String? mimeType,
  }) async {
    try {
      final result = await _uploadFile(
        conversation.conversationId,
        name,
        data,
        mimeType: mimeType,
      );

      return FileInfo(
        id: result['id'] as String,
        name: name,
        mimeType: mimeType ?? 'application/octet-stream',
        size: data.length,
        url: result['url_private'] as String?,
      );
    } catch (e) {
      _log.warning('File upload failed: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> downloadFile(String fileId) async {
    try {
      return await _downloadFile(fileId);
    } catch (e) {
      _log.warning('File download failed: $e');
      return null;
    }
  }

  @override
  Future<ChannelIdentityInfo?> getIdentityInfo(String userId) async {
    try {
      final result = await _apiCall('users.info', {'user': userId});
      final user = result['user'] as Map<String, dynamic>;
      final profile = user['profile'] as Map<String, dynamic>? ?? {};

      return ChannelIdentityInfo.user(
        id: userId,
        displayName: profile['real_name'] as String? ??
            user['real_name'] as String?,
        username: user['name'] as String?,
        avatarUrl: profile['image_72'] as String?,
        email: profile['email'] as String?,
        timezone: user['tz'] as String?,
        locale: user['locale'] as String?,
        isAdmin: user['is_admin'] as bool?,
        platformData: user,
      );
    } catch (e) {
      _log.warning('Failed to get identity info for $userId: $e');
      return null;
    }
  }

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) async {
    try {
      final result =
          await _apiCall('conversations.info', {'channel': key.conversationId});
      final channel = result['channel'] as Map<String, dynamic>;

      return ConversationInfo(
        key: key,
        name: channel['name'] as String?,
        topic: (channel['topic'] as Map<String, dynamic>?)?['value'] as String?,
        isPrivate: channel['is_private'] as bool? ?? false,
        isGroup: channel['is_group'] as bool? ??
            channel['is_mpim'] as bool? ??
            false,
        memberCount: channel['num_members'] as int?,
        createdAt: channel['created'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (channel['created'] as int) * 1000)
            : null,
        platformData: channel,
      );
    } catch (e) {
      _log.warning('Failed to get conversation info: $e');
      return null;
    }
  }

  // =========================================================================
  // Interactive Components
  // =========================================================================

  /// Open a modal dialog in Slack.
  ///
  /// Requires a valid [triggerId] from an interactive event (button click,
  /// slash command, shortcut, etc.) and a [view] definition.
  Future<void> openModal({
    required String triggerId,
    required ModalView view,
  }) async {
    await _apiCall('views.open', {
      'trigger_id': triggerId,
      'view': {
        'type': 'modal',
        'callback_id': view.callbackId,
        'title': {
          'type': 'plain_text',
          'text': view.title,
        },
        if (view.submitText != null)
          'submit': {
            'type': 'plain_text',
            'text': view.submitText,
          },
        'blocks': _translateBlocks(view.blocks),
        if (view.privateMetadata != null)
          'private_metadata': view.privateMetadata,
      },
    });
  }

  /// Handle a block action interaction (button click, menu select, etc.).
  ///
  /// Parses the interaction payload and emits an [ExtendedChannelEvent]
  /// for each action in the interaction.
  void handleBlockAction(Map<String, dynamic> interaction) {
    final actions = interaction['actions'] as List<dynamic>? ?? [];
    final user = interaction['user'] as Map<String, dynamic>?;
    final channel = interaction['channel'] as Map<String, dynamic>?;
    final team = interaction['team'] as Map<String, dynamic>?;
    final message = interaction['message'] as Map<String, dynamic>?;

    for (final action in actions) {
      final actionMap = action as Map<String, dynamic>;

      final event = ExtendedChannelEvent.button(
        id: interaction['trigger_id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user?['id'] as String?,
        userName: user?['name'] as String?,
        conversation: ConversationKey(
          channel: ChannelIdentity(
            platform: 'slack',
            channelId: channel?['id'] as String? ?? 'unknown',
          ),
          conversationId: channel?['id'] as String? ?? 'unknown',
          userId: user?['id'] as String?,
        ),
        extendedConversation: ExtendedConversationKey.create(
          platform: 'slack',
          channelId: channel?['id'] as String? ?? 'unknown',
          conversationId: channel?['id'] as String? ?? 'unknown',
          tenantId: team?['id'] as String?,
          threadId: message?['thread_ts'] as String?,
        ),
        actionId: actionMap['action_id'] as String? ?? '',
        actionValue: actionMap['value'] as String?,
        targetMessageId: message?['ts'] as String?,
        rawPayload: interaction,
      );

      emitEvent(event.base);
    }
  }

  /// Handle a modal view submission.
  ///
  /// Parses the submission payload and emits an [ExtendedChannelEvent]
  /// with the submitted form values.
  void handleViewSubmission(Map<String, dynamic> interaction) {
    final user = interaction['user'] as Map<String, dynamic>?;
    final team = interaction['team'] as Map<String, dynamic>?;
    final view = interaction['view'] as Map<String, dynamic>? ?? {};
    final state = view['state'] as Map<String, dynamic>? ?? {};
    final values = _extractViewValues(
      state['values'] as Map<String, dynamic>? ?? {},
    );

    final privateMetadata = view['private_metadata'] as String? ?? '';
    final callbackId = view['callback_id'] as String? ?? '';

    final event = ExtendedChannelEvent.button(
      id: interaction['trigger_id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user?['id'] as String?,
      userName: user?['name'] as String?,
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'slack',
          channelId: privateMetadata.isNotEmpty ? privateMetadata : 'unknown',
        ),
        conversationId:
            privateMetadata.isNotEmpty ? privateMetadata : 'unknown',
        userId: user?['id'] as String?,
      ),
      extendedConversation: ExtendedConversationKey.create(
        platform: 'slack',
        channelId:
            privateMetadata.isNotEmpty ? privateMetadata : 'unknown',
        conversationId:
            privateMetadata.isNotEmpty ? privateMetadata : 'unknown',
        tenantId: team?['id'] as String?,
      ),
      actionId: callbackId,
      rawPayload: {
        ...interaction,
        'values': values,
      },
    );

    emitEvent(event.base);
  }

  // =========================================================================
  // Block Kit Translation
  // =========================================================================

  /// Translate platform-agnostic content blocks to Slack Block Kit format.
  List<Map<String, dynamic>> _translateBlocks(List<ContentBlock> blocks) {
    return blocks.map((block) {
      switch (block.type) {
        case ContentBlockType.section:
          return <String, dynamic>{
            'type': 'section',
            'text': {
              'type': 'mrkdwn',
              'text': block.content['text'],
            },
            if (block.content['accessory'] != null)
              'accessory': block.content['accessory'],
          };

        case ContentBlockType.divider:
          return <String, dynamic>{'type': 'divider'};

        case ContentBlockType.image:
          return <String, dynamic>{
            'type': 'image',
            'image_url': block.content['url'],
            'alt_text': block.content['altText'],
            if (block.content['title'] != null)
              'title': {
                'type': 'plain_text',
                'text': block.content['title'],
              },
          };

        case ContentBlockType.actions:
          final elements = block.content['elements'] as List<dynamic>? ?? [];
          return <String, dynamic>{
            'type': 'actions',
            'elements': _translateActions(elements),
          };

        case ContentBlockType.header:
          return <String, dynamic>{
            'type': 'header',
            'text': {
              'type': 'plain_text',
              'text': block.content['text'],
            },
          };

        case ContentBlockType.context:
          return <String, dynamic>{
            'type': 'context',
            'elements': block.content['elements'],
          };

        case ContentBlockType.input:
          return <String, dynamic>{
            'type': 'input',
            'label': {
              'type': 'plain_text',
              'text': block.content['label'],
            },
            'element': {
              'type': 'plain_text_input',
              'action_id': block.content['actionId'],
              if (block.content['placeholder'] != null)
                'placeholder': {
                  'type': 'plain_text',
                  'text': block.content['placeholder'],
                },
              'multiline': block.content['multiline'] ?? false,
            },
          };
      }
    }).toList();
  }

  /// Translate platform-agnostic action elements to Slack interactive format.
  List<Map<String, dynamic>> _translateActions(List<dynamic> elements) {
    return elements.map((e) {
      final element = e is ActionElement
          ? e
          : ActionElement.fromJson(e as Map<String, dynamic>);

      switch (element.type) {
        case ActionElementType.button:
          return <String, dynamic>{
            'type': 'button',
            'text': {
              'type': 'plain_text',
              'text': element.text ?? '',
            },
            'action_id': element.actionId,
            if (element.value != null) 'value': element.value,
            if (element.style != null) 'style': element.style,
            if (element.confirm != null)
              'confirm': {
                'title': {
                  'type': 'plain_text',
                  'text': element.confirm!.title,
                },
                'text': {
                  'type': 'mrkdwn',
                  'text': element.confirm!.text,
                },
                'confirm': {
                  'type': 'plain_text',
                  'text': element.confirm!.confirm,
                },
                'deny': {
                  'type': 'plain_text',
                  'text': element.confirm!.deny,
                },
              },
          };

        case ActionElementType.select:
          return <String, dynamic>{
            'type': 'static_select',
            'action_id': element.actionId,
            'placeholder': {
              'type': 'plain_text',
              'text': element.text ?? 'Select...',
            },
            if (element.options != null)
              'options': element.options!.map((o) {
                return {
                  'text': {'type': 'plain_text', 'text': o.text},
                  'value': o.value,
                };
              }).toList(),
          };

        case ActionElementType.datePicker:
          return <String, dynamic>{
            'type': 'datepicker',
            'action_id': element.actionId,
            if (element.text != null)
              'placeholder': {
                'type': 'plain_text',
                'text': element.text,
              },
            if (element.value != null) 'initial_date': element.value,
          };

        default:
          throw UnsupportedError(
            'Unknown action type: ${element.type}',
          );
      }
    }).toList();
  }

  // =========================================================================
  // Private: Connection management
  // =========================================================================

  Future<void> _startSocketMode() async {
    final url = await _getSocketModeUrl();
    _wsChannel = WebSocketChannel.connect(Uri.parse(url));
    await _wsChannel!.ready;

    _wsSubscription = _wsChannel!.stream.listen(
      (data) {
        final payload = jsonDecode(data as String) as Map<String, dynamic>;
        _handleSocketModePayload(payload);
      },
      onError: (Object error) {
        _log.severe('WebSocket error: $error');
        onDisconnected();
      },
      onDone: () {
        _log.info('WebSocket connection closed');
        onDisconnected();
      },
    );
  }

  Future<String> _getSocketModeUrl() async {
    final response = await _httpClient.post(
      Uri.parse('$_apiBase/apps.connections.open'),
      headers: {
        'Authorization': 'Bearer ${config.appToken}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] != true) {
      throw ConnectorException(
        'Failed to open Socket Mode connection: ${body['error']}',
        code: 'socket_mode_open_failed',
      );
    }

    return body['url'] as String;
  }

  void _handleSocketModePayload(Map<String, dynamic> payload) {
    final type = payload['type'] as String?;

    // Acknowledge envelope
    final envelopeId = payload['envelope_id'] as String?;
    if (envelopeId != null) {
      _wsChannel?.sink.add(jsonEncode({'envelope_id': envelopeId}));
    }

    switch (type) {
      case 'hello':
        _log.info('Socket Mode connected');
        break;
      case 'disconnect':
        _log.info('Socket Mode disconnect requested, reconnecting...');
        onDisconnected();
        break;
      case 'events_api':
        final eventPayload =
            payload['payload'] as Map<String, dynamic>? ?? {};
        final event = parseEvent(eventPayload);
        emitEvent(event);
        break;
      case 'interactive':
        final interactivePayload =
            payload['payload'] as Map<String, dynamic>? ?? {};
        final interactionType = interactivePayload['type'] as String?;
        if (interactionType == 'view_submission') {
          handleViewSubmission(interactivePayload);
        } else {
          handleBlockAction(interactivePayload);
        }
        break;
      case 'slash_commands':
        final commandPayload =
            payload['payload'] as Map<String, dynamic>? ?? {};
        final event = _parseCommandPayload(commandPayload);
        emitEvent(event);
        break;
    }
  }

  Future<void> _startHttpMode() async {
    // HTTP webhook mode is handled externally via handleWebhook()
    _log.info('Slack connector started in HTTP webhook mode');
  }

  /// Handle an incoming HTTP webhook request.
  ChannelEvent handleWebhook(Map<String, dynamic> payload) {
    return parseEvent(payload);
  }

  // =========================================================================
  // Private: API calls
  // =========================================================================

  /// Generic Slack API call helper.
  Future<Map<String, dynamic>> _apiCall(
    String method,
    Map<String, dynamic> params,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$_apiBase/$method'),
      headers: {
        'Authorization': 'Bearer ${config.botToken}',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(params),
    );

    if (response.statusCode == 429) {
      final retryAfter =
          int.tryParse(response.headers['retry-after'] ?? '') ?? 1;
      throw ChannelError.rateLimited(
        retryAfter: Duration(seconds: retryAfter),
        platformData: {'method': method},
      );
    }

    if (response.statusCode >= 500) {
      throw ChannelError.serverError(
        message: 'Slack API $method returned ${response.statusCode}',
        platformData: {'method': method, 'statusCode': response.statusCode},
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] != true) {
      final error = body['error'] as String? ?? 'unknown_error';
      throw ConnectorException(
        'Slack API $method failed: $error',
        code: error,
      );
    }

    return body;
  }

  Map<String, dynamic> _buildMessagePayload(ChannelResponse response) {
    final payload = <String, dynamic>{};

    if (response.text != null) {
      payload['text'] = response.text;
    }

    if (response.blocks != null) {
      payload['blocks'] = response.blocks;
    }

    if (response.replyTo != null) {
      payload['thread_ts'] = response.replyTo;
    }

    if (response.options != null) {
      // Copy options excluding ephemeral-specific keys handled separately
      final filteredOptions = Map<String, dynamic>.from(response.options!);
      filteredOptions.remove('ephemeral');
      filteredOptions.remove('ephemeralUserId');
      if (filteredOptions.isNotEmpty) {
        payload.addAll(filteredOptions);
      }
    }

    return payload;
  }

  Future<Map<String, dynamic>> _postMessage(
    String channel,
    Map<String, dynamic> payload,
  ) async {
    payload['channel'] = channel;
    return _apiCall('chat.postMessage', payload);
  }

  Future<void> _updateMessage(
    String channel,
    Map<String, dynamic> payload,
  ) async {
    payload['channel'] = channel;
    await _apiCall('chat.update', payload);
  }

  Future<Map<String, dynamic>> _uploadFile(
    String channel,
    String name,
    Uint8List data, {
    String? mimeType,
  }) async {
    // Step 1: Get upload URL
    final uploadUrlResult = await _apiCall('files.getUploadURLExternal', {
      'filename': name,
      'length': data.length,
    });

    final uploadUrl = uploadUrlResult['upload_url'] as String;
    final fileId = uploadUrlResult['file_id'] as String;

    // Step 2: Upload file content
    final uploadRequest = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    uploadRequest.files.add(http.MultipartFile.fromBytes(
      'file',
      data,
      filename: name,
    ));
    final uploadResponse = await _httpClient.send(uploadRequest);
    if (uploadResponse.statusCode != 200) {
      throw ConnectorException(
        'File upload failed with status ${uploadResponse.statusCode}',
        code: 'file_upload_failed',
      );
    }

    // Step 3: Complete upload
    await _apiCall('files.completeUploadExternal', {
      'files': [
        {'id': fileId, 'title': name}
      ],
      'channel_id': channel,
    });

    return {
      'id': fileId,
      'url_private': uploadUrlResult['url_private'] as String?,
    };
  }

  Future<Uint8List?> _downloadFile(String fileId) async {
    // Get file info to obtain the download URL
    final result = await _apiCall('files.info', {'file': fileId});
    final file = result['file'] as Map<String, dynamic>;
    final url = file['url_private_download'] as String? ??
        file['url_private'] as String?;

    if (url == null) return null;

    // Download with authentication
    final response = await _httpClient.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer ${config.botToken}',
      },
    );

    if (response.statusCode != 200) return null;

    return response.bodyBytes;
  }

  bool _isRetryableError(Object error) {
    if (error is ChannelError) {
      return error.retryable;
    }
    if (error is http.ClientException) {
      return true;
    }
    return false;
  }

  // =========================================================================
  // Private: View submission helpers
  // =========================================================================

  /// Extract form values from a view submission state.
  Map<String, dynamic> _extractViewValues(Map<String, dynamic> values) {
    final extracted = <String, dynamic>{};
    for (final blockEntry in values.entries) {
      final blockActions = blockEntry.value as Map<String, dynamic>? ?? {};
      for (final actionEntry in blockActions.entries) {
        final actionData = actionEntry.value as Map<String, dynamic>? ?? {};
        final actionType = actionData['type'] as String?;
        switch (actionType) {
          case 'plain_text_input':
            extracted[actionEntry.key] = actionData['value'];
            break;
          case 'static_select':
          case 'external_select':
          case 'users_select':
          case 'conversations_select':
          case 'channels_select':
            final selected =
                actionData['selected_option'] as Map<String, dynamic>?;
            extracted[actionEntry.key] = selected?['value'];
            break;
          case 'multi_static_select':
          case 'multi_external_select':
          case 'multi_users_select':
          case 'multi_conversations_select':
          case 'multi_channels_select':
            final selected =
                actionData['selected_options'] as List<dynamic>? ?? [];
            extracted[actionEntry.key] = selected
                .map((o) =>
                    (o as Map<String, dynamic>)['value'] as String?)
                .toList();
            break;
          case 'datepicker':
            extracted[actionEntry.key] = actionData['selected_date'];
            break;
          case 'timepicker':
            extracted[actionEntry.key] = actionData['selected_time'];
            break;
          case 'checkboxes':
            final selected =
                actionData['selected_options'] as List<dynamic>? ?? [];
            extracted[actionEntry.key] = selected
                .map((o) =>
                    (o as Map<String, dynamic>)['value'] as String?)
                .toList();
            break;
          case 'radio_buttons':
            final selected =
                actionData['selected_option'] as Map<String, dynamic>?;
            extracted[actionEntry.key] = selected?['value'];
            break;
          default:
            extracted[actionEntry.key] = actionData['value'];
        }
      }
    }
    return extracted;
  }

  // =========================================================================
  // Event parsing
  // =========================================================================

  /// Parse incoming Slack event to ChannelEvent.
  ChannelEvent parseEvent(Map<String, dynamic> payload) {
    final eventData = payload['event'] as Map<String, dynamic>?;

    if (eventData == null) {
      return _parseUnknownEvent(payload);
    }

    final eventType = eventData['type'] as String?;
    final subtype = eventData['subtype'] as String?;

    switch (eventType) {
      case 'message':
        if (subtype == 'file_share') {
          return _parseFileEvent(eventData);
        }
        return _parseMessageEvent(eventData);

      case 'app_mention':
        return _parseMentionEvent(eventData);

      case 'reaction_added':
        return _parseReactionEvent(eventData);

      case 'member_joined_channel':
        return _parseJoinEvent(eventData);

      case 'member_left_channel':
        return _parseLeaveEvent(eventData);

      default:
        return _parseUnknownEvent(eventData);
    }
  }

  ChannelEvent _parseCommandPayload(Map<String, dynamic> payload) {
    final team = payload['team_id'] as String? ?? 'unknown';
    final command = (payload['command'] as String? ?? '').replaceFirst('/', '');
    final text = payload['text'] as String? ?? '';

    return ChannelEvent(
      id: payload['trigger_id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'slack',
          channelId: team,
        ),
        conversationId: payload['channel_id'] as String? ?? 'unknown',
        userId: payload['user_id'] as String?,
      ),
      type: 'command',
      text: '/$command $text'.trim(),
      userId: payload['user_id'] as String?,
      userName: payload['user_name'] as String?,
      timestamp: DateTime.now(),
      metadata: {
        ...payload,
        'command': command,
        'command_args': text.split(' ').where((s) => s.isNotEmpty).toList(),
      },
    );
  }

  ChannelEvent _parseMessageEvent(Map<String, dynamic> event) {
    return ChannelEvent.message(
      id: '${event['team']}_${event['ts']}',
      conversation: _parseConversation(event),
      text: event['text'] as String? ?? '',
      userId: event['user'] as String?,
      userName: event['user'] as String?,
      timestamp: _parseTimestamp(event['ts']),
      metadata: event,
    );
  }

  ChannelEvent _parseMentionEvent(Map<String, dynamic> event) {
    return ChannelEvent(
      id: '${event['team']}_${event['ts']}',
      conversation: _parseConversation(event),
      type: 'mention',
      text: event['text'] as String? ?? '',
      userId: event['user'] as String?,
      userName: event['user'] as String?,
      timestamp: _parseTimestamp(event['ts']),
      metadata: event,
    );
  }

  ChannelEvent _parseFileEvent(Map<String, dynamic> event) {
    final file = event['files']?[0] as Map<String, dynamic>?;
    return ChannelEvent(
      id: '${event['team']}_${event['ts']}',
      conversation: _parseConversation(event),
      type: 'file',
      text: event['text'] as String?,
      userId: event['user'] as String?,
      userName: event['user'] as String?,
      timestamp: _parseTimestamp(event['ts']),
      attachments: file != null
          ? [
              ChannelAttachment(
                type: 'file',
                url: file['url_private'] as String? ?? '',
                filename: file['name'] as String?,
                mimeType: file['mimetype'] as String?,
                size: file['size'] as int?,
              )
            ]
          : null,
      metadata: event,
    );
  }

  ChannelEvent _parseReactionEvent(Map<String, dynamic> event) {
    return ChannelEvent(
      id: event['event_ts'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'slack',
          channelId: event['team'] as String? ?? 'unknown',
        ),
        conversationId: event['item']?['channel'] as String? ?? 'unknown',
      ),
      type: 'reaction',
      text: event['reaction'] as String?,
      userId: event['user'] as String?,
      userName: event['user'] as String?,
      timestamp: _parseTimestamp(event['event_ts']),
      metadata: {
        ...event,
        'target_message_id': event['item']?['ts'] as String?,
      },
    );
  }

  ChannelEvent _parseJoinEvent(Map<String, dynamic> event) {
    return ChannelEvent(
      id: event['event_ts'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'slack',
          channelId: event['team'] as String? ?? 'unknown',
        ),
        conversationId: event['channel'] as String? ?? 'unknown',
      ),
      type: 'join',
      userId: event['user'] as String?,
      userName: event['user'] as String?,
      timestamp: _parseTimestamp(event['event_ts']),
      metadata: event,
    );
  }

  ChannelEvent _parseLeaveEvent(Map<String, dynamic> event) {
    return ChannelEvent(
      id: event['event_ts'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'slack',
          channelId: event['team'] as String? ?? 'unknown',
        ),
        conversationId: event['channel'] as String? ?? 'unknown',
      ),
      type: 'leave',
      userId: event['user'] as String?,
      userName: event['user'] as String?,
      timestamp: _parseTimestamp(event['event_ts']),
      metadata: event,
    );
  }

  ChannelEvent _parseUnknownEvent(Map<String, dynamic> event) {
    return ChannelEvent(
      id: event['event_ts'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      conversation: _parseConversation(event),
      type: 'unknown',
      userId: event['user'] as String?,
      userName: event['user'] as String?,
      timestamp: DateTime.now(),
      metadata: event,
    );
  }

  ConversationKey _parseConversation(Map<String, dynamic> event) {
    return ConversationKey(
      channel: ChannelIdentity(
        platform: 'slack',
        channelId: event['team'] as String? ?? 'unknown',
      ),
      conversationId: event['channel'] as String? ?? 'unknown',
      userId: event['user'] as String?,
    );
  }

  DateTime _parseTimestamp(dynamic ts) {
    if (ts == null) return DateTime.now();
    if (ts is String) {
      // Slack timestamps are in format "1234567890.123456"
      final parts = ts.split('.');
      if (parts.isNotEmpty) {
        final seconds = int.tryParse(parts[0]);
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }
    return DateTime.now();
  }
}
