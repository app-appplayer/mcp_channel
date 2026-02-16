import 'package:meta/meta.dart';

import 'channel_identity.dart';
import 'conversation_key.dart';
import 'file_info.dart';

/// Type of incoming channel event.
enum ChannelEventType {
  /// Text message from user
  message,

  /// Slash command (/help, /call)
  command,

  /// Button or interactive component click
  button,

  /// File upload
  file,

  /// Emoji reaction added
  reaction,

  /// User mentioned
  mention,

  /// Webhook payload
  webhook,

  /// User joined channel
  join,

  /// User left channel
  leave,

  /// Unknown or custom event
  unknown,
}

/// Represents an incoming event from a messaging platform.
@immutable
class ChannelEvent {
  /// Unique event identifier for idempotency
  final String eventId;

  /// Event type
  final ChannelEventType type;

  /// Platform identifier (slack, telegram, discord)
  final String channelType;

  /// Event source identity
  final ChannelIdentity identity;

  /// Conversation context
  final ConversationKey conversation;

  /// Event timestamp
  final DateTime timestamp;

  /// Text content (message, command)
  final String? text;

  /// Command name (type=command)
  final String? command;

  /// Command arguments
  final List<String>? commandArgs;

  /// Button/action identifier (type=button)
  final String? actionId;

  /// Button/action value
  final String? actionValue;

  /// File information (type=file)
  final FileInfo? file;

  /// Emoji (type=reaction)
  final String? reaction;

  /// Target message for reaction/reply
  final String? targetMessageId;

  /// Original platform payload
  final Map<String, dynamic>? rawPayload;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  const ChannelEvent({
    required this.eventId,
    required this.type,
    required this.channelType,
    required this.identity,
    required this.conversation,
    required this.timestamp,
    this.text,
    this.command,
    this.commandArgs,
    this.actionId,
    this.actionValue,
    this.file,
    this.reaction,
    this.targetMessageId,
    this.rawPayload,
    this.metadata,
  });

  /// Creates a text message event.
  factory ChannelEvent.message({
    required String eventId,
    required String channelType,
    required ChannelIdentity identity,
    required ConversationKey conversation,
    required String text,
    DateTime? timestamp,
    String? replyTo,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.message,
      channelType: channelType,
      identity: identity,
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      text: text,
      targetMessageId: replyTo,
      rawPayload: rawPayload,
      metadata: metadata,
    );
  }

  /// Creates a slash command event.
  factory ChannelEvent.command({
    required String eventId,
    required String channelType,
    required ChannelIdentity identity,
    required ConversationKey conversation,
    required String command,
    List<String>? args,
    DateTime? timestamp,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.command,
      channelType: channelType,
      identity: identity,
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      command: command,
      commandArgs: args,
      rawPayload: rawPayload,
      metadata: metadata,
    );
  }

  /// Creates a button click event.
  factory ChannelEvent.button({
    required String eventId,
    required String channelType,
    required ChannelIdentity identity,
    required ConversationKey conversation,
    required String actionId,
    String? actionValue,
    String? targetMessageId,
    DateTime? timestamp,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.button,
      channelType: channelType,
      identity: identity,
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      actionId: actionId,
      actionValue: actionValue,
      targetMessageId: targetMessageId,
      rawPayload: rawPayload,
      metadata: metadata,
    );
  }

  /// Creates a file upload event.
  factory ChannelEvent.file({
    required String eventId,
    required String channelType,
    required ChannelIdentity identity,
    required ConversationKey conversation,
    required FileInfo file,
    String? text,
    DateTime? timestamp,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.file,
      channelType: channelType,
      identity: identity,
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      file: file,
      text: text,
      rawPayload: rawPayload,
      metadata: metadata,
    );
  }

  /// Creates a reaction event.
  factory ChannelEvent.reaction({
    required String eventId,
    required String channelType,
    required ChannelIdentity identity,
    required ConversationKey conversation,
    required String reaction,
    required String targetMessageId,
    DateTime? timestamp,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.reaction,
      channelType: channelType,
      identity: identity,
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      reaction: reaction,
      targetMessageId: targetMessageId,
      rawPayload: rawPayload,
      metadata: metadata,
    );
  }

