import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

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

  /// Helper to create a minimal session for testing.
  Session createTestSession() {
    return Session(
      id: 'session-1',
      conversation: conversation,
      principal: Principal.basic(
        identity: ChannelIdentityInfo.user(
          id: 'U1',
          displayName: 'Test User',
        ),
        tenantId: 'C1',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      ),
      state: SessionState.active,
      createdAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // EchoResponseGenerator
  // ---------------------------------------------------------------------------
  group('EchoResponseGenerator', () {
    late EchoResponseGenerator generator;
    late Session session;

    setUp(() {
      generator = const EchoResponseGenerator();
      session = createTestSession();
    });

    test('generate with text event returns "Echo: {text}"', () async {
      final event = ChannelEvent.message(
        id: 'evt-1',
        conversation: conversation,
        text: 'Hello World',
        userId: 'U1',
      );

      final response = await generator.generate(event, session);
      expect(response.text, 'Echo: Hello World');
      expect(response.conversation, conversation);
    });

    test('generate with null text returns "Echo: [no text]"', () async {
      final event = ChannelEvent(
        id: 'evt-2',
        conversation: conversation,
        type: 'reaction',
        timestamp: DateTime.now(),
      );

      final response = await generator.generate(event, session);
      expect(response.text, 'Echo: [no text]');
    });

    test('generate ignores toolResults', () async {
      final event = ChannelEvent.message(
        id: 'evt-3',
        conversation: conversation,
        text: 'With tools',
        userId: 'U1',
      );

      final response = await generator.generate(
        event,
        session,
        toolResults: [const ToolExecutionResult.success('tool-data')],
      );
      expect(response.text, 'Echo: With tools');
    });
  });

  // ---------------------------------------------------------------------------
  // ChainedResponseGenerator
  // ---------------------------------------------------------------------------
  group('ChainedResponseGenerator', () {
    late Session session;

    setUp(() {
      session = createTestSession();
    });

    test('first generator succeeds returns its result', () async {
      final generator = ChainedResponseGenerator([
        const EchoResponseGenerator(),
        _FailingGenerator(),
      ]);

      final event = ChannelEvent.message(
        id: 'evt-chain1',
        conversation: conversation,
        text: 'Chain test',
        userId: 'U1',
      );

      final response = await generator.generate(event, session);
      expect(response.text, 'Echo: Chain test');
    });

    test('first fails, second succeeds returns second result', () async {
      final generator = ChainedResponseGenerator([
        _FailingGenerator(),
        const EchoResponseGenerator(),
      ]);

      final event = ChannelEvent.message(
        id: 'evt-chain2',
        conversation: conversation,
        text: 'Fallback test',
        userId: 'U1',
      );

      final response = await generator.generate(event, session);
      expect(response.text, 'Echo: Fallback test');
    });

    test('all fail throws StateError', () async {
      final generator = ChainedResponseGenerator([
        _FailingGenerator(),
        _FailingGenerator(),
      ]);

      final event = ChannelEvent.message(
        id: 'evt-chain3',
        conversation: conversation,
        text: 'All fail',
        userId: 'U1',
      );

      expect(
        () => generator.generate(event, session),
        throwsA(isA<StateError>()),
      );
    });

    test('empty generators list throws StateError', () async {
      final generator = ChainedResponseGenerator([]);

      final event = ChannelEvent.message(
        id: 'evt-chain4',
        conversation: conversation,
        text: 'Empty',
        userId: 'U1',
      );

      expect(
        () => generator.generate(event, session),
        throwsA(isA<StateError>()),
      );
    });

    test('passes toolResults to generators', () async {
      final captureGenerator = _CapturingGenerator();
      final generator = ChainedResponseGenerator([captureGenerator]);

      final event = ChannelEvent.message(
        id: 'evt-chain5',
        conversation: conversation,
        text: 'Tools',
        userId: 'U1',
      );

      final toolResults = [const ToolExecutionResult.success('data')];
      await generator.generate(event, session, toolResults: toolResults);

      expect(captureGenerator.lastToolResults, toolResults);
    });
  });
}

/// A generator that always throws for testing fallback behavior.
class _FailingGenerator implements ResponseGenerator {
  @override
  Future<ChannelResponse> generate(
    ChannelEvent event,
    Session session, {
    List<ToolExecutionResult>? toolResults,
  }) async {
    throw Exception('Generator failed');
  }
}

/// A generator that captures toolResults for verification.
class _CapturingGenerator implements ResponseGenerator {
  List<ToolExecutionResult>? lastToolResults;

  @override
  Future<ChannelResponse> generate(
    ChannelEvent event,
    Session session, {
    List<ToolExecutionResult>? toolResults,
  }) async {
    lastToolResults = toolResults;
    return ChannelResponse.text(
      conversation: event.conversation,
      text: 'Captured',
    );
  }
}
