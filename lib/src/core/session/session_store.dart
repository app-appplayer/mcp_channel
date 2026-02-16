import 'package:mcp_bundle/ports.dart';

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

  /// Delete session
  Future<void> delete(String sessionId);

  /// Clean up expired sessions
  Future<int> cleanupExpired();

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
        '${session.conversation.channel.platform}:${session.principal.identity.channelId}';
    _userIndex[userKey] = session.id;
  }

  @override
  Future<void> delete(String sessionId) async {
    final session = _sessions.remove(sessionId);
    if (session != null) {
      _conversationIndex.remove(_conversationKeyToString(session.conversation));

      final userKey =
          '${session.conversation.channel.platform}:${session.principal.identity.channelId}';
      _userIndex.remove(userKey);
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
  }

  /// Get total session count
  int get count => _sessions.length;
}