  /// Creates a mention event.
  factory ChannelEvent.mention({
    required String eventId,
    required String channelType,
    required ChannelIdentity identity,
    required ConversationKey conversation,
    required String text,
    DateTime? timestamp,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.mention,
      channelType: channelType,
      identity: identity,
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      text: text,
      rawPayload: rawPayload,
      metadata: metadata,
    );
  }

  /// Creates a user join event.
  factory ChannelEvent.join({
    required String eventId,
    required String channelType,
    required ChannelIdentity identity,
    required ConversationKey conversation,
    DateTime? timestamp,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.join,
      channelType: channelType,
      identity: identity,
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      rawPayload: rawPayload,
      metadata: metadata,
    );
  }

  /// Creates a user leave event.
  factory ChannelEvent.leave({
    required String eventId,
    required String channelType,
    required ChannelIdentity identity,
    required ConversationKey conversation,
    DateTime? timestamp,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.leave,
      channelType: channelType,
      identity: identity,
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      rawPayload: rawPayload,
      metadata: metadata,
    );
  }

  /// Creates a webhook event.
  factory ChannelEvent.webhook({
    required String eventId,
    required String channelType,
    required ConversationKey conversation,
    required Map<String, dynamic> payload,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId,
      type: ChannelEventType.webhook,
      channelType: channelType,
      identity: ChannelIdentity.system(id: 'webhook', displayName: 'Webhook'),
      conversation: conversation,
      timestamp: timestamp ?? DateTime.now(),
      rawPayload: payload,
      metadata: metadata,
    );
  }

  ChannelEvent copyWith({
    String? eventId,
    ChannelEventType? type,
    String? channelType,
    ChannelIdentity? identity,
    ConversationKey? conversation,
    DateTime? timestamp,
    String? text,
    String? command,
    List<String>? commandArgs,
    String? actionId,
    String? actionValue,
    FileInfo? file,
    String? reaction,
    String? targetMessageId,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelEvent(
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      channelType: channelType ?? this.channelType,
      identity: identity ?? this.identity,
      conversation: conversation ?? this.conversation,
      timestamp: timestamp ?? this.timestamp,
      text: text ?? this.text,
      command: command ?? this.command,
      commandArgs: commandArgs ?? this.commandArgs,
      actionId: actionId ?? this.actionId,
      actionValue: actionValue ?? this.actionValue,
      file: file ?? this.file,
      reaction: reaction ?? this.reaction,
      targetMessageId: targetMessageId ?? this.targetMessageId,
      rawPayload: rawPayload ?? this.rawPayload,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'type': type.name,
        'channelType': channelType,
        'identity': identity.toJson(),
        'conversation': conversation.toJson(),
        'timestamp': timestamp.toIso8601String(),
        if (text != null) 'text': text,
        if (command != null) 'command': command,
        if (commandArgs != null) 'commandArgs': commandArgs,
        if (actionId != null) 'actionId': actionId,
        if (actionValue != null) 'actionValue': actionValue,
        if (file != null) 'file': file!.toJson(),
        if (reaction != null) 'reaction': reaction,
        if (targetMessageId != null) 'targetMessageId': targetMessageId,
        if (rawPayload != null) 'rawPayload': rawPayload,
        if (metadata != null) 'metadata': metadata,
      };

  factory ChannelEvent.fromJson(Map<String, dynamic> json) {
    return ChannelEvent(
      eventId: json['eventId'] as String,
      type: ChannelEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChannelEventType.unknown,
      ),
      channelType: json['channelType'] as String,
      identity:
          ChannelIdentity.fromJson(json['identity'] as Map<String, dynamic>),
      conversation:
          ConversationKey.fromJson(json['conversation'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      text: json['text'] as String?,
      command: json['command'] as String?,
      commandArgs: json['commandArgs'] != null
          ? List<String>.from(json['commandArgs'] as List)
          : null,
      actionId: json['actionId'] as String?,
      actionValue: json['actionValue'] as String?,
      file: json['file'] != null
          ? FileInfo.fromJson(json['file'] as Map<String, dynamic>)
          : null,
      reaction: json['reaction'] as String?,
      targetMessageId: json['targetMessageId'] as String?,
      rawPayload: json['rawPayload'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelEvent &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId;

  @override
  int get hashCode => eventId.hashCode;

  @override
  String toString() =>
      'ChannelEvent(eventId: $eventId, type: ${type.name}, channelType: $channelType)';
}
