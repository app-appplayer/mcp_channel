import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimitAction', () {
    test('has all expected values', () {
      expect(RateLimitAction.values, hasLength(3));
      expect(RateLimitAction.delay, isNotNull);
      expect(RateLimitAction.reject, isNotNull);
      expect(RateLimitAction.queue, isNotNull);
    });
  });

  group('RateLimitPolicy', () {
    test('constructor sets all fields', () {
      final perConv = RateLimitPolicy(
        maxRequests: 5,
        window: Duration(seconds: 2),
      );
      final perUser = RateLimitPolicy(
        maxRequests: 3,
        window: Duration(seconds: 1),
      );

      final policy = RateLimitPolicy(
        maxRequests: 10,
        window: Duration(seconds: 1),
        burstAllowance: 5,
        perConversation: perConv,
        perUser: perUser,
        action: RateLimitAction.reject,
      );

      expect(policy.maxRequests, 10);
      expect(policy.window, Duration(seconds: 1));
      expect(policy.burstAllowance, 5);
      expect(policy.perConversation, perConv);
      expect(policy.perUser, perUser);
      expect(policy.action, RateLimitAction.reject);
    });

    test('constructor defaults', () {
      final policy = RateLimitPolicy(
        maxRequests: 10,
        window: Duration(seconds: 1),
      );

      expect(policy.burstAllowance, 0);
      expect(policy.perConversation, isNull);
      expect(policy.perUser, isNull);
      expect(policy.action, RateLimitAction.delay);
    });

    test('slack factory', () {
      final policy = RateLimitPolicy.slack();

      expect(policy.maxRequests, 1);
      expect(policy.window, Duration(seconds: 1));
      expect(policy.burstAllowance, 3);
      expect(policy.perConversation, isNotNull);
      expect(policy.perConversation!.maxRequests, 1);
      expect(policy.perConversation!.window, Duration(seconds: 1));
    });

    test('telegram factory', () {
      final policy = RateLimitPolicy.telegram();

      expect(policy.maxRequests, 30);
      expect(policy.window, Duration(seconds: 1));
      expect(policy.burstAllowance, 0);
      expect(policy.perConversation, isNotNull);
      expect(policy.perConversation!.maxRequests, 1);
      expect(policy.perConversation!.window, Duration(seconds: 3));
    });

    test('discord factory', () {
      final policy = RateLimitPolicy.discord();

      expect(policy.maxRequests, 50);
      expect(policy.window, Duration(seconds: 1));
      expect(policy.burstAllowance, 10);
      expect(policy.perConversation, isNull);
    });

    test('copyWith all fields', () {
      final original = RateLimitPolicy(
        maxRequests: 10,
        window: Duration(seconds: 1),
        burstAllowance: 5,
        action: RateLimitAction.delay,
      );

      final perConv = RateLimitPolicy(
        maxRequests: 2,
        window: Duration(seconds: 2),
      );
      final perUser = RateLimitPolicy(
        maxRequests: 3,
        window: Duration(seconds: 3),
      );

      final copied = original.copyWith(
        maxRequests: 20,
        window: Duration(seconds: 5),
        burstAllowance: 10,
        perConversation: perConv,
        perUser: perUser,
        action: RateLimitAction.reject,
      );

      expect(copied.maxRequests, 20);
      expect(copied.window, Duration(seconds: 5));
      expect(copied.burstAllowance, 10);
      expect(copied.perConversation, perConv);
      expect(copied.perUser, perUser);
      expect(copied.action, RateLimitAction.reject);
    });

    test('copyWith no arguments returns equivalent policy', () {
      final original = RateLimitPolicy(
        maxRequests: 10,
        window: Duration(seconds: 1),
        burstAllowance: 5,
        action: RateLimitAction.reject,
      );

      final copied = original.copyWith();

      expect(copied.maxRequests, 10);
      expect(copied.window, Duration(seconds: 1));
      expect(copied.burstAllowance, 5);
      expect(copied.action, RateLimitAction.reject);
    });
  });

  group('RateLimitResult', () {
    test('constructor sets all fields', () {
      final result = RateLimitResult(
        allowed: true,
        retryAfter: Duration(seconds: 1),
        remainingTokens: 5,
      );

      expect(result.allowed, isTrue);
      expect(result.retryAfter, Duration(seconds: 1));
      expect(result.remainingTokens, 5);
    });

    test('allowed factory', () {
      final result = RateLimitResult.allowed(10);

      expect(result.allowed, isTrue);
      expect(result.remainingTokens, 10);
      expect(result.retryAfter, isNull);
    });

    test('allowed factory with zero remaining', () {
      final result = RateLimitResult.allowed(0);

      expect(result.allowed, isTrue);
      expect(result.remainingTokens, 0);
    });

    test('limited factory', () {
      final result =
          RateLimitResult.limited(retryAfter: Duration(seconds: 2));

      expect(result.allowed, isFalse);
      expect(result.retryAfter, Duration(seconds: 2));
      expect(result.remainingTokens, isNull);
    });
  });

  group('RateLimitExceeded', () {
    test('constructor with retryAfter', () {
      final ex = RateLimitExceeded(Duration(seconds: 5));
      expect(ex.retryAfter, Duration(seconds: 5));
    });

    test('constructor without retryAfter', () {
      const ex = RateLimitExceeded();
      expect(ex.retryAfter, isNull);
    });

    test('toString with retryAfter', () {
      final ex = RateLimitExceeded(Duration(milliseconds: 1000));
      expect(ex.toString(), 'RateLimitExceeded: retry after 1000ms');
    });

    test('toString without retryAfter', () {
      const ex = RateLimitExceeded();
      expect(ex.toString(), 'RateLimitExceeded');
    });
  });

  group('RateLimitQueued', () {
    test('constructor with retryAfter', () {
      final ex = RateLimitQueued(Duration(seconds: 3));
      expect(ex.retryAfter, Duration(seconds: 3));
    });

    test('constructor without retryAfter', () {
      const ex = RateLimitQueued();
      expect(ex.retryAfter, isNull);
    });

    test('toString always returns same string', () {
      const ex = RateLimitQueued();
      expect(ex.toString(), 'RateLimitQueued');

      final exWithRetry = RateLimitQueued(Duration(seconds: 1));
      expect(exWithRetry.toString(), 'RateLimitQueued');
    });
  });

  group('Token bucket math', () {
    test('consume tokens until depleted', () async {
      // Use a policy with 3 tokens and no burst
      final policy = RateLimitPolicy(
        maxRequests: 3,
        window: Duration(seconds: 10),
        burstAllowance: 0,
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // First 3 should be allowed (acquire consumes tokens)
      for (var i = 0; i < 3; i++) {
        await limiter.acquire();
      }

      // 4th should be rejected (checkLimit verifies depletion)
      final result = await limiter.checkLimit();
      expect(result.allowed, isFalse);
      expect(result.retryAfter, isNotNull);
    });

    test('burst allowance provides extra tokens', () async {
      final policy = RateLimitPolicy(
        maxRequests: 2,
        window: Duration(seconds: 10),
        burstAllowance: 3,
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // 2 (max) + 3 (burst) = 5 tokens initially (acquire consumes tokens)
      for (var i = 0; i < 5; i++) {
        await limiter.acquire();
      }

      // 6th should be rejected
      final result = await limiter.checkLimit();
      expect(result.allowed, isFalse);
    });

    test('tokens refill after window passes', () async {
      // Use very short window for testing
      final policy = RateLimitPolicy(
        maxRequests: 2,
        window: Duration(milliseconds: 50),
        burstAllowance: 0,
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Consume all tokens via acquire
      for (var i = 0; i < 2; i++) {
        await limiter.acquire();
      }

      // Should be depleted
      var result = await limiter.checkLimit();
      expect(result.allowed, isFalse);

      // Wait for refill
      await Future<void>.delayed(Duration(milliseconds: 60));

      // Should be allowed again
      result = await limiter.checkLimit();
      expect(result.allowed, isTrue);
    });

    test('remaining tokens reported correctly', () async {
      final policy = RateLimitPolicy(
        maxRequests: 3,
        window: Duration(seconds: 10),
        burstAllowance: 0,
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // checkLimit peeks without consuming - always reports full tokens
      var result = await limiter.checkLimit();
      expect(result.allowed, isTrue);
      expect(result.remainingTokens, 3);

      // acquire consumes a token, then checkLimit reports updated count
      await limiter.acquire();
      result = await limiter.checkLimit();
      expect(result.allowed, isTrue);
      expect(result.remainingTokens, 2);

      await limiter.acquire();
      result = await limiter.checkLimit();
      expect(result.allowed, isTrue);
      expect(result.remainingTokens, 1);

      await limiter.acquire();
      result = await limiter.checkLimit();
      expect(result.allowed, isFalse);
      expect(result.remainingTokens, isNull);
    });

    test('checkLimit is idempotent (peek only)', () async {
      final policy = RateLimitPolicy(
        maxRequests: 2,
        window: Duration(seconds: 10),
        burstAllowance: 0,
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Multiple checkLimit calls should not consume tokens
      for (var i = 0; i < 10; i++) {
        final result = await limiter.checkLimit();
        expect(result.allowed, isTrue,
            reason: 'checkLimit should never consume tokens');
        expect(result.remainingTokens, 2);
      }
    });
  });

  group('RateLimiter', () {
    test('checkLimit global pass', () async {
      final policy = RateLimitPolicy(
        maxRequests: 10,
        window: Duration(seconds: 1),
      );
      final limiter = RateLimiter(policy);

      final result = await limiter.checkLimit();
      expect(result.allowed, isTrue);
    });

    test('checkLimit global after acquire depleted', () async {
      final policy = RateLimitPolicy(
        maxRequests: 1,
        window: Duration(seconds: 10),
      );
      final limiter = RateLimiter(policy);

      // Consume the single token via acquire
      await limiter.acquire();

      // checkLimit should report depleted
      final result = await limiter.checkLimit();
      expect(result.allowed, isFalse);
      expect(result.retryAfter, isNotNull);
    });

    test('checkLimit perConversation after acquire depleted', () async {
      final policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        perConversation: RateLimitPolicy(
          maxRequests: 1,
          window: Duration(seconds: 10),
        ),
      );
      final limiter = RateLimiter(policy);

      // Consume the per-conversation token via acquire
      await limiter.acquire(conversationKey: 'conv1');

      // checkLimit should report depleted for same conversation
      final result = await limiter.checkLimit(conversationKey: 'conv1');
      expect(result.allowed, isFalse);
    });

    test('checkLimit perUser after acquire depleted', () async {
      final policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        perUser: RateLimitPolicy(
          maxRequests: 1,
          window: Duration(seconds: 10),
        ),
      );
      final limiter = RateLimiter(policy);

      // Consume the per-user token via acquire
      await limiter.acquire(userId: 'user1');

      // checkLimit should report depleted for same user
      final result = await limiter.checkLimit(userId: 'user1');
      expect(result.allowed, isFalse);
    });

    test('checkLimit all pass', () async {
      final policy = RateLimitPolicy(
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
      );
      final limiter = RateLimiter(policy);

      final result = await limiter.checkLimit(
        conversationKey: 'conv1',
        userId: 'user1',
      );
      expect(result.allowed, isTrue);
    });

    test('checkLimit returns allowed when no perConversation/perUser policy',
        () async {
      final policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
      );
      final limiter = RateLimiter(policy);

      // Providing keys should not cause issues when policies are null
      final result = await limiter.checkLimit(
        conversationKey: 'conv1',
        userId: 'user1',
      );
      expect(result.allowed, isTrue);
    });

    test('acquire with delay action waits and retries', () async {
      final policy = RateLimitPolicy(
        maxRequests: 1,
        window: Duration(milliseconds: 50),
        action: RateLimitAction.delay,
      );
      final limiter = RateLimiter(policy);

      // Consume the token
      await limiter.acquire();

      // Next acquire should delay then succeed (after refill)
      // This should not throw
      await limiter.acquire();
    });

    test('acquire with reject action throws RateLimitExceeded', () async {
      final policy = RateLimitPolicy(
        maxRequests: 1,
        window: Duration(seconds: 10),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Consume the token
      await limiter.acquire();

      // Should throw
      expect(
        () => limiter.acquire(),
        throwsA(isA<RateLimitExceeded>()),
      );
    });

    test('acquire with queue action throws RateLimitQueued', () async {
      final policy = RateLimitPolicy(
        maxRequests: 1,
        window: Duration(seconds: 10),
        action: RateLimitAction.queue,
      );
      final limiter = RateLimiter(policy);

      // Consume the token
      await limiter.acquire();

      // Should throw
      expect(
        () => limiter.acquire(),
        throwsA(isA<RateLimitQueued>()),
      );
    });

    test('acquire with delay action when retryAfter is null', () async {
      // This tests the branch where result.retryAfter might be null.
      // In practice, the token bucket always returns retryAfter for limited
      // results, but we verify the delay path still works.
      final policy = RateLimitPolicy(
        maxRequests: 1,
        window: Duration(milliseconds: 50),
        action: RateLimitAction.delay,
      );
      final limiter = RateLimiter(policy);

      // Consume token
      await limiter.acquire();

      // The next acquire will encounter a limited result with retryAfter set
      // and will delay + retry. After the window passes it should succeed.
      await limiter.acquire();
    });

    test('reset clears all buckets', () async {
      final policy = RateLimitPolicy(
        maxRequests: 1,
        window: Duration(seconds: 10),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Consume the token
      await limiter.acquire();

      // Should fail
      final result = await limiter.checkLimit();
      expect(result.allowed, isFalse);

      // Reset
      limiter.reset();

      // Should be allowed again
      final result2 = await limiter.checkLimit();
      expect(result2.allowed, isTrue);
    });
  });
}
