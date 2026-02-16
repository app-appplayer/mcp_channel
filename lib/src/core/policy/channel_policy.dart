import 'package:meta/meta.dart';

import 'circuit_breaker.dart';
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
          requestTimeout: Duration(seconds: 3),
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
  PolicyExecutor(this.policy, String channelName)
      : _rateLimiter = RateLimiter(policy.rateLimit),
        _retrier = Retrier(policy.retry),
        _circuitBreaker = CircuitBreaker(channelName, policy.circuitBreaker),
        _timeoutExecutor = TimeoutExecutor(policy.timeout);

  final ChannelPolicy policy;
  final RateLimiter _rateLimiter;
  final Retrier _retrier;
  final CircuitBreaker _circuitBreaker;
  final TimeoutExecutor _timeoutExecutor;

  /// Get circuit breaker state.
  CircuitState get circuitState => _circuitBreaker.state;

  /// Check if circuit is allowing requests.
  bool get isCircuitAllowed => _circuitBreaker.isAllowed;

  /// Execute operation with all policies applied.
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? conversationKey,
    String? userId,
  }) async {
    // Check circuit breaker
    if (!_circuitBreaker.isAllowed) {
      throw CircuitOpenException(_circuitBreaker.name);
    }

    // Apply timeout
    return await _timeoutExecutor.withOperationTimeout(() async {
      // Apply retry
      return await _retrier.execute(() async {
        // Apply rate limit
        await _rateLimiter.acquire(
          conversationKey: conversationKey,
          userId: userId,
        );

        // Execute with circuit breaker tracking
        return await _circuitBreaker.execute(operation);
      });
    });
  }

  /// Execute without rate limiting.
  Future<T> executeWithoutRateLimit<T>(
    Future<T> Function() operation,
  ) async {
    if (!_circuitBreaker.isAllowed) {
      throw CircuitOpenException(_circuitBreaker.name);
    }

    return await _timeoutExecutor.withOperationTimeout(() async {
      return await _retrier.execute(() async {
        return await _circuitBreaker.execute(operation);
      });
    });
  }

  /// Execute with custom timeout.
  Future<T> executeWithTimeout<T>(
    Future<T> Function() operation,
    Duration timeout, {
    String? conversationKey,
    String? userId,
  }) async {
    if (!_circuitBreaker.isAllowed) {
      throw CircuitOpenException(_circuitBreaker.name);
    }

    return await _timeoutExecutor.withTimeout(
      () async {
        return await _retrier.execute(() async {
          await _rateLimiter.acquire(
            conversationKey: conversationKey,
            userId: userId,
          );
          return await _circuitBreaker.execute(operation);
        });
      },
      timeout,
    );
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
