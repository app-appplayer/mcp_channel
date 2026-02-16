import 'dart:typed_data';

import '../types/channel_event.dart';
import '../types/channel_identity.dart';
import '../types/channel_response.dart';
import '../types/conversation_key.dart';
import '../types/file_info.dart';
import 'channel_capabilities.dart';
import 'connection_state.dart';
import 'conversation_info.dart';
import 'send_result.dart';

/// The primary abstraction for platform-agnostic messaging.
///
/// This interface defines the contract between the MCP application layer
/// and channel adapters. All platform-specific adapters (Slack, Discord,
/// Telegram, etc.) implement this interface.
///
/// Example usage:
/// ```dart
/// class MyBot {
///   final ChannelPort channel;
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
///     if (event.type == ChannelEventType.message) {
///       final response = ChannelResponse.text(
///         conversation: event.conversation,
///         text: 'Hello! You said: ${event.text}',
///         replyTo: event.eventId,
///       );
///
///       final result = await channel.send(response);
///       if (!result.success) {
///         // Handle error
///       }
///     }
///   }
/// }
/// ```
abstract class ChannelPort {
  /// Channel type identifier (slack, telegram, discord, etc.)
  String get channelType;

  /// Platform capabilities
  ChannelCapabilities get capabilities;

  /// Stream of incoming events
  Stream<ChannelEvent> get events;

  /// Send a response to the channel
  Future<SendResult> send(ChannelResponse response);

  /// Get identity information for a user
  Future<ChannelIdentity?> getIdentity(String userId);

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

  /// Start the channel (connect, start polling, etc.)
  Future<void> start();

  /// Stop the channel
  Future<void> stop();

  /// Check if channel is connected/running
  bool get isRunning;

  /// Connection state stream
  Stream<ConnectionState> get connectionState;
}

/// Base implementation of ChannelPort with common functionality.
///
/// Adapters can extend this class for convenience methods.
abstract class BaseChannelPort implements ChannelPort {
  @override
  bool isRunning = false;

  /// Send a text message with retry on retryable errors.
  Future<SendResult> sendWithRetry(
    ChannelResponse response, {
    int maxRetries = 3,
  }) async {
    for (var i = 0; i < maxRetries; i++) {
      final result = await send(response);

      if (result.success) return result;

      if (result.error == null || !result.error!.retryable) {
        return result;
      }

      if (result.error!.retryAfter != null) {
        await Future.delayed(result.error!.retryAfter!);
      } else {
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * (1 << i)));
      }
    }

    return send(response);
  }

  /// Send a simple text message.
  Future<SendResult> sendText(
    ConversationKey conversation,
    String text, {
    String? replyTo,
  }) {
    return send(ChannelResponse.text(
      conversation: conversation,
      text: text,
      replyTo: replyTo,
    ));
  }

  /// Send a typing indicator.
  Future<SendResult> sendTyping(ConversationKey conversation) {
    return send(ChannelResponse.typing(conversation: conversation));
  }
}
