import 'package:mcp_bundle/ports.dart';

import '../session/session.dart';
import 'message_processor.dart';
import 'tool_provider.dart';

/// Interface for agentic response generators that support
/// multi-step tool execution loops.
///
/// Unlike [ResponseGenerator] which returns a single response,
/// an agentic generator can request tool calls iteratively until
/// it produces a final response. The handler drives the loop,
/// executing tools and feeding results back into the generator.
///
/// Returns [ProcessResult] to indicate the next action:
/// - [RespondResult] to send a final response
/// - [NeedsToolResult] / [NeedsToolsResult] to request more tools
/// - [DeferResult] / [IgnoreResult] to stop processing
abstract interface class AgenticResponseGenerator {
  /// Perform one step of the agentic loop.
  ///
  /// [event] - The original incoming event
  /// [session] - Current session
  /// [toolResults] - Results from previous tool executions
  ///
  /// Returns a [ProcessResult] indicating the next action.
  Future<ProcessResult> next(
    ChannelEvent event,
    Session session,
    List<ToolExecutionResult> toolResults,
  );
}
