import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart';

/// Extended conversation key with additional messaging platform features.
///
/// Extends the base ConversationKey from mcp_bundle with:
/// - tenantId for multi-workspace support
/// - threadId for threaded conversations
/// - Additional helper methods
@immutable
class ExtendedConversationKey {
  const ExtendedConversationKey({
    required this.base,
    this.tenantId,
    this.threadId,
  });

  /// Creates from individual components.
  factory ExtendedConversationKey.create({
    required String platform,
    required String channelId,
    required String conversationId,
    String? tenantId,
    String? threadId,
    String? userId,
  }) {
    return ExtendedConversationKey(
      base: ConversationKey(
        channel: ChannelIdentity(
          platform: platform,
          channelId: channelId,
        ),
        conversationId: conversationId,
        userId: userId,
      ),
      tenantId: tenantId,
      threadId: threadId,
    );
  }

  /// Creates from a base ConversationKey.
  factory ExtendedConversationKey.fromBase(
    ConversationKey base, {
    String? tenantId,
    String? threadId,
  }) {
    return ExtendedConversationKey(
      base: base,
      tenantId: tenantId,
      threadId: threadId,
    );
  }

  factory ExtendedConversationKey.fromJson(Map<String, dynamic> json) {
    return ExtendedConversationKey(
      base: ConversationKey.fromJson(json['base'] as Map<String, dynamic>),
      tenantId: json['tenantId'] as String?,
      threadId: json['threadId'] as String?,
    );
  }

  /// Base conversation key from mcp_bundle
  final ConversationKey base;

  /// Workspace/team/server ID (for multi-tenant platforms)
  final String? tenantId;

  /// Thread ID for threaded conversations
  final String? threadId;

  /// Platform identifier
  String get platform => base.channel.platform;

  /// Channel ID
  String get channelId => base.channel.channelId;

  /// Conversation ID
  String get conversationId => base.conversationId;

  /// User ID
  String? get userId => base.userId;

  /// Generates a unique key string for this conversation.
  String get key {
    final parts = [platform, tenantId ?? channelId, conversationId];
    if (threadId != null) parts.add(threadId!);
    return parts.join(':');
  }

  /// Creates a copy with optional field updates.
  ExtendedConversationKey copyWith({
    ConversationKey? base,
    String? tenantId,
    String? threadId,
  }) {
    return ExtendedConversationKey(
      base: base ?? this.base,
      tenantId: tenantId ?? this.tenantId,
      threadId: threadId ?? this.threadId,
    );
  }

  /// Creates a new key for a thread within this conversation.
  ExtendedConversationKey withThread(String threadId) {
    return copyWith(threadId: threadId);
  }

  /// Creates a new key without the thread (parent conversation).
  ExtendedConversationKey withoutThread() {
    return ExtendedConversationKey(
      base: base,
      tenantId: tenantId,
    );
  }

  /// Converts to base ConversationKey.
  ConversationKey toBase() => base;

  Map<String, dynamic> toJson() => {
        'base': base.toJson(),
        if (tenantId != null) 'tenantId': tenantId,
        if (threadId != null) 'threadId': threadId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtendedConversationKey &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          tenantId == other.tenantId &&
          threadId == other.threadId;

  @override
  int get hashCode => Object.hash(base, tenantId, threadId);

  @override
  String toString() => 'ExtendedConversationKey($key)';
}
