import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ExponentialBackoff', () {
    test('constructor with defaults', () {
      const backoff = ExponentialBackoff();
      expect(backoff.initialDelay, Duration(milliseconds: 500));
      expect(backoff.maxDelay, Duration(seconds: 30));
      expect(backoff.multiplier, 2.0);
    });

    test('getDelay attempt 0', () {
      const backoff = ExponentialBackoff(
        initialDelay: Duration(milliseconds: 100),
        multiplier: 2.0,
        maxDelay: Duration(seconds: 60),
      );
      // 100 * 2^0 = 100ms
      expect(backoff.getDelay(0), Duration(milliseconds: 100));
    });

    test('getDelay attempt 1', () {
      const backoff = ExponentialBackoff(
        initialDelay: Duration(milliseconds: 100),
        multiplier: 2.0,
        maxDelay: Duration(seconds: 60),
      );
      // 100 * 2^1 = 200ms
      expect(backoff.getDelay(1), Duration(milliseconds: 200));
    });

    test('getDelay attempt 2', () {
      const backoff = ExponentialBackoff(
        initialDelay: Duration(milliseconds: 100),
        multiplier: 2.0,
        maxDelay: Duration(seconds: 60),
      );
      // 100 * 2^2 = 400ms
      expect(backoff.getDelay(2), Duration(milliseconds: 400));
    });

    test('getDelay capped at maxDelay', () {
      const backoff = ExponentialBackoff(
        initialDelay: Duration(milliseconds: 1000),
        multiplier: 10.0,
        maxDelay: Duration(milliseconds: 5000),
      );
      // 1000 * 10^2 = 100000, capped at 5000
      expect(backoff.getDelay(2), Duration(milliseconds: 5000));
    });
  });

  group('LinearBackoff', () {
    test('constructor with defaults', () {
      const backoff = LinearBackoff();
      expect(backoff.initialDelay, Duration(seconds: 1));
      expect(backoff.increment, Duration(seconds: 1));
      expect(backoff.maxDelay, Duration(seconds: 30));
    });

    test('getDelay attempt 0', () {
      const backoff = LinearBackoff(
        initialDelay: Duration(milliseconds: 100),
        increment: Duration(milliseconds: 50),
        maxDelay: Duration(seconds: 60),
      );
      // 100 + 50*0 = 100ms
      expect(backoff.getDelay(0), Duration(milliseconds: 100));
    });

    test('getDelay attempt 1', () {
      const backoff = LinearBackoff(
        initialDelay: Duration(milliseconds: 100),
        increment: Duration(milliseconds: 50),
        maxDelay: Duration(seconds: 60),
      );
      // 100 + 50*1 = 150ms
      expect(backoff.getDelay(1), Duration(milliseconds: 150));
    });

    test('getDelay attempt 2', () {
      const backoff = LinearBackoff(
        initialDelay: Duration(milliseconds: 100),
        increment: Duration(milliseconds: 50),
        maxDelay: Duration(seconds: 60),
      );
      // 100 + 50*2 = 200ms
      expect(backoff.getDelay(2), Duration(milliseconds: 200));
    });

    test('getDelay capped at maxDelay', () {
      const backoff = LinearBackoff(
        initialDelay: Duration(milliseconds: 100),
        increment: Duration(milliseconds: 1000),
        maxDelay: Duration(milliseconds: 500),
      );
      // 100 + 1000*1 = 1100, capped at 500
      expect(backoff.getDelay(1), Duration(milliseconds: 500));
    });
  });

  group('FixedBackoff', () {
    test('constructor with default', () {
      const backoff = FixedBackoff();
      expect(backoff.delay, Duration(seconds: 1));
    });

    test('constructor with custom delay', () {
      const backoff = FixedBackoff(delay: Duration(milliseconds: 250));
      expect(backoff.delay, Duration(milliseconds: 250));
    });

    test('getDelay always returns same value', () {
      const backoff = FixedBackoff(delay: Duration(milliseconds: 200));
      expect(backoff.getDelay(0), Duration(milliseconds: 200));
      expect(backoff.getDelay(1), Duration(milliseconds: 200));
      expect(backoff.getDelay(5), Duration(milliseconds: 200));
      expect(backoff.getDelay(100), Duration(milliseconds: 200));
    });
  });

  group('RetryPolicy', () {
    test('constructor with defaults', () {
      const policy = RetryPolicy();
      expect(policy.maxAttempts, 3);
      expect(policy.backoff, isA<ExponentialBackoff>());
      expect(
        policy.retryableErrors,
        equals({'rate_limited', 'network_error', 'timeout', 'server_error'}),
      );
      expect(policy.maxDuration, isNull);
      expect(policy.jitter, 0.1);
    });

    test('none factory', () {
      final policy = RetryPolicy.none();
      expect(policy.maxAttempts, 0);
    });

    test('aggressive factory', () {
      final policy = RetryPolicy.aggressive();
      expect(policy.maxAttempts, 5);
      expect(policy.jitter, 0.2);
      final backoff = policy.backoff as ExponentialBackoff;
      expect(backoff.initialDelay, Duration(milliseconds: 100));
      expect(backoff.maxDelay, Duration(seconds: 30));
      expect(backoff.multiplier, 2.0);
    });

    test('copyWith all fields', () {
      const original = RetryPolicy();
      const newBackoff = FixedBackoff(delay: Duration(milliseconds: 100));

      final copied = original.copyWith(
        maxAttempts: 10,
        backoff: newBackoff,
        retryableErrors: {'custom_error'},
        maxDuration: Duration(minutes: 5),
        jitter: 0.5,
      );

      expect(copied.maxAttempts, 10);
      expect(copied.backoff, newBackoff);
      expect(copied.retryableErrors, equals({'custom_error'}));
      expect(copied.maxDuration, Duration(minutes: 5));
      expect(copied.jitter, 0.5);
    });

    test('copyWith no arguments returns equivalent', () {
      const original = RetryPolicy();
      final copied = original.copyWith();

      expect(copied.maxAttempts, original.maxAttempts);
      expect(copied.jitter, original.jitter);
      expect(copied.retryableErrors, original.retryableErrors);
      expect(copied.maxDuration, original.maxDuration);
    });
  });

  group('Retrier', () {
    test('success on first try', () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 3,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
      ));

      var callCount = 0;
      final result = await retrier.execute(() async {
        callCount++;
        return 'success';
      });

      expect(result, 'success');
      expect(callCount, 1);
    });

    test('fail then succeed on retry', () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 3,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
      ));

      var callCount = 0;
      final result = await retrier.execute(
        () async {
          callCount++;
          if (callCount < 3) {
            throw const ChannelError(
              code: 'network_error',
              message: 'fail',
              retryable: true,
            );
          }
          return 'success';
        },
      );

      expect(result, 'success');
      expect(callCount, 3);
    });

    test('exhaust all attempts and rethrow last error', () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 2,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
      ));

      var callCount = 0;
      try {
        await retrier.execute(() async {
          callCount++;
          throw ChannelError(
            code: 'network_error',
            message: 'fail attempt $callCount',
            retryable: true,
          );
        });
        fail('Should have thrown');
      } on ChannelError catch (e) {
        // maxAttempts=2 means 1 initial + 1 retry = 2 total calls
        // attempt increments to 2 which equals maxAttempts, so it rethrows
        expect(callCount, 2);
        expect(e.message, contains('fail attempt'));
      }
    });

    test('custom shouldRetry callback', () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 5,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
      ));

      var callCount = 0;
      final result = await retrier.execute(
        () async {
          callCount++;
          if (callCount < 3) {
            throw StateError('custom error');
          }
          return 'done';
        },
        shouldRetry: (error) => error is StateError,
      );

      expect(result, 'done');
      expect(callCount, 3);
    });

    test('custom shouldRetry returns false stops retrying', () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 5,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
      ));

      var callCount = 0;
      expect(
        () => retrier.execute(
          () async {
            callCount++;
            throw StateError('stop');
          },
          shouldRetry: (error) => false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('maxDuration exceeded stops retrying', () async {
      final retrier = Retrier(RetryPolicy(
        maxAttempts: 100,
        backoff: const FixedBackoff(delay: Duration(milliseconds: 20)),
        jitter: 0,
        maxDuration: Duration(milliseconds: 50),
      ));

      var callCount = 0;
      try {
        await retrier.execute(() async {
          callCount++;
          throw const ChannelError(
            code: 'network_error',
            message: 'fail',
            retryable: true,
          );
        });
        fail('Should have thrown');
      } on ChannelError {
        // Should have stopped before 100 attempts due to maxDuration
        expect(callCount, lessThan(100));
      }
    });

    test('jitter applied - delay varies', () async {
      // With jitter > 0, the delay should have randomness.
      // We verify it runs without error and completes.
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 3,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0.5,
      ));

      var callCount = 0;
      final result = await retrier.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw const ChannelError(
            code: 'network_error',
            message: 'fail',
            retryable: true,
          );
        }
        return 'ok';
      });

      expect(result, 'ok');
      expect(callCount, 2);
    });

    test('jitter = 0 means exact delays', () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 3,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
      ));

      var callCount = 0;
      final stopwatch = Stopwatch()..start();
      final result = await retrier.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw const ChannelError(
            code: 'network_error',
            message: 'fail',
            retryable: true,
          );
        }
        return 'ok';
      });
      stopwatch.stop();

      expect(result, 'ok');
      expect(callCount, 2);
      // With jitter=0, delay should be ~10ms (not wildly different)
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(5));
    });

    test('ChannelError with retryable=true is retried', () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 3,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
        retryableErrors: {},
      ));

      var callCount = 0;
      final result = await retrier.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw const ChannelError(
            code: 'custom_code',
            message: 'fail',
            retryable: true,
          );
        }
        return 'ok';
      });

      expect(result, 'ok');
      expect(callCount, 2);
    });

    test('ChannelError with code in retryableErrors is retried', () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 3,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
        retryableErrors: {'my_error'},
      ));

      var callCount = 0;
      final result = await retrier.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw const ChannelError(
            code: 'my_error',
            message: 'fail',
            retryable: false,
          );
        }
        return 'ok';
      });

      expect(result, 'ok');
      expect(callCount, 2);
    });

    test('ChannelError not retryable and code not in retryableErrors is not retried',
        () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 5,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
        retryableErrors: {'other_error'},
      ));

      var callCount = 0;
      try {
        await retrier.execute(() async {
          callCount++;
          throw const ChannelError(
            code: 'not_found',
            message: 'fail',
            retryable: false,
          );
        });
        fail('Should have thrown');
      } on ChannelError {
        expect(callCount, 1);
      }
    });

    test('non-ChannelError without custom shouldRetry is not retried',
        () async {
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 5,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: 0,
      ));

      var callCount = 0;
      try {
        await retrier.execute(() async {
          callCount++;
          throw FormatException('bad format');
        });
        fail('Should have thrown');
      } on FormatException {
        expect(callCount, 1);
      }
    });

    test('negative jitter treated as no jitter', () async {
      // jitter <= 0 returns delay as-is
      final retrier = Retrier(const RetryPolicy(
        maxAttempts: 3,
        backoff: FixedBackoff(delay: Duration(milliseconds: 10)),
        jitter: -0.5,
      ));

      var callCount = 0;
      final result = await retrier.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw const ChannelError(
            code: 'network_error',
            message: 'fail',
            retryable: true,
          );
        }
        return 'ok';
      });

      expect(result, 'ok');
      expect(callCount, 2);
    });
  });
}
