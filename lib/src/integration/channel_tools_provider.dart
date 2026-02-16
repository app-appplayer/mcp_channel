import 'package:meta/meta.dart';
import 'package:mcp_server/mcp_server.dart';

import '../core/port/channel_port.dart';
import '../core/types/channel_response.dart';
import '../core/types/conversation_key.dart';

/// Tool definition for channel operations.
@immutable
class ChannelToolDefinition {
  /// Tool name.
  final String name;

  /// Tool description.
  final String description;

  /// JSON Schema for input parameters.
  final Map<String, dynamic> inputSchema;

  const ChannelToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });
}

/// Exposes channel operations as MCP tools via mcp_server.
abstract class ChannelToolsProvider {
  /// Register channel tools with MCP server using addTool().
  Future<void> registerTools(Server mcpServer);

  /// Get tool definitions for this channel.
  List<ChannelToolDefinition> get toolDefinitions;

  /// Channel type identifier.
  String get channelType;
}

/// Base implementation for channel tools providers.
abstract class BaseChannelToolsProvider implements ChannelToolsProvider {
  final ChannelPort _adapter;
  final String _toolPrefix;

  BaseChannelToolsProvider(
    this._adapter, {
    String toolPrefix = '',
  }) : _toolPrefix = toolPrefix;

  /// Get the prefixed tool name.
  String prefixedName(String name) =>
      _toolPrefix.isEmpty ? name : '${_toolPrefix}_$name';

  /// Send a message using the adapter.
  Future<Map<String, dynamic>> sendMessage({
    required String tenantId,
    required String roomId,
    required String text,
    String? threadId,
  }) async {
    final result = await _adapter.send(ChannelResponse.text(
      conversation: ConversationKey(
        channelType: channelType,
        tenantId: tenantId,
        roomId: roomId,
        threadId: threadId,
      ),
      text: text,
    ));
    return {
      'success': result.success,
      'messageId': result.messageId,
      if (result.error != null) 'error': result.error!.message,
    };
  }

  @override
  Future<void> registerTools(Server mcpServer) async {
    for (final tool in toolDefinitions) {
      mcpServer.addTool(
        name: tool.name,
        description: tool.description,
        inputSchema: tool.inputSchema,
        handler: (args) => handleToolCall(tool.name, args),
      );
    }
  }

  /// Handle a tool call.
  ///
  /// Subclasses should override this to handle channel-specific tools.
  Future<dynamic> handleToolCall(
    String name,
    Map<String, dynamic> args,
  );
}

/// Generic channel tools provider that works with any ChannelPort.
class GenericChannelToolsProvider extends BaseChannelToolsProvider {
  @override
  final String channelType;

  GenericChannelToolsProvider(
    ChannelPort adapter, {
    required this.channelType,
    String toolPrefix = '',
  }) : super(adapter, toolPrefix: toolPrefix);

  @override
  List<ChannelToolDefinition> get toolDefinitions => [
        ChannelToolDefinition(
          name: prefixedName('${channelType}_send_message'),
          description: 'Send a message to a $channelType channel',
          inputSchema: {
            'type': 'object',
            'properties': {
              'tenant_id': {
                'type': 'string',
                'description': 'Workspace/team/server ID',
              },
              'room_id': {
                'type': 'string',
                'description': 'Channel/chat/room ID',
              },
              'text': {
                'type': 'string',
                'description': 'Message text',
              },
              'thread_id': {
                'type': 'string',
                'description': 'Thread ID for replies (optional)',
              },
            },
            'required': ['tenant_id', 'room_id', 'text'],
          },
        ),
      ];

  @override
  Future<dynamic> handleToolCall(
    String name,
    Map<String, dynamic> args,
  ) async {
    final baseName =
        name.startsWith('${channelType}_') ? name : '${channelType}_$name';

    if (baseName.endsWith('_send_message')) {
      return await sendMessage(
        tenantId: args['tenant_id'] as String,
        roomId: args['room_id'] as String,
        text: args['text'] as String,
        threadId: args['thread_id'] as String?,
      );
    }

    throw ChannelToolsException('Unknown tool: $name');
  }
}

/// Exception thrown by channel tools operations.
class ChannelToolsException implements Exception {
  final String message;

  const ChannelToolsException(this.message);

  @override
  String toString() => 'ChannelToolsException: $message';
}
