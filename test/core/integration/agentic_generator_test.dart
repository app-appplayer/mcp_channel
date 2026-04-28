import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  const channelIdentity = ChannelIdentity(
    platform: 'test',
    channelId: 'ch1',
  );

  const conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'conv1',
    userId: 'u1',
  );

  /// Helper to create a minimal session for testing.
  Session createTestSession() {
    return Session(
      id: 'session-1',
      conversation: conversation,
      principal: Principal.basic(
        identity: ChannelIdentityInfo.user(
          id: 'u1',
          displayName: 'Test User',
        ),
        tenantId: 'ch1',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      ),
      state: SessionState.active,
      createdAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // TC-058: AgenticResponseGenerator interface
  // ---------------------------------------------------------------------------
  group('AgenticResponseGenerator', () {
    late Session session;

    setUp(() {
      session = createTestSession();
    });

    test('next() returns RespondResult as final response', () async {
      final generator = _SingleStepGenerator(conversation);

      final event = ChannelEvent.message(
        id: 'evt-agent-1',
        conversation: conversation,
        text: 'Hello',
        userId: 'u1',
      );

      final result = await generator.next(event, session, []);
      expect(result, isA<RespondResult>());
      final respond = result as RespondResult;
      expect(respond.response.text, 'Direct answer');
    });

    test('next() returns NeedsToolResult to request tool', () async {
      final generator = _ToolRequestGenerator(conversation);

      final event = ChannelEvent.message(
        id: 'evt-agent-2',
        conversation: conversation,
        text: 'What is 2+2?',
        userId: 'u1',
      );

      // First call: request a tool
      final step1 = await generator.next(event, session, []);
      expect(step1, isA<NeedsToolResult>());
      final toolReq = step1 as NeedsToolResult;
      expect(toolReq.toolName, 'calculator');
      expect(toolReq.arguments, {'expression': '2+2'});

      // Second call: provide tool results, get final response
      final step2 = await generator.next(
        event,
        session,
        [const ToolExecutionResult.success('4')],
      );
      expect(step2, isA<RespondResult>());
      final respond = step2 as RespondResult;
      expect(respond.response.text, 'The answer is 4');
    });

    test('next() returns NeedsToolsResult for multiple tools', () async {
      final generator = _MultiToolGenerator(conversation);

      final event = ChannelEvent.message(
        id: 'evt-agent-3',
        conversation: conversation,
        text: 'Complex query',
        userId: 'u1',
      );

      final result = await generator.next(event, session, []);
      expect(result, isA<NeedsToolsResult>());
      final tools = result as NeedsToolsResult;
      expect(tools.tools, hasLength(2));
      expect(tools.tools[0].toolName, 'search');
      expect(tools.tools[1].toolName, 'fetch');
    });
  });

  // ---------------------------------------------------------------------------
  // TC-058: Multi-step agentic loop simulation
  // ---------------------------------------------------------------------------
  group('Multi-step agentic loop simulation', () {
    late Session session;

    setUp(() {
      session = createTestSession();
    });

    test('loop iterates through tool calls until final response', () async {
      final generator =
          _MultiStepGenerator(conversation, stepsBeforeFinal: 3);

      final event = ChannelEvent.message(
        id: 'evt-loop-1',
        conversation: conversation,
        text: 'Complex question',
        userId: 'u1',
      );

      var toolResults = <ToolExecutionResult>[];
      ProcessResult? lastResult;
      const maxIterations = 10;

      for (var i = 0; i < maxIterations; i++) {
        final result = await generator.next(event, session, toolResults);
        lastResult = result;

        switch (result) {
          case NeedsToolResult(:final arguments):
            final execResult = ToolExecutionResult.success(
              'result-for-${arguments['step']}',
            );
            toolResults = [execResult];

          case RespondResult():
            break;

          default:
            break;
        }

        if (result is RespondResult) break;
      }

      expect(lastResult, isA<RespondResult>());
      final finalResult = lastResult! as RespondResult;
      expect(
          finalResult.response.text, 'Completed after 3 tool calls');
    });

    test('loop terminates at maxIterations without final response', () async {
      final generator = _InfiniteToolCallGenerator();

      final event = ChannelEvent.message(
        id: 'evt-loop-2',
        conversation: conversation,
        text: 'Infinite loop test',
        userId: 'u1',
      );

      var toolResults = <ToolExecutionResult>[];
      ProcessResult? lastResult;
      var iterations = 0;
      const maxIterations = 5;

      for (var i = 0; i < maxIterations; i++) {
        iterations++;
        final result = await generator.next(event, session, toolResults);
        lastResult = result;

        if (result is NeedsToolResult) {
          toolResults = [const ToolExecutionResult.success('ok')];
        }

        if (result is RespondResult) break;
      }

      expect(iterations, maxIterations);
      expect(lastResult, isA<NeedsToolResult>());
    });
  });

  // ---------------------------------------------------------------------------
  // TC-058: ProcessResult pattern matching in agentic context
  // ---------------------------------------------------------------------------
  group('ProcessResult pattern matching in agentic context', () {
    test('switch handles all relevant result types', () {
      final results = <ProcessResult>[
        ProcessResult.respond(
          ChannelResponse.text(
            conversation: conversation,
            text: 'done',
          ),
        ),
        ProcessResult.needsTool(
          toolName: 'search',
          arguments: {'q': 'test'},
        ),
        ProcessResult.needsTools(
          tools: const [
            ToolRequest(
                id: 'tr-1', toolName: 'a', arguments: {}),
          ],
        ),
        ProcessResult.ignore(),
      ];

      final types = results.map((r) => switch (r) {
        RespondResult() => 'respond',
        NeedsToolResult() => 'needsTool',
        NeedsToolsResult() => 'needsTools',
        IgnoreResult() => 'ignore',
        DeferResult() => 'defer',
        NeedsAgenticLoopResult() => 'agenticLoop',
      }).toList();

      expect(types, ['respond', 'needsTool', 'needsTools', 'ignore']);
    });
  });
}

// =============================================================================
// Test helpers - mock implementations
// =============================================================================

/// A generator that immediately returns a response.
class _SingleStepGenerator implements AgenticResponseGenerator {
  _SingleStepGenerator(this._conversation);

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
        text: 'Direct answer',
      ),
    );
  }
}

