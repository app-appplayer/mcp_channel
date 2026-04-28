import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart';

import 'attachment.dart';
import 'content_block.dart';
import 'embed.dart';
import 'extended_conversation_key.dart';

/// Type of outgoing channel response.
enum ChannelResponseType {
  /// Plain text message
  text,

  /// Rich content (blocks, cards, embeds)
  rich,

  /// File attachment
  file,

  /// Link preview
  link,

  /// Update existing message
  update,

  /// Delete message
  delete,

  /// Ephemeral message (visible only to one user)
  ephemeral,

  /// Add reaction to message
  reaction,

  /// Typing indicator
  typing,
}

/// Extended channel response with additional messaging platform features.
///
/// Wraps the base ChannelResponse from mcp_bundle and adds:
/// - Extended conversation key with threading
/// - Rich content blocks
/// - Embeds (for Discord-like platforms)
/// - Ephemeral message support
/// - Attachment support
@immutable
class ExtendedChannelResponse {
  const ExtendedChannelResponse({
    required this.base,
    this.extendedConversation,
    this.responseType = ChannelResponseType.text,
    this.blocks,
    this.attachments,
    this.embeds,
    this.targetMessageId,
    this.ephemeral = false,
    this.ephemeralUserId,
    this.reaction,
  });

  /// Creates from a base ChannelResponse.
  factory ExtendedChannelResponse.fromBase(
    ChannelResponse response, {
    ExtendedConversationKey? extendedConversation,
    ChannelResponseType? responseType,
    List<ContentBlock>? blocks,
    List<Attachment>? attachments,
    List<Embed>? embeds,
    String? targetMessageId,
    bool ephemeral = false,
    String? ephemeralUserId,
    String? reaction,
  }) {
    return ExtendedChannelResponse(
      base: response,
      extendedConversation: extendedConversation,
      responseType: responseType ?? _parseResponseType(response.type),
      blocks: blocks,
      attachments: attachments,
      embeds: embeds,
      targetMessageId: targetMessageId,
      ephemeral: ephemeral,
      ephemeralUserId: ephemeralUserId,
      reaction: reaction,
    );
  }

  /// Creates a simple text response.
  factory ExtendedChannelResponse.text({
    required ConversationKey conversation,
    required String text,
    String? replyTo,
    ExtendedConversationKey? extendedConversation,
    Map<String, dynamic>? options,
  }) {
    return ExtendedChannelResponse(
      base: ChannelResponse.text(
        conversation: conversation,
        text: text,
        replyTo: replyTo,
        options: options,
      ),
      extendedConversation: extendedConversation,
      responseType: ChannelResponseType.text,
    );
  }

  /// Creates a rich content response.
  factory ExtendedChannelResponse.rich({
    required ConversationKey conversation,
    required List<ContentBlock> blocks,
    String? text,
    String? replyTo,
    ExtendedConversationKey? extendedConversation,
    Map<String, dynamic>? options,
  }) {
    return ExtendedChannelResponse(
      base: ChannelResponse.rich(
        conversation: conversation,
        blocks: blocks.map((b) => b.toJson()).toList(),
        text: text,
        replyTo: replyTo,
        options: options,
      ),
      extendedConversation: extendedConversation,
      responseType: ChannelResponseType.rich,
      blocks: blocks,
    );
  }

  /// Creates an ephemeral response (visible only to one user).
  factory ExtendedChannelResponse.ephemeral({
    required ConversationKey conversation,
    required String userId,
    required String text,
    List<ContentBlock>? blocks,
    ExtendedConversationKey? extendedConversation,
    Map<String, dynamic>? options,
  }) {
    return ExtendedChannelResponse(
      base: ChannelResponse.text(
        conversation: conversation,
        text: text,
        options: {...?options, 'ephemeral': true, 'ephemeralUserId': userId},
      ),
      extendedConversation: extendedConversation,
      responseType: ChannelResponseType.ephemeral,
      blocks: blocks,
      ephemeral: true,
      ephemeralUserId: userId,
    );
  }

  /// Creates a typing indicator response.
  factory ExtendedChannelResponse.typing({
    required ConversationKey conversation,
    ExtendedConversationKey? extendedConversation,
  }) {
    return ExtendedChannelResponse(
      base: ChannelResponse(
        conversation: conversation,
        type: 'typing',
      ),
      extendedConversation: extendedConversation,
      responseType: ChannelResponseType.typing,
    );
  }

