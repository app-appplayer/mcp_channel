import 'package:mcp_bundle/ports.dart';

import 'concurrent_modification_exception.dart';
import 'session.dart';
import 'session_state.dart';

/// Session store configuration.
class SessionStoreConfig {
  const SessionStoreConfig({
    this.defaultTimeout = const Duration(hours: 24),
    this.maxHistorySize = 100,
    this.cleanupInterval = const Duration(minutes: 15),
    this.persistent = false,
  });

  /// Default session timeout
  final Duration defaultTimeout;

  /// Maximum history messages to keep
  final int maxHistorySize;

  /// Cleanup interval for expired sessions
  final Duration cleanupInterval;

  /// Whether to persist across restarts
  final bool persistent;

  SessionStoreConfig copyWith({
    Duration? defaultTimeout,
    int? maxHistorySize,
    Duration? cleanupInterval,
    bool? persistent,
  }) {
    return SessionStoreConfig(
      defaultTimeout: defaultTimeout ?? this.defaultTimeout,
      maxHistorySize: maxHistorySize ?? this.maxHistorySize,
      cleanupInterval: cleanupInterval ?? this.cleanupInterval,
      persistent: persistent ?? this.persistent,
    );
  }
}

/// Exception thrown when a session is not found.
class SessionNotFound implements Exception {
  const SessionNotFound(this.sessionId);

  final String sessionId;

  @override
  String toString() => 'SessionNotFound: $sessionId';
}

/// Interface for session storage.
abstract class SessionStore {
  /// Get session by ID
  Future<Session?> get(String sessionId);

  /// Get session by conversation key
  Future<Session?> getByConversation(ConversationKey conversation);

  /// Get session by user identity
  Future<Session?> getByUser(String channelType, String userId);

  /// Save session
  Future<void> save(Session session);

  /// Save session with optimistic concurrency check.
  ///
  /// Throws [ConcurrentModificationException] if the session's version
  /// does not match the currently stored version.
  Future<void> saveIfCurrent(Session session);

  /// Delete session
  Future<void> delete(String sessionId);

  /// Clean up expired sessions
  Future<int> cleanupExpired();

  /// Get all sessions for a cross-channel user.
  Future<List<Session>> getByGlobalUser(String crossChannelUserId);

  /// List sessions (with pagination)
  Future<List<Session>> list({
    int offset = 0,
    int limit = 100,
    SessionState? state,
  });
}

/// In-memory implementation of SessionStore.
class InMemorySessionStore implements SessionStore {
  final Map<String, Session> _sessions = {};
  final Map<String, String> _conversationIndex = {};
  final Map<String, String> _userIndex = {};
  final Map<String, Set<String>> _globalUserIndex = {};

  /// Generate a unique key from ConversationKey.
  String _conversationKeyToString(ConversationKey conv) {
    return '${conv.channel.platform}:${conv.channel.channelId}:${conv.conversationId}';
  }

  @override
  Future<Session?> get(String sessionId) async {
    return _sessions[sessionId];
  }

  @override
  Future<Session?> getByConversation(ConversationKey conversation) async {
    final sessionId = _conversationIndex[_conversationKeyToString(conversation)];
    return sessionId != null ? _sessions[sessionId] : null;
  }

  @override
  Future<Session?> getByUser(String channelType, String userId) async {
    final key = '$channelType:$userId';
    final sessionId = _userIndex[key];
    return sessionId != null ? _sessions[sessionId] : null;
  }

  @override
  Future<void> save(Session session) async {
    _sessions[session.id] = session;
    _conversationIndex[_conversationKeyToString(session.conversation)] = session.id;

    final userKey =
        '${session.conversation.channel.platform}:${session.principal.identity.id}';
    _userIndex[userKey] = session.id;

    // Index by global user
    if (session.crossChannelUserId != null) {
      _globalUserIndex
          .putIfAbsent(session.crossChannelUserId!, () => {})
          .add(session.id);
    }
  }

  @override
  Future<void> saveIfCurrent(Session session) async {
    final existing = _sessions[session.id];
    if (existing != null && existing.version != session.version - 1) {
      throw ConcurrentModificationException(
        sessionId: session.id,
        expectedVersion: session.version - 1,
        actualVersion: existing.version,
      );
    }
    await save(session);
  }

  @override
  Future<void> delete(String sessionId) async {
    final session = _sessions.remove(sessionId);
    if (session != null) {
      _conversationIndex.remove(_conversationKeyToString(session.conversation));

      final userKey =
          '${session.conversation.channel.platform}:${session.principal.identity.id}';
      _userIndex.remove(userKey);

      // Clean up global user index
      if (session.crossChannelUserId != null) {
        final ids = _globalUserIndex[session.crossChannelUserId!];
        if (ids != null) {
          ids.remove(sessionId);
          if (ids.isEmpty) {
            _globalUserIndex.remove(session.crossChannelUserId!);
          }
        }
      }
    }
  }

  @override
  Future<int> cleanupExpired() async {
    final expired = _sessions.values
        .where((s) => s.isExpired)
        .map((s) => s.id)
        .toList();

    for (final id in expired) {
      await delete(id);
    }

    return expired.length;
  }

  @override
  Future<List<Session>> getByGlobalUser(String crossChannelUserId) async {
    final sessionIds = _globalUserIndex[crossChannelUserId] ?? {};
    return sessionIds
        .map((id) => _sessions[id])
        .whereType<Session>()
        .toList();
  }

  @override
  Future<List<Session>> list({
    int offset = 0,
    int limit = 100,
    SessionState? state,
  }) async {
    var sessions = _sessions.values.toList();

    if (state != null) {
      sessions = sessions.where((s) => s.state == state).toList();
    }

    sessions.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));

    if (offset >= sessions.length) return [];

    final end = offset + limit;
    return sessions.sublist(
      offset,
      end > sessions.length ? sessions.length : end,
    );
  }

  /// Clear all sessions (for testing)
  void clear() {
    _sessions.clear();
    _conversationIndex.clear();
    _userIndex.clear();
    _globalUserIndex.clear();
  }

  /// Get total session count
  int get count => _sessions.length;
}