/// A generator that requests a tool on first call, then responds.
class _ToolRequestGenerator implements AgenticResponseGenerator {
  _ToolRequestGenerator(this._conversation);

  final ConversationKey _conversation;
  var _stepCount = 0;

  @override
  Future<ProcessResult> next(
    ChannelEvent event,
    Session session,
    List<ToolExecutionResult> toolResults,
  ) async {
    _stepCount++;

    if (_stepCount == 1) {
      return ProcessResult.needsTool(
        toolName: 'calculator',
        arguments: {'expression': '2+2'},
      );
    }

    final content =
        toolResults.isNotEmpty ? toolResults.first.content : 'N/A';
    return ProcessResult.respond(
      ChannelResponse.text(
        conversation: _conversation,
        text: 'The answer is $content',
      ),
    );
  }
}

/// A generator that requests multiple tools at once.
class _MultiToolGenerator implements AgenticResponseGenerator {
  _MultiToolGenerator(this._conversation);

  final ConversationKey _conversation;

  @override
  Future<ProcessResult> next(
    ChannelEvent event,
    Session session,
    List<ToolExecutionResult> toolResults,
  ) async {
    if (toolResults.isEmpty) {
      return ProcessResult.needsTools(
        tools: const [
          ToolRequest(id: 'tr-1', toolName: 'search', arguments: {'q': 'x'}),
          ToolRequest(
              id: 'tr-2', toolName: 'fetch', arguments: {'url': 'y'}),
        ],
        mode: ToolExecutionMode.parallel,
      );
    }

    return ProcessResult.respond(
      ChannelResponse.text(
        conversation: _conversation,
        text: 'Done with tools',
      ),
    );
  }
}

/// A generator that requires [stepsBeforeFinal] tool calls before final.
class _MultiStepGenerator implements AgenticResponseGenerator {
  _MultiStepGenerator(this._conversation, {required this.stepsBeforeFinal});

  final ConversationKey _conversation;
  final int stepsBeforeFinal;
  var _stepCount = 0;

  @override
  Future<ProcessResult> next(
    ChannelEvent event,
    Session session,
    List<ToolExecutionResult> toolResults,
  ) async {
    _stepCount++;

    if (_stepCount <= stepsBeforeFinal) {
      return ProcessResult.needsTool(
        toolName: 'step-tool',
        arguments: {'step': _stepCount},
      );
    }

    return ProcessResult.respond(
      ChannelResponse.text(
        conversation: _conversation,
        text: 'Completed after $stepsBeforeFinal tool calls',
      ),
    );
  }
}

/// A generator that always requests tool calls (never produces final).
class _InfiniteToolCallGenerator implements AgenticResponseGenerator {
  var _callCount = 0;

  @override
  Future<ProcessResult> next(
    ChannelEvent event,
    Session session,
    List<ToolExecutionResult> toolResults,
  ) async {
    _callCount++;
    return ProcessResult.needsTool(
      toolName: 'infinite-tool',
      arguments: {'iteration': _callCount},
    );
  }
}
