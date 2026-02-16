import 'dart:typed_data';

import '../../core/policy/channel_policy.dart';
import '../../core/port/channel_capabilities.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/send_result.dart';
import '../../core/types/channel_event.dart';
import '../../core/types/channel_identity.dart';
import '../../core/types/channel_response.dart';
import '../../core/types/conversation_key.dart';
import '../../core/types/file_info.dart';
import '../base_connector.dart';
import 'slack_config.dart';

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
  @override
  final SlackConfig config;

  @override
  final ChannelPolicy policy;

  @override
  final String channelType = 'slack';

  @override
  final ChannelCapabilities capabilities = ChannelCapabilities.slack();

  SlackConnector({
    required this.config,
    ChannelPolicy? policy,
  }) : policy = policy ?? ChannelPolicy.slack();

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
    // Close socket connection or HTTP server
    // Implementation depends on actual Slack SDK integration
  }

  @override
  Future<SendResult> send(ChannelResponse response) async {
    // Validate response
    if (response.text == null && response.blocks == null) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.invalidRequest,
          message: 'Response must have text or blocks',
        ),
      );
    }

    try {
      // Build Slack message payload
      final payload = _buildMessagePayload(response);

      // Send via Slack API
      final result = await _postMessage(
        response.conversation.roomId,
        payload,
        threadTs: response.conversation.threadId,
      );

      return SendResult.success(
        messageId: result['ts'] as String,
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
  Future<ChannelIdentity?> getIdentity(String userId) async {
    try {
      final userInfo = await _getUserInfo(userId);
      if (userInfo == null) return null;

      final isBot = userInfo['is_bot'] as bool? ?? false;
      if (isBot) {
        return ChannelIdentity.bot(
          id: userId,
          displayName: userInfo['real_name'] as String? ??
              userInfo['name'] as String? ??
              userId,
        );
      }

      return ChannelIdentity.user(
        id: userId,
        displayName: userInfo['real_name'] as String? ??
            userInfo['name'] as String? ??
            userId,
        username: userInfo['name'] as String?,
        avatarUrl: userInfo['profile']?['image_72'] as String?,
        email: userInfo['profile']?['email'] as String?,
      );
    } catch (e) {
      return null;
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
      final result = await _uploadFile(
        conversation.roomId,
        name,
        data,
        mimeType: mimeType,
        threadTs: conversation.threadId,
      );

      return FileInfo(
        id: result['id'] as String,
        name: name,
        mimeType: mimeType ?? 'application/octet-stream',
        size: data.length,
        url: result['url_private'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Uint8List?> downloadFile(String fileId) async {
    try {
      return await _downloadFile(fileId);
    } catch (e) {
      return null;
    }
  }

  // Platform-specific methods

  Future<void> _startSocketMode() async {
    // Socket Mode implementation
    // This would use Slack's Socket Mode API for real-time events
    // Placeholder for actual implementation
  }

  Future<void> _startHttpMode() async {
    // HTTP webhook mode implementation
    // This would set up an HTTP server to receive events
    // Placeholder for actual implementation
  }

  Map<String, dynamic> _buildMessagePayload(ChannelResponse response) {
    final payload = <String, dynamic>{};

    if (response.text != null) {
      payload['text'] = response.text;
    }

    if (response.blocks != null) {
      payload['blocks'] = response.blocks!.map((b) => b.toJson()).toList();
    }

    if (response.replyTo != null) {
      payload['thread_ts'] = response.replyTo;
    }

    if (response.metadata != null) {
      payload['metadata'] = response.metadata;
    }

    return payload;
  }

  Future<Map<String, dynamic>> _postMessage(
    String channel,
    Map<String, dynamic> payload, {
    String? threadTs,
  }) async {
    // Slack API call implementation
    // This would use chat.postMessage or chat.postEphemeral
    // Placeholder for actual implementation
    return {'ts': DateTime.now().millisecondsSinceEpoch.toString()};
  }

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    // Slack API call to users.info
    // Placeholder for actual implementation
    return null;
  }

  Future<Map<String, dynamic>> _uploadFile(
    String channel,
    String name,
    Uint8List data, {
    String? mimeType,
    String? threadTs,
  }) async {
    // Slack API call to files.upload
    // Placeholder for actual implementation
    return {'id': 'F${DateTime.now().millisecondsSinceEpoch}'};
  }

  Future<Uint8List?> _downloadFile(String fileId) async {
    // Slack API call to download file
    // Placeholder for actual implementation
    return null;
  }

  bool _isRetryableError(Object error) {
    // Check if error is retryable (rate limit, temporary failure, etc.)
    return false;
  }

  /// Parse incoming Slack event to ChannelEvent.
  ChannelEvent parseEvent(Map<String, dynamic> payload) {
    final eventType = payload['type'] as String?;
    final event = payload['event'] as Map<String, dynamic>?;

    if (event == null) {
      return _parseUnknownEvent(payload);
    }

    final subtype = event['subtype'] as String?;

    switch (eventType) {
      case 'message':
        if (subtype == 'file_share') {
          return _parseFileEvent(event);
        }
        return _parseMessageEvent(event);

      case 'app_mention':
        return _parseMentionEvent(event);

      case 'reaction_added':
        return _parseReactionEvent(event);

      case 'member_joined_channel':
        return _parseJoinEvent(event);

      case 'member_left_channel':
        return _parseLeaveEvent(event);

      default:
        return _parseUnknownEvent(event);
    }
  }

  ChannelEvent _parseMessageEvent(Map<String, dynamic> event) {
    return ChannelEvent.message(
      eventId: '${event['team']}_${event['ts']}',
      channelType: channelType,
      identity: _parseIdentity(event),
      conversation: _parseConversation(event),
      text: event['text'] as String? ?? '',
      replyTo: event['thread_ts'] as String?,
      rawPayload: event,
    );
  }

  ChannelEvent _parseMentionEvent(Map<String, dynamic> event) {
    return ChannelEvent.mention(
      eventId: '${event['team']}_${event['ts']}',
      channelType: channelType,
      identity: _parseIdentity(event),
      conversation: _parseConversation(event),
      text: event['text'] as String? ?? '',
      rawPayload: event,
    );
  }

  ChannelEvent _parseFileEvent(Map<String, dynamic> event) {
    final file = event['files']?[0] as Map<String, dynamic>?;
    return ChannelEvent.file(
      eventId: '${event['team']}_${event['ts']}',
      channelType: channelType,
      identity: _parseIdentity(event),
      conversation: _parseConversation(event),
      file: file != null ? _parseFileInfo(file) : _emptyFileInfo(),
      text: event['text'] as String?,
      rawPayload: event,
    );
  }

  ChannelEvent _parseReactionEvent(Map<String, dynamic> event) {
    return ChannelEvent.reaction(
      eventId: '${event['event_ts']}',
      channelType: channelType,
      identity: ChannelIdentity.user(
        id: event['user'] as String,
        displayName: event['user'] as String,
      ),
      conversation: ConversationKey(
        channelType: channelType,
        tenantId: event['team'] as String? ?? 'unknown',
        roomId: event['item']?['channel'] as String? ?? 'unknown',
      ),
      reaction: event['reaction'] as String? ?? '',
      targetMessageId: event['item']?['ts'] as String? ?? '',
      rawPayload: event,
    );
  }

  ChannelEvent _parseJoinEvent(Map<String, dynamic> event) {
    return ChannelEvent.join(
      eventId: '${event['event_ts']}',
      channelType: channelType,
      identity: ChannelIdentity.user(
        id: event['user'] as String,
        displayName: event['user'] as String,
      ),
      conversation: ConversationKey(
        channelType: channelType,
        tenantId: event['team'] as String? ?? 'unknown',
        roomId: event['channel'] as String? ?? 'unknown',
      ),
      rawPayload: event,
    );
  }

  ChannelEvent _parseLeaveEvent(Map<String, dynamic> event) {
    return ChannelEvent.leave(
      eventId: '${event['event_ts']}',
      channelType: channelType,
      identity: ChannelIdentity.user(
        id: event['user'] as String,
        displayName: event['user'] as String,
      ),
      conversation: ConversationKey(
        channelType: channelType,
        tenantId: event['team'] as String? ?? 'unknown',
        roomId: event['channel'] as String? ?? 'unknown',
      ),
      rawPayload: event,
    );
  }

  ChannelEvent _parseUnknownEvent(Map<String, dynamic> event) {
    return ChannelEvent(
      eventId: event['event_ts'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChannelEventType.unknown,
      channelType: channelType,
      identity: _parseIdentity(event),
      conversation: _parseConversation(event),
      timestamp: DateTime.now(),
      rawPayload: event,
    );
  }

  ChannelIdentity _parseIdentity(Map<String, dynamic> event) {
    final userId = event['user'] as String? ?? 'unknown';
    return ChannelIdentity.user(
      id: userId,
      displayName: userId,
    );
  }

  ConversationKey _parseConversation(Map<String, dynamic> event) {
    return ConversationKey(
      channelType: channelType,
      tenantId: event['team'] as String? ?? 'unknown',
      roomId: event['channel'] as String? ?? 'unknown',
      threadId: event['thread_ts'] as String?,
    );
  }

  FileInfo _parseFileInfo(Map<String, dynamic> file) {
    return FileInfo(
      id: file['id'] as String,
      name: file['name'] as String? ?? 'unknown',
      mimeType: file['mimetype'] as String? ?? 'application/octet-stream',
      size: file['size'] as int? ?? 0,
      url: file['url_private'] as String?,
    );
  }

  FileInfo _emptyFileInfo() {
    return const FileInfo(
      id: 'unknown',
      name: 'unknown',
      mimeType: 'application/octet-stream',
      size: 0,
    );
  }
}
