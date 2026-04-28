import 'dart:async';

import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Shared test fixtures
  final channelIdentity = ChannelIdentity(
    platform: 'slack',
    channelId: 'T123',
  );

  final conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'C456',
    userId: 'U123',
  );

  final identity = ChannelIdentityInfo.user(
    id: 'U123',
    displayName: 'Test User',
  );

  final now = DateTime.utc(2025, 1, 15, 10, 0, 0);

  Principal makePrincipal({DateTime? authenticatedAt}) {
    return Principal(
      identity: identity,
      tenantId: 'T123',
      roles: const {'user'},
      permissions: const {},
      authenticatedAt: authenticatedAt ?? now,
    );
  }

  Session makeSession({
    String id = 'session_123',
    ConversationKey? conv,
    Principal? principal,
    SessionState state = SessionState.active,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    DateTime? expiresAt,
    Map<String, dynamic> context = const {},
    List<SessionMessage> history = const [],
    Map<String, dynamic>? metadata,
  }) {
    return Session(
      id: id,
      conversation: conv ?? conversation,
      principal: principal ?? makePrincipal(),
      state: state,
      createdAt: createdAt ?? now,
      lastActivityAt: lastActivityAt ?? now,
      expiresAt: expiresAt,
      context: context,
      history: history,
      metadata: metadata,
    );
  }

  // =========================================================================
  // Session
  // =========================================================================
  group('Session', () {
    test('creates session with required fields', () {
      final session = makeSession();

      expect(session.id, 'session_123');
      expect(session.conversation, conversation);
      expect(session.state, SessionState.active);
      expect(session.history, isEmpty);
      expect(session.context, isEmpty);
      expect(session.metadata, isNull);
      expect(session.expiresAt, isNull);
    });

    test('creates session with all optional fields', () {
      final expiresAt = now.add(const Duration(hours: 24));
      final msg = SessionMessage.user(
        content: 'Hello',
        eventId: 'evt_1',
        timestamp: now,
      );
      final session = makeSession(
        expiresAt: expiresAt,
        context: {'key': 'value'},
        history: [msg],
        metadata: {'source': 'test'},
      );

      expect(session.expiresAt, expiresAt);
      expect(session.context, {'key': 'value'});
      expect(session.history, hasLength(1));
      expect(session.metadata, {'source': 'test'});
    });

    group('fromJson', () {
      test('parses all fields including context, history, metadata', () {
        final expiresAt = now.add(const Duration(hours: 24));
        final json = {
          'id': 'session_abc',
          'conversation': {
            'channel': {'platform': 'slack', 'channelId': 'T123'},
            'conversationId': 'C456',
            'userId': 'U123',
          },
          'principal': {
            'identity': {'id': 'U123', 'type': 'user'},
            'tenantId': 'T123',
            'roles': ['user'],
            'permissions': [],
            'authenticatedAt': now.toIso8601String(),
          },
          'state': 'active',
          'createdAt': now.toIso8601String(),
          'lastActivityAt': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
          'context': {'intent': 'greeting'},
          'history': [
            {
              'role': 'user',
              'content': 'Hello',
              'timestamp': now.toIso8601String(),
              'eventId': 'evt_1',
            },
          ],
          'metadata': {'source': 'test'},
        };

        final session = Session.fromJson(json);

        expect(session.id, 'session_abc');
        expect(session.conversation.conversationId, 'C456');
        expect(session.principal.identity.id, 'U123');
        expect(session.state, SessionState.active);
        expect(session.createdAt, now);
        expect(session.lastActivityAt, now);
        expect(session.expiresAt, expiresAt);
        expect(session.context['intent'], 'greeting');
        expect(session.history, hasLength(1));
        expect(session.history.first.content, 'Hello');
        expect(session.metadata, {'source': 'test'});
      });

      test('parses with null context and history to defaults', () {
        final json = {
          'id': 'session_abc',
          'conversation': {
            'channel': {'platform': 'slack', 'channelId': 'T123'},
            'conversationId': 'C456',
          },
          'principal': {
            'identity': {'id': 'U123', 'type': 'user'},
            'tenantId': 'T123',
            'roles': ['user'],
            'permissions': [],
            'authenticatedAt': now.toIso8601String(),
          },
          'state': 'active',
          'createdAt': now.toIso8601String(),
          'lastActivityAt': now.toIso8601String(),
        };

        final session = Session.fromJson(json);

        expect(session.context, isEmpty);
        expect(session.history, isEmpty);
        expect(session.expiresAt, isNull);
        expect(session.metadata, isNull);
      });

      test('parses unknown state as expired (fallback via orElse)', () {
        final json = {
          'id': 'session_abc',
          'conversation': {
            'channel': {'platform': 'slack', 'channelId': 'T123'},
            'conversationId': 'C456',
          },
          'principal': {
            'identity': {'id': 'U123', 'type': 'user'},
            'tenantId': 'T123',
            'roles': ['user'],
            'permissions': [],
            'authenticatedAt': now.toIso8601String(),
          },
          'state': 'unknown_state',
          'createdAt': now.toIso8601String(),
          'lastActivityAt': now.toIso8601String(),
        };

        final session = Session.fromJson(json);

        expect(session.state, SessionState.expired);
      });
    });

    group('isExpired', () {
      test('returns true when state is expired', () {
        final session = makeSession(state: SessionState.expired);
        expect(session.isExpired, isTrue);
      });

      test('returns true when expiresAt is in the past', () {
        final session = makeSession(
          state: SessionState.active,
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(session.isExpired, isTrue);
      });

      test('returns false when active and no expiresAt', () {
        final session = makeSession(state: SessionState.active);
        expect(session.isExpired, isFalse);
      });

      test('returns false when active and expiresAt is in the future', () {
        final session = makeSession(
          state: SessionState.active,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
        expect(session.isExpired, isFalse);
      });
    });

    group('isActive', () {
      test('returns true for active and not expired session', () {
        final session = makeSession(
          state: SessionState.active,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
        expect(session.isActive, isTrue);
      });

      test('returns false for active but expired session', () {
        final session = makeSession(
          state: SessionState.active,
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(session.isActive, isFalse);
      });

      test('returns false for paused session', () {
        final session = makeSession(state: SessionState.paused);
        expect(session.isActive, isFalse);
      });

      test('returns false for closed session', () {
        final session = makeSession(state: SessionState.closed);
        expect(session.isActive, isFalse);
      });

      test('returns false for expired state session', () {
        final session = makeSession(state: SessionState.expired);
        expect(session.isActive, isFalse);
      });
    });

    group('isClosed', () {
      test('returns true when state is closed', () {
        final session = makeSession(state: SessionState.closed);
        expect(session.isClosed, isTrue);
      });

      test('returns false when state is active', () {
        final session = makeSession(state: SessionState.active);
        expect(session.isClosed, isFalse);
      });

      test('returns false when state is paused', () {
        final session = makeSession(state: SessionState.paused);
        expect(session.isClosed, isFalse);
      });

      test('returns false when state is expired', () {
        final session = makeSession(state: SessionState.expired);
        expect(session.isClosed, isFalse);
      });
    });

    group('state transitions', () {
      test('touch updates lastActivityAt', () {
        final session = makeSession();
        final touched = session.touch();

        expect(touched.id, session.id);
        expect(touched.state, SessionState.active);
        expect(touched.lastActivityAt.isAfter(now) || touched.lastActivityAt == now, isTrue);
      });

      test('pause sets state to paused', () {
        final session = makeSession(state: SessionState.active);
        final paused = session.pause();

        expect(paused.state, SessionState.paused);
        expect(paused.id, session.id);
      });

      test('resume from paused changes state to active', () {
        final session = makeSession(state: SessionState.paused);
        final resumed = session.resume();

        expect(resumed.state, SessionState.active);
        expect(resumed.lastActivityAt.millisecondsSinceEpoch,
            greaterThanOrEqualTo(now.millisecondsSinceEpoch));
      });

      test('resume from non-paused returns same instance', () {
        final session = makeSession(state: SessionState.active);
        final resumed = session.resume();

        expect(identical(resumed, session), isTrue);
      });

      test('resume from closed returns same instance', () {
        final session = makeSession(state: SessionState.closed);
        final resumed = session.resume();

        expect(identical(resumed, session), isTrue);
      });

      test('resume from expired returns same instance', () {
        final session = makeSession(state: SessionState.expired);
        final resumed = session.resume();

        expect(identical(resumed, session), isTrue);
      });

      test('close sets state to closed', () {
        final session = makeSession(state: SessionState.active);
        final closed = session.close();

        expect(closed.state, SessionState.closed);
        expect(closed.isClosed, isTrue);
      });

      test('expire sets state to expired', () {
        final session = makeSession(state: SessionState.active);
        final expired = session.expire();

        expect(expired.state, SessionState.expired);
        expect(expired.isExpired, isTrue);
      });
    });

    group('context operations', () {
      test('addMessage adds to history and updates lastActivityAt', () {
        final session = makeSession();
        final msg = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_1',
        );

        final updated = session.addMessage(msg);

        expect(session.history, isEmpty);
        expect(updated.history, hasLength(1));
        expect(updated.history.first.role, MessageRole.user);
        expect(updated.history.first.content, 'Hello');
        expect(
            updated.lastActivityAt.millisecondsSinceEpoch,
            greaterThanOrEqualTo(now.millisecondsSinceEpoch));
      });

      test('addMessage appends to existing history', () {
        final msg1 = SessionMessage.user(
          content: 'First',
          eventId: 'evt_1',
          timestamp: now,
        );
        final session = makeSession(history: [msg1]);

        final msg2 = SessionMessage.assistant(
          content: 'Second',
        );
        final updated = session.addMessage(msg2);

        expect(updated.history, hasLength(2));
        expect(updated.history[0].content, 'First');
        expect(updated.history[1].content, 'Second');
      });

      test('updateContext adds key-value to context', () {
        final session = makeSession();
        final updated = session.updateContext('key', 'value');

        expect(updated.context['key'], 'value');
        expect(
            updated.lastActivityAt.millisecondsSinceEpoch,
            greaterThanOrEqualTo(now.millisecondsSinceEpoch));
      });

      test('updateContext overwrites existing key', () {
        final session = makeSession(context: {'key': 'old'});
        final updated = session.updateContext('key', 'new');

        expect(updated.context['key'], 'new');
      });

      test('removeContext removes key from context', () {
        final session = makeSession(context: {'key1': 'v1', 'key2': 'v2'});
        final updated = session.removeContext('key1');

        expect(updated.context.containsKey('key1'), isFalse);
        expect(updated.context['key2'], 'v2');
      });

      test('removeContext with non-existent key returns updated session', () {
        final session = makeSession(context: {'key': 'value'});
        final updated = session.removeContext('nonexistent');

        expect(updated.context, {'key': 'value'});
      });

      test('clearContext removes all context', () {
        final session = makeSession(context: {'a': 1, 'b': 2, 'c': 3});
        final updated = session.clearContext();

        expect(updated.context, isEmpty);
        expect(
            updated.lastActivityAt.millisecondsSinceEpoch,
            greaterThanOrEqualTo(now.millisecondsSinceEpoch));
      });
    });

    group('trimHistory', () {
      test('returns same session when already within limit', () {
        final msg = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_1',
          timestamp: now,
        );
        final session = makeSession(history: [msg]);
        final trimmed = session.trimHistory(10);

        expect(identical(trimmed, session), isTrue);
      });

      test('trims history when exceeds limit', () {
        final messages = List.generate(
          5,
          (i) => SessionMessage.user(
            content: 'Message $i',
            eventId: 'evt_$i',
            timestamp: now,
          ),
        );
        final session = makeSession(history: messages);
        final trimmed = session.trimHistory(3);

        expect(trimmed.history, hasLength(3));
        expect(trimmed.history[0].content, 'Message 2');
        expect(trimmed.history[1].content, 'Message 3');
        expect(trimmed.history[2].content, 'Message 4');
      });

      test('returns same session when history length equals limit', () {
        final messages = List.generate(
          3,
          (i) => SessionMessage.user(
            content: 'Message $i',
            eventId: 'evt_$i',
            timestamp: now,
          ),
        );
        final session = makeSession(history: messages);
        final trimmed = session.trimHistory(3);

        expect(identical(trimmed, session), isTrue);
      });
    });

    group('toJson', () {
      test('serializes all fields including expiresAt and metadata', () {
        final expiresAt = now.add(const Duration(hours: 24));
        final msg = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_1',
          timestamp: now,
        );
        final session = makeSession(
          expiresAt: expiresAt,
          context: {'intent': 'greeting'},
          history: [msg],
          metadata: {'source': 'test'},
        );

        final json = session.toJson();

        expect(json['id'], 'session_123');
        expect(json['conversation'], isA<Map<String, dynamic>>());
        expect(json['principal'], isA<Map<String, dynamic>>());
        expect(json['state'], 'active');
        expect(json['createdAt'], now.toIso8601String());
        expect(json['lastActivityAt'], now.toIso8601String());
        expect(json['expiresAt'], expiresAt.toIso8601String());
        expect(json['context'], {'intent': 'greeting'});
        expect(json['history'], isA<List>());
        expect((json['history'] as List), hasLength(1));
        expect(json['metadata'], {'source': 'test'});
      });

      test('omits expiresAt when null', () {
        final session = makeSession();
        final json = session.toJson();

        expect(json.containsKey('expiresAt'), isFalse);
      });

      test('omits metadata when null', () {
        final session = makeSession();
        final json = session.toJson();

        expect(json.containsKey('metadata'), isFalse);
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final session = makeSession();
        final newConv = ConversationKey(
          channel: ChannelIdentity(platform: 'discord', channelId: 'D123'),
          conversationId: 'D456',
        );
        final newPrincipal = Principal.admin(
          identity: ChannelIdentityInfo.user(id: 'U999'),
          tenantId: 'T999',
        );
        final newCreatedAt = now.add(const Duration(hours: 1));
        final newLastActivity = now.add(const Duration(hours: 2));
        final newExpires = now.add(const Duration(hours: 48));
        final newMsg = SessionMessage.system(
          content: 'System',
          timestamp: now,
        );

        final copied = session.copyWith(
          id: 'session_999',
          conversation: newConv,
          principal: newPrincipal,
          state: SessionState.paused,
          createdAt: newCreatedAt,
          lastActivityAt: newLastActivity,
          expiresAt: newExpires,
          context: {'new': true},
          history: [newMsg],
          metadata: {'copy': true},
        );

        expect(copied.id, 'session_999');
        expect(copied.conversation, newConv);
        expect(copied.principal, newPrincipal);
        expect(copied.state, SessionState.paused);
        expect(copied.createdAt, newCreatedAt);
        expect(copied.lastActivityAt, newLastActivity);
        expect(copied.expiresAt, newExpires);
        expect(copied.context, {'new': true});
        expect(copied.history, hasLength(1));
        expect(copied.metadata, {'copy': true});
      });

      test('retains original values when no overrides', () {
        final session = makeSession(
          context: {'key': 'value'},
          metadata: {'m': 1},
        );
        final copied = session.copyWith();

        expect(copied.id, session.id);
        expect(copied.conversation, session.conversation);
        expect(copied.state, session.state);
        expect(copied.context, session.context);
        expect(copied.metadata, session.metadata);
      });
    });

    group('equality', () {
      test('equal when same id', () {
        final session1 = makeSession(id: 'same_id');
        final session2 = makeSession(
          id: 'same_id',
          state: SessionState.paused,
        );

        expect(session1 == session2, isTrue);
      });

      test('not equal when different id', () {
        final session1 = makeSession(id: 'id_1');
        final session2 = makeSession(id: 'id_2');

        expect(session1 == session2, isFalse);
      });

      test('not equal to different type', () {
        final session = makeSession();
        expect(session == Object(), isFalse);
      });
    });

    group('hashCode', () {
      test('same for sessions with same id', () {
        final session1 = makeSession(id: 'same');
        final session2 = makeSession(id: 'same');

        expect(session1.hashCode, session2.hashCode);
      });

      test('based on id', () {
        final session = makeSession(id: 'test_id');
        expect(session.hashCode, 'test_id'.hashCode);
      });
    });

    group('toString', () {
      test('returns formatted string with id, state, and conversationId', () {
        final session = makeSession();
        final str = session.toString();

        expect(str, contains('Session'));
        expect(str, contains('session_123'));
        expect(str, contains('active'));
        expect(str, contains('C456'));
      });
    });
  });

  // =========================================================================
  // SessionMessage
  // =========================================================================
  group('SessionMessage', () {
    group('user factory', () {
      test('creates user message with eventId', () {
        final ts = DateTime.utc(2025, 1, 15, 10, 0, 0);
        final message = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_123',
          timestamp: ts,
          metadata: {'source': 'test'},
        );

        expect(message.role, MessageRole.user);
        expect(message.content, 'Hello');
        expect(message.eventId, 'evt_123');
        expect(message.timestamp, ts);
        expect(message.metadata, {'source': 'test'});
        expect(message.toolCalls, isNull);
        expect(message.toolResult, isNull);
      });

      test('creates user message with default timestamp', () {
        final before = DateTime.now();
        final message = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_1',
        );
        final after = DateTime.now();

        expect(message.timestamp.millisecondsSinceEpoch,
            greaterThanOrEqualTo(before.millisecondsSinceEpoch));
        expect(message.timestamp.millisecondsSinceEpoch,
            lessThanOrEqualTo(after.millisecondsSinceEpoch));
      });
    });

    group('assistant factory', () {
      test('creates assistant message with toolCalls', () {
        final toolCalls = [
          SessionToolCall(
            name: 'search',
            arguments: {'query': 'test'},
            id: 'call_1',
          ),
        ];
        final message = SessionMessage.assistant(
          content: 'Let me search...',
          toolCalls: toolCalls,
          metadata: {'model': 'gpt-4'},
        );

        expect(message.role, MessageRole.assistant);
        expect(message.content, 'Let me search...');
        expect(message.toolCalls, hasLength(1));
        expect(message.toolCalls!.first.name, 'search');
        expect(message.eventId, isNull);
        expect(message.toolResult, isNull);
        expect(message.metadata, {'model': 'gpt-4'});
      });

      test('creates assistant message without toolCalls', () {
        final message = SessionMessage.assistant(content: 'Hi there!');

        expect(message.role, MessageRole.assistant);
        expect(message.toolCalls, isNull);
      });

      test('creates assistant message with default timestamp', () {
        final before = DateTime.now();
        final message = SessionMessage.assistant(content: 'Response');
        final after = DateTime.now();

        expect(message.timestamp.millisecondsSinceEpoch,
            greaterThanOrEqualTo(before.millisecondsSinceEpoch));
        expect(message.timestamp.millisecondsSinceEpoch,
            lessThanOrEqualTo(after.millisecondsSinceEpoch));
      });
    });

    group('system factory', () {
      test('creates system message', () {
        final ts = DateTime.utc(2025, 1, 15);
        final message = SessionMessage.system(
          content: 'You are a helpful assistant',
          timestamp: ts,
          metadata: {'priority': 'high'},
        );

        expect(message.role, MessageRole.system);
        expect(message.content, 'You are a helpful assistant');
        expect(message.timestamp, ts);
        expect(message.metadata, {'priority': 'high'});
        expect(message.eventId, isNull);
        expect(message.toolCalls, isNull);
        expect(message.toolResult, isNull);
      });

      test('creates system message with default timestamp', () {
        final before = DateTime.now();
        final message = SessionMessage.system(content: 'System prompt');
        final after = DateTime.now();

        expect(message.timestamp.millisecondsSinceEpoch,
            greaterThanOrEqualTo(before.millisecondsSinceEpoch));
        expect(message.timestamp.millisecondsSinceEpoch,
            lessThanOrEqualTo(after.millisecondsSinceEpoch));
      });
    });

    group('tool factory', () {
      test('creates tool message with toolResult', () {
        final result = SessionToolResult(
          toolName: 'search',
          content: 'Found 5 results',
          success: true,
        );
        final message = SessionMessage.tool(
          content: 'Search completed',
          result: result,
          metadata: {'duration_ms': 150},
        );

        expect(message.role, MessageRole.tool);
        expect(message.content, 'Search completed');
        expect(message.toolResult, isNotNull);
        expect(message.toolResult!.toolName, 'search');
        expect(message.toolResult!.content, 'Found 5 results');
        expect(message.toolResult!.success, isTrue);
        expect(message.metadata, {'duration_ms': 150});
        expect(message.eventId, isNull);
        expect(message.toolCalls, isNull);
      });

      test('creates tool message with default timestamp', () {
        final result = SessionToolResult(
          toolName: 'test',
          content: 'result',
        );
        final before = DateTime.now();
        final message = SessionMessage.tool(
          content: 'Done',
          result: result,
        );
        final after = DateTime.now();

        expect(message.timestamp.millisecondsSinceEpoch,
            greaterThanOrEqualTo(before.millisecondsSinceEpoch));
        expect(message.timestamp.millisecondsSinceEpoch,
            lessThanOrEqualTo(after.millisecondsSinceEpoch));
      });
    });

    group('fromJson', () {
      test('parses all fields including toolCalls and toolResult', () {
        final ts = DateTime.utc(2025, 1, 15);
        final json = {
          'role': 'assistant',
          'content': 'Let me search',
          'timestamp': ts.toIso8601String(),
          'toolCalls': [
            {
              'name': 'search',
              'arguments': {'query': 'test'},
              'id': 'call_1',
            },
          ],
          'metadata': {'model': 'gpt-4'},
        };

        final message = SessionMessage.fromJson(json);

        expect(message.role, MessageRole.assistant);
        expect(message.content, 'Let me search');
        expect(message.timestamp, ts);
        expect(message.toolCalls, hasLength(1));
        expect(message.toolCalls!.first.name, 'search');
        expect(message.toolCalls!.first.id, 'call_1');
        expect(message.metadata, {'model': 'gpt-4'});
        expect(message.eventId, isNull);
        expect(message.toolResult, isNull);
      });

      test('parses tool message with toolResult', () {
        final ts = DateTime.utc(2025, 1, 15);
        final json = {
          'role': 'tool',
          'content': 'Result data',
          'timestamp': ts.toIso8601String(),
          'toolResult': {
            'toolName': 'search',
            'content': 'Found 3 results',
            'success': true,
          },
        };

        final message = SessionMessage.fromJson(json);

        expect(message.role, MessageRole.tool);
        expect(message.toolResult, isNotNull);
        expect(message.toolResult!.toolName, 'search');
        expect(message.toolResult!.success, isTrue);
      });

      test('parses user message with eventId', () {
        final ts = DateTime.utc(2025, 1, 15);
        final json = {
          'role': 'user',
          'content': 'Hello',
          'timestamp': ts.toIso8601String(),
          'eventId': 'evt_123',
        };

        final message = SessionMessage.fromJson(json);

        expect(message.role, MessageRole.user);
        expect(message.eventId, 'evt_123');
      });

      test('parses with unknown role falling back to user', () {
        final ts = DateTime.utc(2025, 1, 15);
        final json = {
          'role': 'unknown_role',
          'content': 'Message',
          'timestamp': ts.toIso8601String(),
        };

        final message = SessionMessage.fromJson(json);

        expect(message.role, MessageRole.user);
      });

      test('parses without optional fields', () {
        final ts = DateTime.utc(2025, 1, 15);
        final json = {
          'role': 'system',
          'content': 'Prompt',
          'timestamp': ts.toIso8601String(),
        };

        final message = SessionMessage.fromJson(json);

        expect(message.eventId, isNull);
        expect(message.toolCalls, isNull);
        expect(message.toolResult, isNull);
        expect(message.metadata, isNull);
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final original = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_1',
          timestamp: now,
        );
        final newTimestamp = now.add(const Duration(hours: 1));
        final toolCalls = [
          SessionToolCall(name: 'tool', arguments: {}),
        ];
        final toolResult = SessionToolResult(
          toolName: 'tool',
          content: 'result',
        );

        final copied = original.copyWith(
          role: MessageRole.assistant,
          content: 'World',
          timestamp: newTimestamp,
          eventId: 'evt_2',
          toolCalls: toolCalls,
          toolResult: toolResult,
          metadata: {'new': true},
        );

        expect(copied.role, MessageRole.assistant);
        expect(copied.content, 'World');
        expect(copied.timestamp, newTimestamp);
        expect(copied.eventId, 'evt_2');
        expect(copied.toolCalls, toolCalls);
        expect(copied.toolResult, toolResult);
        expect(copied.metadata, {'new': true});
      });

      test('retains original values when no overrides', () {
        final original = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_1',
          timestamp: now,
          metadata: {'key': 'value'},
        );

        final copied = original.copyWith();

        expect(copied.role, original.role);
        expect(copied.content, original.content);
        expect(copied.timestamp, original.timestamp);
        expect(copied.eventId, original.eventId);
        expect(copied.metadata, original.metadata);
      });
    });

    group('toJson', () {
      test('serializes all fields including optional ones', () {
        final ts = DateTime.utc(2025, 1, 15);
        final toolCalls = [
          SessionToolCall(
            name: 'search',
            arguments: {'q': 'test'},
            id: 'call_1',
          ),
        ];
        final message = SessionMessage.assistant(
          content: 'Searching...',
          toolCalls: toolCalls,
          timestamp: ts,
          metadata: {'model': 'gpt-4'},
        );

        final json = message.toJson();

        expect(json['role'], 'assistant');
        expect(json['content'], 'Searching...');
        expect(json['timestamp'], ts.toIso8601String());
        expect(json['toolCalls'], isA<List>());
        expect((json['toolCalls'] as List), hasLength(1));
        expect(json['metadata'], {'model': 'gpt-4'});
        expect(json.containsKey('eventId'), isFalse);
        expect(json.containsKey('toolResult'), isFalse);
      });

      test('serializes user message with eventId', () {
        final ts = DateTime.utc(2025, 1, 15);
        final message = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_123',
          timestamp: ts,
        );

        final json = message.toJson();

        expect(json['eventId'], 'evt_123');
        expect(json.containsKey('toolCalls'), isFalse);
        expect(json.containsKey('toolResult'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });

      test('serializes tool message with toolResult', () {
        final ts = DateTime.utc(2025, 1, 15);
        final result = SessionToolResult(
          toolName: 'tool',
          content: 'result',
        );
        final message = SessionMessage.tool(
          content: 'Done',
          result: result,
          timestamp: ts,
        );

        final json = message.toJson();

        expect(json['role'], 'tool');
        expect(json['toolResult'], isA<Map<String, dynamic>>());
        expect(
            (json['toolResult'] as Map<String, dynamic>)['toolName'], 'tool');
      });

      test('omits optional fields when null', () {
        final ts = DateTime.utc(2025, 1, 15);
        final message = SessionMessage.system(
          content: 'Prompt',
          timestamp: ts,
        );

        final json = message.toJson();

        expect(json.containsKey('eventId'), isFalse);
        expect(json.containsKey('toolCalls'), isFalse);
        expect(json.containsKey('toolResult'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });
    });

    group('toString', () {
      test('returns short content as-is', () {
        final message = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_1',
        );

        final str = message.toString();

        expect(str, contains('user'));
        expect(str, contains('Hello'));
        expect(str, isNot(contains('...')));
      });

      test('truncates long content at 50 characters', () {
        final longContent =
            'This is a very long message that exceeds the fifty character limit for display';
        final message = SessionMessage.user(
          content: longContent,
          eventId: 'evt_1',
        );

        final str = message.toString();

        expect(str, contains('...'));
        expect(str, contains(longContent.substring(0, 50)));
        // The full content should not appear
        expect(str, isNot(contains(longContent)));
      });

      test('shows exactly 50 chars without truncation', () {
        // Exactly 50 characters
        final content = 'a' * 50;
        final message = SessionMessage.user(
          content: content,
          eventId: 'evt_1',
        );

        final str = message.toString();

        expect(str, contains(content));
        expect(str, isNot(contains('...')));
      });

      test('truncates at 51+ characters', () {
        final content = 'a' * 51;
        final message = SessionMessage.user(
          content: content,
          eventId: 'evt_1',
        );

        final str = message.toString();

        expect(str, contains('...'));
      });
    });
  });

  // =========================================================================
  // SessionToolCall
  // =========================================================================
  group('SessionToolCall', () {
    test('constructor creates with all fields', () {
      final call = SessionToolCall(
        name: 'search',
        arguments: {'query': 'test', 'limit': 10},
        id: 'call_123',
      );

      expect(call.name, 'search');
      expect(call.arguments, {'query': 'test', 'limit': 10});
      expect(call.id, 'call_123');
    });

    test('constructor without optional id', () {
      final call = SessionToolCall(
        name: 'tool',
        arguments: {},
      );

      expect(call.id, isNull);
    });

    group('fromJson', () {
      test('parses all fields from JSON', () {
        final json = {
          'name': 'search',
          'arguments': {'query': 'test'},
          'id': 'call_1',
        };

        final call = SessionToolCall.fromJson(json);

        expect(call.name, 'search');
        expect(call.arguments, {'query': 'test'});
        expect(call.id, 'call_1');
      });

      test('parses without id', () {
        final json = {
          'name': 'tool',
          'arguments': {'key': 'value'},
        };

        final call = SessionToolCall.fromJson(json);

        expect(call.name, 'tool');
        expect(call.id, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields including id', () {
        final call = SessionToolCall(
          name: 'search',
          arguments: {'q': 'test'},
          id: 'call_1',
        );

        final json = call.toJson();

        expect(json['name'], 'search');
        expect(json['arguments'], {'q': 'test'});
        expect(json['id'], 'call_1');
      });

      test('omits id when null', () {
        final call = SessionToolCall(
          name: 'tool',
          arguments: {},
        );

        final json = call.toJson();

        expect(json['name'], 'tool');
        expect(json['arguments'], {});
        expect(json.containsKey('id'), isFalse);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final call = SessionToolCall(
          name: 'search',
          arguments: {'q': 'test'},
          id: 'call_1',
        );

        final str = call.toString();

        expect(str, contains('SessionToolCall'));
        expect(str, contains('search'));
        expect(str, contains('call_1'));
      });

      test('shows null id', () {
        final call = SessionToolCall(
          name: 'tool',
          arguments: {},
        );

        final str = call.toString();

        expect(str, contains('tool'));
        expect(str, contains('null'));
      });
    });
  });

  // =========================================================================
  // SessionToolResult
  // =========================================================================
  group('SessionToolResult', () {
    test('constructor creates with all fields', () {
      final result = SessionToolResult(
        toolName: 'search',
        content: 'Found 5 results',
        success: true,
        error: null,
      );

      expect(result.toolName, 'search');
      expect(result.content, 'Found 5 results');
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('constructor with default success=true', () {
      final result = SessionToolResult(
        toolName: 'tool',
        content: 'Done',
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('constructor with failure and error', () {
      final result = SessionToolResult(
        toolName: 'tool',
        content: '',
        success: false,
        error: 'Timeout occurred',
      );

      expect(result.success, isFalse);
      expect(result.error, 'Timeout occurred');
    });

    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'toolName': 'search',
          'content': 'Results',
          'success': true,
          'error': null,
        };

        final result = SessionToolResult.fromJson(json);

        expect(result.toolName, 'search');
        expect(result.content, 'Results');
        expect(result.success, isTrue);
        expect(result.error, isNull);
      });

      test('defaults success to true when not present', () {
        final json = {
          'toolName': 'tool',
          'content': 'Done',
        };

        final result = SessionToolResult.fromJson(json);

        expect(result.success, isTrue);
      });

      test('parses failure with error', () {
        final json = {
          'toolName': 'tool',
          'content': '',
          'success': false,
          'error': 'Something went wrong',
        };

        final result = SessionToolResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, 'Something went wrong');
      });
    });

    group('toJson', () {
      test('serializes all fields including error', () {
        final result = SessionToolResult(
          toolName: 'search',
          content: 'Results',
          success: false,
          error: 'Timeout',
        );

        final json = result.toJson();

        expect(json['toolName'], 'search');
        expect(json['content'], 'Results');
        expect(json['success'], isFalse);
        expect(json['error'], 'Timeout');
      });

      test('omits error when null', () {
        final result = SessionToolResult(
          toolName: 'tool',
          content: 'Done',
        );

        final json = result.toJson();

        expect(json['toolName'], 'tool');
        expect(json['content'], 'Done');
        expect(json['success'], isTrue);
        expect(json.containsKey('error'), isFalse);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final result = SessionToolResult(
          toolName: 'search',
          content: 'Results',
          success: true,
        );

        final str = result.toString();

        expect(str, contains('SessionToolResult'));
        expect(str, contains('search'));
        expect(str, contains('true'));
      });

      test('shows success false', () {
        final result = SessionToolResult(
          toolName: 'tool',
          content: '',
          success: false,
        );

        final str = result.toString();

        expect(str, contains('false'));
      });
    });
  });

  // =========================================================================
  // SessionStoreConfig
  // =========================================================================
  group('SessionStoreConfig', () {
    test('constructor with defaults', () {
      final config = SessionStoreConfig();

      expect(config.defaultTimeout, const Duration(hours: 24));
      expect(config.maxHistorySize, 100);
      expect(config.cleanupInterval, const Duration(minutes: 15));
      expect(config.persistent, isFalse);
    });

    test('constructor with custom values', () {
      final config = SessionStoreConfig(
        defaultTimeout: const Duration(hours: 2),
        maxHistorySize: 50,
        cleanupInterval: const Duration(minutes: 5),
        persistent: true,
      );

      expect(config.defaultTimeout, const Duration(hours: 2));
      expect(config.maxHistorySize, 50);
      expect(config.cleanupInterval, const Duration(minutes: 5));
      expect(config.persistent, isTrue);
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final original = SessionStoreConfig();
        final copied = original.copyWith(
          defaultTimeout: const Duration(hours: 48),
          maxHistorySize: 200,
          cleanupInterval: const Duration(minutes: 30),
          persistent: true,
        );

        expect(copied.defaultTimeout, const Duration(hours: 48));
        expect(copied.maxHistorySize, 200);
        expect(copied.cleanupInterval, const Duration(minutes: 30));
        expect(copied.persistent, isTrue);
      });

      test('retains original values when no overrides', () {
        final original = SessionStoreConfig(
          defaultTimeout: const Duration(hours: 2),
          maxHistorySize: 50,
          cleanupInterval: const Duration(minutes: 5),
          persistent: true,
        );
        final copied = original.copyWith();

        expect(copied.defaultTimeout, const Duration(hours: 2));
        expect(copied.maxHistorySize, 50);
        expect(copied.cleanupInterval, const Duration(minutes: 5));
        expect(copied.persistent, isTrue);
      });
    });
  });

  // =========================================================================
  // SessionNotFound
  // =========================================================================
  group('SessionNotFound', () {
    test('constructor stores sessionId', () {
      final ex = SessionNotFound('session_123');
      expect(ex.sessionId, 'session_123');
    });

    test('toString returns formatted message', () {
      final ex = SessionNotFound('session_abc');
      expect(ex.toString(), 'SessionNotFound: session_abc');
    });

    test('is an Exception', () {
      final ex = SessionNotFound('id');
      expect(ex, isA<Exception>());
    });
  });

  // =========================================================================
  // InMemorySessionStore
  // =========================================================================
  group('InMemorySessionStore', () {
    late InMemorySessionStore store;

    setUp(() {
      store = InMemorySessionStore();
    });

    Session makeStoreSession({
      String id = 'session_1',
      ConversationKey? conv,
      SessionState state = SessionState.active,
      DateTime? lastActivityAt,
      DateTime? expiresAt,
    }) {
      return Session(
        id: id,
        conversation: conv ?? conversation,
        principal: Principal(
          identity: identity,
          tenantId: 'T123',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        ),
        state: state,
        createdAt: now,
        lastActivityAt: lastActivityAt ?? now,
        expiresAt: expiresAt,
      );
    }

    group('get', () {
      test('returns session when found', () async {
        final session = makeStoreSession();
        await store.save(session);

        final result = await store.get('session_1');

        expect(result, isNotNull);
        expect(result!.id, 'session_1');
      });

      test('returns null when not found', () async {
        final result = await store.get('nonexistent');
        expect(result, isNull);
      });
    });

    group('getByConversation', () {
      test('returns session when found', () async {
        final session = makeStoreSession();
        await store.save(session);

        final result = await store.getByConversation(conversation);

        expect(result, isNotNull);
        expect(result!.id, 'session_1');
      });

      test('returns null when not found', () async {
        final otherConv = ConversationKey(
          channel: ChannelIdentity(platform: 'discord', channelId: 'D123'),
          conversationId: 'D456',
        );

        final result = await store.getByConversation(otherConv);

        expect(result, isNull);
      });
    });

    group('getByUser', () {
      test('returns session when found', () async {
        final session = makeStoreSession();
        await store.save(session);

        final result = await store.getByUser('slack', 'U123');

        expect(result, isNotNull);
        expect(result!.id, 'session_1');
      });

      test('returns null when not found', () async {
        final result = await store.getByUser('slack', 'U999');
        expect(result, isNull);
      });

      test('returns null when no sessions saved', () async {
        final result = await store.getByUser('slack', 'U123');
        expect(result, isNull);
      });
    });

    group('save', () {
      test('saves session and updates indices', () async {
        final session = makeStoreSession();
        await store.save(session);

        expect(store.count, 1);
        expect(await store.get('session_1'), isNotNull);
        expect(await store.getByConversation(conversation), isNotNull);
        expect(await store.getByUser('slack', 'U123'), isNotNull);
      });

      test('overwrites existing session', () async {
        final session1 = makeStoreSession(state: SessionState.active);
        await store.save(session1);

        final session2 = makeStoreSession(state: SessionState.paused);
        await store.save(session2);

        expect(store.count, 1);
        final result = await store.get('session_1');
        expect(result!.state, SessionState.paused);
      });
    });

    group('delete', () {
      test('removes session and indices', () async {
        final session = makeStoreSession();
        await store.save(session);

        await store.delete('session_1');

        expect(store.count, 0);
        expect(await store.get('session_1'), isNull);
        expect(await store.getByConversation(conversation), isNull);
        expect(await store.getByUser('slack', 'U123'), isNull);
      });

      test('does nothing for non-existent id', () async {
        await store.delete('nonexistent');
        expect(store.count, 0);
      });

      test('does not affect other sessions', () async {
        final conv2 = ConversationKey(
          channel: ChannelIdentity(platform: 'slack', channelId: 'T123'),
          conversationId: 'C789',
        );
        final identity2 = ChannelIdentityInfo.user(id: 'U999');
        final session1 = makeStoreSession(id: 'session_1');
        final session2 = Session(
          id: 'session_2',
          conversation: conv2,
          principal: Principal(
            identity: identity2,
            tenantId: 'T123',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          state: SessionState.active,
          createdAt: now,
          lastActivityAt: now,
        );

        await store.save(session1);
        await store.save(session2);
        await store.delete('session_1');

        expect(store.count, 1);
        expect(await store.get('session_2'), isNotNull);
      });
    });

    group('cleanupExpired', () {
      test('removes expired sessions and returns count', () async {
        // Active session
        final active = makeStoreSession(
          id: 'active_1',
          state: SessionState.active,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );

        // Expired by state
        final conv2 = ConversationKey(
          channel: ChannelIdentity(platform: 'slack', channelId: 'T123'),
          conversationId: 'C789',
        );
        final expired1 = Session(
          id: 'expired_1',
          conversation: conv2,
          principal: Principal(
            identity: ChannelIdentityInfo.user(id: 'U200'),
            tenantId: 'T123',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          state: SessionState.expired,
          createdAt: now,
          lastActivityAt: now,
        );

        // Expired by expiresAt in the past
        final conv3 = ConversationKey(
          channel: ChannelIdentity(platform: 'slack', channelId: 'T123'),
          conversationId: 'C101',
        );
        final expired2 = Session(
          id: 'expired_2',
          conversation: conv3,
          principal: Principal(
            identity: ChannelIdentityInfo.user(id: 'U300'),
            tenantId: 'T123',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          state: SessionState.active,
          createdAt: now,
          lastActivityAt: now,
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        await store.save(active);
        await store.save(expired1);
        await store.save(expired2);

        final count = await store.cleanupExpired();

        expect(count, 2);
        expect(store.count, 1);
        expect(await store.get('active_1'), isNotNull);
        expect(await store.get('expired_1'), isNull);
        expect(await store.get('expired_2'), isNull);
      });

      test('returns 0 when no expired sessions', () async {
        final session = makeStoreSession(
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
        await store.save(session);

        final count = await store.cleanupExpired();

        expect(count, 0);
        expect(store.count, 1);
      });
    });

    group('list', () {
      test('returns empty list when no sessions', () async {
        final result = await store.list();
        expect(result, isEmpty);
      });

      test('returns all sessions sorted by lastActivityAt descending',
          () async {
        final conv1 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C001',
        );
        final conv2 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C002',
        );
        final conv3 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C003',
        );

        final session1 = makeStoreSession(
          id: 's1',
          conv: conv1,
          lastActivityAt: DateTime.utc(2025, 1, 1),
        );
        final session2 = makeStoreSession(
          id: 's2',
          conv: conv2,
          lastActivityAt: DateTime.utc(2025, 1, 3),
        );
        final session3 = makeStoreSession(
          id: 's3',
          conv: conv3,
          lastActivityAt: DateTime.utc(2025, 1, 2),
        );

        await store.save(session1);
        await store.save(session2);
        await store.save(session3);

        final result = await store.list();

        expect(result, hasLength(3));
        expect(result[0].id, 's2'); // Most recent
        expect(result[1].id, 's3');
        expect(result[2].id, 's1'); // Oldest
      });

      test('applies offset and limit', () async {
        final sessions = <Session>[];
        for (var i = 0; i < 5; i++) {
          final conv = ConversationKey(
            channel: channelIdentity,
            conversationId: 'C_$i',
          );
          sessions.add(Session(
            id: 's_$i',
            conversation: conv,
            principal: Principal(
              identity: ChannelIdentityInfo.user(id: 'U_$i'),
              tenantId: 'T123',
              roles: const {'user'},
              permissions: const {},
              authenticatedAt: now,
            ),
            state: SessionState.active,
            createdAt: now,
            lastActivityAt: now.add(Duration(hours: i)),
          ));
        }
        for (final s in sessions) {
          await store.save(s);
        }

        final result = await store.list(offset: 1, limit: 2);

        expect(result, hasLength(2));
        // Sorted desc: s_4, s_3, s_2, s_1, s_0
        // offset 1, limit 2 => s_3, s_2
        expect(result[0].id, 's_3');
        expect(result[1].id, 's_2');
      });

      test('filters by state', () async {
        final conv1 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_a',
        );
        final conv2 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_b',
        );
        final conv3 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_c',
        );

        final active = makeStoreSession(
          id: 's_active',
          conv: conv1,
          state: SessionState.active,
        );
        final paused = Session(
          id: 's_paused',
          conversation: conv2,
          principal: Principal(
            identity: ChannelIdentityInfo.user(id: 'U_b'),
            tenantId: 'T123',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          state: SessionState.paused,
          createdAt: now,
          lastActivityAt: now,
        );
        final closed = Session(
          id: 's_closed',
          conversation: conv3,
          principal: Principal(
            identity: ChannelIdentityInfo.user(id: 'U_c'),
            tenantId: 'T123',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          state: SessionState.closed,
          createdAt: now,
          lastActivityAt: now,
        );

        await store.save(active);
        await store.save(paused);
        await store.save(closed);

        final result = await store.list(state: SessionState.active);

        expect(result, hasLength(1));
        expect(result[0].id, 's_active');
      });

      test('returns empty list when offset exceeds session count', () async {
        final session = makeStoreSession();
        await store.save(session);

        final result = await store.list(offset: 10);

        expect(result, isEmpty);
      });

      test('handles limit larger than remaining items', () async {
        final conv1 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_x',
        );
        final conv2 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_y',
        );

        final s1 = makeStoreSession(id: 's1', conv: conv1);
        final s2 = Session(
          id: 's2',
          conversation: conv2,
          principal: Principal(
            identity: ChannelIdentityInfo.user(id: 'U_y'),
            tenantId: 'T123',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          state: SessionState.active,
          createdAt: now,
          lastActivityAt: now,
        );

        await store.save(s1);
        await store.save(s2);

        final result = await store.list(offset: 1, limit: 100);

        expect(result, hasLength(1));
      });
    });

    group('clear', () {
      test('removes all sessions', () async {
        await store.save(makeStoreSession(id: 's1'));

        final conv2 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_other',
        );
        await store.save(Session(
          id: 's2',
          conversation: conv2,
          principal: Principal(
            identity: ChannelIdentityInfo.user(id: 'U_other'),
            tenantId: 'T123',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          state: SessionState.active,
          createdAt: now,
          lastActivityAt: now,
        ));

        store.clear();

        expect(store.count, 0);
        expect(await store.get('s1'), isNull);
        expect(await store.get('s2'), isNull);
      });
    });

    group('count', () {
      test('returns 0 for empty store', () {
        expect(store.count, 0);
      });

      test('returns correct count after saves', () async {
        final conv1 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_1',
        );
        final conv2 = ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_2',
        );

        await store.save(makeStoreSession(id: 's1', conv: conv1));
        await store.save(Session(
          id: 's2',
          conversation: conv2,
          principal: Principal(
            identity: ChannelIdentityInfo.user(id: 'U_2'),
            tenantId: 'T123',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          state: SessionState.active,
          createdAt: now,
          lastActivityAt: now,
        ));

        expect(store.count, 2);
      });
    });
  });

  // =========================================================================
  // SessionManager
  // =========================================================================
  group('SessionManager', () {
    late InMemorySessionStore store;
    late SessionManager manager;

    setUp(() {
      store = InMemorySessionStore();
      manager = SessionManager(store);
    });

    tearDown(() {
      manager.dispose();
    });

    ChannelEvent makeEvent({
      String id = 'evt_1',
      String conversationId = 'C456',
      String? userId = 'U123',
      String? userName = 'Test User',
    }) {
      return ChannelEvent.message(
        id: id,
        conversation: ConversationKey(
          channel: channelIdentity,
          conversationId: conversationId,
          userId: userId,
        ),
        text: 'Hello',
        userId: userId,
        userName: userName,
      );
    }

    group('constructor', () {
      test('creates with default config', () {
        final mgr = SessionManager(store);
        addTearDown(() => mgr.dispose());

        // Verify it works - no exception thrown
        expect(mgr, isNotNull);
      });

      test('creates with custom config', () {
        final config = SessionStoreConfig(
          defaultTimeout: const Duration(hours: 2),
          maxHistorySize: 50,
        );
        final mgr = SessionManager(store, config: config);
        addTearDown(() => mgr.dispose());

        expect(mgr, isNotNull);
      });
    });

    group('getOrCreateSession', () {
      test('creates new session for new event', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);

        expect(session, isNotNull);
        expect(session.conversation.conversationId, 'C456');
        expect(session.state, SessionState.active);
        expect(session.principal.identity.id, 'U123');
        expect(session.expiresAt, isNotNull);
      });

      test('returns existing active session', () async {
        final event1 = makeEvent(id: 'evt_1');
        final event2 = makeEvent(id: 'evt_2');

        final session1 = await manager.getOrCreateSession(event1);
        final session2 = await manager.getOrCreateSession(event2);

        expect(session1.id, session2.id);
      });

      test('creates new session when existing is not active (expired)',
          () async {
        final event = makeEvent();
        final session1 = await manager.getOrCreateSession(event);

        // Expire the session
        final expired = session1.expire();
        await store.save(expired);

        final session2 = await manager.getOrCreateSession(event);

        expect(session2.id, isNot(session1.id));
        expect(session2.state, SessionState.active);
      });

      test('creates new session when existing is closed', () async {
        final event = makeEvent();
        final session1 = await manager.getOrCreateSession(event);

        // Close the session
        final closed = session1.close();
        await store.save(closed);

        final session2 = await manager.getOrCreateSession(event);

        expect(session2.id, isNot(session1.id));
      });

      test('creates principal with unknown when userId is null', () async {
        final event = makeEvent(userId: null, userName: null);
        final session = await manager.getOrCreateSession(event);

        expect(session.principal.identity.id, 'unknown');
      });
    });

    group('getSession', () {
      test('returns session by id', () async {
        final event = makeEvent();
        final created = await manager.getOrCreateSession(event);

        final found = await manager.getSession(created.id);

        expect(found, isNotNull);
        expect(found!.id, created.id);
      });

      test('returns null for non-existent id', () async {
        final result = await manager.getSession('nonexistent');
        expect(result, isNull);
      });
    });

    group('getSessionByConversation', () {
      test('returns session by conversation key', () async {
        final event = makeEvent();
        final created = await manager.getOrCreateSession(event);

        final found = await manager.getSessionByConversation(
            event.conversation);

        expect(found, isNotNull);
        expect(found!.id, created.id);
      });

      test('returns null for unknown conversation', () async {
        final unknownConv = ConversationKey(
          channel: ChannelIdentity(platform: 'discord', channelId: 'X'),
          conversationId: 'X',
        );

        final result = await manager.getSessionByConversation(unknownConv);
        expect(result, isNull);
      });
    });

    group('createSession', () {
      test('creates session with context and metadata', () async {
        final session = await manager.createSession(
          conversation: conversation,
          identity: identity,
          context: {'intent': 'greeting'},
          metadata: {'source': 'api'},
        );

        expect(session.state, SessionState.active);
        expect(session.conversation, conversation);
        expect(session.context['intent'], 'greeting');
        expect(session.metadata, {'source': 'api'});
        expect(session.expiresAt, isNotNull);
      });

      test('creates session without optional fields', () async {
        final session = await manager.createSession(
          conversation: conversation,
          identity: identity,
        );

        expect(session.context, isEmpty);
        expect(session.metadata, isNull);
      });
    });

    group('addMessage', () {
      test('adds message to session history', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);

        final msg = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_msg_1',
        );

        final updated = await manager.addMessage(session.id, msg);

        expect(updated.history, hasLength(1));
        expect(updated.history.first.content, 'Hello');
      });

      test('throws SessionNotFound for non-existent session', () async {
        final msg = SessionMessage.user(
          content: 'Hello',
          eventId: 'evt_1',
        );

        expect(
          () => manager.addMessage('nonexistent', msg),
          throwsA(isA<SessionNotFound>()),
        );
      });

      test('trims history when exceeding maxHistorySize', () async {
        final config = SessionStoreConfig(maxHistorySize: 3);
        final mgr = SessionManager(store, config: config);
        addTearDown(() => mgr.dispose());

        final event = makeEvent(conversationId: 'C_trim');
        final session = await mgr.getOrCreateSession(event);

        for (var i = 0; i < 5; i++) {
          await mgr.addMessage(
            session.id,
            SessionMessage.user(
              content: 'Message $i',
              eventId: 'evt_$i',
            ),
          );
        }

        final result = await mgr.getSession(session.id);
        expect(result!.history.length, lessThanOrEqualTo(3));
        // Should keep the 3 most recent messages
        expect(result.history.last.content, 'Message 4');
      });
    });

    group('updateContext', () {
      test('updates session context with merge', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);

        final updated = await manager.updateContext(
          session.id,
          {'intent': 'greeting', 'mood': 'happy'},
        );

        expect(updated.context['intent'], 'greeting');
        expect(updated.context['mood'], 'happy');
      });

      test('throws SessionNotFound for non-existent session', () async {
        expect(
          () => manager.updateContext('nonexistent', {'key': 'value'}),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('setContextValue', () {
      test('sets single context value', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);

        final updated =
            await manager.setContextValue(session.id, 'key', 'value');

        expect(updated.context['key'], 'value');
      });

      test('throws SessionNotFound for non-existent session', () async {
        expect(
          () => manager.setContextValue('nonexistent', 'key', 'value'),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('removeContextValue', () {
      test('removes context value', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);
        await manager.setContextValue(session.id, 'key', 'value');

        final updated =
            await manager.removeContextValue(session.id, 'key');

        expect(updated.context.containsKey('key'), isFalse);
      });

      test('throws SessionNotFound for non-existent session', () async {
        expect(
          () => manager.removeContextValue('nonexistent', 'key'),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('clearContext', () {
      test('clears all context', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);
        await manager.setContextValue(session.id, 'a', 1);
        await manager.setContextValue(session.id, 'b', 2);

        final updated = await manager.clearContext(session.id);

        expect(updated.context, isEmpty);
      });

      test('throws SessionNotFound for non-existent session', () async {
        expect(
          () => manager.clearContext('nonexistent'),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('pauseSession', () {
      test('pauses active session', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);

        final paused = await manager.pauseSession(session.id);

        expect(paused.state, SessionState.paused);
      });

      test('throws SessionNotFound for non-existent session', () async {
        expect(
          () => manager.pauseSession('nonexistent'),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('resumeSession', () {
      test('resumes paused session', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);
        await manager.pauseSession(session.id);

        final resumed = await manager.resumeSession(session.id);

        expect(resumed.state, SessionState.active);
      });

      test('throws SessionNotFound for non-existent session', () async {
        expect(
          () => manager.resumeSession('nonexistent'),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('closeSession', () {
      test('closes existing session', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);

        await manager.closeSession(session.id);

        final result = await manager.getSession(session.id);
        expect(result!.state, SessionState.closed);
      });

      test('does nothing for non-existent session (no-op)', () async {
        // Should not throw
        await manager.closeSession('nonexistent');
      });
    });

    group('deleteSession', () {
      test('deletes session from store', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);

        await manager.deleteSession(session.id);

        final result = await manager.getSession(session.id);
        expect(result, isNull);
      });
    });

    group('touchSession', () {
      test('updates lastActivityAt and expiresAt', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);
        final originalExpires = session.expiresAt;

        // Small delay to ensure timestamp difference
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final touched = await manager.touchSession(session.id);

        expect(touched.lastActivityAt.millisecondsSinceEpoch,
            greaterThanOrEqualTo(session.lastActivityAt.millisecondsSinceEpoch));
        // expiresAt should be updated (extended)
        if (originalExpires != null) {
          expect(touched.expiresAt!.millisecondsSinceEpoch,
              greaterThanOrEqualTo(originalExpires.millisecondsSinceEpoch));
        }
      });

      test('throws SessionNotFound for non-existent session', () async {
        expect(
          () => manager.touchSession('nonexistent'),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('listSessions', () {
      test('lists all sessions', () async {
        final event1 = makeEvent(id: 'evt_1', conversationId: 'C1');
        final event2 = makeEvent(id: 'evt_2', conversationId: 'C2');

        await manager.getOrCreateSession(event1);
        await manager.getOrCreateSession(event2);

        final sessions = await manager.listSessions();

        expect(sessions, hasLength(2));
      });

      test('lists sessions with offset, limit, and state filter', () async {
        final event = makeEvent(id: 'evt_1', conversationId: 'C1');
        await manager.getOrCreateSession(event);

        final sessions = await manager.listSessions(
          offset: 0,
          limit: 10,
          state: SessionState.active,
        );

        expect(sessions, hasLength(1));
      });
    });

    group('startCleanup and stopCleanup', () {
      test('starts and stops cleanup timer', () async {
        final config = SessionStoreConfig(
          cleanupInterval: const Duration(milliseconds: 50),
        );
        final mgr = SessionManager(store, config: config);
        addTearDown(() => mgr.dispose());

        mgr.startCleanup();

        // Wait for at least one cleanup cycle
        await Future<void>.delayed(const Duration(milliseconds: 100));

        mgr.stopCleanup();

        // Should not throw or cause issues
      });

      test('startCleanup cancels previous timer before creating new one',
          () async {
        final config = SessionStoreConfig(
          cleanupInterval: const Duration(milliseconds: 50),
        );
        final mgr = SessionManager(store, config: config);
        addTearDown(() => mgr.dispose());

        mgr.startCleanup();
        mgr.startCleanup(); // Second call should cancel first

        mgr.stopCleanup();
      });
    });

    group('cleanup', () {
      test('manually triggers cleanup and returns count', () async {
        final event = makeEvent();
        final session = await manager.getOrCreateSession(event);

        // Expire the session
        final expired = session.expire();
        await store.save(expired);

        final count = await manager.cleanup();

        expect(count, 1);
        expect(await manager.getSession(session.id), isNull);
      });
    });

    group('dispose', () {
      test('stops cleanup timer', () {
        final mgr = SessionManager(store);
        mgr.startCleanup();
        mgr.dispose();

        // Calling dispose again should not throw
        mgr.dispose();
      });
    });
  });
}
