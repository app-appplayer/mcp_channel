import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('TimeoutPolicy', () {
    test('constructor with defaults', () {
      const policy = TimeoutPolicy();

      expect(policy.connectionTimeout, Duration(seconds: 10));
      expect(policy.requestTimeout, Duration(seconds: 30));
      expect(policy.operationTimeout, Duration(minutes: 2));
      expect(policy.idleTimeout, Duration(minutes: 5));
    });

    test('constructor with custom values', () {
      const policy = TimeoutPolicy(
        connectionTimeout: Duration(seconds: 5),
        requestTimeout: Duration(seconds: 15),
        operationTimeout: Duration(minutes: 1),
        idleTimeout: Duration(minutes: 10),
      );

      expect(policy.connectionTimeout, Duration(seconds: 5));
      expect(policy.requestTimeout, Duration(seconds: 15));
      expect(policy.operationTimeout, Duration(minutes: 1));
      expect(policy.idleTimeout, Duration(minutes: 10));
    });

    test('copyWith all fields', () {
      const original = TimeoutPolicy();

      final copied = original.copyWith(
        connectionTimeout: Duration(seconds: 1),
        requestTimeout: Duration(seconds: 2),
        operationTimeout: Duration(seconds: 3),
        idleTimeout: Duration(seconds: 4),
      );

      expect(copied.connectionTimeout, Duration(seconds: 1));
      expect(copied.requestTimeout, Duration(seconds: 2));
      expect(copied.operationTimeout, Duration(seconds: 3));
      expect(copied.idleTimeout, Duration(seconds: 4));
    });

    test('copyWith no arguments returns equivalent', () {
      const original = TimeoutPolicy();
      final copied = original.copyWith();

      expect(copied.connectionTimeout, original.connectionTimeout);
      expect(copied.requestTimeout, original.requestTimeout);
      expect(copied.operationTimeout, original.operationTimeout);
      expect(copied.idleTimeout, original.idleTimeout);
    });
  });

  group('OperationTimeoutException', () {
    test('constructor', () {
      const ex = OperationTimeoutException(
        'test_op',
        Duration(seconds: 5),
      );

      expect(ex.operation, 'test_op');
      expect(ex.timeout, Duration(seconds: 5));
    });

    test('toString', () {
      const ex = OperationTimeoutException(
        'request',
        Duration(milliseconds: 3000),
      );

      expect(
        ex.toString(),
        'OperationTimeoutException: request timed out after 3000ms',
      );
    });
  });

  group('TimeoutExecutor', () {
    group('withRequestTimeout', () {
      test('success - completes within timeout', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy(
          requestTimeout: Duration(seconds: 5),
        ));

        final result =
            await executor.withRequestTimeout(() async => 'done');
        expect(result, 'done');
      });

      test('timeout - throws OperationTimeoutException', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy(
          requestTimeout: Duration(milliseconds: 50),
        ));

        expect(
          () => executor.withRequestTimeout(
            () => Future.delayed(Duration(seconds: 10), () => 'late'),
          ),
          throwsA(
            isA<OperationTimeoutException>()
                .having((e) => e.operation, 'operation', 'request'),
          ),
        );
      });
    });

    group('withOperationTimeout', () {
      test('success - completes within timeout', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ));

        final result =
            await executor.withOperationTimeout(() async => 42);
        expect(result, 42);
      });

      test('timeout - throws OperationTimeoutException', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy(
          operationTimeout: Duration(milliseconds: 50),
        ));

        expect(
          () => executor.withOperationTimeout(
            () => Future.delayed(Duration(seconds: 10), () => 42),
          ),
          throwsA(
            isA<OperationTimeoutException>()
                .having((e) => e.operation, 'operation', 'operation'),
          ),
        );
      });
    });

    group('withConnectionTimeout', () {
      test('success - completes within timeout', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy(
          connectionTimeout: Duration(seconds: 5),
        ));

        final result =
            await executor.withConnectionTimeout(() async => true);
        expect(result, isTrue);
      });

      test('timeout - throws OperationTimeoutException', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy(
          connectionTimeout: Duration(milliseconds: 50),
        ));

        expect(
          () => executor.withConnectionTimeout(
            () => Future.delayed(Duration(seconds: 10), () => true),
          ),
          throwsA(
            isA<OperationTimeoutException>()
                .having((e) => e.operation, 'operation', 'connection'),
          ),
        );
      });
    });

    group('withTimeout (custom duration + name)', () {
      test('success - completes within timeout', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy());

        final result = await executor.withTimeout(
          () async => 'custom',
          Duration(seconds: 5),
          name: 'custom_op',
        );
        expect(result, 'custom');
      });

      test('success - with default name', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy());

        final result = await executor.withTimeout(
          () async => 'custom',
          Duration(seconds: 5),
        );
        expect(result, 'custom');
      });

      test('timeout - throws OperationTimeoutException', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy());

        expect(
          () => executor.withTimeout(
            () => Future.delayed(Duration(seconds: 10), () => 'late'),
            Duration(milliseconds: 50),
            name: 'my_op',
          ),
          throwsA(
            isA<OperationTimeoutException>()
                .having((e) => e.operation, 'operation', 'my_op')
                .having(
                  (e) => e.timeout,
                  'timeout',
                  Duration(milliseconds: 50),
                ),
          ),
        );
      });

      test('timeout - with default name', () async {
        final executor = TimeoutExecutor(const TimeoutPolicy());

        expect(
          () => executor.withTimeout(
            () => Future.delayed(Duration(seconds: 10), () => 'late'),
            Duration(milliseconds: 50),
          ),
          throwsA(
            isA<OperationTimeoutException>()
                .having((e) => e.operation, 'operation', 'operation'),
          ),
        );
      });
    });
  });
}
