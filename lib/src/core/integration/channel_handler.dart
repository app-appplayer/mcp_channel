import 'dart:async';

import 'package:mcp_bundle/ports.dart';

import '../idempotency/idempotency_guard.dart';
import '../idempotency/idempotency_result.dart';
import '../session/session_manager.dart';
import 'message_processor.dart';
import 'response_generator.dart';
import 'tool_provider.dart';

/// Main handler that orchestrates channel event processing.
///
/// This class ties together the channel port, session management,
/// idempotency, and optional integrations (processor, generator, tools).
///
/// Example usage:
/// ```dart
/// final handler = ChannelHandler(
///   port: slackConnector,
///   sessionManager: SessionManager(InMemorySessionStore()),
///   idempotency: IdempotencyGuard(InMemoryIdempotencyStore()),
///   processor: myMessageProcessor,      // optional
///   generator: myResponseGenerator,     // optional
///   toolProvider: myToolProvider,       // optional
/// );
///
/// await handler.start();
/// ```
class ChannelHandler {
  ChannelHandler({
    required ChannelPort port,
    required SessionManager sessionManager,
    IdempotencyGuard? idempotency,
    MessageProcessor? processor,
    ResponseGenerator? generator,
    ToolProvider? toolProvider,
  })  : _port = port,
        _sessionManager = sessionManager,
        _idempotency = idempotency,
        _processor = processor,
        _generator = generator,
        _toolProvider = toolProvider;

  final ChannelPort _port;
  final SessionManager _sessionManager;
  final IdempotencyGuard? _idempotency;
  final MessageProcessor? _processor;
  final ResponseGenerator? _generator;
  final ToolProvider? _toolProvider;

  StreamSubscription<ChannelEvent>? _subscription;

  /// The channel port being handled.
  ChannelPort get port => _port;

  /// The session manager.
  SessionManager get sessionManager => _sessionManager;

  /// The tool provider, if any.
  ToolProvider? get toolProvider => _toolProvider;

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
    if (_idempotency != null) {
      await _idempotency.process(event, () => _processEvent(event));
    } else {
      await _processEvent(event);
    }
  }

  Future<IdempotencyResult> _processEvent(ChannelEvent event) async {
    final session = await _sessionManager.getOrCreateSession(event);

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
}
