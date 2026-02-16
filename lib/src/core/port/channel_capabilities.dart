import 'package:meta/meta.dart';

import '../types/attachment.dart';

/// Declares what features a platform supports.
@immutable
class ChannelCapabilities {
  /// Supports threaded conversations
  final bool supportsThreads;

  /// Supports reactions
  final bool supportsReactions;

  /// Supports file uploads
  final bool supportsFiles;

  /// Maximum file size in bytes
  final int? maxFileSize;

  /// Supports rich content blocks
  final bool supportsBlocks;

  /// Supports interactive buttons
  final bool supportsButtons;

  /// Supports select menus
  final bool supportsMenus;

  /// Supports modals/dialogs
  final bool supportsModals;

  /// Supports ephemeral messages
  final bool supportsEphemeral;

  /// Supports message editing
  final bool supportsEdit;

  /// Supports message deletion
  final bool supportsDelete;

  /// Supports typing indicators
  final bool supportsTyping;

  /// Supports slash commands
  final bool supportsCommands;

  /// Maximum message length
  final int? maxMessageLength;

  /// Maximum blocks per message
  final int? maxBlocksPerMessage;

  /// Supported attachment types
  final Set<AttachmentType> supportedAttachments;

  /// Custom capabilities (platform-specific)
  final Map<String, dynamic>? custom;

  const ChannelCapabilities({
    this.supportsThreads = false,
    this.supportsReactions = false,
    this.supportsFiles = false,
    this.maxFileSize,
    this.supportsBlocks = false,
    this.supportsButtons = false,
    this.supportsMenus = false,
    this.supportsModals = false,
    this.supportsEphemeral = false,
    this.supportsEdit = false,
    this.supportsDelete = false,
    this.supportsTyping = false,
    this.supportsCommands = false,
    this.maxMessageLength,
    this.maxBlocksPerMessage,
    this.supportedAttachments = const {},
    this.custom,
  });

  /// Creates capabilities for Slack.
  factory ChannelCapabilities.slack() {
    return const ChannelCapabilities(
      supportsThreads: true,
      supportsReactions: true,
      supportsFiles: true,
      maxFileSize: 1024 * 1024 * 1024, // 1GB
      supportsBlocks: true,
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: true,
      supportsEphemeral: true,
      supportsEdit: true,
      supportsDelete: true,
      supportsTyping: true,
      supportsCommands: true,
      maxMessageLength: 40000,
      maxBlocksPerMessage: 50,
      supportedAttachments: {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.audio,
        AttachmentType.document,
      },
    );
  }

  /// Creates capabilities for Discord.
  factory ChannelCapabilities.discord() {
    return const ChannelCapabilities(
      supportsThreads: true,
      supportsReactions: true,
      supportsFiles: true,
      maxFileSize: 25 * 1024 * 1024, // 25MB (Nitro: 100MB)
      supportsBlocks: true, // embeds
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: true,
      supportsEphemeral: true,
      supportsEdit: true,
      supportsDelete: true,
      supportsTyping: true,
      supportsCommands: true,
      maxMessageLength: 2000,
      maxBlocksPerMessage: 10, // max embeds
      supportedAttachments: {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.audio,
        AttachmentType.document,
      },
    );
  }

  /// Creates capabilities for Telegram.
  factory ChannelCapabilities.telegram() {
    return const ChannelCapabilities(
      supportsThreads: true, // limited
      supportsReactions: true,
      supportsFiles: true,
      maxFileSize: 50 * 1024 * 1024, // 50MB (Bot API)
      supportsBlocks: true, // limited (inline keyboard)
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: false,
      supportsEphemeral: false,
      supportsEdit: true,
      supportsDelete: true,
      supportsTyping: true,
      supportsCommands: true,
      maxMessageLength: 4096,
      supportedAttachments: {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.audio,
        AttachmentType.document,
      },
    );
  }

  /// Creates capabilities for Microsoft Teams.
  factory ChannelCapabilities.teams() {
    return const ChannelCapabilities(
      supportsThreads: true,
      supportsReactions: true,
      supportsFiles: true,
      maxFileSize: 250 * 1024 * 1024, // 250MB
      supportsBlocks: true, // Adaptive Cards
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: true,
      supportsEphemeral: false,
      supportsEdit: true,
      supportsDelete: true,
      supportsTyping: true,
      supportsCommands: true,
      maxMessageLength: 28000,
      supportedAttachments: {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.document,
      },
    );
  }

