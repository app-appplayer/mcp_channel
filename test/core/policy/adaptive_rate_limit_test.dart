import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformRateLimitFeedback', () {
    group('fromHeaders', () {
      // TC-141-01: Parse X-RateLimit-Remaining and X-RateLimit-Limit
      test('parses X-RateLimit-Remaining and X-RateLimit-Limit', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'X-RateLimit-Remaining': '42',
          'X-RateLimit-Limit': '100',
        });

        expect(feedback.remainingRequests, 42);
        expect(feedback.limit, 100);
        expect(feedback.resetAt, isNull);
        expect(feedback.retryAfter, isNull);
      });

      // TC-141-02: Parse X-RateLimit-Reset as Unix epoch seconds
      test('parses X-RateLimit-Reset as Unix epoch seconds', () {
        const epochSeconds = 1700000000;
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'X-RateLimit-Reset': '$epochSeconds',
        });

        expect(feedback.resetAt, isNotNull);
        expect(
          feedback.resetAt,
          DateTime.fromMillisecondsSinceEpoch(
            epochSeconds * 1000,
            isUtc: true,
          ),
        );
      });

      // TC-141-03: Parse Retry-After in seconds
      test('parses Retry-After header in seconds', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'Retry-After': '30',
        });

        expect(feedback.retryAfter, const Duration(seconds: 30));
        expect(feedback.remainingRequests, isNull);
        expect(feedback.limit, isNull);
        expect(feedback.resetAt, isNull);
      });

      // TC-141-04: Case-insensitive header matching
      test('handles case-insensitive headers', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'x-ratelimit-remaining': '5',
          'X-RATELIMIT-LIMIT': '50',
          'x-RateLimit-Reset': '1700000000',
          'RETRY-AFTER': '10',
        });

        expect(feedback.remainingRequests, 5);
        expect(feedback.limit, 50);
        expect(feedback.resetAt, isNotNull);
        expect(feedback.retryAfter, const Duration(seconds: 10));
      });

      // TC-141-05: Standard headers without X- prefix
      test('parses standard headers without X- prefix', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'RateLimit-Remaining': '10',
          'RateLimit-Limit': '200',
          'RateLimit-Reset': '1700000000',
        });

        expect(feedback.remainingRequests, 10);
        expect(feedback.limit, 200);
        expect(feedback.resetAt, isNotNull);
        expect(
          feedback.resetAt,
          DateTime.fromMillisecondsSinceEpoch(
            1700000000 * 1000,
            isUtc: true,
          ),
        );
      });

      // TC-141-06: X- prefixed headers take precedence over non-X- prefixed
      test('X- prefixed headers take precedence', () {
        // When both are present, fromHeaders checks x-ratelimit-* first
        // via the ?? operator, so x-ratelimit-remaining is preferred
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'X-RateLimit-Remaining': '3',
          'RateLimit-Remaining': '10',
          'X-RateLimit-Limit': '50',
          'RateLimit-Limit': '200',
        });

        expect(feedback.remainingRequests, 3);
        expect(feedback.limit, 50);
      });

      // TC-141-07: Empty/invalid values return nulls
      test('returns nulls for empty header values', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'X-RateLimit-Remaining': '',
          'X-RateLimit-Limit': '',
          'X-RateLimit-Reset': '',
          'Retry-After': '',
        });

        expect(feedback.remainingRequests, isNull);
        expect(feedback.limit, isNull);
        expect(feedback.resetAt, isNull);
        expect(feedback.retryAfter, isNull);
      });

      test('returns nulls for non-numeric header values', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'X-RateLimit-Remaining': 'abc',
          'X-RateLimit-Limit': 'not-a-number',
          'X-RateLimit-Reset': 'invalid',
          'Retry-After': 'soon',
        });

        expect(feedback.remainingRequests, isNull);
        expect(feedback.limit, isNull);
        expect(feedback.resetAt, isNull);
        expect(feedback.retryAfter, isNull);
      });

      test('returns all nulls for empty headers map', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {});

        expect(feedback.remainingRequests, isNull);
        expect(feedback.limit, isNull);
        expect(feedback.resetAt, isNull);
        expect(feedback.retryAfter, isNull);
      });

      test('parses all headers together', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'X-RateLimit-Remaining': '0',
          'X-RateLimit-Limit': '100',
          'X-RateLimit-Reset': '1700000000',
          'Retry-After': '60',
          'X-RateLimit-Bucket': 'bucket-abc',
        });

        expect(feedback.remainingRequests, 0);
        expect(feedback.limit, 100);
        expect(feedback.resetAt, isNotNull);
        expect(feedback.retryAfter, const Duration(seconds: 60));
        expect(feedback.bucketId, 'bucket-abc');
      });

      test('parses X-RateLimit-Bucket header', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'X-RateLimit-Bucket': 'discord-bucket-123',
        });

        expect(feedback.bucketId, 'discord-bucket-123');
      });

      test('bucketId is null when header not present', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders(const {
          'X-RateLimit-Remaining': '10',
        });

        expect(feedback.bucketId, isNull);
      });
    });

    group('isLimited', () {
      // TC-141-08: isLimited when remaining is 0
      test('returns true when remaining is 0', () {
        const feedback = PlatformRateLimitFeedback(remainingRequests: 0, limit: 100);
        expect(feedback.isLimited, isTrue);
      });

      // TC-141-09: isLimited when remaining is negative
      test('returns true when remaining is negative', () {
        const feedback = PlatformRateLimitFeedback(remainingRequests: -1, limit: 100);
        expect(feedback.isLimited, isTrue);
      });

      // TC-141-10: isLimited when remaining is null
      test('returns false when remaining is null', () {
        const feedback = PlatformRateLimitFeedback(limit: 100);
        expect(feedback.isLimited, isFalse);
      });

      // TC-141-11: isLimited when remaining > 0
      test('returns false when remaining is greater than 0', () {
        const feedback = PlatformRateLimitFeedback(remainingRequests: 5, limit: 100);
        expect(feedback.isLimited, isFalse);
      });

      test('returns false when remaining is 1', () {
        const feedback = PlatformRateLimitFeedback(remainingRequests: 1, limit: 100);
        expect(feedback.isLimited, isFalse);
      });
    });

    group('durationUntilReset', () {
      // TC-141-12: durationUntilReset with future resetAt
      test('returns positive duration when resetAt is in the future', () {
        final futureTime = DateTime.now().add(const Duration(minutes: 5));
        final feedback = PlatformRateLimitFeedback(
          remainingRequests: 0,
          limit: 100,
          resetAt: futureTime,
        );

        final duration = feedback.durationUntilReset();

        expect(duration, isNotNull);
        expect(duration!.isNegative, isFalse);
        // Should be close to 5 minutes (allow some margin for test execution)
        expect(duration.inSeconds, greaterThan(290));
        expect(duration.inSeconds, lessThanOrEqualTo(300));
      });

      test('returns exact duration using explicit now parameter', () {
        final now = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final resetAt = DateTime.utc(2024, 1, 1, 12, 5, 0);
        final feedback = PlatformRateLimitFeedback(
          remainingRequests: 0,
          limit: 100,
          resetAt: resetAt,
        );

        final duration = feedback.durationUntilReset(now: now);

        expect(duration, isNotNull);
        expect(duration, const Duration(minutes: 5));
      });

      // TC-141-13: durationUntilReset with past resetAt
      test('returns null when resetAt is in the past', () {
        final pastTime = DateTime.now().subtract(const Duration(minutes: 5));
        final feedback = PlatformRateLimitFeedback(
          remainingRequests: 0,
          limit: 100,
          resetAt: pastTime,
        );

        final duration = feedback.durationUntilReset();

        expect(duration, isNull);
      });

      test('returns Duration.zero when resetAt equals now', () {
        final now = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final feedback = PlatformRateLimitFeedback(
          remainingRequests: 0,
          limit: 100,
          resetAt: now,
        );

        // difference is zero, which is not negative, so it should return
        // Duration.zero (not null)
        final duration = feedback.durationUntilReset(now: now);

        expect(duration, isNotNull);
        expect(duration, Duration.zero);
      });

      // TC-141-14: durationUntilReset with null resetAt
      test('returns null when resetAt is null', () {
        const feedback = PlatformRateLimitFeedback(remainingRequests: 0, limit: 100);

        final duration = feedback.durationUntilReset();

        expect(duration, isNull);
      });
    });

    group('copyWith', () {
      // TC-141-15: copyWith creates modified copy
      test('creates copy with updated fields', () {
        const original = PlatformRateLimitFeedback(
          remainingRequests: 10,
          limit: 100,
        );

        final resetTime = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final copied = original.copyWith(
          remainingRequests: 5,
          resetAt: resetTime,
          retryAfter: const Duration(seconds: 30),
        );

        expect(copied.remainingRequests, 5);
        expect(copied.limit, 100); // unchanged
        expect(copied.resetAt, resetTime);
        expect(copied.retryAfter, const Duration(seconds: 30));
      });

      test('returns equivalent when no arguments provided', () {
        final resetTime = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final original = PlatformRateLimitFeedback(
          remainingRequests: 10,
          limit: 100,
          resetAt: resetTime,
          retryAfter: const Duration(seconds: 5),
        );

        final copied = original.copyWith();

        expect(copied, original);
      });
    });

    group('equality and hashCode', () {
      // TC-141-16: Equality
      test('equal instances are equal', () {
        final resetTime = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final a = PlatformRateLimitFeedback(
          remainingRequests: 10,
          limit: 100,
          resetAt: resetTime,
          retryAfter: const Duration(seconds: 5),
        );
        final b = PlatformRateLimitFeedback(
          remainingRequests: 10,
          limit: 100,
          resetAt: resetTime,
          retryAfter: const Duration(seconds: 5),
        );

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('different instances are not equal', () {
        const a = PlatformRateLimitFeedback(remainingRequests: 10, limit: 100);
        const b = PlatformRateLimitFeedback(remainingRequests: 5, limit: 100);

        expect(a, isNot(b));
      });

      test('null fields are considered in equality', () {
        const a = PlatformRateLimitFeedback(remainingRequests: 10);
        const b = PlatformRateLimitFeedback(remainingRequests: 10, limit: 100);

        expect(a, isNot(b));
      });

      test('identity equality', () {
        const feedback = PlatformRateLimitFeedback(remainingRequests: 10, limit: 100);
        expect(feedback == feedback, isTrue);
      });
    });

    group('toString', () {
      // TC-141-17: toString
      test('produces readable output', () {
        const feedback = PlatformRateLimitFeedback(
          remainingRequests: 10,
          limit: 100,
        );

        final str = feedback.toString();
        expect(str, contains('PlatformRateLimitFeedback'));
        expect(str, contains('remainingRequests: 10'));
        expect(str, contains('limit: 100'));
        expect(str, contains('resetAt: null'));
        expect(str, contains('retryAfter: null'));
        expect(str, contains('bucketId: null'));
      });

      test('includes all non-null fields', () {
        final resetTime = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final feedback = PlatformRateLimitFeedback(
          remainingRequests: 0,
          limit: 50,
          resetAt: resetTime,
          retryAfter: const Duration(seconds: 30),
        );

        final str = feedback.toString();
        expect(str, contains('remainingRequests: 0'));
        expect(str, contains('limit: 50'));
        expect(str, contains(resetTime.toString()));
        expect(str, contains('0:00:30'));
      });
    });

    group('constructor', () {
      test('all fields null by default', () {
        const feedback = PlatformRateLimitFeedback();

        expect(feedback.remainingRequests, isNull);
        expect(feedback.limit, isNull);
        expect(feedback.resetAt, isNull);
        expect(feedback.retryAfter, isNull);
        expect(feedback.bucketId, isNull);
      });

      test('sets all fields', () {
        final resetTime = DateTime.utc(2024, 6, 15, 10, 30, 0);
        final feedback = PlatformRateLimitFeedback(
          remainingRequests: 42,
          limit: 200,
          resetAt: resetTime,
          retryAfter: const Duration(seconds: 120),
          bucketId: 'test-bucket',
        );

        expect(feedback.remainingRequests, 42);
        expect(feedback.limit, 200);
        expect(feedback.resetAt, resetTime);
        expect(feedback.retryAfter, const Duration(seconds: 120));
        expect(feedback.bucketId, 'test-bucket');
      });
    });
  });

  group('RateLimiter adaptive rate limiting', () {
    // TC-142-01: updateFromResponse with retryAfter pauses rate limiter
    test('updateFromResponse with retryAfter pauses rate limiter', () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Verify requests are allowed before update
      final beforeResult = await limiter.checkLimit();
      expect(beforeResult.allowed, isTrue);

      // Simulate platform returning Retry-After
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          retryAfter: Duration(seconds: 5),
        ),
      );

      // Requests should now be blocked
      final afterResult = await limiter.checkLimit();
      expect(afterResult.allowed, isFalse);
      expect(afterResult.retryAfter, isNotNull);
      // The retryAfter in the result should be close to 5 seconds
      expect(afterResult.retryAfter!.inSeconds, greaterThanOrEqualTo(4));
      expect(afterResult.retryAfter!.inSeconds, lessThanOrEqualTo(5));
    });

    // TC-142-02: After pause expires, requests are allowed again
    test('after pause expires requests are allowed again', () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Pause for a very short duration
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          retryAfter: Duration(milliseconds: 50),
        ),
      );

      // Should be blocked immediately
      final blockedResult = await limiter.checkLimit();
      expect(blockedResult.allowed, isFalse);

      // Wait for the pause to expire
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Should be allowed again
      final allowedResult = await limiter.checkLimit();
      expect(allowedResult.allowed, isTrue);
    });

    // TC-142-03: updateFromResponse with resetAt and isLimited pauses until
    //            resetAt
    test('updateFromResponse with resetAt and isLimited pauses until resetAt',
        () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Simulate platform indicating rate limited with a reset time
      final resetAt = DateTime.now().add(const Duration(seconds: 5));
      limiter.updateFromResponse(
        PlatformRateLimitFeedback(
          remainingRequests: 0,
          limit: 100,
          resetAt: resetAt,
        ),
      );

      // Should be blocked
      final result = await limiter.checkLimit();
      expect(result.allowed, isFalse);
      expect(result.retryAfter, isNotNull);
      expect(result.retryAfter!.inSeconds, greaterThanOrEqualTo(4));
    });

    test(
        'updateFromResponse with resetAt but not isLimited does not pause',
        () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // remaining > 0 means isLimited is false, so no pause should occur
      final resetAt = DateTime.now().add(const Duration(seconds: 5));
      limiter.updateFromResponse(
        PlatformRateLimitFeedback(
          remainingRequests: 10,
          limit: 100,
          resetAt: resetAt,
        ),
      );

      // Should still be allowed (no pause applied)
      final result = await limiter.checkLimit();
      expect(result.allowed, isTrue);
    });

    test('retryAfter takes precedence over resetAt when both present',
        () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // When retryAfter is present, it should be used regardless of resetAt
      final resetAt = DateTime.now().add(const Duration(seconds: 10));
      limiter.updateFromResponse(
        PlatformRateLimitFeedback(
          remainingRequests: 0,
          limit: 100,
          resetAt: resetAt,
          retryAfter: const Duration(seconds: 2),
        ),
      );

      final result = await limiter.checkLimit();
      expect(result.allowed, isFalse);
      // The retryAfter should be close to 2 seconds (not 10 from resetAt)
      expect(result.retryAfter!.inSeconds, lessThanOrEqualTo(2));
    });

    test('updateFromResponse with no retryAfter and no limit does nothing',
        () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Feedback with no actionable data
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          remainingRequests: 50,
          limit: 100,
        ),
      );

      // Should still be allowed
      final result = await limiter.checkLimit();
      expect(result.allowed, isTrue);
    });

    // TC-142-04: reset() clears pause state
    test('reset clears pause state from updateFromResponse', () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Pause the limiter
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          retryAfter: Duration(seconds: 60),
        ),
      );

      // Verify it is paused
      final pausedResult = await limiter.checkLimit();
      expect(pausedResult.allowed, isFalse);

      // Reset should clear the pause
      limiter.reset();

      // Should be allowed again immediately
      final afterResetResult = await limiter.checkLimit();
      expect(afterResetResult.allowed, isTrue);
    });

    test('reset clears both pause state and token buckets', () async {
      const policy = RateLimitPolicy(
        maxRequests: 1,
        window: Duration(seconds: 10),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Consume the single token
      await limiter.checkLimit();

      // Also pause via platform feedback
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          retryAfter: Duration(seconds: 60),
        ),
      );

      // Should be blocked (both by pause and depleted bucket)
      final blockedResult = await limiter.checkLimit();
      expect(blockedResult.allowed, isFalse);

      // Reset everything
      limiter.reset();

      // Should be fully allowed again (pause cleared + bucket refilled)
      final afterResetResult = await limiter.checkLimit();
      expect(afterResetResult.allowed, isTrue);
    });

    test('multiple updateFromResponse calls update pause time', () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // First pause: short
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          retryAfter: Duration(milliseconds: 50),
        ),
      );

      // Update with longer pause
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          retryAfter: Duration(seconds: 5),
        ),
      );

      // Wait past the first pause time
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Should still be blocked (second, longer pause is active)
      final result = await limiter.checkLimit();
      expect(result.allowed, isFalse);
    });

    test('pause does not affect per-conversation or per-user buckets logic',
        () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        perConversation: RateLimitPolicy(
          maxRequests: 100,
          window: Duration(seconds: 1),
        ),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Pause globally
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          retryAfter: Duration(seconds: 5),
        ),
      );

      // Even with conversation key, global pause applies first
      final result = await limiter.checkLimit(conversationKey: 'conv1');
      expect(result.allowed, isFalse);
    });

    test('expired pause is cleaned up on next checkLimit', () async {
      const policy = RateLimitPolicy(
        maxRequests: 100,
        window: Duration(seconds: 1),
        action: RateLimitAction.reject,
      );
      final limiter = RateLimiter(policy);

      // Set a very short pause
      limiter.updateFromResponse(
        const PlatformRateLimitFeedback(
          retryAfter: Duration(milliseconds: 10),
        ),
      );

      // Wait for it to expire
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // First check after expiry should pass and clean up the pause
      final result1 = await limiter.checkLimit();
      expect(result1.allowed, isTrue);

      // Subsequent checks should also pass (pause entry removed)
      final result2 = await limiter.checkLimit();
      expect(result2.allowed, isTrue);
    });
  });
}
