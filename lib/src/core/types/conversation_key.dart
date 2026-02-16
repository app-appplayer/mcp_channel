import 'package:meta/meta.dart';

/// Uniquely identifies a conversation context across platforms.
@immutable
class ConversationKey {
  /// Platform identifier (slack, telegram, discord, etc.)
  final String channelType;

  /// Workspace/team/server ID
  final String tenantId;

  /// Channel/chat/room ID
  final String roomId;

  /// Thread ID for threaded conversations (optional)
  final String? threadId;

  const ConversationKey({
    required this.channelType,
    required this.tenantId,
    required this.roomId,
    this.threadId,
  });

  /// Generates a unique key string for this conversation.
  String get key => threadId != null
      ? '$channelType:$tenantId:$roomId:$threadId'
      : '$channelType:$tenantId:$roomId';

  /// Creates a copy with optional field updates.
  ConversationKey copyWith({
    String? channelType,
    String? tenantId,
    String? roomId,
    String? threadId,
  }) {
    return ConversationKey(
      channelType: channelType ?? this.channelType,
      tenantId: tenantId ?? this.tenantId,
      roomId: roomId ?? this.roomId,
      threadId: threadId ?? this.threadId,
    );
  }

  /// Creates a new key for a thread within this conversation.
  ConversationKey withThread(String threadId) {
    return copyWith(threadId: threadId);
  }

  /// Creates a new key without the thread (parent conversation).
  ConversationKey withoutThread() {
    return ConversationKey(
      channelType: channelType,
      tenantId: tenantId,
      roomId: roomId,
    );
  }

  Map<String, dynamic> toJson() => {
        'channelType': channelType,
        'tenantId': tenantId,
        'roomId': roomId,
        if (threadId != null) 'threadId': threadId,
      };

  factory ConversationKey.fromJson(Map<String, dynamic> json) {
    return ConversationKey(
      channelType: json['channelType'] as String,
      tenantId: json['tenantId'] as String,
      roomId: json['roomId'] as String,
      threadId: json['threadId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationKey &&
          runtimeType == other.runtimeType &&
          channelType == other.channelType &&
          tenantId == other.tenantId &&
          roomId == other.roomId &&
          threadId == other.threadId;

  @override
  int get hashCode => Object.hash(channelType, tenantId, roomId, threadId);

  @override
  String toString() => 'ConversationKey($key)';
}
