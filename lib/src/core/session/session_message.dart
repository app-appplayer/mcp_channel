import 'package:meta/meta.dart';

import 'message_role.dart';

/// Tool call information within a session.
@immutable
class SessionToolCall {
  const SessionToolCall({
    required this.name,
    required this.arguments,
    this.id,
  });

  factory SessionToolCall.fromJson(Map<String, dynamic> json) {
    return SessionToolCall(
      name: json['name'] as String,
      arguments: Map<String, dynamic>.from(json['arguments'] as Map),
      id: json['id'] as String?,
    );
  }

  /// Tool name
  final String name;

  /// Tool arguments
  final Map<String, dynamic> arguments;

  /// Call ID (for matching with results)
  final String? id;

  Map<String, dynamic> toJson() => {
        'name': name,
        'arguments': arguments,
        if (id != null) 'id': id,
      };

  @override
  String toString() => 'SessionToolCall(name: $name, id: $id)';
}

/// Tool execution result within a session.
@immutable
class SessionToolResult {
  const SessionToolResult({
    required this.toolName,
    required this.content,
    this.success = true,
    this.error,
  });

  factory SessionToolResult.fromJson(Map<String, dynamic> json) {
    return SessionToolResult(
      toolName: json['toolName'] as String,
      content: json['content'] as String,
      success: json['success'] as bool? ?? true,
      error: json['error'] as String?,
    );
  }

  /// Tool name
  final String toolName;

  /// Result content
  final String content;

  /// Whether the tool execution was successful
  final bool success;

  /// Error message (if failed)
  final String? error;

  Map<String, dynamic> toJson() => {
        'toolName': toolName,
        'content': content,
        'success': success,
        if (error != null) 'error': error,
      };

  @override
  String toString() => 'SessionToolResult(toolName: $toolName, success: $success)';
}

/// A message in session history.
@immutable
class SessionMessage {
  const SessionMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.eventId,
    this.toolCalls,
    this.toolResult,
    this.metadata,
  });

  /// Creates a user message.
  factory SessionMessage.user({
    required String content,
    required String eventId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SessionMessage(
      role: MessageRole.user,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      eventId: eventId,
      metadata: metadata,
    );
  }

  /// Creates an assistant message.
  factory SessionMessage.assistant({
    required String content,
    List<SessionToolCall>? toolCalls,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SessionMessage(
      role: MessageRole.assistant,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      toolCalls: toolCalls,
      metadata: metadata,
    );
  }

  /// Creates a system message.
  factory SessionMessage.system({
    required String content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SessionMessage(
      role: MessageRole.system,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      metadata: metadata,
    );
  }

  /// Creates a tool result message.
  factory SessionMessage.tool({
    required String content,
    required SessionToolResult result,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SessionMessage(
      role: MessageRole.tool,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      toolResult: result,
      metadata: metadata,
    );
  }

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    return SessionMessage(
      role: MessageRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      eventId: json['eventId'] as String?,
      toolCalls: json['toolCalls'] != null
          ? (json['toolCalls'] as List)
              .map((t) =>
                  SessionToolCall.fromJson(t as Map<String, dynamic>))
              .toList()
          : null,
      toolResult: json['toolResult'] != null
          ? SessionToolResult.fromJson(
              json['toolResult'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Message role
  final MessageRole role;

  /// Message content
  final String content;

  /// Timestamp
  final DateTime timestamp;

  /// Original event ID (for user messages)
  final String? eventId;

  /// Tool calls (for assistant messages)
  final List<SessionToolCall>? toolCalls;

  /// Tool result (for tool messages)
  final SessionToolResult? toolResult;

  /// Metadata
  final Map<String, dynamic>? metadata;

  SessionMessage copyWith({
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    String? eventId,
    List<SessionToolCall>? toolCalls,
    SessionToolResult? toolResult,
    Map<String, dynamic>? metadata,
  }) {
    return SessionMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      eventId: eventId ?? this.eventId,
      toolCalls: toolCalls ?? this.toolCalls,
      toolResult: toolResult ?? this.toolResult,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (eventId != null) 'eventId': eventId,
        if (toolCalls != null)
          'toolCalls': toolCalls!.map((t) => t.toJson()).toList(),
        if (toolResult != null) 'toolResult': toolResult!.toJson(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() =>
      'SessionMessage(role: ${role.name}, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
}
