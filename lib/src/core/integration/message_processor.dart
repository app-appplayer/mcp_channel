import 'package:mcp_bundle/ports.dart';

import '../session/session.dart';

/// Callback interface for processing incoming messages.
///
/// Developers implement this to connect with their preferred
/// processing backend (mcp_llm, mcp_server, custom logic, etc.)
///
/// Example with mcp_llm:
/// ```dart
/// class LlmMessageProcessor implements MessageProcessor {
///   final LlmClient llm;
///
///   LlmMessageProcessor(this.llm);
///
///   @override
///   Future<ProcessResult> process(ChannelEvent event, Session session) async {
///     final response = await llm.chat(event.text ?? '');
///     return ProcessResult.respond(
///       ChannelResponse.text(
///         conversation: event.conversation,
///         text: response.content,
///       ),
///     );
///   }
/// }
/// ```
abstract interface class MessageProcessor {
  /// Process an incoming event and return a result.
  ///
  /// [event] - The incoming channel event
  /// [session] - Current session with conversation history
  ///
  /// Returns [ProcessResult] indicating how to respond.
  Future<ProcessResult> process(ChannelEvent event, Session session);
}

/// Result of message processing.
sealed class ProcessResult {
  const ProcessResult._();

  /// Create a response result.
  factory ProcessResult.respond(ChannelResponse response) = RespondResult;

  /// Create a result that defers to another processor.
  factory ProcessResult.defer() = DeferResult;

  /// Create a result that ignores the event.
  factory ProcessResult.ignore() = IgnoreResult;

  /// Create a result that requires tool execution first.
  factory ProcessResult.needsTool({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) = NeedsToolResult;
}

/// Response with a channel message.
final class RespondResult extends ProcessResult {
  const RespondResult(this.response) : super._();

  /// The response to send.
  final ChannelResponse response;
}

/// Defer processing to the next processor in chain.
final class DeferResult extends ProcessResult {
  const DeferResult() : super._();
}

/// Ignore the event without responding.
final class IgnoreResult extends ProcessResult {
  const IgnoreResult() : super._();
}

/// Requires tool execution before responding.
final class NeedsToolResult extends ProcessResult {
  const NeedsToolResult({
    required this.toolName,
    required this.arguments,
  }) : super._();

  /// Name of the tool to execute.
  final String toolName;

  /// Arguments for the tool.
  final Map<String, dynamic> arguments;
}
