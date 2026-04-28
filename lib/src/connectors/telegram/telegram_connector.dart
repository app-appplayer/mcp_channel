import 'dart:async' show unawaited;
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
import 'telegram_config.dart';

final _log = Logger('TelegramConnector');

/// Telegram Bot API connector.
///
/// Supports long polling and webhook modes for receiving updates,
/// and the Bot API for sending messages.
class TelegramConnector extends BaseConnector {
  TelegramConnector({
    required this.config,
    ChannelPolicy? policy,
    http.Client? httpClient,
  })  : policy = policy ?? ChannelPolicy.telegram(),
        _httpClient = httpClient ?? http.Client();

  @override
  final TelegramConfig config;

  @override
  final ChannelPolicy policy;

  final http.Client _httpClient;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.telegram();

  String get _apiBase => '${config.apiBaseUrl}/bot${config.botToken}';

  int _lastUpdateId = 0;
  bool _polling = false;

  @override
  String get channelType => 'telegram';

  @override
  ChannelIdentity get identity => const ChannelIdentity(
        platform: 'telegram',
        channelId: 'bot',
        displayName: 'Telegram Bot',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connecting);

    try {
      if (config.webhookUrl != null) {
        await _setupWebhook();
      } else {
        await _startPolling();
      }
      onConnected();
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  @override
  Future<void> doStop() async {
    _polling = false;
    if (config.webhookUrl != null) {
      await _apiCall('deleteWebhook', {});
    }
  }

  @override
  Future<void> send(ChannelResponse response) async {
    final chatId = response.conversation.conversationId;

    if (response.text != null) {
      await _apiCall('sendMessage', {
        'chat_id': chatId,
        'text': response.text,
        if (response.replyTo != null)
          'reply_parameters': {'message_id': int.tryParse(response.replyTo!)},
        if (response.blocks != null)
          'reply_markup': _buildReplyMarkup(response.blocks!),
      });
    }
  }

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    try {
      final chatId = response.conversation.conversationId;
      final params = <String, dynamic>{
        'chat_id': chatId,
        'text': response.text ?? '',
        if (response.replyTo != null)
          'reply_parameters': {'message_id': int.tryParse(response.replyTo!)},
        if (response.blocks != null)
          'reply_markup': _buildReplyMarkup(response.blocks!),
      };

      final result = await _apiCall('sendMessage', params);
      final messageResult = result['result'] as Map<String, dynamic>? ?? {};

      return SendResult.success(
        messageId: messageResult['message_id']?.toString() ?? '',
        platformData: messageResult,
      );
    } catch (e) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.serverError,
          message: 'Failed to send Telegram message: $e',
          retryable: _isRetryableError(e),
        ),
      );
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    await _apiCall('sendChatAction', {
      'chat_id': conversation.conversationId,
      'action': 'typing',
    });
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    await _apiCall('editMessageText', {
      'chat_id': response.conversation.conversationId,
      'message_id': int.tryParse(messageId),
      'text': response.text ?? '',
      if (response.blocks != null)
        'reply_markup': _buildReplyMarkup(response.blocks!),
    });
  }

  @override
  Future<void> delete(String messageId) async {
    // messageId format: "chatId:messageId"
    final parts = messageId.split(':');
    if (parts.length == 2) {
      await _apiCall('deleteMessage', {
        'chat_id': parts[0],
        'message_id': int.tryParse(parts[1]),
      });
    }
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    final parts = messageId.split(':');
    if (parts.length == 2) {
      await _apiCall('setMessageReaction', {
        'chat_id': parts[0],
        'message_id': int.tryParse(parts[1]),
        'reaction': [
          {'type': 'emoji', 'emoji': reaction}
        ],
      });
    }
  }

  @override
  Future<FileInfo?> uploadFile({
    required ConversationKey conversation,
    required String name,
    required Uint8List data,
    String? mimeType,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiBase/sendDocument'),
      );
      request.fields['chat_id'] = conversation.conversationId;
      request.files.add(http.MultipartFile.fromBytes(
        'document',
        data,
        filename: name,
      ));

      final response = await _httpClient.send(request);
      final body =
          jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;

      if (body['ok'] == true) {
        final result = body['result'] as Map<String, dynamic>;
        final doc = result['document'] as Map<String, dynamic>? ?? {};
        return FileInfo(
          id: doc['file_id'] as String? ?? '',
          name: name,
          mimeType: mimeType ?? doc['mime_type'] as String? ?? 'application/octet-stream',
          size: data.length,
        );
      }
      return null;
    } catch (e) {
      _log.warning('File upload failed: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> downloadFile(String fileId) async {
    try {
      final result = await _apiCall('getFile', {'file_id': fileId});
      final filePath =
          (result['result'] as Map<String, dynamic>)['file_path'] as String?;
      if (filePath == null) return null;

      final response = await _httpClient.get(
        Uri.parse('${config.apiBaseUrl}/file/bot${config.botToken}/$filePath'),
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
      final result = await _apiCall('getChat', {'chat_id': userId});
      final chat = result['result'] as Map<String, dynamic>? ?? {};

      return ChannelIdentityInfo.user(
        id: userId,
        displayName: chat['first_name'] as String?,
        username: chat['username'] as String?,
        avatarUrl: null, // Requires getFile on photo
        platformData: chat,
      );
    } catch (e) {
      _log.warning('Failed to get identity for $userId: $e');
      return null;
    }
  }

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) async {
    try {
      final result =
          await _apiCall('getChat', {'chat_id': key.conversationId});
      final chat = result['result'] as Map<String, dynamic>? ?? {};
      final chatType = chat['type'] as String? ?? 'private';

      return ConversationInfo(
        key: key,
        name: chat['title'] as String? ?? chat['first_name'] as String?,
        topic: chat['description'] as String?,
        isPrivate: chatType == 'private',
        isGroup: chatType == 'group' || chatType == 'supergroup',
        platformData: chat,
      );
    } catch (e) {
      _log.warning('Failed to get conversation info: $e');
      return null;
    }
  }

  /// Handle an incoming webhook update.
  ///
  /// If [headers] is provided and [TelegramConfig.webhookSecret] is set,
  /// validates the `x-telegram-bot-api-secret-token` header before processing.
  /// Throws [ChannelError] with [ChannelErrorCode.permissionDenied] if the
  /// secret token does not match.
  ChannelEvent handleWebhookUpdate(
    Map<String, dynamic> update, {
    Map<String, String>? headers,
  }) {
    // Verify webhook secret token if configured
    if (config.webhookSecret != null) {
      final token = headers?['x-telegram-bot-api-secret-token'];
      if (token != config.webhookSecret) {
        throw ChannelError.permissionDenied(
          message: 'Invalid webhook secret token',
        );
      }
    }

    return _parseUpdate(update);
  }

  // =========================================================================
  // Private: Polling & webhook
  // =========================================================================

  Future<void> _startPolling() async {
    _polling = true;
    // Delete any existing webhook
    await _apiCall('deleteWebhook', {});
    unawaited(_pollLoop());
  }

  Future<void> _pollLoop() async {
    while (_polling) {
      try {
        final result = await _apiCall('getUpdates', {
          'offset': _lastUpdateId + 1,
          'timeout': config.pollingTimeout,
          'allowed_updates': config.allowedUpdates,
        });

        final updates = result['result'] as List<dynamic>? ?? [];
        for (final update in updates) {
          final updateMap = update as Map<String, dynamic>;
          _lastUpdateId = updateMap['update_id'] as int;
          final event = _parseUpdate(updateMap);
          emitEvent(event);
        }
      } catch (e) {
        _log.warning('Polling error: $e');
        if (_polling) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  Future<void> _setupWebhook() async {
    await _apiCall('setWebhook', {
      'url': config.webhookUrl,
      if (config.webhookSecret != null) 'secret_token': config.webhookSecret,
      'allowed_updates': config.allowedUpdates,
    });
    _log.info('Webhook set to ${config.webhookUrl}');
  }

  // =========================================================================
  // Private: API calls
  // =========================================================================

  Future<Map<String, dynamic>> _apiCall(
    String method,
    Map<String, dynamic> params,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$_apiBase/$method'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body['ok'] != true) {
      final errorCode = body['error_code'] as int? ?? response.statusCode;
      final description =
          body['description'] as String? ?? 'Unknown Telegram API error';
      throw _translateTelegramError(errorCode, description, body);
    }

    return body;
  }

  /// Translate Telegram HTTP error codes to [ChannelError].
  ///
  /// Mapping based on Telegram Bot API error codes:
  /// - 400: Bad request (invalid request)
  /// - 401: Unauthorized (permission denied)
  /// - 403: Forbidden (permission denied)
  /// - 404: Not found
  /// - 409: Conflict (invalid request)
  /// - 429: Too many requests (rate limited, retryable)
  /// - 500+: Server error (retryable)
  ChannelError _translateTelegramError(
    int errorCode,
    String description,
    Map<String, dynamic> body,
  ) {
    final platformData = <String, dynamic>{'telegramErrorCode': errorCode};

    switch (errorCode) {
      case 400:
        return ChannelError.invalidRequest(
          message: description,
          platformData: platformData,
        );
      case 401:
      case 403:
        return ChannelError.permissionDenied(
          message: description,
          platformData: platformData,
        );
      case 404:
        return ChannelError.notFound(
          message: description,
          platformData: platformData,
        );
      case 409:
        return ChannelError.invalidRequest(
          message: description,
          platformData: platformData,
        );
      case 429:
        final retryAfter =
            body['parameters']?['retry_after'] as int? ?? 1;
        return ChannelError.rateLimited(
          message: description,
          retryAfter: Duration(seconds: retryAfter),
          platformData: platformData,
        );
      default:
        if (errorCode >= 500) {
          return ChannelError.serverError(
            message: description,
            platformData: platformData,
          );
        }
        return ChannelError.unknown(
          message: description,
          platformData: platformData,
        );
    }
  }

  Map<String, dynamic>? _buildReplyMarkup(
      List<Map<String, dynamic>> blocks) {
    // Convert blocks to Telegram InlineKeyboardMarkup
    final rows = <List<Map<String, dynamic>>>[];
    for (final block in blocks) {
      if (block['type'] == 'actions') {
        final elements = block['elements'] as List<dynamic>? ?? [];
        final row = <Map<String, dynamic>>[];
        for (final el in elements) {
          final element = el as Map<String, dynamic>;
          row.add({
            'text': element['text'] ?? element['actionId'] ?? '',
            'callback_data': element['value'] ?? element['actionId'] ?? '',
            if (element['url'] != null) 'url': element['url'],
          });
        }
        if (row.isNotEmpty) rows.add(row);
      }
    }
    if (rows.isEmpty) return null;
    return {'inline_keyboard': rows};
  }

  // =========================================================================
  // Event parsing
  // =========================================================================

  ChannelEvent _parseUpdate(Map<String, dynamic> update) {
    if (update.containsKey('message')) {
      return _parseMessageUpdate(
          update['message'] as Map<String, dynamic>, update);
    }
    if (update.containsKey('edited_message')) {
      return _parseMessageUpdate(
          update['edited_message'] as Map<String, dynamic>, update);
    }
    if (update.containsKey('callback_query')) {
      return _parseCallbackQuery(
          update['callback_query'] as Map<String, dynamic>, update);
    }
    return _parseUnknownUpdate(update);
  }

  ChannelEvent _parseMessageUpdate(
      Map<String, dynamic> message, Map<String, dynamic> update) {
    final chat = message['chat'] as Map<String, dynamic>? ?? {};
    final from = message['from'] as Map<String, dynamic>? ?? {};
    final chatId = chat['id']?.toString() ?? 'unknown';
    final messageId = message['message_id']?.toString() ?? '';
    final updateId = update['update_id'];

    // Check if it's a command
    final entities = message['entities'] as List<dynamic>?;
    final isCommand = entities?.any((e) =>
            (e as Map<String, dynamic>)['type'] == 'bot_command' &&
            e['offset'] == 0) ??
        false;

    final text = message['text'] as String? ?? '';
    final type = isCommand ? 'command' : 'message';

    return ChannelEvent(
      id: '${updateId}_$messageId',
      conversation: ConversationKey(
        channel: const ChannelIdentity(
          platform: 'telegram',
          channelId: 'bot',
        ),
        conversationId: chatId,
        userId: from['id']?.toString(),
      ),
      type: type,
      text: text,
      userId: from['id']?.toString(),
      userName: from['first_name'] as String? ?? from['username'] as String?,
      timestamp: message['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (message['date'] as int) * 1000)
          : DateTime.now(),
      attachments: _parseAttachments(message),
      metadata: {
        ...update,
        if (isCommand) 'command': text.split(' ').first.replaceFirst('/', ''),
        if (isCommand)
          'command_args': text
              .split(' ')
              .skip(1)
              .where((s) => s.isNotEmpty)
              .toList(),
        'message_id': messageId,
      },
    );
  }

  ChannelEvent _parseCallbackQuery(
      Map<String, dynamic> query, Map<String, dynamic> update) {
    final from = query['from'] as Map<String, dynamic>? ?? {};
    final message = query['message'] as Map<String, dynamic>?;
    final chat = message?['chat'] as Map<String, dynamic>? ?? {};
    final updateId = update['update_id'];
    final messageId = message?['message_id'] ?? updateId;

    return ChannelEvent(
      id: '${updateId}_$messageId',
      conversation: ConversationKey(
        channel: const ChannelIdentity(
          platform: 'telegram',
          channelId: 'bot',
        ),
        conversationId: chat['id']?.toString() ?? 'unknown',
        userId: from['id']?.toString(),
      ),
      type: 'button',
      text: query['data'] as String?,
      userId: from['id']?.toString(),
      userName: from['first_name'] as String?,
      timestamp: DateTime.now(),
      metadata: {
        ...update,
        'callback_query_id': query['id'],
        'action_value': query['data'],
        'target_message_id': message?['message_id']?.toString(),
      },
    );
  }

  ChannelEvent _parseUnknownUpdate(Map<String, dynamic> update) {
    final updateId = update['update_id'] ?? DateTime.now().millisecondsSinceEpoch;
    return ChannelEvent(
      id: '${updateId}_$updateId',
      conversation: const ConversationKey(
        channel: ChannelIdentity(platform: 'telegram', channelId: 'bot'),
        conversationId: 'unknown',
      ),
      type: 'unknown',
      timestamp: DateTime.now(),
      metadata: update,
    );
  }

  List<ChannelAttachment>? _parseAttachments(Map<String, dynamic> message) {
    final attachments = <ChannelAttachment>[];

    if (message.containsKey('photo')) {
      final photos = message['photo'] as List<dynamic>;
      if (photos.isNotEmpty) {
        final largest = photos.last as Map<String, dynamic>;
        attachments.add(ChannelAttachment(
          type: 'image',
          url: largest['file_id'] as String,
          size: largest['file_size'] as int?,
        ));
      }
    }

    if (message.containsKey('document')) {
      final doc = message['document'] as Map<String, dynamic>;
      attachments.add(ChannelAttachment(
        type: 'file',
        url: doc['file_id'] as String,
        filename: doc['file_name'] as String?,
        mimeType: doc['mime_type'] as String?,
        size: doc['file_size'] as int?,
      ));
    }

    if (message.containsKey('audio')) {
      final audio = message['audio'] as Map<String, dynamic>;
      attachments.add(ChannelAttachment(
        type: 'audio',
        url: audio['file_id'] as String,
        filename: audio['file_name'] as String?,
        mimeType: audio['mime_type'] as String?,
        size: audio['file_size'] as int?,
      ));
    }

    if (message.containsKey('video')) {
      final video = message['video'] as Map<String, dynamic>;
      attachments.add(ChannelAttachment(
        type: 'video',
        url: video['file_id'] as String,
        filename: video['file_name'] as String?,
        mimeType: video['mime_type'] as String?,
        size: video['file_size'] as int?,
      ));
    }

    return attachments.isEmpty ? null : attachments;
  }

  bool _isRetryableError(Object error) {
    if (error is ChannelError) return error.retryable;
    if (error is http.ClientException) return true;
    return false;
  }
}
