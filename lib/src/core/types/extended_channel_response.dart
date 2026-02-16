import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart';

import 'attachment.dart';
import 'content_block.dart';
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

/// Embedded content for rich messages.
@immutable
class Embed {
  const Embed({
    this.title,
    this.description,
    this.url,
    this.color,
    this.imageUrl,
    this.thumbnailUrl,
    this.author,
    this.footer,
    this.timestamp,
    this.fields,
  });

  factory Embed.fromJson(Map<String, dynamic> json) {
    return Embed(
      title: json['title'] as String?,
      description: json['description'] as String?,
      url: json['url'] as String?,
      color: json['color'] as String?,
      imageUrl: json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      author: json['author'] as String?,
      footer: json['footer'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      fields: json['fields'] != null
          ? (json['fields'] as List)
              .map((f) => EmbedField.fromJson(f as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  /// Title
  final String? title;

  /// Description
  final String? description;

  /// URL
  final String? url;

  /// Color (hex string or platform-specific)
  final String? color;

  /// Image URL
  final String? imageUrl;

  /// Thumbnail URL
  final String? thumbnailUrl;

  /// Author name
  final String? author;

  /// Footer text
  final String? footer;

  /// Timestamp
  final DateTime? timestamp;

  /// Additional fields
  final List<EmbedField>? fields;

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (url != null) 'url': url,
        if (color != null) 'color': color,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (author != null) 'author': author,
        if (footer != null) 'footer': footer,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
        if (fields != null) 'fields': fields!.map((f) => f.toJson()).toList(),
      };
}

/// Field for embed content.
@immutable
class EmbedField {
  const EmbedField({
    required this.name,
    required this.value,
    this.inline = false,
  });

  factory EmbedField.fromJson(Map<String, dynamic> json) {
    return EmbedField(
      name: json['name'] as String,
      value: json['value'] as String,
      inline: json['inline'] as bool? ?? false,
    );
  }

  /// Field name/title
  final String name;

  /// Field value
  final String value;

  /// Display inline
  final bool inline;

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'inline': inline,
      };
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
