import 'dart:async';

import 'package:mcp_bundle/ports.dart';
import 'package:uuid/uuid.dart';

import '../types/channel_identity_info.dart';
import 'concurrent_modification_exception.dart';
import 'principal.dart';
import 'session.dart';
import 'session_message.dart';
import 'session_state.dart';
import 'session_store.dart';

/// High-level session management service.
class SessionManager {
  SessionManager(this._store, {SessionStoreConfig? config})
      : _config = config ?? const SessionStoreConfig();

  final SessionStore _store;
  final SessionStoreConfig _config;
  final Uuid _uuid = const Uuid();
  Timer? _cleanupTimer;

  /// Generate a unique session ID.
  String _generateSessionId() => _uuid.v4();

  /// Create a principal from an event.
  Future<Principal> _createPrincipal(ChannelEvent event) async {
    // Create identity info from event's channel info
    final identity = ChannelIdentityInfo.user(
      id: event.userId ?? 'unknown',
      displayName: event.userName,
    );
    return Principal.basic(
      identity: identity,
      tenantId: event.conversation.channel.channelId,
      expiresAt: DateTime.now().add(_config.defaultTimeout),
    );
  }

  /// Get or create session for an event.
  Future<Session> getOrCreateSession(ChannelEvent event) async {
    // Try to find existing session
    var session = await _store.getByConversation(event.conversation);

    if (session != null && session.isActive) {
      // Update activity timestamp
      session = session.touch();
      await _store.save(session);
      return session;
    }

    // Create new session
    final principal = await _createPrincipal(event);
    session = Session(
      id: _generateSessionId(),
      conversation: event.conversation,
      principal: principal,
      state: SessionState.active,
      createdAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
      expiresAt: DateTime.now().add(_config.defaultTimeout),
    );

    await _store.save(session);
    return session;
  }

  /// Get session by ID.
  Future<Session?> getSession(String sessionId) {
    return _store.get(sessionId);
  }

  /// Get session by conversation key.
  Future<Session?> getSessionByConversation(ConversationKey conversation) {
    return _store.getByConversation(conversation);
  }

  /// Create a new session explicitly.
  Future<Session> createSession({
    required ConversationKey conversation,
    required ChannelIdentityInfo identity,
    Map<String, dynamic>? context,
    Map<String, dynamic>? metadata,
  }) async {
    final principal = Principal.basic(
      identity: identity,
      tenantId: conversation.channel.channelId,
      expiresAt: DateTime.now().add(_config.defaultTimeout),
    );

    final session = Session(
      id: _generateSessionId(),
      conversation: conversation,
      principal: principal,
      state: SessionState.active,
      createdAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
      expiresAt: DateTime.now().add(_config.defaultTimeout),
      context: context ?? const {},
      metadata: metadata,
    );

    await _store.save(session);
    return session;
  }

  /// Add message to session history.
  Future<Session> addMessage(
    String sessionId,
    SessionMessage message,
  ) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    var updated = session.addMessage(message);

    // Trim history if exceeds max size
    updated = updated.trimHistory(_config.maxHistorySize);

