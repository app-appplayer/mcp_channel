import 'package:meta/meta.dart';

import '../types/conversation_key.dart';

/// Information about a conversation.
@immutable
class ConversationInfo {
  /// Conversation key
  final ConversationKey key;

  /// Conversation name/title
  final String? name;

  /// Conversation topic/description
  final String? topic;

  /// Is this a private/DM conversation
  final bool isPrivate;

  /// Is this a group conversation
  final bool isGroup;

  /// Member count (if available)
  final int? memberCount;

  /// Creation timestamp
  final DateTime? createdAt;

  /// Platform-specific data
  final Map<String, dynamic>? platformData;

  const ConversationInfo({
    required this.key,
    this.name,
    this.topic,
    this.isPrivate = false,
    this.isGroup = false,
    this.memberCount,
    this.createdAt,
    this.platformData,
  });

  ConversationInfo copyWith({
    ConversationKey? key,
    String? name,
    String? topic,
    bool? isPrivate,
    bool? isGroup,
    int? memberCount,
    DateTime? createdAt,
    Map<String, dynamic>? platformData,
  }) {
    return ConversationInfo(
      key: key ?? this.key,
      name: name ?? this.name,
      topic: topic ?? this.topic,
      isPrivate: isPrivate ?? this.isPrivate,
      isGroup: isGroup ?? this.isGroup,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      platformData: platformData ?? this.platformData,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key.toJson(),
        if (name != null) 'name': name,
        if (topic != null) 'topic': topic,
        'isPrivate': isPrivate,
        'isGroup': isGroup,
        if (memberCount != null) 'memberCount': memberCount,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (platformData != null) 'platformData': platformData,
      };

  factory ConversationInfo.fromJson(Map<String, dynamic> json) {
    return ConversationInfo(
      key: ConversationKey.fromJson(json['key'] as Map<String, dynamic>),
      name: json['name'] as String?,
      topic: json['topic'] as String?,
      isPrivate: json['isPrivate'] as bool? ?? false,
      isGroup: json['isGroup'] as bool? ?? false,
      memberCount: json['memberCount'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      platformData: json['platformData'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationInfo &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() =>
      'ConversationInfo(key: ${key.key}, name: $name, isPrivate: $isPrivate)';
}
