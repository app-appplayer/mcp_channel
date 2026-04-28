import 'dart:async';

import 'package:mcp_bundle/ports.dart';

import '../idempotency/idempotency_guard.dart';
import '../idempotency/idempotency_result.dart';
import '../observability/observability.dart';
import '../security/security.dart';
import '../session/conversation_lock.dart';
import '../session/session.dart';
import '../session/session_manager.dart';
import 'agentic_response_generator.dart';
import 'error_handler.dart';
import 'event_middleware.dart';
import 'message_processor.dart';
import 'response_generator.dart';
import 'streaming_response_generator.dart';
import 'tool_provider.dart';

/// Main handler that orchestrates channel event processing.
///
/// This class ties together the channel port, session management,
/// idempotency, middleware chain, and all generator types into
/// a unified processing pipeline.
class ChannelHandler {
  ChannelHandler({
    required ChannelPort port,
    required SessionManager sessionManager,
    IdempotencyGuard? idempotency,
    MessageProcessor? processor,
    ResponseGenerator? generator,
    StreamingResponseGenerator? streamingGenerator,
    AgenticResponseGenerator? agenticGenerator,
    ToolProvider? toolProvider,
    List<EventMiddleware>? middleware,
    ErrorHandler? errorHandler,
    ChannelObserverConfig? observer,
    ChannelSecurityConfig? security,
    bool useConversationLock = false,
  })  : _port = port,
        _sessionManager = sessionManager,
        _idempotency = idempotency,
        _processor = processor,
        _generator = generator,
        _streamingGenerator = streamingGenerator,
        _toolProvider = toolProvider,
        _agenticGenerator = agenticGenerator,
        _middleware = middleware ?? const [],
        _errorHandler = errorHandler,
        _observer = observer,
        _security = security,
        _conversationLock = useConversationLock ? ConversationLock() : null;

  final ChannelPort _port;
  final SessionManager _sessionManager;
  final IdempotencyGuard? _idempotency;
  final MessageProcessor? _processor;
  final ResponseGenerator? _generator;
  final StreamingResponseGenerator? _streamingGenerator;
  final ToolProvider? _toolProvider;
  final AgenticResponseGenerator? _agenticGenerator;
  final List<EventMiddleware> _middleware;
  final ErrorHandler? _errorHandler;
  final ChannelObserverConfig? _observer;
  final ChannelSecurityConfig? _security;
  final ConversationLock? _conversationLock;

  StreamSubscription<ChannelEvent>? _subscription;

  /// The channel port being handled.
  ChannelPort get port => _port;

  /// The session manager.
  SessionManager get sessionManager => _sessionManager;

  /// The tool provider, if any.
  ToolProvider? get toolProvider => _toolProvider;

  /// The streaming response generator, if any.
  StreamingResponseGenerator? get streamingGenerator => _streamingGenerator;

  /// The error handler, if any.
  ErrorHandler? get errorHandler => _errorHandler;

  /// Start listening to channel events.
  Future<void> start() async {
    await _port.start();
    _subscription = _port.events.listen(_handleEvent);
  }

