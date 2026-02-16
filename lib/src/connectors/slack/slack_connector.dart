import 'dart:typed_data';

import 'package:mcp_bundle/ports.dart';

import '../../core/policy/channel_policy.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/extended_channel_capabilities.dart';
import '../../core/port/send_result.dart';
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
  SlackConnector({
    required this.config,
    ChannelPolicy? policy,
  }) : policy = policy ?? ChannelPolicy.slack();

  @override
  final SlackConfig config;

  @override
  final ChannelPolicy policy;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.slack();

  @override
  String get channelType => 'slack';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'slack',
        channelId: config.workspaceId ?? 'default',
        displayName: 'Slack Connector',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities.toBase();

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
    // Close socket connection or HTTP server
    // Implementation depends on actual Slack SDK integration
  }

  @override
  Future<void> send(ChannelResponse response) async {
    // Validate response
    if (response.text == null && response.blocks == null) {
      throw ArgumentError('Response must have text or blocks');
    }

    // Build Slack message payload
    final payload = _buildMessagePayload(response);

    // Send via Slack API
    await _postMessage(
      response.conversation.conversationId,
      payload,
    );
  }

  /// Send with result wrapper.
  Future<SendResult> sendWithResult(ChannelResponse response) async {
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
        response.conversation.conversationId,
        payload,
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
  Future<void> sendTyping(ConversationKey conversation) async {
    // Slack doesn't have a built-in typing indicator API for bots
    // This is a no-op
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    // Use chat.update API
    final payload = _buildMessagePayload(response);
    payload['ts'] = messageId;
    await _updateMessage(response.conversation.conversationId, payload);
  }

  @override
  Future<void> delete(String messageId) async {
    // Use chat.delete API
    // Placeholder for actual implementation
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    // Use reactions.add API
    // Placeholder for actual implementation
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
      payload['blocks'] = response.blocks;
    }

    if (response.replyTo != null) {
      payload['thread_ts'] = response.replyTo;
    }

    if (response.options != null) {
      payload.addAll(response.options!);
    }

    return payload;
  }

  Future<Map<String, dynamic>> _postMessage(
    String channel,
    Map<String, dynamic> payload,
  ) async {
    // Slack API call implementation
    // This would use chat.postMessage or chat.postEphemeral
    // Placeholder for actual implementation
    return {'ts': DateTime.now().millisecondsSinceEpoch.toString()};
  }

  Future<void> _updateMessage(
    String channel,
    Map<String, dynamic> payload,
  ) async {
    // Slack API call to chat.update
    // Placeholder for actual implementation
  }

  Future<Map<String, dynamic>> _uploadFile(
    String channel,
    String name,
    Uint8List data, {
    String? mimeType,
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
