import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('Session', () {
    final conversation = ConversationKey(
      channelType: 'slack',
      tenantId: 'T123',
      roomId: 'C456',
    );

    final identity = ChannelIdentity.user(id: 'U123', displayName: 'Test User');
    final principal = Principal.basic(identity: identity, tenantId: 'T123');
    final now = DateTime.now();

    test('creates session with required fields', () {
      final session = Session(
        id: 'session_123',
        conversation: conversation,
        principal: principal,
        state: SessionState.active,
        createdAt: now,
        lastActivityAt: now,
      );

      expect(session.id, 'session_123');
      expect(session.conversation, conversation);
      expect(session.state, SessionState.active);
      expect(session.history, isEmpty);
    });

    test('addMessage returns new session with message added', () {
      final session = Session(
        id: 'session_123',
        conversation: conversation,
        principal: principal,
        state: SessionState.active,
        createdAt: now,
        lastActivityAt: now,
      );

      final updatedSession = session.addMessage(SessionMessage.user(
        content: 'Hello',
        eventId: 'evt_1',
      ));

      expect(session.history, isEmpty);
      expect(updatedSession.history, hasLength(1));
      expect(updatedSession.history.first.role, MessageRole.user);
      expect(updatedSession.history.first.content, 'Hello');
    });

    test('isActive returns true for active non-expired session', () {
      final session = Session(
        id: 'session_123',
        conversation: conversation,
        principal: principal,
        state: SessionState.active,
        createdAt: now,
        lastActivityAt: now,
      );

      expect(session.isActive, isTrue);
    });

    test('isExpired returns true for expired session', () {
      final session = Session(
        id: 'session_123',
        conversation: conversation,
        principal: principal,
        state: SessionState.expired,
        createdAt: now,
        lastActivityAt: now,
      );

      expect(session.isExpired, isTrue);
    });

    test('close returns session with closed state', () {
      final session = Session(
        id: 'session_123',
        conversation: conversation,
        principal: principal,
        state: SessionState.active,
        createdAt: now,
        lastActivityAt: now,
      );

      final closedSession = session.close();

      expect(closedSession.state, SessionState.closed);
      expect(closedSession.isClosed, isTrue);
    });

    test('updateContext adds context value', () {
      final session = Session(
        id: 'session_123',
        conversation: conversation,
        principal: principal,
        state: SessionState.active,
        createdAt: now,
        lastActivityAt: now,
      );

      final updatedSession = session.updateContext('key', 'value');

      expect(updatedSession.context['key'], 'value');
    });
  });

  group('SessionMessage', () {
    test('user creates user message', () {
      final message = SessionMessage.user(
        content: 'Hello',
        eventId: 'evt_123',
      );

      expect(message.role, MessageRole.user);
      expect(message.content, 'Hello');
      expect(message.eventId, 'evt_123');
    });

    test('assistant creates assistant message', () {
      final message = SessionMessage.assistant(
        content: 'Hi there!',
      );

      expect(message.role, MessageRole.assistant);
      expect(message.content, 'Hi there!');
    });

    test('system creates system message', () {
      final message = SessionMessage.system(
        content: 'You are a helpful assistant',
      );

      expect(message.role, MessageRole.system);
      expect(message.content, 'You are a helpful assistant');
    });

    test('tool creates tool message', () {
      final message = SessionMessage.tool(
        content: 'Tool result',
        result: ToolResult(
          callId: 'call_123',
          name: 'test_tool',
          content: 'Result data',
        ),
      );

      expect(message.role, MessageRole.tool);
      expect(message.toolResult, isNotNull);
      expect(message.toolResult!.name, 'test_tool');
    });
  });

  group('SessionManager', () {
    late InMemorySessionStore store;
    late SessionManager manager;

    setUp(() {
      store = InMemorySessionStore();
      manager = SessionManager(store);
    });

    test('creates new session for new event', () async {
      final event = ChannelEvent.message(
        eventId: 'evt_123',
        channelType: 'slack',
        identity: ChannelIdentity.user(id: 'U123'),
        conversation: ConversationKey(
          channelType: 'slack',
          tenantId: 'T123',
          roomId: 'C456',
        ),
        text: 'Hello',
      );

      final session = await manager.getOrCreateSession(event);

      expect(session, isNotNull);
      expect(session.conversation.roomId, 'C456');
    });

    test('returns existing session for same conversation', () async {
      final conversation = ConversationKey(
        channelType: 'slack',
        tenantId: 'T123',
        roomId: 'C456',
      );

      final event1 = ChannelEvent.message(
        eventId: 'evt_1',
        channelType: 'slack',
        identity: ChannelIdentity.user(id: 'U123'),
        conversation: conversation,
        text: 'First',
      );

      final event2 = ChannelEvent.message(
        eventId: 'evt_2',
        channelType: 'slack',
        identity: ChannelIdentity.user(id: 'U123'),
        conversation: conversation,
        text: 'Second',
      );

      final session1 = await manager.getOrCreateSession(event1);
      final session2 = await manager.getOrCreateSession(event2);

      expect(session1.id, session2.id);
    });

    tearDown(() {
      manager.dispose();
    });
  });
}
