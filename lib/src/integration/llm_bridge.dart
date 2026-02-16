import 'package:mcp_client/mcp_client.dart';

import '../core/session/session.dart';
import '../core/session/session_message.dart';

/// Response chunk from LLM chat.
class ChatResponse {
  /// Text content (may be partial in streaming).
  final String? content;

  /// Tool calls requested by the LLM.
  final List<ToolCall>? toolCalls;

  /// Whether this is the final response.
  final bool isComplete;

  /// Usage information (only in final response).
  final TokenUsage? usage;

  const ChatResponse({
    this.content,
    this.toolCalls,
    this.isComplete = false,
    this.usage,
  });
}

/// Token usage information.
class TokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  const TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });
}

/// Chat message for LLM interaction.
class ChatMessage {
  final String role;
  final String content;
  final List<ToolCall>? toolCalls;
  final ToolResult? toolResult;

  const ChatMessage({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolResult,
  });

  factory ChatMessage.fromSessionMessage(SessionMessage msg) {
    return ChatMessage(
      role: msg.role.name,
      content: msg.content,
      toolCalls: msg.toolCalls,
      toolResult: msg.toolResult,
    );
  }
}

/// Health check result for MCP services.
class HealthCheckResult {
  final Map<String, ClientHealthStatus> clientStatuses;
  final bool allHealthy;
  final DateTime timestamp;

  const HealthCheckResult({
    required this.clientStatuses,
    required this.allHealthy,
    required this.timestamp,
  });
}

/// Health status for an MCP client.
enum ClientHealthStatus {
  healthy,
  degraded,
  unhealthy,
  unknown,
}

/// LLM integration for channel events.
///
/// Wraps mcp_llm's LlmClient for chat and tool orchestration.
abstract class LlmBridge {
  /// Process message with LLM (stream-based, may include tool calls).
  ///
  /// Returns stream of responses for real-time updates.
  Stream<ChatResponse> chat(
    String userInput, {
    required Session session,
    String? systemPrompt,
    bool enableToolCalls = true,
  });

  /// Execute a specific tool through LLM client.
  Future<CallToolResult> executeTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? clientId,
  });

  /// Execute tool on specific MCP client.
  Future<CallToolResult> executeToolWithSpecificClient(
    String clientId,
    String toolName,
    Map<String, dynamic> arguments,
  );

  /// Execute batch tools for optimization.
  Future<List<CallToolResult>> executeBatchTools(
    List<ToolCall> toolCalls,
  );

  /// Get available tools from connected MCP clients.
  Future<Map<String, List<Tool>>> getToolsByClient();

  /// Perform health check on MCP clients.
  Future<HealthCheckResult> performHealthCheck();

  /// Get conversation history from session.
  List<ChatMessage> getHistory(Session session);
}

/// Placeholder implementation of LlmBridge.
///
/// This implementation provides basic functionality without requiring
/// the full mcp_llm package. For production use, integrate with the
/// actual mcp_llm LlmClient.
class SimpleLlmBridge implements LlmBridge {
  final Map<String, Client> _mcpClients;
  final Future<String> Function(String, List<ChatMessage>)? _chatHandler;

  SimpleLlmBridge({
    required Map<String, Client> mcpClients,
    Future<String> Function(String, List<ChatMessage>)? chatHandler,
  })  : _mcpClients = mcpClients,
        _chatHandler = chatHandler;

  @override
  Stream<ChatResponse> chat(
    String userInput, {
    required Session session,
    String? systemPrompt,
    bool enableToolCalls = true,
  }) async* {
    final history = getHistory(session);

    if (_chatHandler != null) {
      final response = await _chatHandler!(userInput, history);
      yield ChatResponse(
        content: response,
        isComplete: true,
      );
    } else {
      // Default echo response for testing
      yield ChatResponse(
        content: 'Received: $userInput',
        isComplete: true,
      );
    }
  }

  @override
  Future<CallToolResult> executeTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? clientId,
  }) async {
    final client = _getClient(clientId);
    return await client.callTool(toolName, arguments);
  }

  @override
  Future<CallToolResult> executeToolWithSpecificClient(
    String clientId,
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final client = _mcpClients[clientId];
    if (client == null) {
      throw LlmBridgeException('Client not found: $clientId');
    }
    return await client.callTool(toolName, arguments);
  }

  @override
  Future<List<CallToolResult>> executeBatchTools(
    List<ToolCall> toolCalls,
  ) async {
    final results = <CallToolResult>[];
    for (final call in toolCalls) {
      try {
        final result = await executeTool(call.name, call.arguments);
        results.add(result);
      } catch (e) {
        results.add(CallToolResult(
          [TextContent(text: 'Error: $e')],
          isError: true,
        ));
      }
    }
    return results;
  }

  @override
  Future<Map<String, List<Tool>>> getToolsByClient() async {
    final toolsByClient = <String, List<Tool>>{};
    for (final entry in _mcpClients.entries) {
      try {
        toolsByClient[entry.key] = await entry.value.listTools();
      } catch (e) {
        toolsByClient[entry.key] = [];
      }
    }
    return toolsByClient;
  }

  @override
  Future<HealthCheckResult> performHealthCheck() async {
    final statuses = <String, ClientHealthStatus>{};
    var allHealthy = true;

    for (final entry in _mcpClients.entries) {
      try {
        await entry.value.healthCheck();
        statuses[entry.key] = ClientHealthStatus.healthy;
      } catch (e) {
        statuses[entry.key] = ClientHealthStatus.unhealthy;
        allHealthy = false;
      }
    }

    return HealthCheckResult(
      clientStatuses: statuses,
      allHealthy: allHealthy,
      timestamp: DateTime.now(),
    );
  }

  @override
  List<ChatMessage> getHistory(Session session) {
    return session.history.map(ChatMessage.fromSessionMessage).toList();
  }

  Client _getClient(String? clientId) {
    if (clientId != null) {
      final client = _mcpClients[clientId];
      if (client == null) {
        throw LlmBridgeException('Client not found: $clientId');
      }
      return client;
    }
    if (_mcpClients.isEmpty) {
      throw LlmBridgeException('No MCP clients available');
    }
    return _mcpClients.values.first;
  }
}

/// Exception thrown by LlmBridge operations.
class LlmBridgeException implements Exception {
  final String message;

  const LlmBridgeException(this.message);

  @override
  String toString() => 'LlmBridgeException: $message';
}
