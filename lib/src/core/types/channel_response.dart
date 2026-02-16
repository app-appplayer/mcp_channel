import 'package:meta/meta.dart';

import 'attachment.dart';
import 'content_block.dart';
import 'conversation_key.dart';

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
}

/// Field for embed content.
@immutable
class EmbedField {
  /// Field name/title
  final String name;

  /// Field value
  final String value;

  /// Display inline
  final bool inline;

  const EmbedField({
    required this.name,
    required this.value,
    this.inline = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'inline': inline,
      };

  factory EmbedField.fromJson(Map<String, dynamic> json) {
    return EmbedField(
      name: json['name'] as String,
      value: json['value'] as String,
      inline: json['inline'] as bool? ?? false,
    );
  }
}

/// Represents an outgoing response to a messaging platform.
@immutable
class ChannelResponse {
  /// Response type
  final ChannelResponseType type;

  /// Target conversation
  final ConversationKey conversation;

  /// Text content
  final String? text;

  /// Rich content blocks
  final List<ContentBlock>? blocks;

  /// File attachments
  final List<Attachment>? attachments;

  /// Embedded content
  final List<Embed>? embeds;

  /// Message to update/delete/react to
  final String? targetMessageId;

  /// Reply to specific message
  final String? replyTo;

  /// Ephemeral message flag
  final bool ephemeral;

  /// Target user for ephemeral
  final String? ephemeralUserId;

  /// Emoji for reaction
  final String? reaction;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  const ChannelResponse({
    required this.type,
    required this.conversation,
    this.text,
    this.blocks,
    this.attachments,
    this.embeds,
    this.targetMessageId,
    this.replyTo,
    this.ephemeral = false,
    this.ephemeralUserId,
    this.reaction,
    this.metadata,
  });

  /// Creates a simple text response.
  factory ChannelResponse.text({
    required ConversationKey conversation,
    required String text,
    String? replyTo,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.text,
      conversation: conversation,
      text: text,
      replyTo: replyTo,
      metadata: metadata,
    );
  }

  /// Creates a rich content response.
  factory ChannelResponse.rich({
    required ConversationKey conversation,
    required List<ContentBlock> blocks,
    String? text,
    String? replyTo,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.rich,
      conversation: conversation,
      blocks: blocks,
      text: text,
      replyTo: replyTo,
      metadata: metadata,
    );
  }

  /// Creates an ephemeral response (visible only to one user).
  factory ChannelResponse.ephemeral({
    required ConversationKey conversation,
    required String userId,
    required String text,
    List<ContentBlock>? blocks,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.ephemeral,
      conversation: conversation,
      text: text,
      blocks: blocks,
      ephemeral: true,
      ephemeralUserId: userId,
      metadata: metadata,
    );
  }

  /// Creates a response to update an existing message.
  factory ChannelResponse.update({
    required ConversationKey conversation,
    required String targetMessageId,
    String? text,
    List<ContentBlock>? blocks,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.update,
      conversation: conversation,
      targetMessageId: targetMessageId,
      text: text,
      blocks: blocks,
      metadata: metadata,
    );
  }

  /// Creates a response to delete a message.
  factory ChannelResponse.delete({
    required ConversationKey conversation,
    required String targetMessageId,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.delete,
      conversation: conversation,
      targetMessageId: targetMessageId,
      metadata: metadata,
    );
  }

  /// Creates a typing indicator response.
  factory ChannelResponse.typing({
    required ConversationKey conversation,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.typing,
      conversation: conversation,
    );
  }

  /// Creates a reaction response.
  factory ChannelResponse.reaction({
    required ConversationKey conversation,
    required String targetMessageId,
    required String reaction,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.reaction,
      conversation: conversation,
      targetMessageId: targetMessageId,
      reaction: reaction,
      metadata: metadata,
    );
  }

  /// Creates a file attachment response.
  factory ChannelResponse.file({
    required ConversationKey conversation,
    required List<Attachment> attachments,
    String? text,
    String? replyTo,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.file,
      conversation: conversation,
      attachments: attachments,
      text: text,
      replyTo: replyTo,
      metadata: metadata,
    );
  }

  /// Creates a link preview response.
  factory ChannelResponse.link({
    required ConversationKey conversation,
    required String url,
    String? text,
    String? replyTo,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.link,
      conversation: conversation,
      text: text ?? url,
      replyTo: replyTo,
      metadata: {...?metadata, 'url': url},
    );
  }

  /// Creates a response with embeds (for Discord-like platforms).
  factory ChannelResponse.embed({
    required ConversationKey conversation,
    required List<Embed> embeds,
    String? text,
    String? replyTo,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: ChannelResponseType.rich,
      conversation: conversation,
      embeds: embeds,
      text: text,
      replyTo: replyTo,
      metadata: metadata,
    );
  }

  ChannelResponse copyWith({
    ChannelResponseType? type,
    ConversationKey? conversation,
    String? text,
    List<ContentBlock>? blocks,
    List<Attachment>? attachments,
    List<Embed>? embeds,
    String? targetMessageId,
    String? replyTo,
    bool? ephemeral,
    String? ephemeralUserId,
    String? reaction,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponse(
      type: type ?? this.type,
      conversation: conversation ?? this.conversation,
      text: text ?? this.text,
      blocks: blocks ?? this.blocks,
      attachments: attachments ?? this.attachments,
      embeds: embeds ?? this.embeds,
      targetMessageId: targetMessageId ?? this.targetMessageId,
      replyTo: replyTo ?? this.replyTo,
      ephemeral: ephemeral ?? this.ephemeral,
      ephemeralUserId: ephemeralUserId ?? this.ephemeralUserId,
      reaction: reaction ?? this.reaction,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'conversation': conversation.toJson(),
        if (text != null) 'text': text,
        if (blocks != null) 'blocks': blocks!.map((b) => b.toJson()).toList(),
        if (attachments != null)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
        if (embeds != null) 'embeds': embeds!.map((e) => e.toJson()).toList(),
        if (targetMessageId != null) 'targetMessageId': targetMessageId,
        if (replyTo != null) 'replyTo': replyTo,
        'ephemeral': ephemeral,
        if (ephemeralUserId != null) 'ephemeralUserId': ephemeralUserId,
        if (reaction != null) 'reaction': reaction,
        if (metadata != null) 'metadata': metadata,
      };

  factory ChannelResponse.fromJson(Map<String, dynamic> json) {
    return ChannelResponse(
      type: ChannelResponseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChannelResponseType.text,
      ),
      conversation:
          ConversationKey.fromJson(json['conversation'] as Map<String, dynamic>),
      text: json['text'] as String?,
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
      replyTo: json['replyTo'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      ephemeralUserId: json['ephemeralUserId'] as String?,
      reaction: json['reaction'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelResponse &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          conversation == other.conversation &&
          targetMessageId == other.targetMessageId;

  @override
  int get hashCode => Object.hash(type, conversation, targetMessageId);

  @override
  String toString() =>
      'ChannelResponse(type: ${type.name}, conversation: ${conversation.key})';
}
