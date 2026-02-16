import 'dart:math';

import 'package:meta/meta.dart';

import '../port/channel_error.dart';

/// Backoff strategy for retry delays.
abstract class BackoffStrategy {
  const BackoffStrategy();

  /// Calculate delay for attempt number (0-indexed).
  Duration getDelay(int attempt);
}

/// Exponential backoff strategy.
class ExponentialBackoff extends BackoffStrategy {
  const ExponentialBackoff({
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;

  @override
  Duration getDelay(int attempt) {
    final delay = initialDelay.inMilliseconds * pow(multiplier, attempt);
    return Duration(
      milliseconds: min(delay.toInt(), maxDelay.inMilliseconds),
    );
  }
}

/// Linear backoff strategy.
class LinearBackoff extends BackoffStrategy {
  const LinearBackoff({
    this.initialDelay = const Duration(seconds: 1),
    this.increment = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  });

  final Duration initialDelay;
  final Duration increment;
  final Duration maxDelay;

  @override
  Duration getDelay(int attempt) {
    final delay = Duration(
      milliseconds:
          initialDelay.inMilliseconds + (increment.inMilliseconds * attempt),
    );
    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Fixed backoff strategy.
class FixedBackoff extends BackoffStrategy {
  const FixedBackoff({this.delay = const Duration(seconds: 1)});

  final Duration delay;

  @override
  Duration getDelay(int attempt) => delay;
}

/// Retry policy configuration.
@immutable
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.backoff = const ExponentialBackoff(),
    this.retryableErrors = const {
      'rate_limited',
      'network_error',
      'timeout',
      'server_error',
    },
    this.maxDuration,
    this.jitter = 0.1,
  });

  /// No retry policy.
  factory RetryPolicy.none() => const RetryPolicy(maxAttempts: 0);

  /// Aggressive retry for critical operations.
  factory RetryPolicy.aggressive() => const RetryPolicy(
        maxAttempts: 5,
        backoff: ExponentialBackoff(
          initialDelay: Duration(milliseconds: 100),
          maxDelay: Duration(seconds: 30),
          multiplier: 2.0,
        ),
        jitter: 0.2,
      );

  /// Maximum retry attempts
  final int maxAttempts;

  /// Backoff strategy
  final BackoffStrategy backoff;

  /// Retryable error codes
  final Set<String> retryableErrors;

  /// Maximum total retry duration
  final Duration? maxDuration;

  /// Jitter factor (0.0 - 1.0) for randomizing delays
  final double jitter;

  RetryPolicy copyWith({
    int? maxAttempts,
    BackoffStrategy? backoff,
    Set<String>? retryableErrors,
    Duration? maxDuration,
    double? jitter,
  }) {
    return RetryPolicy(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      backoff: backoff ?? this.backoff,
      retryableErrors: retryableErrors ?? this.retryableErrors,
      maxDuration: maxDuration ?? this.maxDuration,
      jitter: jitter ?? this.jitter,
    );
  }
}

/// Retrier with configurable policy.
class Retrier {
  Retrier(this._policy);

  final RetryPolicy _policy;
  final Random _random = Random();

  /// Execute operation with retry logic.
  Future<T> execute<T>(
    Future<T> Function() operation, {
    bool Function(Object error)? shouldRetry,
  }) async {
    var attempt = 0;
    final startTime = DateTime.now();

    while (true) {
      try {
        return await operation();
      } catch (error) {
        attempt++;

        // Check if we should retry
        if (!_shouldRetry(error, attempt, startTime, shouldRetry)) {
          rethrow;
        }

        // Calculate delay with jitter
        final baseDelay = _policy.backoff.getDelay(attempt - 1);
        final jitteredDelay = _applyJitter(baseDelay);

        await Future<void>.delayed(jitteredDelay);
      }
    }
  }

  bool _shouldRetry(
    Object error,
    int attempt,
    DateTime startTime,
    bool Function(Object)? customCheck,
  ) {
    // Check max attempts
    if (attempt >= _policy.maxAttempts) return false;

    // Check max duration
    if (_policy.maxDuration != null) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= _policy.maxDuration!) return false;
    }

    // Check if error is retryable
    if (customCheck != null) {
      return customCheck(error);
    }

    if (error is ChannelError) {
      return error.retryable || _policy.retryableErrors.contains(error.code);
    }

    return false;
  }

  Duration _applyJitter(Duration delay) {
    if (_policy.jitter <= 0) return delay;

    final jitterRange = delay.inMilliseconds * _policy.jitter;
    final jitter = (_random.nextDouble() * 2 - 1) * jitterRange;
    return Duration(milliseconds: delay.inMilliseconds + jitter.toInt());
  }
}
