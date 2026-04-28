import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformRateLimitFeedback', () {
    test('creates with default values', () {
      const feedback = PlatformRateLimitFeedback();
      expect(feedback.retryAfter, isNull);
      expect(feedback.remainingRequests, isNull);
      expect(feedback.resetAt, isNull);
      expect(feedback.limit, isNull);
      expect(feedback.bucketId, isNull);
    });

    test('creates with all values', () {
      final resetAt = DateTime.utc(2025, 1, 15, 10, 0);
      final feedback = PlatformRateLimitFeedback(
        retryAfter: const Duration(seconds: 30),
        remainingRequests: 5,
        resetAt: resetAt,
        limit: 100,
        bucketId: 'bucket_abc',
      );

      expect(feedback.retryAfter, const Duration(seconds: 30));
      expect(feedback.remainingRequests, 5);
      expect(feedback.resetAt, resetAt);
      expect(feedback.limit, 100);
      expect(feedback.bucketId, 'bucket_abc');
    });

    group('fromHeaders', () {
      test('parses X-RateLimit headers', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders({
          'X-RateLimit-Remaining': '42',
          'X-RateLimit-Limit': '100',
          'X-RateLimit-Reset': '1705312800',
          'X-RateLimit-Bucket': 'abc123',
        });

        expect(feedback.remainingRequests, 42);
        expect(feedback.limit, 100);
        expect(feedback.resetAt, isNotNull);
        expect(feedback.bucketId, 'abc123');
      });

      test('parses RateLimit headers (without X- prefix)', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders({
          'RateLimit-Remaining': '10',
          'RateLimit-Limit': '50',
          'RateLimit-Reset': '1705312800',
        });

        expect(feedback.remainingRequests, 10);
        expect(feedback.limit, 50);
      });

      test('parses Retry-After header', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders({
          'Retry-After': '60',
        });

        expect(feedback.retryAfter, const Duration(seconds: 60));
      });

      test('handles case-insensitive headers', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders({
          'x-ratelimit-remaining': '5',
          'retry-after': '10',
        });

        expect(feedback.remainingRequests, 5);
        expect(feedback.retryAfter, const Duration(seconds: 10));
      });

      test('handles missing headers', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders({});

        expect(feedback.remainingRequests, isNull);
        expect(feedback.limit, isNull);
        expect(feedback.resetAt, isNull);
        expect(feedback.retryAfter, isNull);
        expect(feedback.bucketId, isNull);
      });

      test('handles unparseable values', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders({
          'X-RateLimit-Remaining': 'not_a_number',
          'X-RateLimit-Limit': 'abc',
          'X-RateLimit-Reset': 'invalid',
          'Retry-After': 'nope',
        });

        expect(feedback.remainingRequests, isNull);
        expect(feedback.limit, isNull);
        expect(feedback.resetAt, isNull);
        expect(feedback.retryAfter, isNull);
      });

      test('X- prefix headers take priority over non-prefixed', () {
        final feedback = PlatformRateLimitFeedback.fromHeaders({
          'X-RateLimit-Remaining': '5',
          'RateLimit-Remaining': '10',
        });

        // Both exist, but X- prefix checked first via ??
        expect(feedback.remainingRequests, 5);
      });
    });

    group('isLimited', () {
      test('returns true when remaining is 0', () {
        const feedback = PlatformRateLimitFeedback(remainingRequests: 0);
        expect(feedback.isLimited, true);
      });

      test('returns false when remaining is positive', () {
        const feedback = PlatformRateLimitFeedback(remainingRequests: 5);
        expect(feedback.isLimited, false);
      });

      test('returns false when remaining is null', () {
        const feedback = PlatformRateLimitFeedback();
        expect(feedback.isLimited, false);
      });
    });

    group('durationUntilReset', () {
      test('returns duration when resetAt is in the future', () {
        final futureReset = DateTime.now().add(const Duration(minutes: 5));
        final feedback = PlatformRateLimitFeedback(resetAt: futureReset);
        final duration = feedback.durationUntilReset();
        expect(duration, isNotNull);
        expect(duration!.inSeconds, greaterThan(0));
      });

      test('returns null when resetAt is in the past', () {
        final pastReset = DateTime.now().subtract(const Duration(minutes: 5));
        final feedback = PlatformRateLimitFeedback(resetAt: pastReset);
        expect(feedback.durationUntilReset(), isNull);
      });

      test('returns null when resetAt is null', () {
        const feedback = PlatformRateLimitFeedback();
        expect(feedback.durationUntilReset(), isNull);
      });

      test('accepts custom now parameter', () {
        final resetAt = DateTime.utc(2025, 1, 15, 11, 0);
        final customNow = DateTime.utc(2025, 1, 15, 10, 0);
        final feedback = PlatformRateLimitFeedback(resetAt: resetAt);
        final duration = feedback.durationUntilReset(now: customNow);
        expect(duration, const Duration(hours: 1));
      });
    });

    test('copyWith creates modified copy', () {
      const original = PlatformRateLimitFeedback(
        remainingRequests: 10,
        limit: 100,
      );
      final copy = original.copyWith(remainingRequests: 5);
      expect(copy.remainingRequests, 5);
      expect(copy.limit, 100);
    });

    group('equality', () {
      test('equal instances', () {
        const a = PlatformRateLimitFeedback(
          remainingRequests: 10,
          limit: 100,
        );
        const b = PlatformRateLimitFeedback(
          remainingRequests: 10,
          limit: 100,
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different instances', () {
        const a = PlatformRateLimitFeedback(remainingRequests: 10);
        const b = PlatformRateLimitFeedback(remainingRequests: 20);
        expect(a, isNot(equals(b)));
      });
    });

    test('toString contains relevant info', () {
      const feedback = PlatformRateLimitFeedback(
        remainingRequests: 10,
        limit: 100,
      );
      final str = feedback.toString();
      expect(str, contains('10'));
      expect(str, contains('100'));
    });
  });
}
