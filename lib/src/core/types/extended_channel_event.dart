import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart';

import 'channel_identity_info.dart';
import 'extended_conversation_key.dart';
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

/// Extended channel event with additional messaging platform features.
///
/// Wraps the base ChannelEvent from mcp_bundle and adds:
/// - Extended conversation key with threading
/// - Extended identity info
/// - Command parsing
/// - File information
/// - Action/button data
@immutable
class ExtendedChannelEvent {
  const ExtendedChannelEvent({
    required this.base,
    this.extendedConversation,
    this.identityInfo,
    this.eventType = ChannelEventType.message,
    this.command,
    this.commandArgs,
    this.actionId,
    this.actionValue,
    this.file,
    this.reaction,
    this.targetMessageId,
    this.rawPayload,
  });

  /// Creates from a base ChannelEvent.
  factory ExtendedChannelEvent.fromBase(
    ChannelEvent event, {
    ExtendedConversationKey? extendedConversation,
    ChannelIdentityInfo? identityInfo,
    ChannelEventType? eventType,
    String? command,
    List<String>? commandArgs,
    String? actionId,
    String? actionValue,
    FileInfo? file,
    String? reaction,
    String? targetMessageId,
    Map<String, dynamic>? rawPayload,
  }) {
    return ExtendedChannelEvent(
      base: event,
      extendedConversation: extendedConversation,
      identityInfo: identityInfo,
      eventType: eventType ?? _parseEventType(event.type),
      command: command,
      commandArgs: commandArgs,
      actionId: actionId,
      actionValue: actionValue,
      file: file,
      reaction: reaction,
      targetMessageId: targetMessageId,
      rawPayload: rawPayload ?? event.metadata,
    );
  }

  /// Creates a text message event.
  factory ExtendedChannelEvent.message({
    required String id,
    required ConversationKey conversation,
    required String text,
    String? userId,
    String? userName,
    DateTime? timestamp,
    ExtendedConversationKey? extendedConversation,
    ChannelIdentityInfo? identityInfo,
    String? replyTo,
    Map<String, dynamic>? rawPayload,
  }) {
    return ExtendedChannelEvent(
      base: ChannelEvent.message(
        id: id,
        conversation: conversation,
        text: text,
        userId: userId,
        userName: userName,
        timestamp: timestamp,
        metadata: rawPayload,
      ),
      extendedConversation: extendedConversation,
      identityInfo: identityInfo,
      eventType: ChannelEventType.message,
      targetMessageId: replyTo,
      rawPayload: rawPayload,
    );
  }

  /// Creates a slash command event.
  factory ExtendedChannelEvent.command({
    required String id,
    required ConversationKey conversation,
    required String command,
    List<String>? args,
    String? userId,
    String? userName,
    DateTime? timestamp,
    ExtendedConversationKey? extendedConversation,
    ChannelIdentityInfo? identityInfo,
    Map<String, dynamic>? rawPayload,
  }) {
    return ExtendedChannelEvent(
      base: ChannelEvent(
        id: id,
        conversation: conversation,
        type: 'command',
        text: '/$command ${args?.join(' ') ?? ''}'.trim(),
        userId: userId,
        userName: userName,
        timestamp: timestamp ?? DateTime.now(),
        metadata: rawPayload,
      ),
      extendedConversation: extendedConversation,
      identityInfo: identityInfo,
      eventType: ChannelEventType.command,
      command: command,
      commandArgs: args,
      rawPayload: rawPayload,
    );
  }

  /// Creates a button click event.
  factory ExtendedChannelEvent.button({
    required String id,
    required ConversationKey conversation,
    required String actionId,
    String? actionValue,
    String? targetMessageId,
    String? userId,
    String? userName,
    DateTime? timestamp,
    ExtendedConversationKey? extendedConversation,
    ChannelIdentityInfo? identityInfo,
    Map<String, dynamic>? rawPayload,
  }) {
    return ExtendedChannelEvent(
      base: ChannelEvent(
        id: id,
        conversation: conversation,
        type: 'button',
        userId: userId,
        userName: userName,
        timestamp: timestamp ?? DateTime.now(),
        metadata: rawPayload,
      ),
      extendedConversation: extendedConversation,
      identityInfo: identityInfo,
      eventType: ChannelEventType.button,
      actionId: actionId,
      actionValue: actionValue,
      targetMessageId: targetMessageId,
      rawPayload: rawPayload,
    );
  }

