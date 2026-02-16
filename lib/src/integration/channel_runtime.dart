import 'dart:async';

import 'package:mcp_client/mcp_client.dart' as mcp_client;
import 'package:mcp_server/mcp_server.dart' as mcp_server;

import '../core/idempotency/idempotency.dart';
import '../core/policy/channel_policy.dart';
import '../core/port/channel_port.dart';
import '../core/port/send_result.dart';
import '../core/session/sessions.dart';
import '../core/types/channel_event.dart';
import '../core/types/channel_response.dart';
import 'channel_resource_provider.dart';
import 'channel_runtime_config.dart';
import 'channel_tools_provider.dart';
import 'llm_bridge.dart';
import 'mcp_invoker.dart';

/// Unified channel runtime for MCP integration.
///
/// Supports three modes:
/// - Inbound: Process channel events using MCP tools via LLM
/// - Outbound: Expose channel operations as MCP tools/resources
/// - Bidirectional: Both inbound and outbound simultaneously
class ChannelRuntime {
  final ChannelRuntimeConfig _config;
  final Map<String, ChannelPort> _channels = {};

  SessionManager? _sessionManager;
  SessionStore? _sessionStore;
  IdempotencyGuard? _idempotencyGuard;
  PolicyExecutor? _policyExecutor;
  McpInvoker? _invoker;
  LlmBridge? _llmBridge;

  mcp_server.Server? _mcpServer;

  final _eventController = StreamController<ChannelEvent>.broadcast();
  final _responseController = StreamController<ChannelResponse>.broadcast();
  final _errorController = StreamController<ChannelRuntimeError>.broadcast();

  bool _isRunning = false;

  /// Stream of incoming channel events.
  Stream<ChannelEvent> get events => _eventController.stream;

  /// Stream of outgoing responses.
  Stream<ChannelResponse> get responses => _responseController.stream;

  /// Stream of runtime errors.
  Stream<ChannelRuntimeError> get errors => _errorController.stream;

  /// Whether the runtime is currently running.
  bool get isRunning => _isRunning;

  /// Get registered channels.
  Map<String, ChannelPort> get channels => Map.unmodifiable(_channels);

  /// Get session manager.
  SessionManager? get sessionManager => _sessionManager;

  /// Get MCP invoker for direct tool calls.
  McpInvoker? get invoker => _invoker;

  /// Get LLM bridge for AI-powered processing.
  LlmBridge? get llmBridge => _llmBridge;

  /// Creates a channel runtime with the given configuration.
  ChannelRuntime(this._config);

  /// Factory for inbound-only mode.
  factory ChannelRuntime.inbound({
    required Map<String, mcp_client.Client> mcpClients,
    LlmBridge? llmBridge,
    InboundProcessingMode defaultMode = InboundProcessingMode.llm,
    SessionStoreConfig? sessionConfig,
    IdempotencyConfig? idempotencyConfig,
    ChannelPolicy? policy,
  }) {
    return ChannelRuntime(ChannelRuntimeConfig.inboundOnly(
      inbound: InboundConfig(
        mcpClients: mcpClients,
        llmBridge: llmBridge,
        defaultMode: defaultMode,
      ),
      session: sessionConfig,
      idempotency: idempotencyConfig,
      policy: policy,
    ));
  }

  /// Factory for outbound-only mode.
  factory ChannelRuntime.outbound({
    required McpServerConfig serverConfig,
    Set<String>? exposedChannels,
    Set<String>? exposedResources,
    String toolPrefix = '',
    String resourcePrefix = '',
  }) {
    return ChannelRuntime(ChannelRuntimeConfig.outboundOnly(
      outbound: OutboundConfig(
        serverConfig: serverConfig,
        exposedChannels: exposedChannels ?? const {},
        exposedResources: exposedResources ?? const {},
        toolPrefix: toolPrefix,
        resourcePrefix: resourcePrefix,
      ),
    ));
  }

  /// Factory for bidirectional mode.
  factory ChannelRuntime.bidirectional({
    required Map<String, mcp_client.Client> mcpClients,
    required McpServerConfig serverConfig,
    LlmBridge? llmBridge,
    InboundProcessingMode defaultMode = InboundProcessingMode.llm,
    Set<String>? exposedChannels,
    Set<String>? exposedResources,
    SessionStoreConfig? sessionConfig,
    IdempotencyConfig? idempotencyConfig,
    ChannelPolicy? policy,
  }) {
    return ChannelRuntime(ChannelRuntimeConfig.bidirectional(
      inbound: InboundConfig(
        mcpClients: mcpClients,
        llmBridge: llmBridge,
        defaultMode: defaultMode,
      ),
      outbound: OutboundConfig(
        serverConfig: serverConfig,
        exposedChannels: exposedChannels ?? const {},
        exposedResources: exposedResources ?? const {},
      ),
      session: sessionConfig,
      idempotency: idempotencyConfig,
      policy: policy,
    ));
  }

