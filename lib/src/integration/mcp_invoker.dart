import 'package:mcp_client/mcp_client.dart';

/// Direct MCP tool invocation from channel events.
///
/// Wraps mcp_client's Client for tool/resource operations.
abstract class McpInvoker {
  /// Call a specific tool.
  ///
  /// Returns [CallToolResult] from mcp_client.
  Future<CallToolResult> callTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? clientId,
  });

  /// Call tool on all connected MCP clients.
  Future<Map<String, CallToolResult>> callToolOnAllClients(
    String toolName,
    Map<String, dynamic> arguments,
  );

  /// Read a resource.
  ///
  /// Returns [ReadResourceResult] from mcp_client.
  Future<ReadResourceResult> readResource(
    String uri, {
    String? clientId,
  });

  /// Get available tools from specific or all clients.
  Future<List<Tool>> listTools({String? clientId});

  /// Get tools grouped by client.
  Future<Map<String, List<Tool>>> getToolsByClient();

  /// Find which clients have a specific tool.
  Future<List<String>> findClientsWithTool(String toolName);

  /// Connected MCP client IDs.
  List<String> get connectedClients;

  /// Check connection status.
  bool isClientConnected(String clientId);
}

/// Implementation using mcp_client with multi-client support.
class McpClientInvoker implements McpInvoker {
  final Map<String, Client> _clients;
  Map<String, List<Tool>>? _toolsCache;

  McpClientInvoker(this._clients);

  @override
  List<String> get connectedClients => _clients.keys.toList();

  @override
  bool isClientConnected(String clientId) => _clients.containsKey(clientId);

  @override
  Future<CallToolResult> callTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? clientId,
  }) async {
    final client = await _selectClient(clientId, toolName);
    return await client.callTool(toolName, arguments);
  }

  @override
  Future<Map<String, CallToolResult>> callToolOnAllClients(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final results = <String, CallToolResult>{};
    for (final entry in _clients.entries) {
      try {
        results[entry.key] = await entry.value.callTool(toolName, arguments);
      } catch (e) {
        results[entry.key] = CallToolResult(
          [TextContent(text: 'Error: $e')],
          isError: true,
        );
      }
    }
    return results;
  }

  @override
  Future<ReadResourceResult> readResource(
    String uri, {
    String? clientId,
  }) async {
    final client = _getClient(clientId);
    return await client.readResource(uri);
  }

  @override
  Future<List<Tool>> listTools({String? clientId}) async {
    if (clientId != null) {
      final client = _getClient(clientId);
      return await client.listTools();
    }

    // Get tools from all clients
    final allTools = <Tool>[];
    final toolsByClient = await getToolsByClient();
    for (final tools in toolsByClient.values) {
      allTools.addAll(tools);
    }
    return allTools;
  }

  @override
  Future<Map<String, List<Tool>>> getToolsByClient() async {
    if (_toolsCache != null) return _toolsCache!;

    final toolsByClient = <String, List<Tool>>{};
    for (final entry in _clients.entries) {
      try {
        toolsByClient[entry.key] = await entry.value.listTools();
      } catch (e) {
        toolsByClient[entry.key] = [];
      }
    }
    _toolsCache = toolsByClient;
    return toolsByClient;
  }

  @override
  Future<List<String>> findClientsWithTool(String toolName) async {
    final toolsByClient = await getToolsByClient();
    final clientsWithTool = <String>[];

    for (final entry in toolsByClient.entries) {
      if (entry.value.any((t) => t.name == toolName)) {
        clientsWithTool.add(entry.key);
      }
    }

    return clientsWithTool;
  }

  /// Clear the tools cache.
  void clearCache() {
    _toolsCache = null;
  }

  Client _getClient(String? clientId) {
    if (clientId != null) {
      final client = _clients[clientId];
      if (client == null) {
        throw McpInvokerException('Client not found: $clientId');
      }
      return client;
    }
    if (_clients.isEmpty) {
      throw McpInvokerException('No MCP clients available');
    }
    return _clients.values.first;
  }

  Future<Client> _selectClient(String? clientId, String? toolName) async {
    if (clientId != null) {
      return _getClient(clientId);
    }

    if (toolName != null) {
      final clientsWithTool = await findClientsWithTool(toolName);
      if (clientsWithTool.isNotEmpty) {
        return _clients[clientsWithTool.first]!;
      }
    }

    return _getClient(null);
  }
}

/// Exception thrown by McpInvoker operations.
class McpInvokerException implements Exception {
  final String message;

  const McpInvokerException(this.message);

  @override
  String toString() => 'McpInvokerException: $message';
}
