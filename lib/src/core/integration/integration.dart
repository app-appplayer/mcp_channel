/// Integration interfaces for connecting mcp_channel with external systems.
///
/// These interfaces allow developers to integrate with:
/// - mcp_llm for LLM-based processing
/// - mcp_server for MCP tool execution
/// - mcp_client for MCP client connections
/// - Custom implementations
///
/// The package does NOT depend on any MCP packages.
/// Developers choose what to integrate.
library;

export 'agentic_response_generator.dart';
export 'channel_handler.dart';
export 'error_handler.dart';
export 'event_middleware.dart';
export 'message_processor.dart';
export 'response_generator.dart';
export 'streaming_response_generator.dart';
export 'tool_provider.dart';
