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

  /// Create a result that requires multiple tool executions.
  factory ProcessResult.needsTools({
    required List<ToolRequest> tools,
    ToolExecutionMode mode,
  }) = NeedsToolsResult;

  /// Create a result that requires an agentic loop.
  factory ProcessResult.needsAgenticLoop({
    required List<ToolRequest> initialTools,
    int maxIterations,
  }) = NeedsAgenticLoopResult;
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

/// Execution mode for multiple tool requests.
enum ToolExecutionMode {
  /// Execute tools sequentially, one after another
  sequential,

  /// Execute tools in parallel
  parallel,
}

/// A single tool call request within a multi-tool result.
class ToolRequest {
  const ToolRequest({
    required this.id,
    required this.toolName,
    required this.arguments,
  });

  /// Unique identifier for this request within a batch.
  final String id;

  /// Name of the tool to execute
  final String toolName;

  /// Arguments for the tool
  final Map<String, dynamic> arguments;
}

/// Requires multiple tool executions before responding.
final class NeedsToolsResult extends ProcessResult {
  const NeedsToolsResult({
    required this.tools,
    this.mode = ToolExecutionMode.sequential,
  }) : super._();

  /// List of tool requests to execute
  final List<ToolRequest> tools;

  /// Execution mode (sequential or parallel)
  final ToolExecutionMode mode;
}

/// Requires an agentic loop (multi-step tool execution).
final class NeedsAgenticLoopResult extends ProcessResult {
  const NeedsAgenticLoopResult({
    required this.initialTools,
    this.maxIterations = 10,
  }) : super._();

  /// Initial tool requests to start the agentic loop.
  final List<ToolRequest> initialTools;

  /// Maximum number of loop iterations allowed. Default: 10.
  final int maxIterations;
}
