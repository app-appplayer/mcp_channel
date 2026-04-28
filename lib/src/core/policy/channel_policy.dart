import 'package:meta/meta.dart';

import 'circuit_breaker.dart';
import 'dead_letter_queue.dart';
import 'platform_rate_limit_feedback.dart';
import 'rate_limit.dart';
import 'retry.dart';
import 'timeout.dart';

/// Combined channel policy configuration.
@immutable
class ChannelPolicy {
  const ChannelPolicy({
    this.rateLimit = const RateLimitPolicy(
      maxRequests: 30,
      window: Duration(seconds: 1),
    ),
    this.retry = const RetryPolicy(),
    this.circuitBreaker = const CircuitBreakerPolicy(),
    this.timeout = const TimeoutPolicy(),
  });

  /// Slack platform defaults.
  factory ChannelPolicy.slack() => ChannelPolicy(
        rateLimit: RateLimitPolicy.slack(),
        retry: const RetryPolicy(maxAttempts: 3),
        circuitBreaker: const CircuitBreakerPolicy(
          failureThreshold: 5,
          recoveryTimeout: Duration(seconds: 60),
        ),
        timeout: const TimeoutPolicy(
          requestTimeout: Duration(seconds: 30),
        ),
      );

  /// Telegram platform defaults.
  factory ChannelPolicy.telegram() => ChannelPolicy(
        rateLimit: RateLimitPolicy.telegram(),
        retry: const RetryPolicy(maxAttempts: 5),
        circuitBreaker: const CircuitBreakerPolicy(),
        timeout: const TimeoutPolicy(),
      );

  /// Discord platform defaults.
  factory ChannelPolicy.discord() => ChannelPolicy(
        rateLimit: RateLimitPolicy.discord(),
        retry: const RetryPolicy(maxAttempts: 3),
        circuitBreaker: const CircuitBreakerPolicy(),
        timeout: const TimeoutPolicy(),
      );

  /// Teams platform defaults.
  factory ChannelPolicy.teams() => const ChannelPolicy(
        rateLimit: RateLimitPolicy(
          maxRequests: 20,
          window: Duration(seconds: 1),
        ),
        retry: RetryPolicy(maxAttempts: 3),
        circuitBreaker: CircuitBreakerPolicy(),
        timeout: TimeoutPolicy(),
      );

  /// Email platform defaults.
  factory ChannelPolicy.email() => const ChannelPolicy(
        rateLimit: RateLimitPolicy(
          maxRequests: 10,
          window: Duration(seconds: 1),
        ),
        retry: RetryPolicy(maxAttempts: 3),
        circuitBreaker: CircuitBreakerPolicy(),
        timeout: TimeoutPolicy(
          requestTimeout: Duration(seconds: 60),
        ),
      );

  /// Webhook platform defaults.
  factory ChannelPolicy.webhook() => const ChannelPolicy(
        rateLimit: RateLimitPolicy(
          maxRequests: 100,
          window: Duration(seconds: 1),
        ),
        retry: RetryPolicy(maxAttempts: 3),
        circuitBreaker: CircuitBreakerPolicy(),
        timeout: TimeoutPolicy(),
      );

  /// WeCom platform defaults.
  factory ChannelPolicy.wecom() => const ChannelPolicy(
        rateLimit: RateLimitPolicy(
          maxRequests: 200,
          window: Duration(minutes: 1),
        ),
        retry: RetryPolicy(maxAttempts: 3),
        circuitBreaker: CircuitBreakerPolicy(),
        timeout: TimeoutPolicy(),
      );

  /// YouTube platform defaults.
  factory ChannelPolicy.youtube() => const ChannelPolicy(
        rateLimit: RateLimitPolicy(
          maxRequests: 5,
          window: Duration(seconds: 1),
        ),
        retry: RetryPolicy(maxAttempts: 3),
        circuitBreaker: CircuitBreakerPolicy(),
        timeout: TimeoutPolicy(),
      );