  factory ExtendedChannelEvent.fromJson(Map<String, dynamic> json) {
    return ExtendedChannelEvent(
      base: ChannelEvent.fromJson(json['base'] as Map<String, dynamic>),
      extendedConversation: json['extendedConversation'] != null
          ? ExtendedConversationKey.fromJson(
              json['extendedConversation'] as Map<String, dynamic>)
          : null,
      identityInfo: json['identityInfo'] != null
          ? ChannelIdentityInfo.fromJson(
              json['identityInfo'] as Map<String, dynamic>)
          : null,
      eventType: ChannelEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => ChannelEventType.unknown,
      ),
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
    );
  }

  /// Base event from mcp_bundle
  final ChannelEvent base;

  /// Extended conversation context
  final ExtendedConversationKey? extendedConversation;

  /// Extended identity information
  final ChannelIdentityInfo? identityInfo;

  /// Event type (enum)
  final ChannelEventType eventType;

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

  /// Unique event identifier for idempotency
  String get id => base.id;

  /// Event type as string (from base)
  String get type => base.type;

  /// Text content
  String? get text => base.text;

  /// User ID
  String? get userId => base.userId;

  /// User name
  String? get userName => base.userName;

  /// Event timestamp
  DateTime get timestamp => base.timestamp;

  /// Conversation context
  ConversationKey get conversation => base.conversation;

  /// Platform identifier
  String get channelType => base.conversation.channel.platform;

  /// Additional metadata
  Map<String, dynamic>? get metadata => base.metadata;

  /// Converts to base ChannelEvent.
  ChannelEvent toBase() => base;

  ExtendedChannelEvent copyWith({
    ChannelEvent? base,
    ExtendedConversationKey? extendedConversation,
    ChannelIdentityInfo? identityInfo,
    ChannelEventType? eventType,
    String? command,
    List<String>? commandArgs,
    String? actionId,
    String? actionValue,
    FileInfo? file,
    String? reaction,
    String? targetMessageId,
    Map<String, dynamic>? rawPayload,
  }) {
    return ExtendedChannelEvent(
      base: base ?? this.base,
      extendedConversation: extendedConversation ?? this.extendedConversation,
      identityInfo: identityInfo ?? this.identityInfo,
      eventType: eventType ?? this.eventType,
      command: command ?? this.command,
      commandArgs: commandArgs ?? this.commandArgs,
      actionId: actionId ?? this.actionId,
      actionValue: actionValue ?? this.actionValue,
      file: file ?? this.file,
      reaction: reaction ?? this.reaction,
      targetMessageId: targetMessageId ?? this.targetMessageId,
      rawPayload: rawPayload ?? this.rawPayload,
    );
  }

  Map<String, dynamic> toJson() => {
        'base': base.toJson(),
        if (extendedConversation != null)
          'extendedConversation': extendedConversation!.toJson(),
        if (identityInfo != null) 'identityInfo': identityInfo!.toJson(),
        'eventType': eventType.name,
        if (command != null) 'command': command,
        if (commandArgs != null) 'commandArgs': commandArgs,
        if (actionId != null) 'actionId': actionId,
        if (actionValue != null) 'actionValue': actionValue,
        if (file != null) 'file': file!.toJson(),
        if (reaction != null) 'reaction': reaction,
        if (targetMessageId != null) 'targetMessageId': targetMessageId,
        if (rawPayload != null) 'rawPayload': rawPayload,
      };

  static ChannelEventType _parseEventType(String type) {
    return ChannelEventType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => ChannelEventType.unknown,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtendedChannelEvent &&
          runtimeType == other.runtimeType &&
          base.id == other.base.id;

  @override
  int get hashCode => base.id.hashCode;

  @override
  String toString() =>
      'ExtendedChannelEvent(id: $id, type: ${eventType.name}, channelType: $channelType)';
}