    await _store.save(updated);
    return updated;
  }

  /// Add message with concurrency-safe retry.
  Future<Session> addMessageSafe(
    String sessionId,
    SessionMessage message, {
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final session = await _store.get(sessionId);
        if (session == null) throw SessionNotFound(sessionId);

        final updated = session.addMessage(message);
        await _store.saveIfCurrent(updated);
        return updated;
      } on ConcurrentModificationException {
        if (attempt == maxRetries - 1) rethrow;
        // Re-read and retry
        continue;
      }
    }
    throw StateError('Unreachable');
  }

  /// Update session context.
  Future<Session> updateContext(
    String sessionId,
    Map<String, dynamic> updates,
  ) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    final context = {...session.context, ...updates};
    final updated = session.copyWith(
      context: context,
      lastActivityAt: DateTime.now(),
    );

    await _store.save(updated);
    return updated;
  }

  /// Set a single context value.
  Future<Session> setContextValue(
    String sessionId,
    String key,
    dynamic value,
  ) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    final updated = session.updateContext(key, value);
    await _store.save(updated);
    return updated;
  }

  /// Remove a context value.
  Future<Session> removeContextValue(String sessionId, String key) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    final updated = session.removeContext(key);
    await _store.save(updated);
    return updated;
  }

  /// Clear all context.
  Future<Session> clearContext(String sessionId) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    final updated = session.clearContext();
    await _store.save(updated);
    return updated;
  }

  /// Pause session.
  Future<Session> pauseSession(String sessionId) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    final paused = session.pause();
    await _store.save(paused);
    return paused;
  }

  /// Resume session.
  Future<Session> resumeSession(String sessionId) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    final resumed = session.resume();
    await _store.save(resumed);
    return resumed;
  }

  /// Close session.
  Future<void> closeSession(String sessionId) async {
    final session = await _store.get(sessionId);
    if (session == null) return;

    final closed = session.close();
    await _store.save(closed);
  }

  /// Delete session.
  Future<void> deleteSession(String sessionId) async {
    await _store.delete(sessionId);
  }

  /// Touch session to extend expiration.
  Future<Session> touchSession(String sessionId) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    final touched = session.touch().copyWith(
          expiresAt: DateTime.now().add(_config.defaultTimeout),
        );
    await _store.save(touched);
    return touched;
  }

  /// List active sessions.
  Future<List<Session>> listSessions({
    int offset = 0,
    int limit = 100,
    SessionState? state,
  }) {
    return _store.list(offset: offset, limit: limit, state: state);
  }

  /// Start periodic cleanup.
  void startCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_config.cleanupInterval, (_) async {
      await _store.cleanupExpired();
    });
  }

  /// Stop periodic cleanup.
  void stopCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Manually trigger cleanup.
  Future<int> cleanup() {
    return _store.cleanupExpired();
  }

  /// Link a session to a global user identity.
  Future<Session> linkToGlobalUser(
    String sessionId,
    String crossChannelUserId,
  ) async {
    final session = await _store.get(sessionId);
    if (session == null) throw SessionNotFound(sessionId);

    final updated = session.copyWith(
      crossChannelUserId: crossChannelUserId,
    );
    await _store.save(updated);
    return updated;
  }

  /// Get all sessions for a global user across platforms.
  Future<List<Session>> getGlobalUserSessions(
    String crossChannelUserId,
  ) {
    return _store.getByGlobalUser(crossChannelUserId);
  }

  /// Get combined history across all sessions for a global user.
  ///
  /// Merges and sorts by timestamp. Useful for providing full context
  /// to an LLM regardless of which platform the user is currently on.
  Future<List<SessionMessage>> getGlobalHistory(
    String crossChannelUserId, {
    int maxMessages = 100,
  }) async {
    final sessions = await _store.getByGlobalUser(crossChannelUserId);

    final allMessages = sessions
        .expand((s) => s.history)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (allMessages.length > maxMessages) {
      return allMessages.sublist(allMessages.length - maxMessages);
    }
    return allMessages;
  }

  /// Migrate session context to a new platform.
  ///
  /// Creates a new session on the target conversation with the source
  /// session's context and recent history. The source session remains
  /// active (it is NOT closed).
  ///
  /// Both sessions are linked via [crossChannelUserId].
  Future<Session> migrateSession({
    required String sourceSessionId,
    required ConversationKey targetConversation,
    required ChannelIdentityInfo targetIdentity,
    int historyToMigrate = 20,
  }) async {
    final source = await _store.get(sourceSessionId);
    if (source == null) throw SessionNotFound(sourceSessionId);

    // Determine cross-channel user ID
    final globalUserId = source.crossChannelUserId ??
        'migrated_${source.principal.identity.id}';

    // Link source if not already linked
    if (source.crossChannelUserId == null) {
      await linkToGlobalUser(sourceSessionId, globalUserId);
    }

    // Create new session with migrated context
    final recentHistory = source.history.length > historyToMigrate
        ? source.history.sublist(source.history.length - historyToMigrate)
        : List<SessionMessage>.from(source.history);

    final target = Session(
      id: _generateSessionId(),
      conversation: targetConversation,
      principal: Principal(
        identity: targetIdentity,
        tenantId: targetConversation.channel.channelId,
        roles: source.principal.roles,
        permissions: source.principal.permissions,
        authenticatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(_config.defaultTimeout),
      ),
      state: SessionState.active,
      crossChannelUserId: globalUserId,
      createdAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
      expiresAt: DateTime.now().add(_config.defaultTimeout),
      context: Map<String, dynamic>.from(source.context),
      history: recentHistory,
      metadata: {
        'migratedFrom': sourceSessionId,
        'migratedAt': DateTime.now().toIso8601String(),
        'sourcePlatform': source.conversation.channel.platform,
      },
    );

    await _store.save(target);
    return target;
  }

  /// Dispose the session manager.
  void dispose() {
    stopCleanup();
  }
}