  /// Register a channel adapter.
  void registerChannel(String channelType, ChannelPort adapter) {
    if (_isRunning) {
      throw ChannelRuntimeException(
        'Cannot register channel while runtime is running',
      );
    }
    _channels[channelType] = adapter;
  }

  /// Start the runtime.
  Future<void> start() async {
    if (_isRunning) return;

    _initializeComponents();
    await _startChannels();
    await _startMcpServer();

    _isRunning = true;
  }

  /// Stop the runtime.
  Future<void> stop() async {
    if (!_isRunning) return;

    await _stopMcpServer();
    await _stopChannels();

    _isRunning = false;
  }

  /// Process an incoming event.
  ///
  /// This is the main entry point for channel events.
  Future<ChannelResponse?> processEvent(ChannelEvent event) async {
    if (!_isRunning) {
      throw ChannelRuntimeException('Runtime is not running');
    }

    _eventController.add(event);

    try {
      // Use idempotency guard if configured
      if (_idempotencyGuard != null) {
        final result = await _idempotencyGuard!.process(
          event,
          () async {
            final response = await _executeWithPolicy(event);
            return IdempotencyResult.success(response: response);
          },
        );

        if (result.success && result.response != null) {
          _responseController.add(result.response!);
          return result.response;
        }

        if (!result.success) {
          throw ChannelRuntimeException(result.error ?? 'Processing failed');
        }

        return null;
      }

      // No idempotency guard - execute directly
      final response = await _executeWithPolicy(event);
      if (response != null) {
        _responseController.add(response);
      }
      return response;
    } catch (e) {
      _errorController.add(ChannelRuntimeError(
        event: event,
        error: e,
        timestamp: DateTime.now(),
      ));
      rethrow;
    }
  }

  Future<ChannelResponse?> _executeWithPolicy(ChannelEvent event) async {
    if (_policyExecutor != null) {
      return await _policyExecutor!.execute(
        () => _processEventInternal(event),
      );
    }
    return await _processEventInternal(event);
  }

  /// Send a response through the appropriate channel.
  Future<SendResult> sendResponse(ChannelResponse response) async {
    if (!_isRunning) {
      throw ChannelRuntimeException('Runtime is not running');
    }

    final channel = _channels[response.conversation.channelType];
    if (channel == null) {
      throw ChannelRuntimeException(
        'Channel not found: ${response.conversation.channelType}',
      );
    }

    return await channel.send(response);
  }

  /// Get or create a session for an event.
  Future<Session> getSession(ChannelEvent event) async {
    if (_sessionManager == null) {
      throw ChannelRuntimeException('Session manager not initialized');
    }

    return await _sessionManager!.getOrCreateSession(event);
  }

