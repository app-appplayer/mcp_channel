import 'dart:async';

import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

// =============================================================================
// Stub implementations for testing
// =============================================================================

/// Stub ChannelPort for testing.
class StubChannelPort implements ChannelPort {
  final _eventController = StreamController<ChannelEvent>.broadcast();
  final List<ChannelResponse> sentResponses = [];
  bool started = false;
  bool stopped = false;

  @override
  Stream<ChannelEvent> get events => _eventController.stream;

  @override
  ChannelIdentity get identity =>
      const ChannelIdentity(platform: 'test', channelId: 'test');

  @override
  ChannelCapabilities get capabilities => const ChannelCapabilities();

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> send(ChannelResponse response) async {
    sentResponses.add(response);
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {}

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {}

  @override
  Future<void> delete(String messageId) async {}

  @override
  Future<void> react(String messageId, String reaction) async {}

  void emitEvent(ChannelEvent event) => _eventController.add(event);

  Future<void> dispose() async => _eventController.close();
}

/// Stub MessageProcessor that returns a configurable result.
class StubMessageProcessor implements MessageProcessor {
  ProcessResult? resultToReturn;
  int callCount = 0;

  @override
  Future<ProcessResult> process(ChannelEvent event, Session session) async {
    callCount++;
    return resultToReturn!;
  }
}

/// Stub ToolProvider for testing.
class StubToolProvider implements ToolProvider {
  ToolExecutionResult resultToReturn =
      const ToolExecutionResult.success('tool-output');
  int executeCount = 0;
  String? lastToolName;
  Map<String, dynamic>? lastArguments;

  @override
  Future<List<ToolDefinition>> listTools() async {
    return [
      const ToolDefinition(name: 'test-tool', description: 'A test tool'),
    ];
  }

  @override
  Future<ToolExecutionResult> executeTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    executeCount++;
    lastToolName = name;
    lastArguments = arguments;
    return resultToReturn;
  }
}

