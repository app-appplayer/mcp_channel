import 'dart:async';

import 'package:mcp_bundle/ports.dart';

import '../session/session.dart';
import '../types/channel_response_chunk.dart';
import 'tool_provider.dart';

/// Strategy for delivering streaming response chunks.
enum StreamingDeliveryStrategy {
  /// Edit the same message in place with updated content (e.g., Slack, Discord)
  editInPlace,

  /// Show typing indicator, then send complete message
  typingThenSend,

  /// Append each chunk as a new message (e.g., platforms without edit support)
  appendMessages,
}

/// Token to cancel an in-progress streaming response.
class StreamCancellation {
  bool _cancelled = false;

  /// Whether cancellation has been requested.
  bool get isCancelled => _cancelled;

  /// Request cancellation of the streaming response.
  void cancel() {
    _cancelled = true;
  }
}

/// Interface for generators that produce streaming responses.
///
/// Unlike [ResponseGenerator] which returns a single response,
/// this yields a stream of [ChannelResponseChunk] objects,
/// enabling real-time token-by-token delivery to the user.
abstract interface class StreamingResponseGenerator {
  /// Generate a streaming response for the given event.
  ///
  /// Returns a stream of [ChannelResponseChunk] objects.
  /// The stream completes when the final chunk (isComplete=true) is emitted.
  ///
  /// [event] - The incoming channel event
  /// [session] - Current session with conversation history
  /// [toolResults] - Results from any tool executions
  /// [cancellation] - Token that can be used to cancel the stream
  Stream<ChannelResponseChunk> generateStream(
    ChannelEvent event,
    Session session, {
    List<ToolExecutionResult>? toolResults,
    StreamCancellation? cancellation,
  });
}

/// An echo streaming generator for testing.
///
/// Streams the event text one character at a time.
class EchoStreamingGenerator implements StreamingResponseGenerator {
  const EchoStreamingGenerator({
    this.chunkDelay = Duration.zero,
  });

  /// Delay between each chunk emission
  final Duration chunkDelay;

  @override
  Stream<ChannelResponseChunk> generateStream(
    ChannelEvent event,
    Session session, {
    List<ToolExecutionResult>? toolResults,
    StreamCancellation? cancellation,
  }) async* {
    final text = event.text ?? '[no text]';
    final messageId = 'echo-${event.conversation.conversationId}';

    yield ChannelResponseChunk.first(
      conversation: event.conversation,
      textDelta: text.isNotEmpty ? text[0] : '',
    );

    for (var i = 1; i < text.length; i++) {
      if (cancellation?.isCancelled ?? false) {
        yield ChannelResponseChunk.complete(
          conversation: event.conversation,
          messageId: messageId,
          sequenceNumber: i,
        );
        return;
      }

      if (chunkDelay > Duration.zero) {
        await Future<void>.delayed(chunkDelay);
      }

      yield ChannelResponseChunk.delta(
        conversation: event.conversation,
        textDelta: text[i],
        messageId: messageId,
        sequenceNumber: i,
      );
    }

    yield ChannelResponseChunk.complete(
      conversation: event.conversation,
      messageId: messageId,
      sequenceNumber: text.length,
    );
  }
}
