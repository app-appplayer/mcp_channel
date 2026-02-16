import 'dart:typed_data';

import 'package:mcp_bundle/ports.dart'
    show
        ChannelPort,
        ChannelCapabilities,
        ChannelResponse,
        ConversationKey;

import '../types/channel_identity_info.dart';
import '../types/file_info.dart';
import 'connection_state.dart';
import 'conversation_info.dart';
import 'extended_channel_capabilities.dart';
import 'send_result.dart';

// Re-export base ChannelPort from mcp_bundle
export 'package:mcp_bundle/ports.dart'
    show
        ChannelPort,
        ChannelIdentity,
        ChannelCapabilities,
        ChannelEvent,
        ChannelResponse,
        ConversationKey,
        ChannelAttachment;

/// Extended channel port with additional features for messaging platforms.
///
/// Implements the base [ChannelPort] from mcp_bundle and adds:
/// - Extended capabilities for messaging platforms
/// - User identity lookup
/// - Conversation information retrieval
/// - File upload/download
/// - Connection state management
/// - Send with result wrapper
///
/// Example usage:
/// ```dart
/// class MyBot {
///   final ExtendedChannelPort channel;
///
///   MyBot(this.channel);
///
///   Future<void> run() async {
///     await channel.start();
///
///     await for (final event in channel.events) {
///       await handleEvent(event);
///     }
///   }
///
///   Future<void> handleEvent(ChannelEvent event) async {
///     if (event.type == 'message') {
///       final response = ChannelResponse.text(
///         conversation: event.conversation,
///         text: 'Hello! You said: ${event.text}',
///         replyTo: event.id,
///       );
///
///       final result = await channel.sendWithResult(response);
///       if (!result.success) {
///         // Handle error
///       }
///     }
///   }
/// }
/// ```
abstract class ExtendedChannelPort implements ChannelPort {
  /// Channel type identifier (slack, telegram, discord, etc.)
  /// Derived from identity.platform.
  String get channelType => identity.platform;

  /// Extended platform capabilities
  ExtendedChannelCapabilities get extendedCapabilities;

  /// Get identity information for a user
  Future<ChannelIdentityInfo?> getIdentityInfo(String userId);

  /// Get conversation information
  Future<ConversationInfo?> getConversation(ConversationKey key);

  /// Upload a file
  Future<FileInfo?> uploadFile({
    required ConversationKey conversation,
    required String name,
    required Uint8List data,
    String? mimeType,
  });

  /// Download a file
  Future<Uint8List?> downloadFile(String fileId);

  /// Check if channel is connected/running
  bool get isRunning;

  /// Connection state stream
  Stream<ConnectionState> get connectionState;

  /// Send a response with result (wraps base send with SendResult).
  Future<SendResult> sendWithResult(ChannelResponse response);
}

/// Base implementation of ExtendedChannelPort with common functionality.
///
/// Adapters can extend this class for convenience methods.
abstract class BaseExtendedChannelPort implements ExtendedChannelPort {
  @override
  bool isRunning = false;

  @override
  ChannelCapabilities get capabilities => extendedCapabilities.toBase();

  /// Send a text message with retry on retryable errors.
  Future<SendResult> sendWithRetry(
    ChannelResponse response, {
    int maxRetries = 3,
  }) async {
    for (var i = 0; i < maxRetries; i++) {
      final result = await sendWithResult(response);

      if (result.success) return result;

      if (result.error == null || !result.error!.retryable) {
        return result;
      }

      if (result.error!.retryAfter != null) {
        await Future<void>.delayed(result.error!.retryAfter!);
      } else {
        // Exponential backoff
        await Future<void>.delayed(Duration(milliseconds: 100 * (1 << i)));
      }
    }

    return sendWithResult(response);
  }

  /// Send a simple text message.
  Future<SendResult> sendText(
    ConversationKey conversation,
    String text, {
    String? replyTo,
  }) {
    return sendWithResult(ChannelResponse.text(
      conversation: conversation,
      text: text,
      replyTo: replyTo,
    ));
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    // Default implementation - override if platform supports typing indicator
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) {
    throw UnsupportedError('Editing not supported by this channel');
  }

  @override
  Future<void> delete(String messageId) {
    throw UnsupportedError('Deleting not supported by this channel');
  }

  @override
  Future<void> react(String messageId, String reaction) {
    throw UnsupportedError('Reactions not supported by this channel');
  }
}
