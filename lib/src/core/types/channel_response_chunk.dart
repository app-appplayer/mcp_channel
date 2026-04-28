import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart';

/// Represents an incremental chunk of a streaming response.
///
/// Used when integrating with LLM streaming APIs to deliver responses
/// progressively. Platforms that support message editing (Slack, Discord,
/// Telegram, Teams) can show the response building up in real-time.
@immutable
class ChannelResponseChunk {
  const ChannelResponseChunk({
    required this.conversation,
    this.textDelta,
    required this.isComplete,
    this.messageId,
    required this.sequenceNumber,
    this.metadata,
  });

  /// Create the first chunk in a stream.
  factory ChannelResponseChunk.first({
    required ConversationKey conversation,
    String? textDelta,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponseChunk(
      conversation: conversation,
      textDelta: textDelta,
      isComplete: false,
      sequenceNumber: 0,
      metadata: metadata,
    );
  }

  /// Create a continuation chunk.
  factory ChannelResponseChunk.delta({
    required ConversationKey conversation,
    required String textDelta,
    required String messageId,
    required int sequenceNumber,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponseChunk(
      conversation: conversation,
      textDelta: textDelta,
      isComplete: false,
      messageId: messageId,
      sequenceNumber: sequenceNumber,
      metadata: metadata,
    );
  }

  /// Create the final chunk.
  factory ChannelResponseChunk.complete({
    required ConversationKey conversation,
    String? textDelta,
    required String messageId,
    required int sequenceNumber,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponseChunk(
      conversation: conversation,
      textDelta: textDelta,
      isComplete: true,
      messageId: messageId,
      sequenceNumber: sequenceNumber,
      metadata: metadata,
    );
  }

  factory ChannelResponseChunk.fromJson(Map<String, dynamic> json) {
    return ChannelResponseChunk(
      conversation: ConversationKey.fromJson(
          json['conversation'] as Map<String, dynamic>),
      textDelta: json['textDelta'] as String?,
      isComplete: json['isComplete'] as bool,
      messageId: json['messageId'] as String?,
      sequenceNumber: json['sequenceNumber'] as int,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Target conversation for this chunk.
  final ConversationKey conversation;

  /// Incremental text content.
  /// Null for non-text chunks (e.g., status-only updates).
  final String? textDelta;

  /// Whether this is the final chunk in the stream.
  final bool isComplete;

  /// Platform message ID for edit-based streaming.
  ///
  /// On the first chunk, this is null (message not yet sent).
  /// After the first send, the platform returns a messageId which
  /// subsequent chunks use to edit the same message.
  final String? messageId;

  /// Sequence number within this stream (0-indexed).
  final int sequenceNumber;

  /// Additional metadata (e.g., token count, model info).
  final Map<String, dynamic>? metadata;

  ChannelResponseChunk copyWith({
    ConversationKey? conversation,
    String? textDelta,
    bool? isComplete,
    String? messageId,
    int? sequenceNumber,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelResponseChunk(
      conversation: conversation ?? this.conversation,
      textDelta: textDelta ?? this.textDelta,
      isComplete: isComplete ?? this.isComplete,
      messageId: messageId ?? this.messageId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'conversation': conversation.toJson(),
        if (textDelta != null) 'textDelta': textDelta,
        'isComplete': isComplete,
        if (messageId != null) 'messageId': messageId,
        'sequenceNumber': sequenceNumber,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelResponseChunk &&
          runtimeType == other.runtimeType &&
          conversation == other.conversation &&
          sequenceNumber == other.sequenceNumber;

  @override
  int get hashCode => Object.hash(conversation, sequenceNumber);

  @override
  String toString() =>
      'ChannelResponseChunk(seq: $sequenceNumber, isComplete: $isComplete, textDelta: $textDelta)';
}
