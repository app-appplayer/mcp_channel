import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelPolicy', () {
    test('constructor with defaults', () {
      const policy = ChannelPolicy();

      expect(policy.rateLimit.maxRequests, 30);
      expect(policy.rateLimit.window, Duration(seconds: 1));
      expect(policy.retry, isA<RetryPolicy>());
      expect(policy.circuitBreaker, isA<CircuitBreakerPolicy>());
      expect(policy.timeout, isA<TimeoutPolicy>());
    });

    test('slack factory', () {
      final policy = ChannelPolicy.slack();

      expect(policy.rateLimit.maxRequests, 1);
      expect(policy.rateLimit.burstAllowance, 3);
      expect(policy.rateLimit.perConversation, isNotNull);
      expect(policy.retry.maxAttempts, 3);
      expect(policy.circuitBreaker.failureThreshold, 5);
      expect(
        policy.circuitBreaker.recoveryTimeout,
        Duration(seconds: 60),
      );
      expect(policy.timeout.requestTimeout, const Duration(seconds: 30));
    });

    test('telegram factory', () {
      final policy = ChannelPolicy.telegram();

      expect(policy.rateLimit.maxRequests, 30);
      expect(policy.rateLimit.perConversation, isNotNull);
      expect(policy.rateLimit.perConversation!.maxRequests, 1);
      expect(
        policy.rateLimit.perConversation!.window,
        Duration(seconds: 3),
      );
      expect(policy.retry.maxAttempts, 5);
      expect(policy.circuitBreaker, isA<CircuitBreakerPolicy>());
      expect(policy.timeout, isA<TimeoutPolicy>());
    });

    test('discord factory', () {
      final policy = ChannelPolicy.discord();

      expect(policy.rateLimit.maxRequests, 50);
      expect(policy.rateLimit.burstAllowance, 10);
      expect(policy.retry.maxAttempts, 3);
      expect(policy.circuitBreaker, isA<CircuitBreakerPolicy>());
      expect(policy.timeout, isA<TimeoutPolicy>());
    });

    test('teams factory', () {
      final policy = ChannelPolicy.teams();

      expect(policy.rateLimit.maxRequests, 20);
      expect(policy.rateLimit.window, Duration(seconds: 1));
      expect(policy.retry.maxAttempts, 3);
      expect(policy.circuitBreaker, isA<CircuitBreakerPolicy>());
      expect(policy.timeout, isA<TimeoutPolicy>());
    });

    test('email factory', () {
      final policy = ChannelPolicy.email();

      expect(policy.rateLimit.maxRequests, 10);
      expect(policy.rateLimit.window, Duration(seconds: 1));
      expect(policy.retry.maxAttempts, 3);
      expect(policy.timeout.requestTimeout, Duration(seconds: 60));
    });

    test('webhook factory', () {
      final policy = ChannelPolicy.webhook();

      expect(policy.rateLimit.maxRequests, 100);
      expect(policy.rateLimit.window, Duration(seconds: 1));
      expect(policy.retry.maxAttempts, 3);
      expect(policy.circuitBreaker, isA<CircuitBreakerPolicy>());
      expect(policy.timeout, isA<TimeoutPolicy>());
    });

    test('wecom factory', () {
      final policy = ChannelPolicy.wecom();

      expect(policy.rateLimit.maxRequests, 200);
      expect(policy.rateLimit.window, Duration(minutes: 1));
      expect(policy.retry.maxAttempts, 3);
      expect(policy.circuitBreaker, isA<CircuitBreakerPolicy>());
      expect(policy.timeout, isA<TimeoutPolicy>());
    });

    test('youtube factory', () {
      final policy = ChannelPolicy.youtube();

      expect(policy.rateLimit.maxRequests, 5);
      expect(policy.rateLimit.window, Duration(seconds: 1));
      expect(policy.retry.maxAttempts, 3);
      expect(policy.circuitBreaker, isA<CircuitBreakerPolicy>());
      expect(policy.timeout, isA<TimeoutPolicy>());
    });

    test('kakao factory', () {
      final policy = ChannelPolicy.kakao();

      expect(policy.rateLimit.maxRequests, 30);
      expect(policy.rateLimit.window, Duration(seconds: 1));
      expect(policy.retry.maxAttempts, 0);
      expect(policy.circuitBreaker, isA<CircuitBreakerPolicy>());
      expect(policy.timeout.requestTimeout, Duration(seconds: 5));
    });

    test('copyWith all fields', () {
      const original = ChannelPolicy();

      final newRateLimit = RateLimitPolicy(
        maxRequests: 50,
        window: Duration(seconds: 2),
      );
      const newRetry = RetryPolicy(maxAttempts: 10);
      const newCircuit = CircuitBreakerPolicy(failureThreshold: 20);
      const newTimeout = TimeoutPolicy(
        requestTimeout: Duration(seconds: 60),
      );

      final copied = original.copyWith(
        rateLimit: newRateLimit,
        retry: newRetry,
        circuitBreaker: newCircuit,
        timeout: newTimeout,
      );

      expect(copied.rateLimit.maxRequests, 50);
      expect(copied.retry.maxAttempts, 10);
      expect(copied.circuitBreaker.failureThreshold, 20);
      expect(copied.timeout.requestTimeout, Duration(seconds: 60));
    });

    test('copyWith no arguments returns equivalent', () {
      const original = ChannelPolicy();
      final copied = original.copyWith();

      expect(copied.rateLimit.maxRequests, original.rateLimit.maxRequests);
      expect(copied.retry.maxAttempts, original.retry.maxAttempts);
      expect(
        copied.circuitBreaker.failureThreshold,
        original.circuitBreaker.failureThreshold,
      );
      expect(copied.timeout.requestTimeout, original.timeout.requestTimeout);
    });
  });

  group('PolicyExecutor', () {
    test('constructor', () {
      final executor = PolicyExecutor(const ChannelPolicy(), 'test');
      expect(executor.circuitState, CircuitState.closed);
    });

    group('execute', () {
      test('success path', () async {
        final executor = PolicyExecutor(
          ChannelPolicy(
            rateLimit: RateLimitPolicy(
              maxRequests: 100,
              window: Duration(seconds: 1),
            ),
            retry: const RetryPolicy(maxAttempts: 0),
            circuitBreaker: const CircuitBreakerPolicy(),
            timeout: const TimeoutPolicy(
              operationTimeout: Duration(seconds: 5),
            ),
          ),
          'test',
        );

        final result = await executor.execute(() async => 'hello');
        expect(result, 'hello');
      });

      test('circuit open throws CircuitOpenException', () async {
        final executor = PolicyExecutor(const ChannelPolicy(), 'test');
        executor.openCircuit();

        expect(
          () => executor.execute(() async => 'hello'),
          throwsA(isA<CircuitOpenException>()),
        );
      });

      test('with conversationKey and userId', () async {
        final executor = PolicyExecutor(
          ChannelPolicy(
            rateLimit: RateLimitPolicy(
              maxRequests: 100,
              window: Duration(seconds: 1),
              perConversation: RateLimitPolicy(
                maxRequests: 100,
                window: Duration(seconds: 1),
              ),
              perUser: RateLimitPolicy(
                maxRequests: 100,
                window: Duration(seconds: 1),
              ),
            ),
            retry: const RetryPolicy(maxAttempts: 0),
            timeout: const TimeoutPolicy(
              operationTimeout: Duration(seconds: 5),
            ),
          ),
          'test',
        );

        final result = await executor.execute(
          () async => 'ok',
          conversationKey: 'conv1',
          userId: 'user1',
        );
        expect(result, 'ok');
      });
    });

    group('circuit state getters', () {
      test('circuitState returns current state', () {
        final executor = PolicyExecutor(const ChannelPolicy(), 'test');
        expect(executor.circuitState, CircuitState.closed);

        executor.openCircuit();
        expect(executor.circuitState, CircuitState.open);
      });

      test('isCircuitAllowed returns whether circuit allows requests', () {
        final executor = PolicyExecutor(const ChannelPolicy(), 'test');
        expect(executor.isCircuitAllowed, isTrue);

        executor.openCircuit();
        expect(executor.isCircuitAllowed, isFalse);
      });
    });

    group('circuit control', () {
      test('openCircuit', () {
        final executor = PolicyExecutor(const ChannelPolicy(), 'test');
        executor.openCircuit();
        expect(executor.circuitState, CircuitState.open);
      });

      test('closeCircuit', () {
        final executor = PolicyExecutor(const ChannelPolicy(), 'test');
        executor.openCircuit();
        executor.closeCircuit();
        expect(executor.circuitState, CircuitState.closed);
      });

      test('reset clears all state', () async {
        final executor = PolicyExecutor(
          ChannelPolicy(
            rateLimit: RateLimitPolicy(
              maxRequests: 1,
              window: Duration(seconds: 10),
              action: RateLimitAction.reject,
            ),
            retry: const RetryPolicy(maxAttempts: 0),
            timeout: const TimeoutPolicy(
              operationTimeout: Duration(seconds: 5),
            ),
          ),
          'test',
        );

        // Use up rate limit
        await executor.execute(() async => 'ok');

        // Open circuit
        executor.openCircuit();

        // Reset all
        executor.reset();

        expect(executor.circuitState, CircuitState.closed);

        // Rate limiter should also be reset, so this should succeed
        final result = await executor.execute(() async => 'after_reset');
        expect(result, 'after_reset');
      });
    });

    group('circuit breaker + retry interaction', () {
      test('retry on failure then succeed', () async {
        final executor = PolicyExecutor(
          ChannelPolicy(
            rateLimit: RateLimitPolicy(
              maxRequests: 100,
              window: Duration(seconds: 1),
            ),
            retry: const RetryPolicy(
              maxAttempts: 3,
              backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
              jitter: 0,
            ),
            circuitBreaker: const CircuitBreakerPolicy(
              failureThreshold: 10,
            ),
            timeout: const TimeoutPolicy(
              operationTimeout: Duration(seconds: 5),
            ),
          ),
          'test',
        );

        var callCount = 0;
        final result = await executor.execute(() async {
          callCount++;
          if (callCount < 2) {
            throw const ChannelError(
              code: 'network_error',
              message: 'fail',
              retryable: true,
            );
          }
          return 'recovered';
        });

        expect(result, 'recovered');
        expect(callCount, 2);
      });
    });
  });
}