  /// Call an MCP tool directly.
  Future<mcp_client.CallToolResult> callTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? clientId,
  }) async {
    if (_invoker == null) {
      throw ChannelRuntimeException('MCP invoker not initialized');
    }

    return await _invoker!.callTool(toolName, arguments, clientId: clientId);
  }

  /// Process event with LLM integration.
  Stream<ChatResponse> chat(
    ChannelEvent event, {
    String? systemPrompt,
    bool enableToolCalls = true,
  }) async* {
    if (_llmBridge == null) {
      throw ChannelRuntimeException('LLM bridge not initialized');
    }

    final session = await getSession(event);

    yield* _llmBridge!.chat(
      event.text ?? '',
      session: session,
      systemPrompt: systemPrompt,
      enableToolCalls: enableToolCalls,
    );
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    await stop();
    await _eventController.close();
    await _responseController.close();
    await _errorController.close();
    _sessionManager?.dispose();
    _idempotencyGuard?.dispose();
  }

  void _initializeComponents() {
    // Initialize session store and manager
    _sessionStore = InMemorySessionStore();
    _sessionManager = SessionManager(_sessionStore!, config: _config.session);

    // Initialize idempotency guard
    _idempotencyGuard = IdempotencyGuard(
      InMemoryIdempotencyStore(),
      config: _config.idempotency,
    );

    // Initialize policy executor (use 'default' as channel name)
    _policyExecutor = PolicyExecutor(_config.policy, 'default');

    // Initialize inbound components
    if (_config.isInboundEnabled) {
      final inbound = _config.inbound!;

      _invoker = McpClientInvoker(inbound.mcpClients);

      _llmBridge = inbound.llmBridge ??
          SimpleLlmBridge(mcpClients: inbound.mcpClients);
    }
  }

  Future<void> _startChannels() async {
    for (final entry in _channels.entries) {
      final adapter = entry.value;
      await adapter.start();

      // Subscribe to channel events
      adapter.events.listen((event) {
        processEvent(event);
      });
    }
  }

  Future<void> _stopChannels() async {
    for (final adapter in _channels.values) {
      await adapter.stop();
    }
  }

  Future<void> _startMcpServer() async {
    if (!_config.isOutboundEnabled) return;

    final outbound = _config.outbound!;
    final serverConfig = outbound.serverConfig;

    _mcpServer = mcp_server.Server(
      name: serverConfig.name,
      version: serverConfig.version,
    );

    // Register channel tools
    for (final channelType in outbound.exposedChannels) {
      final adapter = _channels[channelType];
      if (adapter != null) {
        final toolsProvider = GenericChannelToolsProvider(
          adapter,
          channelType: channelType,
          toolPrefix: outbound.toolPrefix,
        );
        await toolsProvider.registerTools(_mcpServer!);
      }
    }

    // Register channel resources
    for (final channelType in outbound.exposedResources) {
      final adapter = _channels[channelType];
      if (adapter != null) {
        final resourceProvider = GenericChannelResourceProvider(
          adapter,
          channelType: channelType,
          resourcePrefix: outbound.resourcePrefix,
        );
        await resourceProvider.registerResources(_mcpServer!);
      }
    }

    // Start server based on transport type
    switch (serverConfig.transportType) {
      case ServerTransportType.stdio:
        // Stdio server starts automatically
        break;
      case ServerTransportType.sse:
      case ServerTransportType.streamableHttp:
        // HTTP-based servers need additional setup
        break;
    }
  }

  Future<void> _stopMcpServer() async {
    // Server cleanup if needed
    _mcpServer = null;
  }

  Future<ChannelResponse?> _processEventInternal(ChannelEvent event) async {
    final inbound = _config.inbound;
    if (inbound == null) return null;

    final session = await getSession(event);

    // Add user message to session
    session.addMessage(SessionMessage.user(
      content: event.text ?? '',
      eventId: event.eventId,
    ));

    switch (inbound.defaultMode) {
      case InboundProcessingMode.llm:
        return await _processWithLlm(event, session);

      case InboundProcessingMode.directTool:
        return await _processDirectTool(event);

      case InboundProcessingMode.custom:
        // Custom mode - return null, let the caller handle it
        return null;
    }
  }

  Future<ChannelResponse?> _processWithLlm(
    ChannelEvent event,
    Session session,
  ) async {
    if (_llmBridge == null) return null;

    final responses = <String>[];

    await for (final chunk in _llmBridge!.chat(
      event.text ?? '',
      session: session,
    )) {
      if (chunk.content != null) {
        responses.add(chunk.content!);
      }

      // Handle tool calls
      if (chunk.toolCalls != null && chunk.toolCalls!.isNotEmpty) {
        final results = await _llmBridge!.executeBatchTools(chunk.toolCalls!);

        // Add tool results to session
        for (var i = 0; i < chunk.toolCalls!.length; i++) {
          final call = chunk.toolCalls![i];
          final result = results[i];

          session.addMessage(SessionMessage.tool(
            content: _extractToolResultText(result),
            result: ToolResult(
              callId: call.callId,
              name: call.name,
              content: _extractToolResultText(result),
            ),
          ));
        }
      }
    }

    final responseText = responses.join();

    // Add assistant message to session
    session.addMessage(SessionMessage.assistant(
      content: responseText,
    ));

    return ChannelResponse.text(
      conversation: event.conversation,
      text: responseText,
    );
  }

  Future<ChannelResponse?> _processDirectTool(ChannelEvent event) async {
    if (_invoker == null) return null;

    // Parse command from event text
    final text = event.text ?? '';
    final parts = text.split(' ');
    if (parts.isEmpty) return null;

    final toolName = parts[0];
    final args = parts.length > 1
        ? {'input': parts.sublist(1).join(' ')}
        : <String, dynamic>{};

    try {
      final result = await _invoker!.callTool(toolName, args);
      final resultText = _extractToolResultText(result);

      return ChannelResponse.text(
        conversation: event.conversation,
        text: resultText,
      );
    } catch (e) {
      return ChannelResponse.text(
        conversation: event.conversation,
        text: 'Error executing tool: $e',
      );
    }
  }

  String _extractToolResultText(mcp_client.CallToolResult result) {
    final contents = <String>[];
    for (final content in result.content) {
      if (content is mcp_client.TextContent) {
        contents.add(content.text);
      }
    }
    return contents.join('\n');
  }
}

/// Error that occurred during runtime processing.
class ChannelRuntimeError {
  final ChannelEvent event;
  final Object error;
  final DateTime timestamp;

  const ChannelRuntimeError({
    required this.event,
    required this.error,
    required this.timestamp,
  });
}

/// Exception thrown by channel runtime operations.
class ChannelRuntimeException implements Exception {
  final String message;

  const ChannelRuntimeException(this.message);

  @override
  String toString() => 'ChannelRuntimeException: $message';
}
