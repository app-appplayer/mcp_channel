import 'package:meta/meta.dart';

/// Feedback from platform rate limit response headers.
///
/// Used by [RateLimiter.updateFromResponse] to adaptively adjust
/// rate limiting based on actual platform feedback.
@immutable
class PlatformRateLimitFeedback {
  const PlatformRateLimitFeedback({
    this.retryAfter,
    this.remainingRequests,
    this.resetAt,
    this.limit,
    this.bucketId,
  });

  /// Parses rate limit feedback from HTTP response headers.
  ///
  /// Supports standard headers:
  /// - `X-RateLimit-Remaining` / `RateLimit-Remaining`
  /// - `X-RateLimit-Limit` / `RateLimit-Limit`
  /// - `X-RateLimit-Reset` / `RateLimit-Reset` (Unix epoch seconds)
  /// - `Retry-After` (seconds)
  /// - `X-RateLimit-Bucket` (platform-specific bucket ID)
  factory PlatformRateLimitFeedback.fromHeaders(Map<String, String> headers) {
    final normalised = {
      for (final entry in headers.entries)
        entry.key.toLowerCase(): entry.value,
    };

    int? remainingRequests;
    int? limit;
    DateTime? resetAt;
    Duration? retryAfter;
    String? bucketId;

    // Remaining
    final remainingStr = normalised['x-ratelimit-remaining'] ??
        normalised['ratelimit-remaining'];
    if (remainingStr != null) {
      remainingRequests = int.tryParse(remainingStr);
    }

    // Limit
    final limitStr =
        normalised['x-ratelimit-limit'] ?? normalised['ratelimit-limit'];
    if (limitStr != null) {
      limit = int.tryParse(limitStr);
    }

    // Reset (Unix epoch seconds)
    final resetStr =
        normalised['x-ratelimit-reset'] ?? normalised['ratelimit-reset'];
    if (resetStr != null) {
      final epochSeconds = int.tryParse(resetStr);
      if (epochSeconds != null) {
        resetAt = DateTime.fromMillisecondsSinceEpoch(
          epochSeconds * 1000,
          isUtc: true,
        );
      }
    }

    // Retry-After (seconds)
    final retryStr = normalised['retry-after'];
    if (retryStr != null) {
      final seconds = int.tryParse(retryStr);
      if (seconds != null) {
        retryAfter = Duration(seconds: seconds);
      }
    }

    // Bucket ID
    bucketId = normalised['x-ratelimit-bucket'];

    return PlatformRateLimitFeedback(
      remainingRequests: remainingRequests,
      limit: limit,
      resetAt: resetAt,
      retryAfter: retryAfter,
      bucketId: bucketId,
    );
  }

  /// How long to wait before retrying (from Retry-After header).
  final Duration? retryAfter;

  /// Remaining requests in the current window.
  final int? remainingRequests;

  /// When the rate limit window resets.
  final DateTime? resetAt;

  /// Maximum requests allowed in the window.
  final int? limit;

  /// Platform-specific bucket identifier (e.g., Discord bucket ID).
  final String? bucketId;

  /// Whether the platform indicates the rate limit has been hit.
  bool get isLimited => remainingRequests != null && remainingRequests! <= 0;

  /// Duration until the rate limit resets, relative to [now].
  ///
  /// Returns `null` if [resetAt] is not set or already in the past.
  Duration? durationUntilReset({DateTime? now}) {
    if (resetAt == null) return null;
    final diff = resetAt!.difference(now ?? DateTime.now());
    return diff.isNegative ? null : diff;
  }

  PlatformRateLimitFeedback copyWith({
    int? remainingRequests,
    int? limit,
    DateTime? resetAt,
    Duration? retryAfter,
    String? bucketId,
  }) {
    return PlatformRateLimitFeedback(
      remainingRequests: remainingRequests ?? this.remainingRequests,
      limit: limit ?? this.limit,
      resetAt: resetAt ?? this.resetAt,
      retryAfter: retryAfter ?? this.retryAfter,
      bucketId: bucketId ?? this.bucketId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformRateLimitFeedback &&
          runtimeType == other.runtimeType &&
          remainingRequests == other.remainingRequests &&
          limit == other.limit &&
          resetAt == other.resetAt &&
          retryAfter == other.retryAfter &&
          bucketId == other.bucketId;

  @override
  int get hashCode =>
      Object.hash(remainingRequests, limit, resetAt, retryAfter, bucketId);

  @override
  String toString() =>
      'PlatformRateLimitFeedback(remainingRequests: $remainingRequests, '
      'limit: $limit, resetAt: $resetAt, retryAfter: $retryAfter, '
      'bucketId: $bucketId)';
}
