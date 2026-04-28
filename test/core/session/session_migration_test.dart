import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // ===========================================================================
  // Shared fixtures
  // ===========================================================================

  const slackChannel = ChannelIdentity(
    platform: 'slack',
    channelId: 'T_SLACK',
  );

  const telegramChannel = ChannelIdentity(
    platform: 'telegram',
    channelId: 'T_TELEGRAM',
  );

  const discordChannel = ChannelIdentity(
    platform: 'discord',
    channelId: 'T_DISCORD',
  );

  final now = DateTime.utc(2025, 6, 1, 12, 0, 0);

  ConversationKey makeConversation({
    ChannelIdentity? channel,
    String conversationId = 'conv_1',
    String? userId,
  }) {
    return ConversationKey(
      channel: channel ?? slackChannel,
      conversationId: conversationId,
      userId: userId,
    );
  }

  ChannelIdentityInfo makeIdentity({
    String id = 'user_1',
    String? displayName,
  }) {
    return ChannelIdentityInfo.user(
      id: id,
      displayName: displayName ?? 'User $id',
    );
  }

  SessionMessage makeUserMessage({
    required String content,
    required DateTime timestamp,
    String eventId = 'evt_1',
  }) {
    return SessionMessage.user(
      content: content,
      eventId: eventId,
      timestamp: timestamp,
    );
  }

  SessionMessage makeAssistantMessage({
    required String content,
    required DateTime timestamp,
  }) {
    return SessionMessage.assistant(
      content: content,
      timestamp: timestamp,
    );
  }

  // ===========================================================================
  // TC-030: SessionManager.migrateSession
  // ===========================================================================
  group('TC-030: SessionManager.migrateSession', () {
    late InMemorySessionStore store;
    late SessionManager manager;

    setUp(() {
      store = InMemorySessionStore();
      manager = SessionManager(store);
    });

    tearDown(() {
      manager.dispose();
    });

    test('Normal: source session exists - creates new session with copied context/history, linked via crossChannelUserId',
        () async {
      // Create source session on Slack with context and history
      final sourceConv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_conv_1',
      );
      final sourceIdentity = makeIdentity(id: 'slack_user_1');

      final source = await manager.createSession(
        conversation: sourceConv,
        identity: sourceIdentity,
        context: {'topic': 'onboarding', 'step': 3},
        metadata: {'source': 'slack'},
      );

      // Add messages to source session
      await manager.addMessage(
        source.id,
        makeUserMessage(
          content: 'Hello from Slack',
          timestamp: now,
          eventId: 'evt_s1',
        ),
      );
      await manager.addMessage(
        source.id,
        makeAssistantMessage(
          content: 'Welcome! How can I help?',
          timestamp: now.add(const Duration(seconds: 1)),
        ),
      );

      // Migrate to Telegram
      final targetConv = makeConversation(
        channel: telegramChannel,
        conversationId: 'telegram_conv_1',
      );
      final targetIdentity = makeIdentity(id: 'telegram_user_1');

      final migrated = await manager.migrateSession(
        sourceSessionId: source.id,
        targetConversation: targetConv,
        targetIdentity: targetIdentity,
      );

      // Verify new session was created
      expect(migrated.id, isNot(source.id));
      expect(migrated.state, SessionState.active);

      // Verify conversation is the target
      expect(migrated.conversation, targetConv);
      expect(migrated.conversation.channel.platform, 'telegram');

      // Verify context was copied
      expect(migrated.context['topic'], 'onboarding');
      expect(migrated.context['step'], 3);

      // Verify history was copied
      expect(migrated.history, hasLength(2));
      expect(migrated.history[0].content, 'Hello from Slack');
      expect(migrated.history[1].content, 'Welcome! How can I help?');

      // Verify cross-channel linking
      expect(migrated.crossChannelUserId, isNotNull);

      // Verify source session was also linked
      final updatedSource = await manager.getSession(source.id);
      expect(updatedSource!.crossChannelUserId, migrated.crossChannelUserId);

      // Verify metadata contains migration info
      expect(migrated.metadata, isNotNull);
      expect(migrated.metadata!['migratedFrom'], source.id);
      expect(migrated.metadata!['migratedAt'], isNotNull);
      expect(migrated.metadata!['sourcePlatform'], 'slack');

      // Verify principal uses target identity
      expect(migrated.principal.identity.id, 'telegram_user_1');
      expect(
        migrated.principal.tenantId,
        targetConv.channel.channelId,
      );
    });

    test('Normal: source with existing crossChannelUserId preserves the link',
        () async {
      // Create source session and pre-link to a global user
      final sourceConv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_conv_linked',
      );
      final source = await manager.createSession(
        conversation: sourceConv,
        identity: makeIdentity(id: 'user_linked'),
      );

      await manager.linkToGlobalUser(source.id, 'global_user_42');

      // Migrate to Discord
      final targetConv = makeConversation(
        channel: discordChannel,
        conversationId: 'discord_conv_1',
      );

      final migrated = await manager.migrateSession(
        sourceSessionId: source.id,
        targetConversation: targetConv,
        targetIdentity: makeIdentity(id: 'discord_user_1'),
      );

      // Should reuse the existing crossChannelUserId
      expect(migrated.crossChannelUserId, 'global_user_42');
    });

    test('Boundary: historyToMigrate > source history - all history copied',
        () async {
      final sourceConv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_conv_boundary',
      );
      final source = await manager.createSession(
        conversation: sourceConv,
        identity: makeIdentity(id: 'user_b'),
      );

      // Add only 3 messages
      for (var i = 0; i < 3; i++) {
        await manager.addMessage(
          source.id,
          makeUserMessage(
            content: 'Message $i',
            timestamp: now.add(Duration(seconds: i)),
            eventId: 'evt_b_$i',
          ),
        );
      }

      // Migrate with historyToMigrate = 100 (much larger than 3)
      final targetConv = makeConversation(
        channel: telegramChannel,
        conversationId: 'telegram_conv_boundary',
      );

      final migrated = await manager.migrateSession(
        sourceSessionId: source.id,
        targetConversation: targetConv,
        targetIdentity: makeIdentity(id: 'tg_user_b'),
        historyToMigrate: 100,
      );

      // All 3 messages should be copied
      expect(migrated.history, hasLength(3));
      expect(migrated.history[0].content, 'Message 0');
      expect(migrated.history[1].content, 'Message 1');
      expect(migrated.history[2].content, 'Message 2');
    });

    test('Boundary: historyToMigrate limits the number of copied messages',
        () async {
      final sourceConv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_conv_limit',
      );
      final source = await manager.createSession(
        conversation: sourceConv,
        identity: makeIdentity(id: 'user_limit'),
      );

      // Add 10 messages
      for (var i = 0; i < 10; i++) {
        await manager.addMessage(
          source.id,
          makeUserMessage(
            content: 'Message $i',
            timestamp: now.add(Duration(seconds: i)),
            eventId: 'evt_limit_$i',
          ),
        );
      }

      // Migrate with historyToMigrate = 3
      final targetConv = makeConversation(
        channel: telegramChannel,
        conversationId: 'telegram_conv_limit',
      );

      final migrated = await manager.migrateSession(
        sourceSessionId: source.id,
        targetConversation: targetConv,
        targetIdentity: makeIdentity(id: 'tg_user_limit'),
        historyToMigrate: 3,
      );

      // Only the 3 most recent messages should be copied
      expect(migrated.history, hasLength(3));
      expect(migrated.history[0].content, 'Message 7');
      expect(migrated.history[1].content, 'Message 8');
      expect(migrated.history[2].content, 'Message 9');
    });

    test('Error: source session not found - throws SessionNotFound', () async {
      final targetConv = makeConversation(
        channel: telegramChannel,
        conversationId: 'telegram_conv_err',
      );

      expect(
        () => manager.migrateSession(
          sourceSessionId: 'nonexistent_session_id',
          targetConversation: targetConv,
          targetIdentity: makeIdentity(id: 'tg_user_err'),
        ),
        throwsA(isA<SessionNotFound>()),
      );
    });

    test('Source session remains active after migration', () async {
      final sourceConv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_conv_active',
      );
      final source = await manager.createSession(
        conversation: sourceConv,
        identity: makeIdentity(id: 'user_active'),
      );

      final targetConv = makeConversation(
        channel: telegramChannel,
        conversationId: 'telegram_conv_active',
      );

      await manager.migrateSession(
        sourceSessionId: source.id,
        targetConversation: targetConv,
        targetIdentity: makeIdentity(id: 'tg_user_active'),
      );

      // Source session should still be active (not closed)
      final updatedSource = await manager.getSession(source.id);
      expect(updatedSource, isNotNull);
      expect(updatedSource!.state, SessionState.active);
    });
  });

  // ===========================================================================
  // TC-031: SessionManager.getGlobalHistory
  // ===========================================================================
  group('TC-031: SessionManager.getGlobalHistory', () {
    late InMemorySessionStore store;
    late SessionManager manager;

    setUp(() {
      store = InMemorySessionStore();
      manager = SessionManager(store);
    });

    tearDown(() {
      manager.dispose();
    });

    test('Normal: 2 sessions for same user - merged history sorted by timestamp',
        () async {
      const globalUserId = 'global_user_merge';

      // Create session 1 on Slack
      final conv1 = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_merge_1',
      );
      final session1 = await manager.createSession(
        conversation: conv1,
        identity: makeIdentity(id: 'slack_u1'),
      );
      await manager.linkToGlobalUser(session1.id, globalUserId);

      // Add messages to session 1 at t=0s and t=2s
      await manager.addMessage(
        session1.id,
        makeUserMessage(
          content: 'Slack msg 1',
          timestamp: now,
          eventId: 'evt_sm1',
        ),
      );
      await manager.addMessage(
        session1.id,
        makeAssistantMessage(
          content: 'Slack reply 1',
          timestamp: now.add(const Duration(seconds: 2)),
        ),
      );

      // Create session 2 on Telegram
      final conv2 = makeConversation(
        channel: telegramChannel,
        conversationId: 'telegram_merge_1',
      );
      final session2 = await manager.createSession(
        conversation: conv2,
        identity: makeIdentity(id: 'tg_u1'),
      );
      await manager.linkToGlobalUser(session2.id, globalUserId);

      // Add messages to session 2 at t=1s and t=3s (interleaved)
      await manager.addMessage(
        session2.id,
        makeUserMessage(
          content: 'Telegram msg 1',
          timestamp: now.add(const Duration(seconds: 1)),
          eventId: 'evt_tm1',
        ),
      );
      await manager.addMessage(
        session2.id,
        makeAssistantMessage(
          content: 'Telegram reply 1',
          timestamp: now.add(const Duration(seconds: 3)),
        ),
      );

      // Get global history
      final history = await manager.getGlobalHistory(globalUserId);

      // Should be merged and sorted by timestamp
      expect(history, hasLength(4));
      expect(history[0].content, 'Slack msg 1'); // t=0s
      expect(history[1].content, 'Telegram msg 1'); // t=1s
      expect(history[2].content, 'Slack reply 1'); // t=2s
      expect(history[3].content, 'Telegram reply 1'); // t=3s
    });

    test('Boundary: maxMessages exceeded - trimmed to most recent', () async {
      const globalUserId = 'global_user_trim';

      // Create a session and link it
      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_trim_1',
      );
      final session = await manager.createSession(
        conversation: conv,
        identity: makeIdentity(id: 'slack_trim_u'),
      );
      await manager.linkToGlobalUser(session.id, globalUserId);

      // Add 10 messages
      for (var i = 0; i < 10; i++) {
        await manager.addMessage(
          session.id,
          makeUserMessage(
            content: 'Message $i',
            timestamp: now.add(Duration(seconds: i)),
            eventId: 'evt_trim_$i',
          ),
        );
      }

      // Request only the 3 most recent
      final history = await manager.getGlobalHistory(
        globalUserId,
        maxMessages: 3,
      );

      expect(history, hasLength(3));
      // Should be the 3 most recent messages
      expect(history[0].content, 'Message 7');
      expect(history[1].content, 'Message 8');
      expect(history[2].content, 'Message 9');
    });

    test('Boundary: no sessions for user - returns empty list', () async {
      final history = await manager.getGlobalHistory('nonexistent_global_user');
      expect(history, isEmpty);
    });

    test('Boundary: sessions exist but have no history - returns empty list',
        () async {
      const globalUserId = 'global_user_empty';

      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_empty_hist',
      );
      final session = await manager.createSession(
        conversation: conv,
        identity: makeIdentity(id: 'slack_empty_u'),
      );
      await manager.linkToGlobalUser(session.id, globalUserId);

      final history = await manager.getGlobalHistory(globalUserId);
      expect(history, isEmpty);
    });

    test('Normal: messages within maxMessages limit - all returned', () async {
      const globalUserId = 'global_user_within_limit';

      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_within_limit',
      );
      final session = await manager.createSession(
        conversation: conv,
        identity: makeIdentity(id: 'slack_wl_u'),
      );
      await manager.linkToGlobalUser(session.id, globalUserId);

      // Add 3 messages, with maxMessages default of 100
      for (var i = 0; i < 3; i++) {
        await manager.addMessage(
          session.id,
          makeUserMessage(
            content: 'Message $i',
            timestamp: now.add(Duration(seconds: i)),
            eventId: 'evt_wl_$i',
          ),
        );
      }

      final history = await manager.getGlobalHistory(globalUserId);
      expect(history, hasLength(3));
    });
  });

  // ===========================================================================
  // TC-126: SessionManager.linkToGlobalUser
  // ===========================================================================
  group('TC-126: SessionManager.linkToGlobalUser', () {
    late InMemorySessionStore store;
    late SessionManager manager;

    setUp(() {
      store = InMemorySessionStore();
      manager = SessionManager(store);
    });

    tearDown(() {
      manager.dispose();
    });

    test('Normal: links session to global user successfully', () async {
      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_link_1',
      );
      final session = await manager.createSession(
        conversation: conv,
        identity: makeIdentity(id: 'user_link_1'),
      );

      // Initially no crossChannelUserId
      expect(session.crossChannelUserId, isNull);

      final linked = await manager.linkToGlobalUser(
        session.id,
        'global_user_link_1',
      );

      expect(linked.crossChannelUserId, 'global_user_link_1');

      // Verify persisted in store
      final stored = await manager.getSession(session.id);
      expect(stored!.crossChannelUserId, 'global_user_link_1');
    });

    test('Normal: re-linking overwrites the previous crossChannelUserId',
        () async {
      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_relink',
      );
      final session = await manager.createSession(
        conversation: conv,
        identity: makeIdentity(id: 'user_relink'),
      );

      await manager.linkToGlobalUser(session.id, 'first_global_id');
      final relinked = await manager.linkToGlobalUser(
        session.id,
        'second_global_id',
      );

      expect(relinked.crossChannelUserId, 'second_global_id');
    });

    test('Error: session not found - throws SessionNotFound', () async {
      expect(
        () => manager.linkToGlobalUser('nonexistent_id', 'global_user_x'),
        throwsA(isA<SessionNotFound>()),
      );
    });
  });

  // ===========================================================================
  // TC-127: SessionManager.getGlobalUserSessions
  // ===========================================================================
  group('TC-127: SessionManager.getGlobalUserSessions', () {
    late InMemorySessionStore store;
    late SessionManager manager;

    setUp(() {
      store = InMemorySessionStore();
      manager = SessionManager(store);
    });

    tearDown(() {
      manager.dispose();
    });

    test('Normal: returns all sessions linked to a global user', () async {
      const globalUserId = 'global_multi_sessions';

      // Create 3 sessions on different platforms
      final convSlack = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_gus_1',
      );
      final convTelegram = makeConversation(
        channel: telegramChannel,
        conversationId: 'tg_gus_1',
      );
      final convDiscord = makeConversation(
        channel: discordChannel,
        conversationId: 'discord_gus_1',
      );

      final s1 = await manager.createSession(
        conversation: convSlack,
        identity: makeIdentity(id: 'slack_gus_u'),
      );
      final s2 = await manager.createSession(
        conversation: convTelegram,
        identity: makeIdentity(id: 'tg_gus_u'),
      );
      final s3 = await manager.createSession(
        conversation: convDiscord,
        identity: makeIdentity(id: 'discord_gus_u'),
      );

      // Link all to the same global user
      await manager.linkToGlobalUser(s1.id, globalUserId);
      await manager.linkToGlobalUser(s2.id, globalUserId);
      await manager.linkToGlobalUser(s3.id, globalUserId);

      final sessions = await manager.getGlobalUserSessions(globalUserId);

      expect(sessions, hasLength(3));
      final sessionIds = sessions.map((s) => s.id).toSet();
      expect(sessionIds, contains(s1.id));
      expect(sessionIds, contains(s2.id));
      expect(sessionIds, contains(s3.id));
    });

    test('Boundary: no sessions linked to global user - returns empty list',
        () async {
      final sessions = await manager.getGlobalUserSessions(
        'nonexistent_global_user',
      );
      expect(sessions, isEmpty);
    });

    test('Boundary: only one session linked - returns single-element list',
        () async {
      const globalUserId = 'global_single_session';

      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_single_gus',
      );
      final session = await manager.createSession(
        conversation: conv,
        identity: makeIdentity(id: 'single_u'),
      );
      await manager.linkToGlobalUser(session.id, globalUserId);

      final sessions = await manager.getGlobalUserSessions(globalUserId);

      expect(sessions, hasLength(1));
      expect(sessions.first.id, session.id);
    });

    test('Normal: sessions for different global users are isolated', () async {
      const globalUserA = 'global_user_A';
      const globalUserB = 'global_user_B';

      final convA = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_iso_a',
      );
      final convB = makeConversation(
        channel: telegramChannel,
        conversationId: 'tg_iso_b',
      );

      final sA = await manager.createSession(
        conversation: convA,
        identity: makeIdentity(id: 'user_iso_a'),
      );
      final sB = await manager.createSession(
        conversation: convB,
        identity: makeIdentity(id: 'user_iso_b'),
      );

      await manager.linkToGlobalUser(sA.id, globalUserA);
      await manager.linkToGlobalUser(sB.id, globalUserB);

      final sessionsA = await manager.getGlobalUserSessions(globalUserA);
      final sessionsB = await manager.getGlobalUserSessions(globalUserB);

      expect(sessionsA, hasLength(1));
      expect(sessionsA.first.id, sA.id);
      expect(sessionsB, hasLength(1));
      expect(sessionsB.first.id, sB.id);
    });
  });

  // ===========================================================================
  // TC-122: SessionManager.addMessageSafe
  // ===========================================================================
  group('TC-122: SessionManager.addMessageSafe', () {
    late InMemorySessionStore store;
    late SessionManager manager;

    setUp(() {
      store = InMemorySessionStore();
      manager = SessionManager(store);
    });

    tearDown(() {
      manager.dispose();
    });

    test('Normal: adds message successfully without concurrency conflict',
        () async {
      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_safe_1',
      );
      final session = await manager.createSession(
        conversation: conv,
        identity: makeIdentity(id: 'user_safe_1'),
      );

      final msg = makeUserMessage(
        content: 'Safe message',
        timestamp: now,
        eventId: 'evt_safe_1',
      );

      final updated = await manager.addMessageSafe(session.id, msg);

      expect(updated.history, hasLength(1));
      expect(updated.history.first.content, 'Safe message');
    });

    test('Normal: multiple sequential addMessageSafe calls succeed', () async {
      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_safe_seq',
      );
      final session = await manager.createSession(
        conversation: conv,
        identity: makeIdentity(id: 'user_safe_seq'),
      );

      for (var i = 0; i < 5; i++) {
        await manager.addMessageSafe(
          session.id,
          makeUserMessage(
            content: 'Safe message $i',
            timestamp: now.add(Duration(seconds: i)),
            eventId: 'evt_safe_seq_$i',
          ),
        );
      }

      final result = await manager.getSession(session.id);
      expect(result!.history, hasLength(5));
      expect(result.history.last.content, 'Safe message 4');
    });

    test('Error: session not found - throws SessionNotFound', () async {
      final msg = makeUserMessage(
        content: 'Orphan message',
        timestamp: now,
        eventId: 'evt_orphan',
      );

      expect(
        () => manager.addMessageSafe('nonexistent_safe_id', msg),
        throwsA(isA<SessionNotFound>()),
      );
    });

    test('Error: exhausts retries on persistent ConcurrentModificationException',
        () async {
      // Use a custom store that always throws ConcurrentModificationException
      // on saveIfCurrent to simulate persistent conflicts
      final conflictStore = _AlwaysConflictSessionStore();
      final conflictManager = SessionManager(conflictStore);
      addTearDown(conflictManager.dispose);

      // Pre-populate the store with a session
      final conv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_conflict',
      );
      final identity = makeIdentity(id: 'user_conflict');
      final principal = Principal.basic(
        identity: identity,
        tenantId: slackChannel.channelId,
      );
      final session = Session(
        id: 'conflict_session',
        conversation: conv,
        principal: principal,
        state: SessionState.active,
        createdAt: now,
        lastActivityAt: now,
      );
      await conflictStore.save(session);

      final msg = makeUserMessage(
        content: 'Will conflict',
        timestamp: now,
        eventId: 'evt_conflict',
      );

      expect(
        () => conflictManager.addMessageSafe(
          'conflict_session',
          msg,
          maxRetries: 3,
        ),
        throwsA(isA<ConcurrentModificationException>()),
      );
    });
  });

  // ===========================================================================
  // Integration: migrateSession + getGlobalUserSessions + getGlobalHistory
  // ===========================================================================
  group('Integration: cross-channel migration workflow', () {
    late InMemorySessionStore store;
    late SessionManager manager;

    setUp(() {
      store = InMemorySessionStore();
      manager = SessionManager(store);
    });

    tearDown(() {
      manager.dispose();
    });

    test('Full migration flow: Slack -> Telegram with global user query',
        () async {
      // Step 1: User starts on Slack
      final slackConv = makeConversation(
        channel: slackChannel,
        conversationId: 'slack_full_flow',
      );
      final slackSession = await manager.createSession(
        conversation: slackConv,
        identity: makeIdentity(id: 'user_flow'),
        context: {'language': 'en', 'level': 'beginner'},
      );

      await manager.addMessage(
        slackSession.id,
        makeUserMessage(
          content: 'Start on Slack',
          timestamp: now,
          eventId: 'evt_flow_1',
        ),
      );
      await manager.addMessage(
        slackSession.id,
        makeAssistantMessage(
          content: 'Welcome on Slack!',
          timestamp: now.add(const Duration(seconds: 1)),
        ),
      );

      // Step 2: Migrate to Telegram
      final telegramConv = makeConversation(
        channel: telegramChannel,
        conversationId: 'telegram_full_flow',
      );
      final telegramSession = await manager.migrateSession(
        sourceSessionId: slackSession.id,
        targetConversation: telegramConv,
        targetIdentity: makeIdentity(id: 'tg_user_flow'),
      );

      // Step 3: Continue conversation on Telegram
      await manager.addMessage(
        telegramSession.id,
        makeUserMessage(
          content: 'Continue on Telegram',
          timestamp: now.add(const Duration(seconds: 2)),
          eventId: 'evt_flow_2',
        ),
      );

      // Step 4: Verify global sessions
      final globalUserId = telegramSession.crossChannelUserId!;
      final globalSessions =
          await manager.getGlobalUserSessions(globalUserId);
      expect(globalSessions, hasLength(2));

      // Step 5: Verify global history (merged and sorted)
      final globalHistory = await manager.getGlobalHistory(globalUserId);
      expect(globalHistory, hasLength(5)); // 2 from slack + 2 migrated + 1 new

      // Verify chronological order
      for (var i = 1; i < globalHistory.length; i++) {
        expect(
          globalHistory[i].timestamp.millisecondsSinceEpoch,
          greaterThanOrEqualTo(
            globalHistory[i - 1].timestamp.millisecondsSinceEpoch,
          ),
        );
      }
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

/// A session store that always throws ConcurrentModificationException on
/// saveIfCurrent, simulating persistent version conflicts.
class _AlwaysConflictSessionStore implements SessionStore {
  final Map<String, Session> _sessions = {};

  @override
  Future<Session?> get(String sessionId) async {
    return _sessions[sessionId];
  }

  @override
  Future<Session?> getByConversation(ConversationKey conversation) async {
    return null;
  }

  @override
  Future<Session?> getByUser(String channelType, String userId) async {
    return null;
  }

  @override
  Future<void> save(Session session) async {
    _sessions[session.id] = session;
  }

  @override
  Future<void> saveIfCurrent(Session session) async {
    throw ConcurrentModificationException(
      sessionId: session.id,
      expectedVersion: session.version - 1,
      actualVersion: session.version + 5,
    );
  }

  @override
  Future<void> delete(String sessionId) async {
    _sessions.remove(sessionId);
  }

  @override
  Future<int> cleanupExpired() async => 0;

  @override
  Future<List<Session>> getByGlobalUser(String crossChannelUserId) async {
    return [];
  }

  @override
  Future<List<Session>> list({
    int offset = 0,
    int limit = 100,
    SessionState? state,
  }) async {
    return [];
  }
}