void main() {
  final channelIdentity = ChannelIdentity(
    platform: 'test',
    channelId: 'C1',
  );

  final conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'conv-1',
    userId: 'U1',
  );

  ChannelEvent createEvent({String? id, String? text}) {
    return ChannelEvent.message(
      id: id ?? 'evt-${DateTime.now().microsecondsSinceEpoch}',
      conversation: conversation,
      text: text ?? 'Hello',
      userId: 'U1',
    );
  }

  // ---------------------------------------------------------------------------
  // ChannelHandler
  // ---------------------------------------------------------------------------
  group('ChannelHandler', () {
    late StubChannelPort port;
    late SessionManager sessionManager;

    setUp(() {
      port = StubChannelPort();
      sessionManager = SessionManager(InMemorySessionStore());
    });

    tearDown(() async {
      await port.dispose();
    });

    group('start and stop', () {
      test('start calls port.start and subscribes to events', () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
        );

        await handler.start();
        expect(port.started, isTrue);

        await handler.stop();
      });

      test('stop cancels subscription and calls port.stop', () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
        );

        await handler.start();
        await handler.stop();
        expect(port.stopped, isTrue);
      });
    });

    group('getters', () {
      test('port getter returns the configured port', () {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
        );
        expect(handler.port, port);
      });

      test('sessionManager getter returns the configured session manager', () {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
        );
        expect(handler.sessionManager, sessionManager);
      });

      test('toolProvider getter returns null when not configured', () {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
        );
        expect(handler.toolProvider, isNull);
      });

      test('toolProvider getter returns configured provider', () {
        final toolProvider = StubToolProvider();
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          toolProvider: toolProvider,
        );
        expect(handler.toolProvider, toolProvider);
      });
    });

    group('event processing with RespondResult', () {
      test('sends response via port', () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.respond(
          ChannelResponse.text(
            conversation: conversation,
            text: 'Respond text',
          ),
        );

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Respond text');

        await handler.stop();
      });
    });

    group('event processing with NeedsToolResult', () {
      test('with toolProvider and generator: executes tool, generates response, sends',
          () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsTool(
          toolName: 'test-tool',
          arguments: {'key': 'value'},
        );

        final toolProvider = StubToolProvider();
        const generator = EchoResponseGenerator();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          toolProvider: toolProvider,
          generator: generator,
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'Need tool'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(toolProvider.executeCount, 1);
        expect(toolProvider.lastToolName, 'test-tool');
        expect(toolProvider.lastArguments, {'key': 'value'});
        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Echo: Need tool');

        await handler.stop();
      });

      test('with toolProvider but without generator: returns success without sending',
          () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsTool(
          toolName: 'test-tool',
          arguments: {},
        );

        final toolProvider = StubToolProvider();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          toolProvider: toolProvider,
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(toolProvider.executeCount, 1);
        // No generator, so no response sent
        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });

      test('without toolProvider: returns success without sending', () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsTool(
          toolName: 'test-tool',
          arguments: {},
        );

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          // no toolProvider
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });
    });

    group('event processing with DeferResult', () {
      test('with generator: generates response and sends', () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.defer();

        const generator = EchoResponseGenerator();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          generator: generator,
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'Deferred'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Echo: Deferred');

        await handler.stop();
      });

      test('without generator: returns success', () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.defer();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          // no generator
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });
    });

    group('event processing with IgnoreResult', () {
      test('returns success without sending', () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.ignore();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, isEmpty);
        expect(processor.callCount, 1);

        await handler.stop();
      });
    });

    group('no processor', () {
      test('with generator: generates response directly', () async {
        const generator = EchoResponseGenerator();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: generator,
          // no processor
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'Direct'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Echo: Direct');

        await handler.stop();
      });

      test('no generator: returns success', () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          // no processor, no generator
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });
    });

    group('with idempotency', () {
      test('wraps processing with idempotency guard', () async {
        final store = InMemoryIdempotencyStore();
        final idempotencyGuard = IdempotencyGuard(store);

        const generator = EchoResponseGenerator();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: generator,
          idempotency: idempotencyGuard,
        );

        await handler.start();
        final event = createEvent(id: 'idemp-evt-1', text: 'Idempotent');
        port.emitEvent(event);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Echo: Idempotent');

        // Send same event again - idempotency should prevent reprocessing
        port.emitEvent(event);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should still only have 1 response (cached by idempotency)
        expect(port.sentResponses, hasLength(1));

        await handler.stop();
        idempotencyGuard.dispose();
      });

      test('processes different events separately', () async {
        final store = InMemoryIdempotencyStore();
        final idempotencyGuard = IdempotencyGuard(store);

        const generator = EchoResponseGenerator();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: generator,
          idempotency: idempotencyGuard,
        );

        await handler.start();

        port.emitEvent(createEvent(id: 'evt-a', text: 'First'));
        await Future.delayed(const Duration(milliseconds: 50));

        port.emitEvent(createEvent(id: 'evt-b', text: 'Second'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(2));
        expect(port.sentResponses[0].text, 'Echo: First');
        expect(port.sentResponses[1].text, 'Echo: Second');

        await handler.stop();
        idempotencyGuard.dispose();
      });
    });

    group('without idempotency', () {
      test('processes directly without guard', () async {
        const generator = EchoResponseGenerator();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: generator,
          // no idempotency
        );

        await handler.start();

        final event = createEvent(id: 'no-idemp-1', text: 'No guard');
        port.emitEvent(event);
        await Future.delayed(const Duration(milliseconds: 50));

        // Without idempotency, same event processed again
        port.emitEvent(event);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(2));
        expect(port.sentResponses[0].text, 'Echo: No guard');
        expect(port.sentResponses[1].text, 'Echo: No guard');

        await handler.stop();
      });
    });

    group('multiple events', () {
      test('processes multiple events in sequence', () async {
        final processor = StubMessageProcessor();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
        );

        await handler.start();

        // Send respond event
        processor.resultToReturn = ProcessResult.respond(
          ChannelResponse.text(
            conversation: conversation,
            text: 'Response 1',
          ),
        );
        port.emitEvent(createEvent(id: 'multi-1'));
        await Future.delayed(const Duration(milliseconds: 50));

        // Send ignore event
        processor.resultToReturn = ProcessResult.ignore();
        port.emitEvent(createEvent(id: 'multi-2'));
        await Future.delayed(const Duration(milliseconds: 50));

        // Send another respond event
        processor.resultToReturn = ProcessResult.respond(
          ChannelResponse.text(
            conversation: conversation,
            text: 'Response 3',
          ),
        );
        port.emitEvent(createEvent(id: 'multi-3'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(processor.callCount, 3);
        expect(port.sentResponses, hasLength(2));
        expect(port.sentResponses[0].text, 'Response 1');
        expect(port.sentResponses[1].text, 'Response 3');

        await handler.stop();
      });
    });

    group('NeedsToolResult with toolProvider and no generator', () {
      test('executes tool but does not send response', () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsTool(
          toolName: 'my-tool',
          arguments: {'a': 1},
        );

        final toolProvider = StubToolProvider();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          toolProvider: toolProvider,
          // no generator - should execute tool but not generate/send
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(toolProvider.executeCount, 1);
        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });
    });

    // -----------------------------------------------------------------------
    // NeedsToolsResult (multi-tool execution)
    // -----------------------------------------------------------------------
    group('event processing with NeedsToolsResult', () {
      test('sequential mode: executes tools in order and generates response',
          () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsTools(
          tools: const [
            ToolRequest(id: 'tr-1', toolName: 'tool-a', arguments: {'x': 1}),
            ToolRequest(id: 'tr-2', toolName: 'tool-b', arguments: {'y': 2}),
          ],
          mode: ToolExecutionMode.sequential,
        );

        final toolProvider = StubToolProvider();
        const generator = EchoResponseGenerator();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          toolProvider: toolProvider,
          generator: generator,
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'Multi-tool'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(toolProvider.executeCount, 2);
        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Echo: Multi-tool');

        await handler.stop();
      });

      test('parallel mode: executes tools concurrently and generates response',
          () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsTools(
          tools: const [
            ToolRequest(id: 'tr-1', toolName: 'tool-a', arguments: {}),
            ToolRequest(id: 'tr-2', toolName: 'tool-b', arguments: {}),
          ],
          mode: ToolExecutionMode.parallel,
        );

        final toolProvider = StubToolProvider();
        const generator = EchoResponseGenerator();

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          toolProvider: toolProvider,
          generator: generator,
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'Parallel'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(toolProvider.executeCount, 2);
        expect(port.sentResponses, hasLength(1));

        await handler.stop();
      });

      test('without toolProvider: returns success without sending', () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsTools(
          tools: const [
            ToolRequest(id: 'tr-1', toolName: 'tool-a', arguments: {}),
          ],
        );

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });
    });

    // -----------------------------------------------------------------------
    // NeedsAgenticLoopResult (agentic loop execution)
    // -----------------------------------------------------------------------
    group('event processing with NeedsAgenticLoopResult', () {
      test('runs agentic loop until RespondResult', () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsAgenticLoop(
          initialTools: const [
            ToolRequest(
                id: 'tr-1', toolName: 'lookup', arguments: {'q': 'test'}),
          ],
          maxIterations: 5,
        );

        final toolProvider = StubToolProvider();
        final agenticGenerator = _StubAgenticGenerator(conversation);

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          toolProvider: toolProvider,
          agenticGenerator: agenticGenerator,
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'Agentic'));
        await Future.delayed(const Duration(milliseconds: 100));

        // Initial tool + agentic generator call
        expect(toolProvider.executeCount, greaterThanOrEqualTo(1));
        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Agentic result');

        await handler.stop();
      });

      test('without agenticGenerator: returns success without sending',
          () async {
        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.needsAgenticLoop(
          initialTools: const [
            ToolRequest(id: 'tr-1', toolName: 'tool', arguments: {}),
          ],
        );

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          // no agenticGenerator
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });
    });

    // -----------------------------------------------------------------------
    // Middleware integration via ChannelHandler
    // -----------------------------------------------------------------------
    group('middleware integration', () {
      test('middleware chain executes before processing', () async {
        final order = <String>[];

        final middleware = <EventMiddleware>[
          _TrackingMiddleware('MW1', order),
          _TrackingMiddleware('MW2', order),
        ];

        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.respond(
          ChannelResponse.text(
            conversation: conversation,
            text: 'After middleware',
          ),
        );

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          middleware: middleware,
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(order, [
          'MW1-before',
          'MW2-before',
          'MW2-after',
          'MW1-after',
        ]);
        expect(port.sentResponses, hasLength(1));

        await handler.stop();
      });

      test('filter middleware prevents processing', () async {
        final middleware = <EventMiddleware>[
          EventFilterMiddleware((_) => false),
        ];

        final processor = StubMessageProcessor();
        processor.resultToReturn = ProcessResult.respond(
          ChannelResponse.text(
            conversation: conversation,
            text: 'Should not reach',
          ),
        );

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: processor,
          middleware: middleware,
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(processor.callCount, 0);
        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });
    });

    // -----------------------------------------------------------------------
    // ErrorHandler integration via ChannelHandler
    // -----------------------------------------------------------------------
    group('errorHandler integration', () {
      test('error handler sends fallback on processing error', () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: _ThrowingProcessor(),
          errorHandler: const FallbackErrorHandler(
            fallbackMessage: 'Error occurred',
          ),
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Error occurred');

        await handler.stop();
      });

      test('silent error handler swallows errors', () async {
        final errors = <Object>[];

        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          processor: _ThrowingProcessor(),
          errorHandler: SilentErrorHandler(
            onError: (error, stack) => errors.add(error),
          ),
        );

        await handler.start();
        port.emitEvent(createEvent());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, isEmpty);
        expect(errors, hasLength(1));

        await handler.stop();
      });
    });

    // -----------------------------------------------------------------------
    // Security pipeline integration via ChannelHandler
    // -----------------------------------------------------------------------
    group('security integration', () {
      test('input validator rejects event and sends rejection response',
          () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: const EchoResponseGenerator(),
          security: ChannelSecurityConfig(
            inputValidator: _RejectingValidator(conversation),
          ),
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'bad input'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Input rejected');

        await handler.stop();
      });

      test('input validator sanitizes event before processing', () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: const EchoResponseGenerator(),
          security: ChannelSecurityConfig(
            inputValidator: _SanitizingValidator(),
          ),
        );

        await handler.start();
        port.emitEvent(createEvent(text: '<script>alert(1)</script>Hello'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Echo: sanitized');

        await handler.stop();
      });

      test('input validator allows event through unchanged', () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: const EchoResponseGenerator(),
          security: ChannelSecurityConfig(
            inputValidator: _AllowingValidator(),
          ),
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'Normal input'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Echo: Normal input');

        await handler.stop();
      });

      test('content moderator blocks inbound event', () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: const EchoResponseGenerator(),
          security: ChannelSecurityConfig(
            contentModerator: _BlockingModerator(),
          ),
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'blocked content'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, isEmpty);

        await handler.stop();
      });
    });

    // -----------------------------------------------------------------------
    // useConversationLock
    // -----------------------------------------------------------------------
    group('useConversationLock', () {
      test('handler with conversation lock processes events', () async {
        final handler = ChannelHandler(
          port: port,
          sessionManager: sessionManager,
          generator: const EchoResponseGenerator(),
          useConversationLock: true,
        );

        await handler.start();
        port.emitEvent(createEvent(text: 'Locked'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(port.sentResponses, hasLength(1));
        expect(port.sentResponses.first.text, 'Echo: Locked');

        await handler.stop();
      });
    });
  });
}