  /// Creates a reaction response.
  factory ExtendedChannelResponse.reaction({
    required ConversationKey conversation,
    required String targetMessageId,
    required String reaction,
    ExtendedConversationKey? extendedConversation,
    Map<String, dynamic>? options,
  }) {
    return ExtendedChannelResponse(
      base: ChannelResponse(
        conversation: conversation,
        type: 'reaction',
        options: {...?options, 'targetMessageId': targetMessageId, 'reaction': reaction},
      ),
      extendedConversation: extendedConversation,
      responseType: ChannelResponseType.reaction,
      targetMessageId: targetMessageId,
      reaction: reaction,
    );
  }

  factory ExtendedChannelResponse.fromJson(Map<String, dynamic> json) {
    return ExtendedChannelResponse(
      base: ChannelResponse.fromJson(json['base'] as Map<String, dynamic>),
      extendedConversation: json['extendedConversation'] != null
          ? ExtendedConversationKey.fromJson(
              json['extendedConversation'] as Map<String, dynamic>)
          : null,
      responseType: ChannelResponseType.values.firstWhere(
        (e) => e.name == json['responseType'],
        orElse: () => ChannelResponseType.text,
      ),
      blocks: json['blocks'] != null
          ? (json['blocks'] as List)
              .map((b) => ContentBlock.fromJson(b as Map<String, dynamic>))
              .toList()
          : null,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
              .toList()
          : null,
      embeds: json['embeds'] != null
          ? (json['embeds'] as List)
              .map((e) => Embed.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      targetMessageId: json['targetMessageId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      ephemeralUserId: json['ephemeralUserId'] as String?,
      reaction: json['reaction'] as String?,
    );
  }

  /// Base response from mcp_bundle
  final ChannelResponse base;

  /// Extended conversation context
  final ExtendedConversationKey? extendedConversation;

  /// Response type (enum)
  final ChannelResponseType responseType;

  /// Rich content blocks
  final List<ContentBlock>? blocks;

  /// File attachments
  final List<Attachment>? attachments;

  /// Embedded content
  final List<Embed>? embeds;

  /// Message to update/delete/react to
  final String? targetMessageId;

  /// Ephemeral message flag
  final bool ephemeral;

  /// Target user for ephemeral
  final String? ephemeralUserId;

  /// Emoji for reaction
  final String? reaction;

  /// Target conversation
  ConversationKey get conversation => base.conversation;

  /// Text content
  String? get text => base.text;

  /// Reply to specific message
  String? get replyTo => base.replyTo;

  /// Response type as string (from base)
  String get type => base.type;

  /// Platform-specific options
  Map<String, dynamic>? get options => base.options;

  /// Converts to base ChannelResponse.
  ChannelResponse toBase() => base;

  ExtendedChannelResponse copyWith({
    ChannelResponse? base,
    ExtendedConversationKey? extendedConversation,
    ChannelResponseType? responseType,
    List<ContentBlock>? blocks,
    List<Attachment>? attachments,
    List<Embed>? embeds,
    String? targetMessageId,
    bool? ephemeral,
    String? ephemeralUserId,
    String? reaction,
  }) {
    return ExtendedChannelResponse(
      base: base ?? this.base,
      extendedConversation: extendedConversation ?? this.extendedConversation,
      responseType: responseType ?? this.responseType,
      blocks: blocks ?? this.blocks,
      attachments: attachments ?? this.attachments,
      embeds: embeds ?? this.embeds,
      targetMessageId: targetMessageId ?? this.targetMessageId,
      ephemeral: ephemeral ?? this.ephemeral,
      ephemeralUserId: ephemeralUserId ?? this.ephemeralUserId,
      reaction: reaction ?? this.reaction,
    );
  }

  Map<String, dynamic> toJson() => {
        'base': base.toJson(),
        if (extendedConversation != null)
          'extendedConversation': extendedConversation!.toJson(),
        'responseType': responseType.name,
        if (blocks != null) 'blocks': blocks!.map((b) => b.toJson()).toList(),
        if (attachments != null)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
        if (embeds != null) 'embeds': embeds!.map((e) => e.toJson()).toList(),
        if (targetMessageId != null) 'targetMessageId': targetMessageId,
        'ephemeral': ephemeral,
        if (ephemeralUserId != null) 'ephemeralUserId': ephemeralUserId,
        if (reaction != null) 'reaction': reaction,
      };

  static ChannelResponseType _parseResponseType(String type) {
    return ChannelResponseType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => ChannelResponseType.text,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtendedChannelResponse &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          targetMessageId == other.targetMessageId;

  @override
  int get hashCode => Object.hash(base, targetMessageId);

  @override
  String toString() =>
      'ExtendedChannelResponse(type: ${responseType.name}, conversation: ${conversation.conversationId})';
}