  /// Kakao platform defaults.
  factory ChannelPolicy.kakao() => const ChannelPolicy(
        rateLimit: RateLimitPolicy(
          maxRequests: 30,
          window: Duration(seconds: 1),
        ),
        retry: RetryPolicy(maxAttempts: 0),
        circuitBreaker: CircuitBreakerPolicy(),
        timeout: TimeoutPolicy(
          requestTimeout: Duration(seconds: 5),
        ),
      );

  /// Rate limiting configuration
  final RateLimitPolicy rateLimit;

  /// Retry configuration
  final RetryPolicy retry;

  /// Circuit breaker configuration
  final CircuitBreakerPolicy circuitBreaker;

  /// Timeout configuration
  final TimeoutPolicy timeout;

  ChannelPolicy copyWith({
    RateLimitPolicy? rateLimit,
    RetryPolicy? retry,
    CircuitBreakerPolicy? circuitBreaker,
    TimeoutPolicy? timeout,
  }) {
    return ChannelPolicy(
      rateLimit: rateLimit ?? this.rateLimit,
      retry: retry ?? this.retry,
      circuitBreaker: circuitBreaker ?? this.circuitBreaker,
      timeout: timeout ?? this.timeout,
    );
  }
}

/// Combined policy executor applying all policies.
class PolicyExecutor {
  PolicyExecutor(
    this._policy,
    String channelName, {
    this.deadLetterQueue,
    this.onFailure,
  })  : _rateLimiter = RateLimiter(_policy.rateLimit),
        _retrier = Retrier(_policy.retry),
        _circuitBreaker = CircuitBreaker(channelName, _policy.circuitBreaker),
        _timeoutExecutor = TimeoutExecutor(_policy.timeout);

  final ChannelPolicy _policy;
  final RateLimiter _rateLimiter;
  final Retrier _retrier;
  final CircuitBreaker _circuitBreaker;
  final TimeoutExecutor _timeoutExecutor;

  /// Optional dead letter queue for storing exhausted failures.
  final DeadLetterQueue? deadLetterQueue;

  /// Optional callback when an event fails all retries.
  final FailureHandler? onFailure;

  /// Get circuit breaker state.
  CircuitState get circuitState => _circuitBreaker.state;

  /// Check if circuit is allowing requests.
  bool get isCircuitAllowed => _circuitBreaker.isAllowed;

  /// Execute operation with all policies applied.
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? conversationKey,
    String? userId,
    String? eventId,
    Map<String, dynamic>? eventData,
  }) async {
    try {
      // 1. Check circuit breaker
      if (!_circuitBreaker.isAllowed) {
        throw CircuitOpenException(_circuitBreaker.name);
      }

      // 2. Apply timeout
      return _withTimeout(() async {
        // 3. Apply retry
        return _retrier.execute(() async {
          // 4. Apply rate limit
          await _rateLimiter.acquire(
            conversationKey: conversationKey,
            userId: userId,
          );

          // Execute with circuit breaker tracking
          return _circuitBreaker.execute(operation);
        });
      });
    } catch (error, stackTrace) {
      // All retries exhausted -- record to DLQ
      if (deadLetterQueue != null && eventId != null) {
        final record = FailureRecord(
          eventId: eventId,
          event: eventData ?? {},
          error: error.toString(),
          stackTrace: stackTrace.toString(),
          failedAt: DateTime.now(),
          attemptCount: _policy.retry.maxAttempts,
          conversationKey: conversationKey,
          userId: userId,
        );

        await deadLetterQueue!.enqueue(record);
        await onFailure?.call(record);
      }
      rethrow;
    }
  }

  Future<T> _withTimeout<T>(Future<T> Function() operation) {
    return _timeoutExecutor.withOperationTimeout(operation);
  }

  /// Update rate limiter from platform response feedback.
  void updateFromResponse(PlatformRateLimitFeedback feedback) {
    _rateLimiter.updateFromResponse(feedback);
  }

  /// Force open the circuit breaker.
  void openCircuit() => _circuitBreaker.open();

  /// Force close the circuit breaker.
  void closeCircuit() => _circuitBreaker.close();

  /// Reset all policy state.
  void reset() {
    _rateLimiter.reset();
    _circuitBreaker.reset();
  }
}
