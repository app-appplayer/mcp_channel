import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Shared fixtures
  final channelIdentity = ChannelIdentity(
    platform: 'slack',
    channelId: 'T123',
  );

  final conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'C456',
    userId: 'U123',
  );

  final conversation2 = ConversationKey(
    channel: ChannelIdentity(platform: 'telegram', channelId: 'T999'),
    conversationId: 'chat_789',
    userId: 'U123',
  );

  ChannelEvent makeEvent({
    String id = 'evt_1',
    ConversationKey? conv,
  }) {
    return ChannelEvent.message(
      id: id,
      conversation: conv ?? conversation,
      text: 'hello',
      userId: 'U123',
      userName: 'Test User',
    );
  }

  late InMemorySessionStore store;
  late SessionManager manager;

  setUp(() {
    store = InMemorySessionStore();
    manager = SessionManager(store);
  });

  tearDown(() {
    manager.dispose();
  });

  group('SessionManager', () {
    group('getOrCreateSession', () {
      test('creates new session for first event', () async {
        final session = await manager.getOrCreateSession(makeEvent());

        expect(session.state, SessionState.active);
        expect(session.conversation, conversation);
        expect(session.principal.identity.id, 'U123');
        expect(store.count, 1);
      });

      test('returns existing session for same conversation', () async {
        final first = await manager.getOrCreateSession(makeEvent());
        final second = await manager.getOrCreateSession(makeEvent(id: 'evt_2'));

        expect(second.id, first.id);
        expect(store.count, 1);
      });

      test('creates new session if previous expired', () async {
        // Create session with past expiry
        final identity = ChannelIdentityInfo.user(id: 'U123');
        final principal = Principal.basic(
          identity: identity,
          tenantId: 'T123',
        );
        final expired = Session(
          id: 'old_session',
          conversation: conversation,
          principal: principal,
          state: SessionState.active,
          createdAt: DateTime.now().subtract(const Duration(hours: 48)),
          lastActivityAt: DateTime.now().subtract(const Duration(hours: 48)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await store.save(expired);

        final session = await manager.getOrCreateSession(makeEvent());
        expect(session.id, isNot('old_session'));
        expect(session.state, SessionState.active);
      });

      test('updates touch on returning existing session', () async {
        final first = await manager.getOrCreateSession(makeEvent());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final second = await manager.getOrCreateSession(makeEvent(id: 'evt_2'));

        expect(
          second.lastActivityAt.millisecondsSinceEpoch,
          greaterThanOrEqualTo(first.lastActivityAt.millisecondsSinceEpoch),
        );
      });
    });

    group('getSession / getSessionByConversation', () {
      test('getSession returns session by ID', () async {
        final created = await manager.getOrCreateSession(makeEvent());
        final found = await manager.getSession(created.id);
        expect(found, isNotNull);
        expect(found!.id, created.id);
      });

      test('getSession returns null for unknown ID', () async {
        final found = await manager.getSession('nonexistent');
        expect(found, isNull);
      });

      test('getSessionByConversation returns session', () async {
        await manager.getOrCreateSession(makeEvent());
        final found = await manager.getSessionByConversation(conversation);
        expect(found, isNotNull);
      });

      test('getSessionByConversation returns null for unknown', () async {
        final found = await manager.getSessionByConversation(conversation);
        expect(found, isNull);
      });
    });

    group('createSession', () {
      test('creates session explicitly', () async {
        final identity = ChannelIdentityInfo.user(
          id: 'U999',
          displayName: 'Explicit',
        );
        final session = await manager.createSession(
          conversation: conversation,
          identity: identity,
          context: {'key': 'value'},
          metadata: {'source': 'test'},
        );

        expect(session.state, SessionState.active);
        expect(session.principal.identity.id, 'U999');
        expect(session.context['key'], 'value');
        expect(session.metadata?['source'], 'test');
      });
    });

    group('addMessage', () {
      test('adds message to session history', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        final msg = SessionMessage.user(
          content: 'hello',
          eventId: 'evt_1',
        );
        final updated = await manager.addMessage(session.id, msg);

        expect(updated.history.length, 1);
        expect(updated.history.first.content, 'hello');
      });

      test('trims history when exceeding max size', () async {
        final mgr = SessionManager(
          store,
          config: const SessionStoreConfig(maxHistorySize: 3),
        );
        final session = await mgr.getOrCreateSession(makeEvent());

        for (var i = 0; i < 5; i++) {
          await mgr.addMessage(
            session.id,
            SessionMessage.user(content: 'msg $i', eventId: 'e$i'),
          );
        }

        final result = await mgr.getSession(session.id);
        expect(result!.history.length, 3);
        mgr.dispose();
      });

      test('throws SessionNotFound for unknown ID', () async {
        final msg = SessionMessage.user(content: 'x', eventId: 'e');
        expect(
          () => manager.addMessage('bad_id', msg),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('addMessageSafe', () {
      test('adds message with concurrency safety', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        final msg = SessionMessage.user(content: 'safe', eventId: 'e1');
        final updated = await manager.addMessageSafe(session.id, msg);

        expect(updated.history.length, 1);
      });

      test('throws SessionNotFound for unknown ID', () async {
        final msg = SessionMessage.user(content: 'x', eventId: 'e');
        expect(
          () => manager.addMessageSafe('bad_id', msg),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('context operations', () {
      test('updateContext merges new values', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        final updated = await manager.updateContext(
          session.id,
          {'a': 1, 'b': 2},
        );
        expect(updated.context['a'], 1);
        expect(updated.context['b'], 2);
      });

      test('setContextValue sets single value', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        final updated = await manager.setContextValue(
          session.id,
          'key',
          'value',
        );
        expect(updated.context['key'], 'value');
      });

      test('removeContextValue removes value', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        await manager.setContextValue(session.id, 'key', 'value');
        final updated = await manager.removeContextValue(session.id, 'key');
        expect(updated.context.containsKey('key'), isFalse);
      });

      test('clearContext removes all values', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        await manager.updateContext(session.id, {'a': 1, 'b': 2});
        final updated = await manager.clearContext(session.id);
        expect(updated.context, isEmpty);
      });

      test('context operations throw SessionNotFound for unknown ID',
          () async {
        expect(
          () => manager.updateContext('bad', {'a': 1}),
          throwsA(isA<SessionNotFound>()),
        );
        expect(
          () => manager.setContextValue('bad', 'k', 'v'),
          throwsA(isA<SessionNotFound>()),
        );
        expect(
          () => manager.removeContextValue('bad', 'k'),
          throwsA(isA<SessionNotFound>()),
        );
        expect(
          () => manager.clearContext('bad'),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('session lifecycle', () {
      test('pauseSession changes state', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        final paused = await manager.pauseSession(session.id);
        expect(paused.state, SessionState.paused);
      });

      test('resumeSession changes state', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        await manager.pauseSession(session.id);
        final resumed = await manager.resumeSession(session.id);
        expect(resumed.state, SessionState.active);
      });

      test('closeSession changes state', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        await manager.closeSession(session.id);
        final found = await manager.getSession(session.id);
        expect(found!.state, SessionState.closed);
      });

      test('closeSession does nothing for unknown ID', () async {
        // Should not throw
        await manager.closeSession('nonexistent');
      });

      test('deleteSession removes session', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        await manager.deleteSession(session.id);
        final found = await manager.getSession(session.id);
        expect(found, isNull);
      });

      test('touchSession extends expiration', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        final touched = await manager.touchSession(session.id);
        expect(
          touched.expiresAt!.millisecondsSinceEpoch,
          greaterThan(session.lastActivityAt.millisecondsSinceEpoch),
        );
      });

      test('lifecycle operations throw SessionNotFound for unknown ID',
          () async {
        expect(
          () => manager.pauseSession('bad'),
          throwsA(isA<SessionNotFound>()),
        );
        expect(
          () => manager.resumeSession('bad'),
          throwsA(isA<SessionNotFound>()),
        );
        expect(
          () => manager.touchSession('bad'),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });

    group('listSessions', () {
      test('returns all sessions', () async {
        await manager.getOrCreateSession(makeEvent());
        await manager.getOrCreateSession(makeEvent(conv: conversation2));

        final sessions = await manager.listSessions();
        expect(sessions.length, 2);
      });

      test('filters by state', () async {
        final s = await manager.getOrCreateSession(makeEvent());
        await manager.getOrCreateSession(makeEvent(conv: conversation2));
        await manager.pauseSession(s.id);

        final paused =
            await manager.listSessions(state: SessionState.paused);
        expect(paused.length, 1);
      });

      test('supports pagination', () async {
        await manager.getOrCreateSession(makeEvent());
        await manager.getOrCreateSession(makeEvent(conv: conversation2));

        final page = await manager.listSessions(offset: 0, limit: 1);
        expect(page.length, 1);
      });
    });

    group('cleanup', () {
      test('cleanup returns count of expired sessions', () async {
        // Create session that is already expired
        final identity = ChannelIdentityInfo.user(id: 'U123');
        final principal = Principal.basic(identity: identity, tenantId: 'T');
        final expired = Session(
          id: 'expired_1',
          conversation: conversation,
          principal: principal,
          state: SessionState.active,
          createdAt: DateTime.now().subtract(const Duration(hours: 48)),
          lastActivityAt: DateTime.now().subtract(const Duration(hours: 48)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await store.save(expired);
        expect(store.count, 1);

        final removed = await manager.cleanup();
        expect(removed, 1);
        expect(store.count, 0);
      });

      test('startCleanup and stopCleanup manage timer', () {
        manager.startCleanup();
        // Should not throw
        manager.stopCleanup();
      });
    });

    group('cross-channel linking', () {
      test('linkToGlobalUser sets crossChannelUserId', () async {
        final session = await manager.getOrCreateSession(makeEvent());
        final linked =
            await manager.linkToGlobalUser(session.id, 'global_user_1');
        expect(linked.crossChannelUserId, 'global_user_1');
      });

      test('linkToGlobalUser throws SessionNotFound for unknown ID', () async {
        expect(
          () => manager.linkToGlobalUser('bad', 'g1'),
          throwsA(isA<SessionNotFound>()),
        );
      });

      test('getGlobalUserSessions returns all linked sessions', () async {
        final s1 = await manager.getOrCreateSession(makeEvent());
        final s2 =
            await manager.getOrCreateSession(makeEvent(conv: conversation2));

        await manager.linkToGlobalUser(s1.id, 'global_1');
        await manager.linkToGlobalUser(s2.id, 'global_1');

        final sessions = await manager.getGlobalUserSessions('global_1');
        expect(sessions.length, 2);
      });

      test('getGlobalHistory merges and sorts messages', () async {
        final s1 = await manager.getOrCreateSession(makeEvent());
        final s2 =
            await manager.getOrCreateSession(makeEvent(conv: conversation2));

        await manager.linkToGlobalUser(s1.id, 'global_1');
        await manager.linkToGlobalUser(s2.id, 'global_1');

        final t1 = DateTime.utc(2025, 1, 1, 10, 0);
        final t2 = DateTime.utc(2025, 1, 1, 10, 1);
        final t3 = DateTime.utc(2025, 1, 1, 10, 2);

        await manager.addMessage(
          s1.id,
          SessionMessage.user(content: 'first', eventId: 'e1', timestamp: t1),
        );
        await manager.addMessage(
          s2.id,
          SessionMessage.user(
              content: 'second', eventId: 'e2', timestamp: t2),
        );
        await manager.addMessage(
          s1.id,
          SessionMessage.user(content: 'third', eventId: 'e3', timestamp: t3),
        );

        final history = await manager.getGlobalHistory('global_1');
        expect(history.length, 3);
        expect(history[0].content, 'first');
        expect(history[1].content, 'second');
        expect(history[2].content, 'third');
      });

      test('getGlobalHistory respects maxMessages', () async {
        final s = await manager.getOrCreateSession(makeEvent());
        await manager.linkToGlobalUser(s.id, 'g1');

        for (var i = 0; i < 5; i++) {
          await manager.addMessage(
            s.id,
            SessionMessage.user(content: 'msg$i', eventId: 'e$i'),
          );
        }

        final history =
            await manager.getGlobalHistory('g1', maxMessages: 3);
        expect(history.length, 3);
      });
    });

    group('migrateSession', () {
      test('migrates context and history to new platform', () async {
        final source = await manager.getOrCreateSession(makeEvent());
        await manager.updateContext(source.id, {'lang': 'ko'});
        await manager.addMessage(
          source.id,
          SessionMessage.user(content: 'hi', eventId: 'e1'),
        );

        final target = await manager.migrateSession(
          sourceSessionId: source.id,
          targetConversation: conversation2,
          targetIdentity: ChannelIdentityInfo.user(id: 'U123_tg'),
        );

        expect(target.conversation, conversation2);
        expect(target.context['lang'], 'ko');
        expect(target.history.length, 1);
        expect(target.crossChannelUserId, isNotNull);
        expect(target.metadata?['migratedFrom'], source.id);
      });

      test('links source session if not already linked', () async {
        final source = await manager.getOrCreateSession(makeEvent());

        await manager.migrateSession(
          sourceSessionId: source.id,
          targetConversation: conversation2,
          targetIdentity: ChannelIdentityInfo.user(id: 'U123_tg'),
        );

        final updated = await manager.getSession(source.id);
        expect(updated!.crossChannelUserId, isNotNull);
      });

      test('uses existing crossChannelUserId if already linked', () async {
        final source = await manager.getOrCreateSession(makeEvent());
        await manager.linkToGlobalUser(source.id, 'existing_global');

        final target = await manager.migrateSession(
          sourceSessionId: source.id,
          targetConversation: conversation2,
          targetIdentity: ChannelIdentityInfo.user(id: 'U123_tg'),
        );

        expect(target.crossChannelUserId, 'existing_global');
      });

      test('respects historyToMigrate limit', () async {
        final source = await manager.getOrCreateSession(makeEvent());
        for (var i = 0; i < 30; i++) {
          await manager.addMessage(
            source.id,
            SessionMessage.user(content: 'msg$i', eventId: 'e$i'),
          );
        }

        final target = await manager.migrateSession(
          sourceSessionId: source.id,
          targetConversation: conversation2,
          targetIdentity: ChannelIdentityInfo.user(id: 'U123_tg'),
          historyToMigrate: 5,
        );

        expect(target.history.length, 5);
      });

      test('throws SessionNotFound for unknown source', () async {
        expect(
          () => manager.migrateSession(
            sourceSessionId: 'bad',
            targetConversation: conversation2,
            targetIdentity: ChannelIdentityInfo.user(id: 'U'),
          ),
          throwsA(isA<SessionNotFound>()),
        );
      });
    });
  });

  group('SessionNotFound', () {
    test('has correct sessionId', () {
      const ex = SessionNotFound('sess_1');
      expect(ex.sessionId, 'sess_1');
    });

    test('toString contains session ID', () {
      const ex = SessionNotFound('sess_1');
      expect(ex.toString(), contains('sess_1'));
    });
  });

  group('SessionStoreConfig', () {
    test('has correct defaults', () {
      const config = SessionStoreConfig();
      expect(config.defaultTimeout, const Duration(hours: 24));
      expect(config.maxHistorySize, 100);
      expect(config.cleanupInterval, const Duration(minutes: 15));
      expect(config.persistent, false);
    });

    test('copyWith overrides values', () {
      const config = SessionStoreConfig();
      final copy = config.copyWith(
        defaultTimeout: const Duration(hours: 1),
        maxHistorySize: 50,
        persistent: true,
      );
      expect(copy.defaultTimeout, const Duration(hours: 1));
      expect(copy.maxHistorySize, 50);
      expect(copy.persistent, true);
      expect(copy.cleanupInterval, const Duration(minutes: 15));
    });
  });

  group('InMemorySessionStore', () {
    late InMemorySessionStore store;
    late Session session;

    setUp(() {
      store = InMemorySessionStore();
      final identity = ChannelIdentityInfo.user(id: 'U1');
      final principal = Principal.basic(identity: identity, tenantId: 'T1');
      session = Session(
        id: 'sess_1',
        conversation: conversation,
        principal: principal,
        state: SessionState.active,
        createdAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    });

    test('save and get', () async {
      await store.save(session);
      final found = await store.get('sess_1');
      expect(found, isNotNull);
      expect(found!.id, 'sess_1');
    });

    test('getByConversation', () async {
      await store.save(session);
      final found = await store.getByConversation(conversation);
      expect(found, isNotNull);
    });

    test('getByUser', () async {
      await store.save(session);
      final found = await store.getByUser('slack', 'U1');
      expect(found, isNotNull);
    });

    test('saveIfCurrent succeeds on version match', () async {
      await store.save(session);
      final updated = session.copyWith(
        context: {'a': 1},
        lastActivityAt: DateTime.now(),
      );
      await store.saveIfCurrent(updated);
      final found = await store.get('sess_1');
      expect(found!.context['a'], 1);
    });

    test('saveIfCurrent throws on version mismatch', () async {
      await store.save(session);
      // Simulate version bump
      final v2 = session.copyWith(lastActivityAt: DateTime.now());
      await store.save(v2);
      // Now try saving with original version
      final staleUpdate = session.copyWith(lastActivityAt: DateTime.now());
      expect(
        () => store.saveIfCurrent(staleUpdate),
        throwsA(isA<ConcurrentModificationException>()),
      );
    });

    test('delete removes session and indices', () async {
      await store.save(session);
      await store.delete('sess_1');
      expect(await store.get('sess_1'), isNull);
      expect(await store.getByConversation(conversation), isNull);
      expect(await store.getByUser('slack', 'U1'), isNull);
    });

    test('delete removes global user index', () async {
      final linked = Session(
        id: 'sess_g',
        conversation: conversation,
        principal: session.principal,
        state: SessionState.active,
        crossChannelUserId: 'global_1',
        createdAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await store.save(linked);
      final before = await store.getByGlobalUser('global_1');
      expect(before.length, 1);

      await store.delete('sess_g');
      final after = await store.getByGlobalUser('global_1');
      expect(after, isEmpty);
    });

    test('cleanupExpired removes expired sessions', () async {
      final expired = Session(
        id: 'sess_exp',
        conversation: conversation,
        principal: session.principal,
        state: SessionState.active,
        createdAt: DateTime.now().subtract(const Duration(hours: 48)),
        lastActivityAt: DateTime.now().subtract(const Duration(hours: 48)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await store.save(expired);

      final count = await store.cleanupExpired();
      expect(count, 1);
      expect(store.count, 0);
    });

    test('list with pagination', () async {
      await store.save(session);
      final s2 = Session(
        id: 'sess_2',
        conversation: conversation2,
        principal: session.principal,
        state: SessionState.active,
        createdAt: DateTime.now(),
        lastActivityAt: DateTime.now().add(const Duration(seconds: 1)),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await store.save(s2);

      final all = await store.list();
      expect(all.length, 2);

      final page = await store.list(offset: 0, limit: 1);
      expect(page.length, 1);

      final empty = await store.list(offset: 10);
      expect(empty, isEmpty);
    });

    test('list with state filter', () async {
      await store.save(session);
      final paused = Session(
        id: 'sess_p',
        conversation: conversation2,
        principal: session.principal,
        state: SessionState.paused,
        createdAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await store.save(paused);

      final active = await store.list(state: SessionState.active);
      expect(active.length, 1);
      expect(active.first.id, 'sess_1');
    });

    test('clear removes all', () async {
      await store.save(session);
      store.clear();
      expect(store.count, 0);
    });
  });
}