  /// Creates minimal capabilities for basic platforms.
  factory ChannelCapabilities.minimal() {
    return const ChannelCapabilities(
      supportsThreads: false,
      supportsReactions: false,
      supportsFiles: false,
      supportsBlocks: false,
      supportsButtons: false,
      supportsMenus: false,
      supportsModals: false,
      supportsEphemeral: false,
      supportsEdit: false,
      supportsDelete: false,
      supportsTyping: false,
      supportsCommands: false,
      maxMessageLength: 2000,
    );
  }

  ChannelCapabilities copyWith({
    bool? supportsThreads,
    bool? supportsReactions,
    bool? supportsFiles,
    int? maxFileSize,
    bool? supportsBlocks,
    bool? supportsButtons,
    bool? supportsMenus,
    bool? supportsModals,
    bool? supportsEphemeral,
    bool? supportsEdit,
    bool? supportsDelete,
    bool? supportsTyping,
    bool? supportsCommands,
    int? maxMessageLength,
    int? maxBlocksPerMessage,
    Set<AttachmentType>? supportedAttachments,
    Map<String, dynamic>? custom,
  }) {
    return ChannelCapabilities(
      supportsThreads: supportsThreads ?? this.supportsThreads,
      supportsReactions: supportsReactions ?? this.supportsReactions,
      supportsFiles: supportsFiles ?? this.supportsFiles,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      supportsBlocks: supportsBlocks ?? this.supportsBlocks,
      supportsButtons: supportsButtons ?? this.supportsButtons,
      supportsMenus: supportsMenus ?? this.supportsMenus,
      supportsModals: supportsModals ?? this.supportsModals,
      supportsEphemeral: supportsEphemeral ?? this.supportsEphemeral,
      supportsEdit: supportsEdit ?? this.supportsEdit,
      supportsDelete: supportsDelete ?? this.supportsDelete,
      supportsTyping: supportsTyping ?? this.supportsTyping,
      supportsCommands: supportsCommands ?? this.supportsCommands,
      maxMessageLength: maxMessageLength ?? this.maxMessageLength,
      maxBlocksPerMessage: maxBlocksPerMessage ?? this.maxBlocksPerMessage,
      supportedAttachments: supportedAttachments ?? this.supportedAttachments,
      custom: custom ?? this.custom,
    );
  }

  Map<String, dynamic> toJson() => {
        'supportsThreads': supportsThreads,
        'supportsReactions': supportsReactions,
        'supportsFiles': supportsFiles,
        if (maxFileSize != null) 'maxFileSize': maxFileSize,
        'supportsBlocks': supportsBlocks,
        'supportsButtons': supportsButtons,
        'supportsMenus': supportsMenus,
        'supportsModals': supportsModals,
        'supportsEphemeral': supportsEphemeral,
        'supportsEdit': supportsEdit,
        'supportsDelete': supportsDelete,
        'supportsTyping': supportsTyping,
        'supportsCommands': supportsCommands,
        if (maxMessageLength != null) 'maxMessageLength': maxMessageLength,
        if (maxBlocksPerMessage != null)
          'maxBlocksPerMessage': maxBlocksPerMessage,
        'supportedAttachments':
            supportedAttachments.map((a) => a.name).toList(),
        if (custom != null) 'custom': custom,
      };

  factory ChannelCapabilities.fromJson(Map<String, dynamic> json) {
    return ChannelCapabilities(
      supportsThreads: json['supportsThreads'] as bool? ?? false,
      supportsReactions: json['supportsReactions'] as bool? ?? false,
      supportsFiles: json['supportsFiles'] as bool? ?? false,
      maxFileSize: json['maxFileSize'] as int?,
      supportsBlocks: json['supportsBlocks'] as bool? ?? false,
      supportsButtons: json['supportsButtons'] as bool? ?? false,
      supportsMenus: json['supportsMenus'] as bool? ?? false,
      supportsModals: json['supportsModals'] as bool? ?? false,
      supportsEphemeral: json['supportsEphemeral'] as bool? ?? false,
      supportsEdit: json['supportsEdit'] as bool? ?? false,
      supportsDelete: json['supportsDelete'] as bool? ?? false,
      supportsTyping: json['supportsTyping'] as bool? ?? false,
      supportsCommands: json['supportsCommands'] as bool? ?? false,
      maxMessageLength: json['maxMessageLength'] as int?,
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

  @override
  String toString() => 'ChannelCapabilities('
      'threads: $supportsThreads, '
      'reactions: $supportsReactions, '
      'files: $supportsFiles, '
      'blocks: $supportsBlocks, '
      'buttons: $supportsButtons)';
}