// =============================================================================
// Additional test helpers
// =============================================================================

/// A middleware that tracks before/after execution order.
class _TrackingMiddleware implements EventMiddleware {
  _TrackingMiddleware(this.name, this.order);

  final String name;
  final List<String> order;

  @override
  Future<void> handle(
    ChannelEvent event,
    Session session,
    Future<void> Function() next,
  ) async {
    order.add('$name-before');
    await next();
    order.add('$name-after');
  }
}

/// A processor that always throws.
class _ThrowingProcessor implements MessageProcessor {
  @override
  Future<ProcessResult> process(ChannelEvent event, Session session) async {
    throw StateError('Processing failed');
  }
}

/// Stub AgenticResponseGenerator for testing.
class _StubAgenticGenerator implements AgenticResponseGenerator {
  _StubAgenticGenerator(this._conversation);

  final ConversationKey _conversation;

  @override
  Future<ProcessResult> next(
    ChannelEvent event,
    Session session,
    List<ToolExecutionResult> toolResults,
  ) async {
    return ProcessResult.respond(
      ChannelResponse.text(
        conversation: _conversation,
        text: 'Agentic result',
      ),
    );
  }
}

/// An input validator that rejects all events.
class _RejectingValidator implements ChannelInputValidator {
  _RejectingValidator(this._conversation);

  final ConversationKey _conversation;

  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    return ValidationResult.reject(
      reason: 'Rejected for testing',
      rejectionResponse: ChannelResponse.text(
        conversation: _conversation,
        text: 'Input rejected',
      ),
    );
  }
}

/// An input validator that sanitizes events.
class _SanitizingValidator implements ChannelInputValidator {
  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    return ValidationResult.sanitize(
      ChannelEvent.message(
        id: event.id,
        conversation: event.conversation,
        text: 'sanitized',
        userId: event.userId ?? 'unknown',
      ),
    );
  }
}

/// An input validator that allows all events.
class _AllowingValidator implements ChannelInputValidator {
  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    return ValidationResult.allow();
  }
}

/// A content moderator that blocks all inbound content.
class _BlockingModerator implements ContentModerator {
  @override
  Future<ModerationResult> moderateInbound(ChannelEvent event) async {
    return const ModerationResult(
      action: ModerationAction.block,
      reason: 'Blocked for testing',
    );
  }

  @override
  Future<ModerationResult> moderateOutbound(ChannelResponse response) async {
    return const ModerationResult(action: ModerationAction.allow);
  }
}
