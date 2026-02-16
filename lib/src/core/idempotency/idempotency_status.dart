/// Status of an idempotency record.
enum IdempotencyStatus {
  /// Event is being processed
  processing,

  /// Event processing completed successfully
  completed,

  /// Event processing failed
  failed,

  /// Record expired (can be reprocessed)
  expired,
}
