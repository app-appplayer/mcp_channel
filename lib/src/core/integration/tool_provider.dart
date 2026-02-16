/// Interface for providing external tools to the channel.
///
/// Developers implement this to expose tools from mcp_server,
/// mcp_client, or custom implementations.
///
/// Example with mcp_server:
/// ```dart
/// class McpToolProvider implements ToolProvider {
///   final Server server;
///
///   McpToolProvider(this.server);
///
///   @override
///   Future<List<ToolDefinition>> listTools() async {
///     return server.tools.map((t) => ToolDefinition(
///       name: t.name,
///       description: t.description,
///       parameters: t.inputSchema,
///     )).toList();
///   }
///
///   @override
///   Future<ToolExecutionResult> executeTool(String name, Map<String, dynamic> args) async {
///     final result = await server.callTool(name, args);
///     return ToolExecutionResult(content: result.content);
///   }
/// }
/// ```
abstract interface class ToolProvider {
  /// List available tools.
  Future<List<ToolDefinition>> listTools();

  /// Execute a tool by name with arguments.
  Future<ToolExecutionResult> executeTool(
    String name,
    Map<String, dynamic> arguments,
  );
}

/// Definition of an available tool.
class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    this.parameters,
  });

  factory ToolDefinition.fromJson(Map<String, dynamic> json) {
    return ToolDefinition(
      name: json['name'] as String,
      description: json['description'] as String,
      parameters: json['parameters'] as Map<String, dynamic>?,
    );
  }

  /// Unique tool name.
  final String name;

  /// Human-readable description.
  final String description;

  /// JSON Schema for parameters.
  final Map<String, dynamic>? parameters;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        if (parameters != null) 'parameters': parameters,
      };
}

/// Result of tool execution.
class ToolExecutionResult {
  const ToolExecutionResult({
    this.success = true,
    this.content,
    this.error,
  });

  const ToolExecutionResult.success(this.content)
      : success = true,
        error = null;

  const ToolExecutionResult.failure(this.error)
      : success = false,
        content = null;

  /// Whether execution succeeded.
  final bool success;

  /// Result content (text, JSON, etc.)
  final dynamic content;

  /// Error message if failed.
  final String? error;

  Map<String, dynamic> toJson() => {
        'success': success,
        if (content != null) 'content': content,
        if (error != null) 'error': error,
      };
}
