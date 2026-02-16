import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart' show ChannelCapabilities;

import '../types/attachment.dart';

/// Extended capabilities for messaging platforms.
///
/// Adds platform-specific features beyond the base [ChannelCapabilities]
/// contract from mcp_bundle.
@immutable
class ExtendedChannelCapabilities {
  const ExtendedChannelCapabilities({
    // Base capabilities
    this.text = true,
    this.richMessages = false,
    this.attachments = false,
    this.reactions = false,
    this.threads = false,
    this.editing = false,
    this.deleting = false,
    this.typingIndicator = false,
    this.maxMessageLength,
    // Extended capabilities
    this.supportsFiles = false,
    this.maxFileSize,
    this.supportsButtons = false,
    this.supportsMenus = false,
    this.supportsModals = false,
    this.supportsEphemeral = false,
    this.supportsCommands = false,
    this.maxBlocksPerMessage,
    this.supportedAttachments = const {},
    this.custom,
  });

  /// Creates from base ChannelCapabilities.
  factory ExtendedChannelCapabilities.fromBase(
    ChannelCapabilities base, {
    bool supportsFiles = false,
    int? maxFileSize,
    bool supportsButtons = false,
    bool supportsMenus = false,
    bool supportsModals = false,
    bool supportsEphemeral = false,
    bool supportsCommands = false,
    int? maxBlocksPerMessage,
    Set<AttachmentType> supportedAttachments = const {},
    Map<String, dynamic>? custom,
  }) {
    return ExtendedChannelCapabilities(
      text: base.text,
      richMessages: base.richMessages,
      attachments: base.attachments,
      reactions: base.reactions,
      threads: base.threads,
      editing: base.editing,
      deleting: base.deleting,
      typingIndicator: base.typingIndicator,
      maxMessageLength: base.maxMessageLength,
      supportsFiles: supportsFiles,
      maxFileSize: maxFileSize,
      supportsButtons: supportsButtons,
      supportsMenus: supportsMenus,
      supportsModals: supportsModals,
      supportsEphemeral: supportsEphemeral,
      supportsCommands: supportsCommands,
      maxBlocksPerMessage: maxBlocksPerMessage,
      supportedAttachments: supportedAttachments,
      custom: custom,
    );
  }

  /// Creates capabilities for Slack.
  factory ExtendedChannelCapabilities.slack() {
    return ExtendedChannelCapabilities(
      text: true,
      richMessages: true,
      attachments: true,
      reactions: true,
      threads: true,
      editing: true,
      deleting: true,
      typingIndicator: true,
      maxMessageLength: 40000,
      supportsFiles: true,
      maxFileSize: 1024 * 1024 * 1024, // 1GB
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: true,
      supportsEphemeral: true,
      supportsCommands: true,
      maxBlocksPerMessage: 50,
      supportedAttachments: const {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.audio,
        AttachmentType.document,
      },
    );
  }

  /// Creates capabilities for Discord.
  factory ExtendedChannelCapabilities.discord() {
    return ExtendedChannelCapabilities(
      text: true,
      richMessages: true,
      attachments: true,
      reactions: true,
      threads: true,
      editing: true,
      deleting: true,
      typingIndicator: true,
      maxMessageLength: 2000,
      supportsFiles: true,
      maxFileSize: 25 * 1024 * 1024, // 25MB (Nitro: 100MB)
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: true,
      supportsEphemeral: true,
      supportsCommands: true,
      maxBlocksPerMessage: 10, // max embeds
      supportedAttachments: const {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.audio,
        AttachmentType.document,
      },
    );
  }

  /// Creates capabilities for Telegram.
  factory ExtendedChannelCapabilities.telegram() {
    return ExtendedChannelCapabilities(
      text: true,
      richMessages: true,
      attachments: true,
      reactions: true,
      threads: true,
      editing: true,
      deleting: true,
      typingIndicator: true,
      maxMessageLength: 4096,
      supportsFiles: true,
      maxFileSize: 50 * 1024 * 1024, // 50MB (Bot API)
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: false,
      supportsEphemeral: false,
      supportsCommands: true,
      supportedAttachments: const {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.audio,
        AttachmentType.document,
      },
    );
  }

  /// Creates capabilities for Microsoft Teams.
  factory ExtendedChannelCapabilities.teams() {
    return ExtendedChannelCapabilities(
      text: true,
      richMessages: true,
      attachments: true,
      reactions: true,
      threads: true,
      editing: true,
      deleting: true,
      typingIndicator: true,
      maxMessageLength: 28000,
      supportsFiles: true,
      maxFileSize: 250 * 1024 * 1024, // 250MB
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: true,
      supportsEphemeral: false,
      supportsCommands: true,
      supportedAttachments: const {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.document,
      },
    );
  }

  /// Creates minimal capabilities for basic platforms.
  factory ExtendedChannelCapabilities.minimal() {
    return const ExtendedChannelCapabilities(
      text: true,
      richMessages: false,
      attachments: false,
      reactions: false,
      threads: false,
      editing: false,
      deleting: false,
      typingIndicator: false,
      maxMessageLength: 2000,
      supportsFiles: false,
      supportsButtons: false,
      supportsMenus: false,
      supportsModals: false,
      supportsEphemeral: false,
      supportsCommands: false,
    );
  }