  /// Stop listening and disconnect.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _port.stop();
  }

  Future<void> _handleEvent(ChannelEvent event) async {
    final correlationId = generateCorrelationId();
    final span = _observer?.tracer?.startSpan('channel.handle_event');
    span?.setAttribute('correlation_id', correlationId);
    span?.setAttribute('platform', _port.identity.platform);
    final stopwatch = Stopwatch()..start();

    // Track the potentially modified event through security pipeline
    var currentEvent = event;

    try {
      // Record message received
      _observer?.metrics?.recordMessageReceived(
        _port.identity.platform,
        event.conversation,
      );
      _observer?.logger?.info(
        'Event received',
        component: 'handler',
        correlationId: correlationId,
        data: {'type': event.type},
      );

      // Security: input validation (before idempotency)
      if (_security?.inputValidator != null) {
        final validationResult =
            await _security!.inputValidator!.validateEvent(currentEvent);
        switch (validationResult) {
          case RejectResult(:final rejectionResponse):
            if (rejectionResponse != null) {
              await _port.send(rejectionResponse);
            }
            return;
          case SanitizeResult(:final sanitizedEvent):
            currentEvent = sanitizedEvent;
          case AllowResult():
            break;
        }
      }

      // Security: content moderation on inbound
      if (_security?.contentModerator != null) {
        final modResult =
            await _security!.contentModerator!.moderateInbound(currentEvent);
        switch (modResult.action) {
          case ModerationAction.block:
            return;
          case ModerationAction.allow:
          case ModerationAction.flag:
          case ModerationAction.redact:
            break;
        }
      }

      // Session resolution
      final sessionSpan = _observer?.tracer?.startSpan(
        'channel.session',
        parentSpanId: span?.spanId,
      );
      final session =
          await _sessionManager.getOrCreateSession(currentEvent);
      sessionSpan?.end();

      Future<void> innerHandler() async {
        try {
          // Middleware + processing
          final processSpan = _observer?.tracer?.startSpan(
            'channel.process',
            parentSpanId: span?.spanId,
          );
          if (_idempotency != null) {
            await _idempotency.process(
              currentEvent,
              () => _processEvent(currentEvent, session),
            );
          } else {
            await _processEvent(currentEvent, session);
          }
          processSpan?.setStatus(SpanStatus.ok);
          processSpan?.end();
        } catch (error, stackTrace) {
          if (_errorHandler != null) {
            final fallback = await _errorHandler.handleError(
              error,
              stackTrace,
              currentEvent,
              session,
            );
            if (fallback != null) {
              await _port.send(fallback);
            }
          } else {
            rethrow;
          }
        }
      }

      // Build the middleware chain (chain-of-responsibility)
      Future<void> chainedHandler() => _executeWithMiddleware(
            currentEvent,
            session,
            _middleware,
            innerHandler,
          );

      if (_conversationLock != null) {
        await _conversationLock.withLock(
          currentEvent.conversation,
          chainedHandler,
        );
      } else {
        await chainedHandler();
      }

      // Record success metrics
      _observer?.metrics?.recordLatency('processing', stopwatch.elapsed);
      span?.setStatus(SpanStatus.ok);
    } catch (error, stackTrace) {
      _observer?.logger?.error(
        'Event processing failed',
        component: 'handler',
        correlationId: correlationId,
        error: error,
        stackTrace: stackTrace,
      );
      _observer?.metrics?.recordMessageFailed(
        _port.identity.platform,
        event.conversation,
        errorType: error.runtimeType.toString(),
      );
      span?.setStatus(SpanStatus.error, description: error.toString());
      rethrow;
    } finally {
      span?.end();
    }
  }

  /// Execute the middleware chain using chain-of-responsibility pattern.
  Future<void> _executeWithMiddleware(
    ChannelEvent event,
    Session session,
    List<EventMiddleware> middleware,
    Future<void> Function() handler,
  ) async {
    if (middleware.isEmpty) {
      await handler();
      return;
    }

    final first = middleware.first;
    final rest = middleware.sublist(1);

    await first.handle(event, session, () async {
      await _executeWithMiddleware(event, session, rest, handler);
    });
  }

  Future<IdempotencyResult> _processEvent(
    ChannelEvent event,
    Session session,
  ) async {
    if (_processor != null) {
      final result = await _processor.process(event, session);

      switch (result) {
        case RespondResult(:final response):
          await _port.send(response);
          return IdempotencyResult.success(response: response);

        case NeedsToolResult(:final toolName, :final arguments):
          if (_toolProvider != null) {
            final toolResult = await _toolProvider.executeTool(
              toolName,
              arguments,
            );
            if (_generator != null) {
              final response = await _generator.generate(
                event,
                session,
                toolResults: [toolResult],
              );
              await _port.send(response);
              return IdempotencyResult.success(response: response);
            }
          }
          return IdempotencyResult.success();

        case NeedsToolsResult(:final tools, :final mode):
          if (_toolProvider != null) {
            final toolResults = await _executeTools(tools, mode);
            if (_generator != null) {
              final response = await _generator.generate(
                event,
                session,
                toolResults: toolResults,
              );
              await _port.send(response);
              return IdempotencyResult.success(response: response);
            }
          }
          return IdempotencyResult.success();

        case NeedsAgenticLoopResult(
            :final initialTools,
            :final maxIterations,
          ):
          if (_agenticGenerator != null && _toolProvider != null) {
            final response = await _runAgenticLoop(
              event,
              session,
              initialTools: initialTools,
              maxIterations: maxIterations,
            );
            if (response != null) {
              await _port.send(response);
              return IdempotencyResult.success(response: response);
            }
          }
          return IdempotencyResult.success();

        case DeferResult():
          if (_generator != null) {
            final response = await _generator.generate(event, session);
            await _port.send(response);
            return IdempotencyResult.success(response: response);
          }
          return IdempotencyResult.success();

        case IgnoreResult():
          return IdempotencyResult.success();
      }
    }

    if (_generator != null) {
      final response = await _generator.generate(event, session);
      await _port.send(response);
      return IdempotencyResult.success(response: response);
    }

    return IdempotencyResult.success();
  }

  Future<List<ToolExecutionResult>> _executeTools(
    List<ToolRequest> tools,
    ToolExecutionMode mode,
  ) async {
    switch (mode) {
      case ToolExecutionMode.sequential:
        final results = <ToolExecutionResult>[];
        for (final tool in tools) {
          results.add(
            await _toolProvider!.executeTool(tool.toolName, tool.arguments),
          );
        }
        return results;

      case ToolExecutionMode.parallel:
        return Future.wait(
          tools.map(
            (tool) =>
                _toolProvider!.executeTool(tool.toolName, tool.arguments),
          ),
        );
    }
  }

  Future<ChannelResponse?> _runAgenticLoop(
    ChannelEvent event,
    Session session, {
    required List<ToolRequest> initialTools,
    required int maxIterations,
  }) async {
    final generator = _agenticGenerator!;

    // Execute initial tools
    var toolResults = <ToolExecutionResult>[];
    for (final tool in initialTools) {
      final result = await _toolProvider!.executeTool(
        tool.toolName,
        tool.arguments,
      );
      toolResults.add(result);
    }

    for (var i = 0; i < maxIterations; i++) {
      final result = await generator.next(event, session, toolResults);

      switch (result) {
        case RespondResult(:final response):
          return response;

        case NeedsToolResult(:final toolName, :final arguments):
          final toolResult = await _toolProvider!.executeTool(
            toolName,
            arguments,
          );
          toolResults = [...toolResults, toolResult];

        case NeedsToolsResult(:final tools, :final mode):
          final newResults = await _executeTools(tools, mode);
          toolResults = [...toolResults, ...newResults];

        case NeedsAgenticLoopResult():
          // Nested agentic loops are not supported
          return null;

        case DeferResult():
          if (_generator != null) {
            return _generator.generate(
              event,
              session,
              toolResults: toolResults,
            );
          }
          return null;

        case IgnoreResult():
          return null;
      }
    }
    return null;
  }
}
