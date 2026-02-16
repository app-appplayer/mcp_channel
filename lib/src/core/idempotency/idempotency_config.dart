/// Configuration for idempotency handling.
class IdempotencyConfig {
  /// How long to keep completed records
  final Duration recordTtl;

  /// Lock timeout for processing
  final Duration lockTimeout;

  /// Whether to retry failed events
  final bool retryFailed;

  /// Cleanup interval
  final Duration cleanupInterval;

  const IdempotencyConfig({
    this.recordTtl = const Duration(hours: 24),
    this.lockTimeout = const Duration(minutes: 5),
    this.retryFailed = false,
    this.cleanupInterval = const Duration(hours: 1),
  });

  IdempotencyConfig copyWith({
    Duration? recordTtl,
    Duration? lockTimeout,
    bool? retryFailed,
    Duration? cleanupInterval,
  }) {
    return IdempotencyConfig(
      recordTtl: recordTtl ?? this.recordTtl,
      lockTimeout: lockTimeout ?? this.lockTimeout,
      retryFailed: retryFailed ?? this.retryFailed,
      cleanupInterval: cleanupInterval ?? this.cleanupInterval,
    );
  }
}
