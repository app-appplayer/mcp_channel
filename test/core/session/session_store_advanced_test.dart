import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Shared test fixtures
  const channelIdentity = ChannelIdentity(
    platform: 'slack',
    channelId: 'T123',
  );

  final now = DateTime.utc(2025, 1, 15, 10, 0, 0);

  final identity = ChannelIdentityInfo.user(
    id: 'U123',
    displayName: 'Test User',
  );

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
    String id = 'session_1',
    ConversationKey? conversation,
    Principal? principal,
    SessionState state = SessionState.active,
    int version = 0,
    String? crossChannelUserId,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    DateTime? expiresAt,
    Map<String, dynamic> context = const {},
    List<SessionMessage> history = const [],
    Map<String, dynamic>? metadata,
  }) {
    return Session(
      id: id,
      conversation: conversation ??
          const ConversationKey(
            channel: channelIdentity,
            conversationId: 'C456',
            userId: 'U123',
          ),
      principal: principal ?? makePrincipal(),
      state: state,
      version: version,
      crossChannelUserId: crossChannelUserId,
      createdAt: createdAt ?? now,
      lastActivityAt: lastActivityAt ?? now,
      expiresAt: expiresAt,
      context: context,
      history: history,
      metadata: metadata,
    );
  }

  // ===========================================================================
  // TC-023: Session.copyWith auto-increments version
  // ===========================================================================
  group('TC-023: Session.copyWith version auto-increment', () {
    test('copyWith increments version from 0 to 1', () {
      final session = makeSession(version: 0);
      final updated = session.copyWith();

      expect(session.version, 0);
      expect(updated.version, 1);
    });

    test('copyWith increments version from arbitrary value', () {
      final session = makeSession(version: 5);
      final updated = session.copyWith();

      expect(updated.version, 6);
    });

    test('chained copyWith increments version each time', () {
      final session = makeSession(version: 0);
      final v1 = session.copyWith();
      final v2 = v1.copyWith();
      final v3 = v2.copyWith();

      expect(v1.version, 1);
      expect(v2.version, 2);
      expect(v3.version, 3);
    });

    test('copyWith with field overrides still increments version', () {
      final session = makeSession(version: 0);
      final updated = session.copyWith(
        state: SessionState.paused,
        context: {'key': 'value'},
      );

      expect(updated.version, 1);
      expect(updated.state, SessionState.paused);
      expect(updated.context, {'key': 'value'});
    });

    test('version is not directly settable via copyWith', () {
      // copyWith does not expose a version parameter;
      // version is always auto-incremented
      final session = makeSession(version: 10);
      final updated = session.copyWith();

      expect(updated.version, 11);
    });

    test('default version is 0 for new Session', () {
      final session = makeSession();
      expect(session.version, 0);
    });
  });

  // ===========================================================================
  // TC-111: Session.updateContext increments version
  // ===========================================================================
  group('TC-111: Session.updateContext increments version', () {
    test('updateContext increments version', () {
      final session = makeSession(version: 0);
      final updated = session.updateContext('key', 'value');

      expect(updated.version, 1);
      expect(updated.context['key'], 'value');
    });

    test('successive updateContext calls increment version each time', () {
      final session = makeSession(version: 0);
      final v1 = session.updateContext('a', 1);
      final v2 = v1.updateContext('b', 2);

      expect(v1.version, 1);
      expect(v2.version, 2);
    });
  });

  // ===========================================================================
  // TC-112: Session.removeContext increments version
  // ===========================================================================
  group('TC-112: Session.removeContext increments version', () {
    test('removeContext increments version', () {
      final session = makeSession(
        version: 0,
        context: {'key': 'value'},
      );
      final updated = session.removeContext('key');

      expect(updated.version, 1);
      expect(updated.context.containsKey('key'), isFalse);
    });

    test('removeContext on non-existent key still increments version', () {
      final session = makeSession(version: 3);
      final updated = session.removeContext('nonexistent');

      expect(updated.version, 4);
    });
  });

  // ===========================================================================
  // TC-113: Session.touch increments version
  // ===========================================================================
  group('TC-113: Session.touch increments version', () {
    test('touch increments version', () {
      final session = makeSession(version: 0);
      final touched = session.touch();

      expect(touched.version, 1);
    });

    test('touch preserves other fields while incrementing version', () {
      final session = makeSession(
        version: 5,
        context: {'key': 'value'},
        state: SessionState.active,
      );
      final touched = session.touch();

      expect(touched.version, 6);
      expect(touched.id, session.id);
      expect(touched.state, SessionState.active);
      expect(touched.context, {'key': 'value'});
    });
  });

  // ===========================================================================
  // Session version field in constructor and defaults
  // ===========================================================================
  group('Session version field', () {
    test('defaults to 0 when not provided', () {
      final session = Session(
        id: 'test',
        conversation: const ConversationKey(
          channel: channelIdentity,
          conversationId: 'C1',
        ),
        principal: makePrincipal(),
        state: SessionState.active,
        createdAt: now,
        lastActivityAt: now,
      );

      expect(session.version, 0);
    });

    test('accepts explicit version value', () {
      final session = makeSession(version: 42);
      expect(session.version, 42);
    });
  });

  // ===========================================================================
  // Session crossChannelUserId field
  // ===========================================================================
  group('Session crossChannelUserId field', () {
    test('defaults to null when not provided', () {
      final session = makeSession();
      expect(session.crossChannelUserId, isNull);
    });

    test('stores value when provided', () {
      final session = makeSession(crossChannelUserId: 'global_user_abc');
      expect(session.crossChannelUserId, 'global_user_abc');
    });

    test('copyWith preserves crossChannelUserId', () {
      final session = makeSession(crossChannelUserId: 'global_user_abc');
      final copied = session.copyWith(state: SessionState.paused);

      expect(copied.crossChannelUserId, 'global_user_abc');
    });

    test('copyWith can set crossChannelUserId', () {
      final session = makeSession();
      final copied = session.copyWith(crossChannelUserId: 'new_global_id');

      expect(copied.crossChannelUserId, 'new_global_id');
    });
  });

  // ===========================================================================
  // crossChannelUserId in Session serialization (fromJson / toJson)
  // ===========================================================================
  group('crossChannelUserId serialization', () {
    test('toJson includes crossChannelUserId when set', () {
      final session = makeSession(crossChannelUserId: 'global_user_xyz');
      final json = session.toJson();

      expect(json['crossChannelUserId'], 'global_user_xyz');
    });

    test('toJson omits crossChannelUserId when null', () {
      final session = makeSession();
      final json = session.toJson();

      expect(json.containsKey('crossChannelUserId'), isFalse);
    });

    test('fromJson parses crossChannelUserId when present', () {
      final json = {
        'id': 'session_ser',
        'conversation': {
          'channel': {'platform': 'slack', 'channelId': 'T123'},
          'conversationId': 'C456',
          'userId': 'U123',
        },
        'principal': {
          'identity': {'id': 'U123', 'type': 'user'},
          'tenantId': 'T123',
          'roles': ['user'],
          'permissions': <String>[],
          'authenticatedAt': now.toIso8601String(),
        },
        'state': 'active',
        'version': 3,
        'crossChannelUserId': 'global_user_xyz',
        'createdAt': now.toIso8601String(),
        'lastActivityAt': now.toIso8601String(),
      };

      final session = Session.fromJson(json);

      expect(session.crossChannelUserId, 'global_user_xyz');
      expect(session.version, 3);
    });

    test('fromJson defaults crossChannelUserId to null when absent', () {
      final json = {
        'id': 'session_ser',
        'conversation': {
          'channel': {'platform': 'slack', 'channelId': 'T123'},
          'conversationId': 'C456',
          'userId': 'U123',
        },
        'principal': {
          'identity': {'id': 'U123', 'type': 'user'},
          'tenantId': 'T123',
          'roles': ['user'],
          'permissions': <String>[],
          'authenticatedAt': now.toIso8601String(),
        },
        'state': 'active',
        'createdAt': now.toIso8601String(),
        'lastActivityAt': now.toIso8601String(),
      };

      final session = Session.fromJson(json);

      expect(session.crossChannelUserId, isNull);
    });

    test('fromJson defaults version to 0 when absent', () {
      final json = {
        'id': 'session_ser',
        'conversation': {
          'channel': {'platform': 'slack', 'channelId': 'T123'},
          'conversationId': 'C456',
        },
        'principal': {
          'identity': {'id': 'U123', 'type': 'user'},
          'tenantId': 'T123',
          'roles': ['user'],
          'permissions': <String>[],
          'authenticatedAt': now.toIso8601String(),
        },
        'state': 'active',
        'createdAt': now.toIso8601String(),
        'lastActivityAt': now.toIso8601String(),
      };

      final session = Session.fromJson(json);

      expect(session.version, 0);
    });

    test('version roundtrips through toJson/fromJson', () {
      final session = makeSession(version: 7, crossChannelUserId: 'g_user');
      final json = session.toJson();
      final restored = Session.fromJson(json);

      expect(restored.version, 7);
      expect(restored.crossChannelUserId, 'g_user');
    });
  });

  // ===========================================================================
  // TC-026: InMemorySessionStore.saveIfCurrent
  // ===========================================================================
  group('TC-026: InMemorySessionStore.saveIfCurrent', () {
    late InMemorySessionStore store;

    setUp(() {
      store = InMemorySessionStore();
    });

    test('Normal: save with correct version succeeds', () async {
      // Save initial version 0
      final session = makeSession(id: 'sic_1', version: 0);
      await store.save(session);

      // Use copyWith to get version 1, then saveIfCurrent
      final updated = session.copyWith(state: SessionState.paused);
      expect(updated.version, 1);

      await store.saveIfCurrent(updated);

      final result = await store.get('sic_1');
      expect(result, isNotNull);
      expect(result!.version, 1);
      expect(result.state, SessionState.paused);
    });

    test('Boundary: first save with version=0 succeeds (no prior record)', () async {
      // No existing session in store - saveIfCurrent should succeed
      // because there is no prior version to conflict with.
      // Note: version=0 means no existing record expected, but for
      // saveIfCurrent with no existing record, there's no conflict check.
      final session = makeSession(id: 'sic_new', version: 0);

      // The implementation: if no existing record, no version check is done
      // However, the session has version=0, and saveIfCurrent expects
      // existing.version == session.version - 1 (= -1) which can't exist.
      // But since existing is null, the check is skipped entirely.
      await store.saveIfCurrent(session);

      final result = await store.get('sic_new');
      expect(result, isNotNull);
      expect(result!.version, 0);
    });

    test('Boundary: first saveIfCurrent with version=1 succeeds (no prior record)', () async {
      // Even with version=1, if no prior record exists, saveIfCurrent succeeds
      final session = makeSession(id: 'sic_v1_new', version: 1);

      await store.saveIfCurrent(session);

      final result = await store.get('sic_v1_new');
      expect(result, isNotNull);
      expect(result!.version, 1);
    });

    test('Error: save with stale version throws ConcurrentModificationException', () async {
      // Save initial version 0
      final session = makeSession(id: 'sic_conflict', version: 0);
      await store.save(session);

      // Simulate concurrent update: save version 1 directly
      final v1 = session.copyWith(state: SessionState.paused);
      await store.save(v1);

      // Now try to saveIfCurrent with a stale copy (version 1 based on version 0)
      // The stale copy also has version 1, but the store already has version 1,
      // so the check: existing.version (1) != session.version - 1 (0) -> conflict!
      final staleCopy = session.copyWith(
        context: {'stale': true},
      );
      expect(staleCopy.version, 1);

      expect(
        () => store.saveIfCurrent(staleCopy),
        throwsA(isA<ConcurrentModificationException>()),
      );
    });

    test('ConcurrentModificationException contains correct fields', () async {
      final session = makeSession(id: 'sic_fields', version: 0);
      await store.save(session);

      // Advance stored version to 3 via direct save
      final v3 = makeSession(id: 'sic_fields', version: 3);
      await store.save(v3);

      // Try to save with version 1 (expects stored version 0, but actual is 3)
      final stale = makeSession(id: 'sic_fields', version: 1);

      try {
        await store.saveIfCurrent(stale);
        fail('Expected ConcurrentModificationException');
      } on ConcurrentModificationException catch (e) {
        expect(e.sessionId, 'sic_fields');
        expect(e.expectedVersion, 0); // session.version - 1
        expect(e.actualVersion, 3); // what was actually in the store
      }
    });

    test('ConcurrentModificationException toString is descriptive', () {
      const ex = ConcurrentModificationException(
        sessionId: 'test_session',
        expectedVersion: 2,
        actualVersion: 5,
      );

      final str = ex.toString();
      expect(str, contains('ConcurrentModificationException'));
      expect(str, contains('test_session'));
      expect(str, contains('2'));
      expect(str, contains('5'));
    });

    test('saveIfCurrent succeeds after multiple version increments', () async {
      final v0 = makeSession(id: 'sic_multi', version: 0);
      await store.save(v0);

      final v1 = v0.copyWith(context: {'step': 1});
      await store.saveIfCurrent(v1);

      final v2 = v1.copyWith(context: {'step': 2});
      await store.saveIfCurrent(v2);

      final v3 = v2.copyWith(context: {'step': 3});
      await store.saveIfCurrent(v3);

      final result = await store.get('sic_multi');
      expect(result!.version, 3);
      expect(result.context['step'], 3);
    });

    test('saveIfCurrent updates all indices', () async {
      const conv = ConversationKey(
        channel: channelIdentity,
        conversationId: 'C_sic',
        userId: 'U123',
      );
      final session = makeSession(
        id: 'sic_index',
        conversation: conv,
        version: 0,
        crossChannelUserId: 'global_1',
      );
      await store.save(session);

      final updated = session.copyWith(state: SessionState.paused);
      await store.saveIfCurrent(updated);

      // Verify all indices still work
      final byId = await store.get('sic_index');
      expect(byId!.state, SessionState.paused);

      final byConv = await store.getByConversation(conv);
      expect(byConv!.state, SessionState.paused);

      final byUser = await store.getByUser('slack', 'U123');
      expect(byUser!.state, SessionState.paused);
    });
  });

  // ===========================================================================
  // InMemorySessionStore.getByGlobalUser
  // ===========================================================================
  group('InMemorySessionStore.getByGlobalUser', () {
    late InMemorySessionStore store;

    setUp(() {
      store = InMemorySessionStore();
    });

    test('returns sessions matching crossChannelUserId', () async {
      final session1 = makeSession(
        id: 'g_s1',
        conversation: const ConversationKey(
          channel: ChannelIdentity(platform: 'slack', channelId: 'T1'),
          conversationId: 'C1',
          userId: 'U1',
        ),
        principal: Principal(
          identity: ChannelIdentityInfo.user(id: 'U1'),
          tenantId: 'T1',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        ),
        crossChannelUserId: 'global_alice',
      );

      final session2 = makeSession(
        id: 'g_s2',
        conversation: const ConversationKey(
          channel: ChannelIdentity(platform: 'discord', channelId: 'D1'),
          conversationId: 'D_C1',
          userId: 'U_discord_1',
        ),
        principal: Principal(
          identity: ChannelIdentityInfo.user(id: 'U_discord_1'),
          tenantId: 'T1',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        ),
        crossChannelUserId: 'global_alice',
      );

      await store.save(session1);
      await store.save(session2);

      final results = await store.getByGlobalUser('global_alice');

      expect(results, hasLength(2));
      final ids = results.map((s) => s.id).toSet();
      expect(ids, contains('g_s1'));
      expect(ids, contains('g_s2'));
    });

    test('returns empty list when no sessions match', () async {
      final session = makeSession(
        id: 'g_s_nomatch',
        crossChannelUserId: 'global_bob',
      );
      await store.save(session);

      final results = await store.getByGlobalUser('global_unknown');

      expect(results, isEmpty);
    });

    test('returns empty list when store is empty', () async {
      final results = await store.getByGlobalUser('global_any');
      expect(results, isEmpty);
    });

    test('does not return sessions without crossChannelUserId', () async {
      // Session without crossChannelUserId
      final session1 = makeSession(
        id: 'g_s_no_global',
        conversation: const ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_no_global',
          userId: 'U123',
        ),
      );

      // Session with crossChannelUserId
      final session2 = makeSession(
        id: 'g_s_with_global',
        conversation: const ConversationKey(
          channel: ChannelIdentity(platform: 'discord', channelId: 'D2'),
          conversationId: 'D_C2',
          userId: 'U_d2',
        ),
        principal: Principal(
          identity: ChannelIdentityInfo.user(id: 'U_d2'),
          tenantId: 'T1',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        ),
        crossChannelUserId: 'global_charlie',
      );

      await store.save(session1);
      await store.save(session2);

      final results = await store.getByGlobalUser('global_charlie');

      expect(results, hasLength(1));
      expect(results.first.id, 'g_s_with_global');
    });

    test('returns sessions from multiple platforms for same global user', () async {
      final platforms = ['slack', 'discord', 'telegram'];

      for (var i = 0; i < platforms.length; i++) {
        final session = makeSession(
          id: 'multi_plat_$i',
          conversation: ConversationKey(
            channel: ChannelIdentity(
              platform: platforms[i],
              channelId: '${platforms[i]}_ch',
            ),
            conversationId: '${platforms[i]}_conv',
            userId: 'user_$i',
          ),
          principal: Principal(
            identity: ChannelIdentityInfo.user(id: 'user_$i'),
            tenantId: 'T1',
            roles: const {'user'},
            permissions: const {},
            authenticatedAt: now,
          ),
          crossChannelUserId: 'global_multi',
        );
        await store.save(session);
      }

      final results = await store.getByGlobalUser('global_multi');

      expect(results, hasLength(3));
    });

    test('different crossChannelUserIds are isolated', () async {
      final sessionAlice = makeSession(
        id: 'iso_alice',
        conversation: const ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_alice',
          userId: 'U_alice',
        ),
        principal: Principal(
          identity: ChannelIdentityInfo.user(id: 'U_alice'),
          tenantId: 'T1',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        ),
        crossChannelUserId: 'global_alice',
      );

      final sessionBob = makeSession(
        id: 'iso_bob',
        conversation: const ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_bob',
          userId: 'U_bob',
        ),
        principal: Principal(
          identity: ChannelIdentityInfo.user(id: 'U_bob'),
          tenantId: 'T1',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        ),
        crossChannelUserId: 'global_bob',
      );

      await store.save(sessionAlice);
      await store.save(sessionBob);

      final aliceResults = await store.getByGlobalUser('global_alice');
      final bobResults = await store.getByGlobalUser('global_bob');

      expect(aliceResults, hasLength(1));
      expect(aliceResults.first.id, 'iso_alice');

      expect(bobResults, hasLength(1));
      expect(bobResults.first.id, 'iso_bob');
    });

    test('save indexes crossChannelUserId in global user index', () async {
      final session = makeSession(
        id: 'idx_test',
        conversation: const ConversationKey(
          channel: channelIdentity,
          conversationId: 'C_idx',
          userId: 'U_idx',
        ),
        principal: Principal(
          identity: ChannelIdentityInfo.user(id: 'U_idx'),
          tenantId: 'T1',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        ),
        crossChannelUserId: 'global_idx',
      );
      await store.save(session);

      // Save again (re-save same session) should not duplicate
      await store.save(session);

      final results = await store.getByGlobalUser('global_idx');
      expect(results, hasLength(1));
    });
  });

  // ===========================================================================
  // ConcurrentModificationException
  // ===========================================================================
  group('ConcurrentModificationException', () {
    test('is an Exception', () {
      const ex = ConcurrentModificationException(
        sessionId: 'test',
        expectedVersion: 0,
        actualVersion: 1,
      );
      expect(ex, isA<Exception>());
    });

    test('stores all fields correctly', () {
      const ex = ConcurrentModificationException(
        sessionId: 'session_abc',
        expectedVersion: 5,
        actualVersion: 8,
      );

      expect(ex.sessionId, 'session_abc');
      expect(ex.expectedVersion, 5);
      expect(ex.actualVersion, 8);
    });

    test('toString contains all relevant information', () {
      const ex = ConcurrentModificationException(
        sessionId: 'session_xyz',
        expectedVersion: 3,
        actualVersion: 7,
      );

      final str = ex.toString();
      expect(str, contains('ConcurrentModificationException'));
      expect(str, contains('session_xyz'));
      expect(str, contains('3'));
      expect(str, contains('7'));
    });
  });

  // ===========================================================================
  // Version field in toJson
  // ===========================================================================
  group('Session version in toJson', () {
    test('toJson includes version field', () {
      final session = makeSession(version: 5);
      final json = session.toJson();

      expect(json['version'], 5);
    });

    test('toJson includes version=0 for default', () {
      final session = makeSession();
      final json = session.toJson();

      expect(json['version'], 0);
    });
  });

  // ===========================================================================
  // State transition methods increment version
  // ===========================================================================
  group('State transition methods increment version', () {
    test('addMessage increments version', () {
      final session = makeSession(version: 0);
      final msg = SessionMessage.user(
        content: 'Hello',
        eventId: 'evt_1',
      );
      final updated = session.addMessage(msg);

      expect(updated.version, 1);
    });

    test('clearContext increments version', () {
      final session = makeSession(
        version: 2,
        context: {'a': 1},
      );
      final updated = session.clearContext();

      expect(updated.version, 3);
    });

    test('pause increments version', () {
      final session = makeSession(version: 0);
      final paused = session.pause();

      expect(paused.version, 1);
    });

    test('close increments version', () {
      final session = makeSession(version: 4);
      final closed = session.close();

      expect(closed.version, 5);
    });

    test('expire increments version', () {
      final session = makeSession(version: 0);
      final expired = session.expire();

      expect(expired.version, 1);
    });

    test('resume from paused increments version', () {
      final session = makeSession(
        version: 3,
        state: SessionState.paused,
      );
      final resumed = session.resume();

      expect(resumed.version, 4);
    });

    test('resume from non-paused does not change version (returns same instance)', () {
      final session = makeSession(
        version: 3,
        state: SessionState.active,
      );
      final resumed = session.resume();

      // resume() returns identical instance when not paused
      expect(identical(resumed, session), isTrue);
      expect(resumed.version, 3);
    });

    test('trimHistory increments version only when trimming occurs', () {
      final messages = List.generate(
        5,
        (i) => SessionMessage.user(
          content: 'Message $i',
          eventId: 'evt_$i',
          timestamp: now,
        ),
      );
      final session = makeSession(version: 0, history: messages);

      // Trimming occurs (5 > 3)
      final trimmed = session.trimHistory(3);
      expect(trimmed.version, 1);

      // No trimming needed (3 <= 3), returns same instance
      final notTrimmed = trimmed.trimHistory(3);
      expect(identical(notTrimmed, trimmed), isTrue);
      expect(notTrimmed.version, 1);
    });
  });
}
