import 'package:mcp_bundle/ports.dart';

/// Result of input validation.
sealed class ValidationResult {
  const ValidationResult._();

  /// Allow the event through unchanged.
  factory ValidationResult.allow() = AllowResult;

  /// Allow the event through with sanitized content.
  factory ValidationResult.sanitize(ChannelEvent sanitizedEvent) =
      SanitizeResult;

  /// Reject the event entirely.
  factory ValidationResult.reject({
    required String reason,
    ChannelResponse? rejectionResponse,
  }) = RejectResult;
}

/// Input is valid and allowed.
final class AllowResult extends ValidationResult {
  const AllowResult() : super._();
}

/// Input was sanitized to remove unsafe content.
final class SanitizeResult extends ValidationResult {
  const SanitizeResult(this.sanitizedEvent) : super._();

  /// The sanitized event
  final ChannelEvent sanitizedEvent;
}

/// Input is rejected as invalid or unsafe.
final class RejectResult extends ValidationResult {
  const RejectResult({
    required this.reason,
    this.rejectionResponse,
  }) : super._();

  /// Reason for rejection
  final String reason;

  /// Optional response to send back to the user
  final ChannelResponse? rejectionResponse;
}

/// Validates and sanitizes incoming channel events before processing.
///
/// Applied as the first step after event receipt, before idempotency
/// or session management. Invalid events are rejected or sanitized
/// before entering the processing pipeline.
abstract interface class ChannelInputValidator {
  /// Validate an incoming event.
  ///
  /// Returns [ValidationResult.allow] to pass through unchanged,
  /// [ValidationResult.sanitize] to pass through with modifications,
  /// or [ValidationResult.reject] to block the event entirely.
  Future<ValidationResult> validateEvent(ChannelEvent event);
}
