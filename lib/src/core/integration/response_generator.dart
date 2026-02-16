import 'package:mcp_bundle/ports.dart';

import '../session/session.dart';
import 'tool_provider.dart';

/// Interface for generating responses to channel events.
///
/// Developers implement this to delegate response generation
/// to LLM services, rule engines, or other backends.
///
/// Example with mcp_llm:
/// ```dart
/// class LlmResponseGenerator implements ResponseGenerator {
///   final LlmClient llm;
///   final ToolProvider? tools;
///
///   LlmResponseGenerator(this.llm, {this.tools});
///
///   @override
///   Future<ChannelResponse> generate(
///     ChannelEvent event,
///     Session session, {
///     List<ToolExecutionResult>? toolResults,
///   }) async {
///     final messages = session.history.map((m) => m.toJson()).toList();
///     final response = await llm.chat(
///       messages: messages,
///       toolResults: toolResults,
///     );
///
///     return ChannelResponse.text(
///       conversation: event.conversation,
///       text: response.content,
///     );
///   }
/// }
/// ```
abstract interface class ResponseGenerator {
  /// Generate a response for the given event.
  ///
  /// [event] - The incoming channel event
  /// [session] - Current session with conversation history
  /// [toolResults] - Results from any tool executions
  ///
  /// Returns a [ChannelResponse] to send.
  Future<ChannelResponse> generate(
    ChannelEvent event,
    Session session, {
    List<ToolExecutionResult>? toolResults,
  });
}

/// A simple echo response generator for testing.
class EchoResponseGenerator implements ResponseGenerator {
  const EchoResponseGenerator();

  @override
  Future<ChannelResponse> generate(
    ChannelEvent event,
    Session session, {
    List<ToolExecutionResult>? toolResults,
  }) async {
    final text = event.text ?? '[no text]';
    return ChannelResponse.text(
      conversation: event.conversation,
      text: 'Echo: $text',
    );
  }
}

/// A response generator that chains multiple generators.
class ChainedResponseGenerator implements ResponseGenerator {
  const ChainedResponseGenerator(this._generators);

  final List<ResponseGenerator> _generators;

  @override
  Future<ChannelResponse> generate(
    ChannelEvent event,
    Session session, {
    List<ToolExecutionResult>? toolResults,
  }) async {
    for (final generator in _generators) {
      try {
        return await generator.generate(
          event,
          session,
          toolResults: toolResults,
        );
      } catch (_) {
        continue;
      }
    }
    throw StateError('No generator could handle the event');
  }
}
