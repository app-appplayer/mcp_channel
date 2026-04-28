import 'package:meta/meta.dart';
import 'package:mcp_bundle/ports.dart' show ChannelCapabilities;

import '../types/attachment.dart';

/// Extended capabilities for messaging platforms.
///
/// Extends the base [ChannelCapabilities] from mcp_bundle and adds
/// platform-specific features like files, buttons, menus, modals, etc.
@immutable
class ExtendedChannelCapabilities extends ChannelCapabilities {
  const ExtendedChannelCapabilities({
    // Base capabilities via super
    super.text = true,
    super.richMessages = false,
    super.attachments = false,
    super.reactions = false,
    super.threads = false,
    super.editing = false,
    super.deleting = false,
    super.typingIndicator = false,
    super.maxMessageLength,
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
    return const ExtendedChannelCapabilities(
      text: true,
      richMessages: true,
      attachments: true,
      reactions: true,
      threads: true,
      editing: true,
      deleting: true,
      typingIndicator: false,
      maxMessageLength: 40000,
      supportsFiles: true,
      maxFileSize: 1024 * 1024 * 1024, // 1GB
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: true,
      supportsEphemeral: true,
      supportsCommands: true,
      maxBlocksPerMessage: 50,
      supportedAttachments: {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.audio,
        AttachmentType.document,
      },
      custom: {
        'supportsBlockKit': true,
        'supportsWorkflows': true,
        'supportsShortcuts': true,
        'supportsHomeTab': true,
      },
    );
  }

  /// Creates capabilities for Discord.
  factory ExtendedChannelCapabilities.discord() {
    return const ExtendedChannelCapabilities(
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
  factory ExtendedChannelCapabilities.telegram() {
    return const ExtendedChannelCapabilities(
      text: true,
      richMessages: false,
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
  factory ExtendedChannelCapabilities.teams() {
    return const ExtendedChannelCapabilities(
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
      maxFileSize: 25 * 1024 * 1024, // 25MB
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: true,
      supportsEphemeral: false,
      supportsCommands: true,
      supportedAttachments: {
        AttachmentType.file,
        AttachmentType.image,
      },
      custom: {
        'supportsAdaptiveCards': true,
        'supportsTaskModules': true,
        'supportsMeetings': true,
        'supportsMessageExtensions': true,
      },
    );
  }

  /// Creates capabilities for Email.
  factory ExtendedChannelCapabilities.email() {
    return const ExtendedChannelCapabilities(
      text: true,
      richMessages: false,
      attachments: true,
      reactions: false,
      threads: true,
      editing: false,
      deleting: false,
      typingIndicator: false,
      supportsFiles: true,
      maxFileSize: 25 * 1024 * 1024, // 25MB typical
      supportsButtons: false,
      supportsMenus: false,
      supportsModals: false,
      supportsEphemeral: false,
      supportsCommands: true,
      supportedAttachments: {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.document,
      },
      custom: {
        'supportsHtml': true,
        'supportsAsync': true,
        'avgResponseTime': 'minutes to hours',
      },
    );
  }

  /// Creates capabilities for Webhook.
  factory ExtendedChannelCapabilities.webhook() {
    return const ExtendedChannelCapabilities(
      text: true,
      richMessages: true,
      attachments: false,
      reactions: false,
      threads: false,
      editing: false,
      deleting: false,
      typingIndicator: false,
      supportsFiles: false,
      supportsButtons: true,
      supportsMenus: false,
      supportsModals: false,
      supportsEphemeral: false,
      supportsCommands: true,
    );
  }

  /// Creates capabilities for WeCom.
  factory ExtendedChannelCapabilities.wecom() {
    return const ExtendedChannelCapabilities(
      text: true,
      richMessages: true,
      attachments: true,
      reactions: false,
      threads: false,
      editing: false,
      deleting: true,
      typingIndicator: false,
      maxMessageLength: 2048,
      supportsFiles: true,
      maxFileSize: 20 * 1024 * 1024, // 20MB
      supportsButtons: true,
      supportsMenus: true,
      supportsModals: false,
      supportsEphemeral: false,
      supportsCommands: true,
      supportedAttachments: {
        AttachmentType.file,
        AttachmentType.image,
        AttachmentType.video,
        AttachmentType.audio,
      },
      custom: {
        'supportsMarkdown': true,
        'supportsTextCard': true,
        'supportsNewsCard': true,
        'supportsInteractiveCard': true,
      },
    );
  }

  /// Creates capabilities for YouTube.
  factory ExtendedChannelCapabilities.youtube() {
    return const ExtendedChannelCapabilities(
      text: true,
      richMessages: false,
      attachments: false,
      reactions: false,
      threads: true,
      editing: true,
      deleting: true,
      typingIndicator: false,
      maxMessageLength: 10000,
      supportsFiles: false,
      supportsButtons: false,
      supportsMenus: false,
      supportsModals: false,
      supportsEphemeral: false,
      supportsCommands: true,
      supportedAttachments: {},
      custom: {
        'isPublic': true,
        'requiresOAuth': true,
        'quotaLimited': true,
        'liveChatMaxLength': 200,
      },
    );
  }

  /// Creates capabilities for Kakao.
  factory ExtendedChannelCapabilities.kakao() {
    return const ExtendedChannelCapabilities(
      text: true,
      richMessages: false,
      attachments: false,
      reactions: false,
      threads: false,
      editing: false,
      deleting: false,
      typingIndicator: false,
      maxMessageLength: 1000,
      supportsFiles: false,
      supportsButtons: true,
      supportsMenus: false,
      supportsModals: false,
      supportsEphemeral: false,
      supportsCommands: false,
      supportedAttachments: {},
      custom: {
        'templateBased': true,
        'requiresApproval': true,
        'userInitiatedOnly': true,
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

  /// Converts to base ChannelCapabilities (explicit downcast).
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

  @override
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
