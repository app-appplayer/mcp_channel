/// Core types for MCP Channel.
///
/// Re-exports base types from mcp_bundle and provides extended types
/// for messaging platform-specific features.
library;

// Re-export base types from mcp_bundle
export 'package:mcp_bundle/ports.dart'
    show
        ChannelIdentity,
        ConversationKey,
        ChannelEvent,
        ChannelResponse,
        ChannelCapabilities,
        ChannelAttachment,
        ChannelPort;

// mcp_channel extended types
export 'attachment.dart';
export 'channel_identity_info.dart';
export 'content_block.dart';
export 'extended_channel_event.dart';
export 'extended_channel_response.dart';
export 'extended_conversation_key.dart';
export 'file_info.dart';
