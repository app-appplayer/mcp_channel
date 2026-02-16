import 'package:meta/meta.dart';

import '../types/conversation_key.dart';
import 'principal.dart';
import 'session_message.dart';
import 'session_state.dart';

/// Represents a conversation session with state and history.
@immutable
class Session {
  /// Unique session identifier
  final String id;

  /// Conversation key
  final ConversationKey conversation;

  /// Authenticated principal
  final Principal principal;

  /// Current state
  final SessionState state;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last activity timestamp
  final DateTime lastActivityAt;

  /// Expiration timestamp (optional)
  final DateTime? expiresAt;

  /// Application context/state data
  final Map<String, dynamic> context;

  /// Recent message history
  final List<SessionMessage> history;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  const Session({
    required this.id,
    required this.conversation,
    required this.principal,
    required this.state,
    required this.createdAt,
    required this.lastActivityAt,
    this.expiresAt,
    this.context = const {},
    this.history = const [],
    this.metadata,
  });

  /// Check if session is expired
  bool get isExpired =>
      state == SessionState.expired ||
      (expiresAt != null && DateTime.now().isAfter(expiresAt!));

  /// Check if session is active and valid
  bool get isActive => state == SessionState.active && !isExpired;

  /// Check if session is closed
  bool get isClosed => state == SessionState.closed;

  /// Create copy with updated fields
  Session copyWith({
    String? id,
    ConversationKey? conversation,
    Principal? principal,
    SessionState? state,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    DateTime? expiresAt,
    Map<String, dynamic>? context,
    List<SessionMessage>? history,
    Map<String, dynamic>? metadata,
  }) {
    return Session(
      id: id ?? this.id,
      conversation: conversation ?? this.conversation,
      principal: principal ?? this.principal,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      expiresAt: expiresAt ?? this.expiresAt,
      context: context ?? this.context,
      history: history ?? this.history,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Add message to history
  Session addMessage(SessionMessage message) {
    return copyWith(
      history: [...history, message],
      lastActivityAt: DateTime.now(),
    );
  }

  /// Update context value
  Session updateContext(String key, dynamic value) {
    return copyWith(
      context: {...context, key: value},
      lastActivityAt: DateTime.now(),
    );
  }

  /// Remove context value
  Session removeContext(String key) {
    final newContext = Map<String, dynamic>.from(context)..remove(key);
    return copyWith(
      context: newContext,
      lastActivityAt: DateTime.now(),
    );
  }

  /// Clear all context
  Session clearContext() {
    return copyWith(
      context: const {},
      lastActivityAt: DateTime.now(),
    );
  }

  /// Touch session (update lastActivityAt)
  Session touch() {
    return copyWith(lastActivityAt: DateTime.now());
  }

  /// Pause the session
  Session pause() {
    return copyWith(
      state: SessionState.paused,
      lastActivityAt: DateTime.now(),
    );
  }

  /// Resume a paused session
  Session resume() {
    if (state != SessionState.paused) return this;
    return copyWith(
      state: SessionState.active,
      lastActivityAt: DateTime.now(),
    );
  }

  /// Close the session
  Session close() {
    return copyWith(
      state: SessionState.closed,
      lastActivityAt: DateTime.now(),
    );
  }

  /// Expire the session
  Session expire() {
    return copyWith(
      state: SessionState.expired,
      lastActivityAt: DateTime.now(),
    );
  }

  /// Trim history to max size
  Session trimHistory(int maxSize) {
    if (history.length <= maxSize) return this;
    return copyWith(
      history: history.sublist(history.length - maxSize),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation': conversation.toJson(),
        'principal': principal.toJson(),
        'state': state.name,
        'createdAt': createdAt.toIso8601String(),
        'lastActivityAt': lastActivityAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'context': context,
        'history': history.map((m) => m.toJson()).toList(),
        if (metadata != null) 'metadata': metadata,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      conversation:
          ConversationKey.fromJson(json['conversation'] as Map<String, dynamic>),
      principal:
          Principal.fromJson(json['principal'] as Map<String, dynamic>),
      state: SessionState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => SessionState.expired,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActivityAt: DateTime.parse(json['lastActivityAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      context: Map<String, dynamic>.from(json['context'] as Map? ?? {}),
      history: (json['history'] as List?)
              ?.map(
                  (m) => SessionMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Session(id: $id, state: ${state.name}, conversation: ${conversation.key})';
}
