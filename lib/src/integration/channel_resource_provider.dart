import 'package:meta/meta.dart';
import 'package:mcp_server/mcp_server.dart';

import '../core/port/channel_port.dart';

/// Resource definition for channel data.
@immutable
class ChannelResourceDefinition {
  /// Resource URI.
  final String uri;

  /// Resource name.
  final String name;

  /// Resource description.
  final String description;

  /// MIME type.
  final String mimeType;

  /// URI template parameters.
  final Map<String, dynamic>? uriTemplate;

  const ChannelResourceDefinition({
    required this.uri,
    required this.name,
    required this.description,
    this.mimeType = 'application/json',
    this.uriTemplate,
  });
}

/// Exposes channel data as MCP resources via mcp_server.
abstract class ChannelResourceProvider {
  /// Register channel resources with MCP server using addResource().
  Future<void> registerResources(Server mcpServer);

  /// Get resource definitions for this channel.
  List<ChannelResourceDefinition> get resourceDefinitions;

  /// Channel type identifier.
  String get channelType;
}

/// Base implementation for channel resource providers.
abstract class BaseChannelResourceProvider implements ChannelResourceProvider {
  final ChannelPort adapter;
  final String resourcePrefix;

  BaseChannelResourceProvider(
    this.adapter, {
    this.resourcePrefix = '',
  });

  /// Get the prefixed URI.
  String prefixedUri(String uri) =>
      resourcePrefix.isEmpty ? uri : '$resourcePrefix$uri';

  @override
  Future<void> registerResources(Server mcpServer) async {
    for (final resource in resourceDefinitions) {
      mcpServer.addResource(
        uri: resource.uri,
        name: resource.name,
        description: resource.description,
        mimeType: resource.mimeType,
        handler: (uri, params) => handleResourceRead(uri, params),
      );
    }
  }

  /// Handle a resource read request.
  ///
  /// Subclasses should override this to handle channel-specific resources.
  Future<dynamic> handleResourceRead(
    String uri,
    Map<String, dynamic> params,
  );
}

/// Generic channel resource provider that works with any ChannelPort.
class GenericChannelResourceProvider extends BaseChannelResourceProvider {
  @override
  final String channelType;

  GenericChannelResourceProvider(
    ChannelPort adapter, {
    required this.channelType,
    String resourcePrefix = '',
  }) : super(adapter, resourcePrefix: resourcePrefix);

  @override
  List<ChannelResourceDefinition> get resourceDefinitions => [
        ChannelResourceDefinition(
          uri: prefixedUri('$channelType://status'),
          name: '$channelType Status',
          description: 'Current status of the $channelType channel',
        ),
        ChannelResourceDefinition(
          uri: prefixedUri('$channelType://capabilities'),
          name: '$channelType Capabilities',
          description: 'Capabilities of the $channelType channel',
        ),
      ];

  @override
  Future<dynamic> handleResourceRead(
    String uri,
    Map<String, dynamic> params,
  ) async {
    if (uri.endsWith('/status')) {
      return {
        'channelType': channelType,
        'isRunning': adapter.isRunning,
      };
    }

    if (uri.endsWith('/capabilities')) {
      return adapter.capabilities.toJson();
    }

    throw ChannelResourceException('Resource not found: $uri');
  }
}

/// Exception thrown by channel resource operations.
class ChannelResourceException implements Exception {
  final String message;

  const ChannelResourceException(this.message);

  @override
  String toString() => 'ChannelResourceException: $message';
}
