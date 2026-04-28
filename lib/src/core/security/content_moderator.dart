import 'package:mcp_bundle/ports.dart';

/// Actions that can be taken on moderated content.
enum ModerationAction {
  /// Allow the content through unchanged.
  allow,

  /// Block the content entirely. Do not process or deliver.
  block,

  /// Flag the content for human review. Process but mark for review.
  flag,

  /// Redact specific portions. Replace flagged parts with [replacementContent].
  redact,
}

/// Result of content moderation.
class ModerationResult {
  const ModerationResult({
    required this.action,
    this.reason,
    this.flaggedCategories,
    this.replacementContent,
    this.confidence,
  });

  /// The moderation action to take.
  final ModerationAction action;

  /// Why the content was flagged (null if allowed).
  final String? reason;

  /// Content categories that were flagged.
  final List<String>? flaggedCategories;

  /// Replacement content (for redact action).
  final String? replacementContent;

  /// Confidence score of the moderation decision (0.0 - 1.0).
  final double? confidence;
}

/// Moderates content flowing through the channel.
///
/// Applied to both inbound (user messages) and outbound (bot responses)
/// to enforce content policies. The application implements this based
/// on its content policy.
abstract interface class ContentModerator {
  /// Moderate an inbound event (from user).
  Future<ModerationResult> moderateInbound(ChannelEvent event);

  /// Moderate an outbound response (from bot/LLM).
  Future<ModerationResult> moderateOutbound(ChannelResponse response);
}