  factory ExtendedChannelCapabilities.fromJson(Map<String, dynamic> json) {
    return ExtendedChannelCapabilities(
      text: json['text'] as bool? ?? true,
      richMessages: json['richMessages'] as bool? ?? false,
      attachments: json['attachments'] as bool? ?? false,
      reactions: json['reactions'] as bool? ?? false,
      threads: json['threads'] as bool? ?? false,
      editing: json['editing'] as bool? ?? false,
      deleting: json['deleting'] as bool? ?? false,
      typingIndicator: json['typingIndicator'] as bool? ?? false,
      maxMessageLength: json['maxMessageLength'] as int?,
      supportsFiles: json['supportsFiles'] as bool? ?? false,
      maxFileSize: json['maxFileSize'] as int?,
      supportsButtons: json['supportsButtons'] as bool? ?? false,
      supportsMenus: json['supportsMenus'] as bool? ?? false,
      supportsModals: json['supportsModals'] as bool? ?? false,
      supportsEphemeral: json['supportsEphemeral'] as bool? ?? false,
      supportsCommands: json['supportsCommands'] as bool? ?? false,
      maxBlocksPerMessage: json['maxBlocksPerMessage'] as int?,
      supportedAttachments: json['supportedAttachments'] != null
          ? (json['supportedAttachments'] as List)
              .map((a) => AttachmentType.values.firstWhere(
                    (t) => t.name == a,
                    orElse: () => AttachmentType.file,
                  ))
              .toSet()
          : {},
      custom: json['custom'] as Map<String, dynamic>?,
    );
  }

  // =========================================================================
  // Base capabilities (mapped to mcp_bundle ChannelCapabilities)
  // =========================================================================

  /// Supports text messages
  final bool text;

  /// Supports rich/block messages
  final bool richMessages;

  /// Supports attachments
  final bool attachments;

  /// Supports reactions
  final bool reactions;

  /// Supports threaded conversations
  final bool threads;

  /// Supports message editing
  final bool editing;

  /// Supports message deletion
  final bool deleting;

  /// Supports typing indicators
  final bool typingIndicator;

  /// Maximum message length
  final int? maxMessageLength;

  // =========================================================================
  // Extended capabilities (mcp_channel specific)
  // =========================================================================

  /// Supports file uploads
  final bool supportsFiles;

  /// Maximum file size in bytes
  final int? maxFileSize;

  /// Supports interactive buttons
  final bool supportsButtons;

  /// Supports select menus
  final bool supportsMenus;

  /// Supports modals/dialogs
  final bool supportsModals;

  /// Supports ephemeral messages
  final bool supportsEphemeral;

  /// Supports slash commands
  final bool supportsCommands;

  /// Maximum blocks per message
  final int? maxBlocksPerMessage;

  /// Supported attachment types
  final Set<AttachmentType> supportedAttachments;

  /// Custom capabilities (platform-specific)
  final Map<String, dynamic>? custom;

  /// Converts to base ChannelCapabilities.
  ChannelCapabilities toBase() {
    return ChannelCapabilities(
      text: text,
      richMessages: richMessages,
      attachments: attachments,
      reactions: reactions,
      threads: threads,
      editing: editing,
      deleting: deleting,
      typingIndicator: typingIndicator,
      maxMessageLength: maxMessageLength,
    );
  }

  ExtendedChannelCapabilities copyWith({
    bool? text,
    bool? richMessages,
    bool? attachments,
    bool? reactions,
    bool? threads,
    bool? editing,
    bool? deleting,
    bool? typingIndicator,
    int? maxMessageLength,
    bool? supportsFiles,
    int? maxFileSize,
    bool? supportsButtons,
    bool? supportsMenus,
    bool? supportsModals,
    bool? supportsEphemeral,
    bool? supportsCommands,
    int? maxBlocksPerMessage,
    Set<AttachmentType>? supportedAttachments,
    Map<String, dynamic>? custom,
  }) {
    return ExtendedChannelCapabilities(
      text: text ?? this.text,
      richMessages: richMessages ?? this.richMessages,
      attachments: attachments ?? this.attachments,
      reactions: reactions ?? this.reactions,
      threads: threads ?? this.threads,
      editing: editing ?? this.editing,
      deleting: deleting ?? this.deleting,
      typingIndicator: typingIndicator ?? this.typingIndicator,
      maxMessageLength: maxMessageLength ?? this.maxMessageLength,
      supportsFiles: supportsFiles ?? this.supportsFiles,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      supportsButtons: supportsButtons ?? this.supportsButtons,
      supportsMenus: supportsMenus ?? this.supportsMenus,
      supportsModals: supportsModals ?? this.supportsModals,
      supportsEphemeral: supportsEphemeral ?? this.supportsEphemeral,
      supportsCommands: supportsCommands ?? this.supportsCommands,
      maxBlocksPerMessage: maxBlocksPerMessage ?? this.maxBlocksPerMessage,
      supportedAttachments: supportedAttachments ?? this.supportedAttachments,
      custom: custom ?? this.custom,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'richMessages': richMessages,
        'attachments': attachments,
        'reactions': reactions,
        'threads': threads,
        'editing': editing,
        'deleting': deleting,
        'typingIndicator': typingIndicator,
        if (maxMessageLength != null) 'maxMessageLength': maxMessageLength,
        'supportsFiles': supportsFiles,
        if (maxFileSize != null) 'maxFileSize': maxFileSize,
        'supportsButtons': supportsButtons,
        'supportsMenus': supportsMenus,
        'supportsModals': supportsModals,
        'supportsEphemeral': supportsEphemeral,
        'supportsCommands': supportsCommands,
        if (maxBlocksPerMessage != null)
          'maxBlocksPerMessage': maxBlocksPerMessage,
        'supportedAttachments':
            supportedAttachments.map((a) => a.name).toList(),
        if (custom != null) 'custom': custom,
      };

  @override
  String toString() => 'ExtendedChannelCapabilities('
      'text: $text, '
      'richMessages: $richMessages, '
      'threads: $threads, '
      'reactions: $reactions, '
      'files: $supportsFiles, '
      'buttons: $supportsButtons)';
}
