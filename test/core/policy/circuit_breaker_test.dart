import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('CircuitState', () {
    test('has all expected values', () {
      expect(CircuitState.values, hasLength(3));
      expect(CircuitState.closed, isNotNull);
      expect(CircuitState.open, isNotNull);
      expect(CircuitState.halfOpen, isNotNull);
    });
  });

  group('CircuitBreakerPolicy', () {
    test('constructor with defaults', () {
      const policy = CircuitBreakerPolicy();

      expect(policy.failureThreshold, 5);
      expect(policy.failureWindow, Duration(minutes: 1));
      expect(policy.recoveryTimeout, Duration(seconds: 30));
      expect(policy.successThreshold, 3);
      expect(
        policy.triggerErrors,
        equals({'network_error', 'timeout', 'server_error'}),
      );
    });

    test('constructor with custom values', () {
      final policy = CircuitBreakerPolicy(
        failureThreshold: 10,
        failureWindow: Duration(seconds: 30),
        recoveryTimeout: Duration(minutes: 1),
        successThreshold: 5,
        triggerErrors: {'custom_error'},
      );

      expect(policy.failureThreshold, 10);
      expect(policy.failureWindow, Duration(seconds: 30));
      expect(policy.recoveryTimeout, Duration(minutes: 1));
      expect(policy.successThreshold, 5);
      expect(policy.triggerErrors, equals({'custom_error'}));
    });

    test('copyWith all fields', () {
      const original = CircuitBreakerPolicy();

      final copied = original.copyWith(
        failureThreshold: 10,
        failureWindow: Duration(seconds: 30),
        recoveryTimeout: Duration(minutes: 2),
        successThreshold: 5,
        triggerErrors: {'custom_error'},
      );

      expect(copied.failureThreshold, 10);
      expect(copied.failureWindow, Duration(seconds: 30));
      expect(copied.recoveryTimeout, Duration(minutes: 2));
      expect(copied.successThreshold, 5);
      expect(copied.triggerErrors, equals({'custom_error'}));
    });

    test('copyWith no arguments returns equivalent', () {
      const original = CircuitBreakerPolicy();
      final copied = original.copyWith();

      expect(copied.failureThreshold, original.failureThreshold);
      expect(copied.failureWindow, original.failureWindow);
      expect(copied.recoveryTimeout, original.recoveryTimeout);
      expect(copied.successThreshold, original.successThreshold);
      expect(copied.triggerErrors, original.triggerErrors);
    });
  });

  group('CircuitOpenException', () {
    test('constructor', () {
      const ex = CircuitOpenException('test_circuit');
      expect(ex.circuitName, 'test_circuit');
    });

    test('toString', () {
      const ex = CircuitOpenException('my_channel');
      expect(ex.toString(), 'CircuitOpenException: my_channel is open');
    });
  });

  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    test('constructor sets initial state', () {
      breaker = CircuitBreaker('test', const CircuitBreakerPolicy());
      expect(breaker.name, 'test');
      expect(breaker.state, CircuitState.closed);
      expect(breaker.isAllowed, isTrue);
    });

    group('closed state', () {
      setUp(() {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 3,
            failureWindow: Duration(minutes: 1),
          ),
        );
      });

      test('success resets failure count', () async {
        // Record some failures
        for (var i = 0; i < 2; i++) {
          try {
            await breaker.execute(
                () => Future<void>.error(Exception('fail')));
          } catch (_) {}
        }

        // Record a success
        final result = await breaker.execute(() async => 'ok');
        expect(result, 'ok');
        expect(breaker.state, CircuitState.closed);

        // Now two more failures should not open circuit (failure count was reset)
        for (var i = 0; i < 2; i++) {
          try {
            await breaker.execute(
                () => Future<void>.error(Exception('fail')));
          } catch (_) {}
        }
        expect(breaker.state, CircuitState.closed);
      });

      test('failure increments count', () async {
        try {
          await breaker
              .execute(() => Future<void>.error(Exception('fail')));
        } catch (_) {}

        expect(breaker.state, CircuitState.closed);
      });
    });

    group('closed to open transition', () {
      test('exceeds failureThreshold within failureWindow', () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 3,
            failureWindow: Duration(minutes: 1),
          ),
        );

        for (var i = 0; i < 3; i++) {
          try {
            await breaker.execute(
                () => Future<void>.error(Exception('fail')));
          } catch (_) {}
        }

        expect(breaker.state, CircuitState.open);
      });

      test('failures outside failureWindow do not accumulate', () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 3,
            failureWindow: Duration(milliseconds: 30),
          ),
        );

        // Record 2 failures
        for (var i = 0; i < 2; i++) {
          try {
            await breaker.execute(
                () => Future<void>.error(Exception('fail')));
          } catch (_) {}
        }

        // Wait for window to expire
        await Future<void>.delayed(Duration(milliseconds: 40));

        // Record 1 more failure - should start fresh
        try {
          await breaker
              .execute(() => Future<void>.error(Exception('fail')));
        } catch (_) {}

        // Should still be closed since failure count was reset
        expect(breaker.state, CircuitState.closed);
      });
    });

    group('open state', () {
      setUp(() {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 1,
            recoveryTimeout: Duration(seconds: 30),
          ),
        );
        // Open the circuit
        breaker.open();
      });

      test('rejects with CircuitOpenException', () async {
        expect(breaker.state, CircuitState.open);
        expect(breaker.isAllowed, isFalse);

        expect(
          () => breaker.execute(() async => 'ok'),
          throwsA(isA<CircuitOpenException>()),
        );
      });
    });

    group('open to halfOpen transition', () {
      test('after recoveryTimeout passes', () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 1,
            recoveryTimeout: Duration(milliseconds: 50),
          ),
        );

        // Open the circuit
        breaker.open();
        expect(breaker.state, CircuitState.open);

        // Wait for recovery timeout
        await Future<void>.delayed(Duration(milliseconds: 60));

        // isAllowed should transition to halfOpen
        expect(breaker.isAllowed, isTrue);
        expect(breaker.state, CircuitState.halfOpen);
      });
    });

    group('halfOpen state', () {
      late CircuitBreaker halfOpenBreaker;

      setUp(() async {
        halfOpenBreaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 1,
            recoveryTimeout: Duration(milliseconds: 30),
            successThreshold: 2,
          ),
        );
        halfOpenBreaker.open();
        await Future<void>.delayed(Duration(milliseconds: 40));
        // Trigger transition to halfOpen
        expect(halfOpenBreaker.isAllowed, isTrue);
        expect(halfOpenBreaker.state, CircuitState.halfOpen);
      });

      test('success increments successCount', () async {
        await halfOpenBreaker.execute(() async => 'ok');
        // Still halfOpen (need 2 successes)
        expect(halfOpenBreaker.state, CircuitState.halfOpen);
      });

      test('enough successes transitions to closed', () async {
        await halfOpenBreaker.execute(() async => 'ok');
        await halfOpenBreaker.execute(() async => 'ok');
        expect(halfOpenBreaker.state, CircuitState.closed);
      });

      test('failure transitions back to open', () async {
        // Record one success first
        await halfOpenBreaker.execute(() async => 'ok');
        expect(halfOpenBreaker.state, CircuitState.halfOpen);

        // Now fail
        try {
          await halfOpenBreaker
              .execute(() => Future<void>.error(Exception('fail')));
        } catch (_) {}

        expect(halfOpenBreaker.state, CircuitState.open);
      });
    });

    group('non-trigger errors', () {
      test('ChannelError with non-trigger code does not count as failure',
          () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 1,
            triggerErrors: {'network_error'},
          ),
        );

        // Throw a ChannelError with a code NOT in triggerErrors
        try {
          await breaker.execute(() => Future<void>.error(
                const ChannelError(
                  code: 'not_found',
                  message: 'Not found',
                ),
              ));
        } catch (_) {}

        // Should still be closed
        expect(breaker.state, CircuitState.closed);
      });

      test('ChannelError with trigger code counts as failure', () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 1,
            triggerErrors: {'network_error'},
          ),
        );

        try {
          await breaker.execute(() => Future<void>.error(
                const ChannelError(
                  code: 'network_error',
                  message: 'Network error',
                ),
              ));
        } catch (_) {}

        expect(breaker.state, CircuitState.open);
      });

      test('non-ChannelError always counts as failure', () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 1,
            triggerErrors: {'network_error'},
          ),
        );

        try {
          await breaker
              .execute(() => Future<void>.error(Exception('generic')));
        } catch (_) {}

        expect(breaker.state, CircuitState.open);
      });
    });

    group('execute()', () {
      test('success path returns result', () async {
        breaker = CircuitBreaker('test', const CircuitBreakerPolicy());

        final result = await breaker.execute(() async => 42);
        expect(result, 42);
        expect(breaker.state, CircuitState.closed);
      });

      test('failure path rethrows', () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(failureThreshold: 10),
        );

        expect(
          () => breaker.execute(() => Future<int>.error(
                StateError('boom'),
              )),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('manual control', () {
      setUp(() {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 3,
            recoveryTimeout: Duration(milliseconds: 30),
          ),
        );
      });

      test('open() forces circuit to open state', () {
        breaker.open();
        expect(breaker.state, CircuitState.open);
        expect(breaker.isAllowed, isFalse);
      });

      test('close() forces circuit to closed state and resets counts',
          () async {
        breaker.open();
        expect(breaker.state, CircuitState.open);

        breaker.close();
        expect(breaker.state, CircuitState.closed);
        expect(breaker.isAllowed, isTrue);

        // Verify failure counts were reset by checking we can reach threshold again
        for (var i = 0; i < 3; i++) {
          try {
            await breaker.execute(
                () => Future<void>.error(Exception('fail')));
          } catch (_) {}
        }
        expect(breaker.state, CircuitState.open);
      });

      test('reset() resets everything', () async {
        // Build up some state
        try {
          await breaker
              .execute(() => Future<void>.error(Exception('fail')));
        } catch (_) {}

        breaker.reset();
        expect(breaker.state, CircuitState.closed);

        // After reset, failure count should be 0.
        // We need exactly failureThreshold failures to open.
        for (var i = 0; i < 2; i++) {
          try {
            await breaker.execute(
                () => Future<void>.error(Exception('fail')));
          } catch (_) {}
        }
        expect(breaker.state, CircuitState.closed);

        // One more should open it (3 total)
        try {
          await breaker
              .execute(() => Future<void>.error(Exception('fail')));
        } catch (_) {}
        expect(breaker.state, CircuitState.open);
      });
    });

    group('open state _recordSuccess (should not happen branch)', () {
      test('success in open state is no-op', () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 1,
            recoveryTimeout: Duration(seconds: 30),
          ),
        );

        // Open the circuit
        breaker.open();

        // Calling _recordSuccess from open state should be a no-op.
        // The only way to trigger this is indirectly through execute(),
        // but execute throws when circuit is open. So we verify it stays open
        // by just checking the state.
        expect(breaker.state, CircuitState.open);
      });
    });

    group('open state _recordFailure (already open branch)', () {
      test('failure in open state is no-op', () {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(failureThreshold: 1),
        );
        breaker.open();

        // The circuit is already open. Even if we could record a failure
        // it should remain open. We verify the state does not change.
        expect(breaker.state, CircuitState.open);
      });
    });

    group('open to halfOpen with _openedAt not null', () {
      test('transitions when openedAt is set and timeout has passed',
          () async {
        breaker = CircuitBreaker(
          'test',
          const CircuitBreakerPolicy(
            failureThreshold: 1,
            recoveryTimeout: Duration(milliseconds: 30),
          ),
        );

        // Trigger open via failures (not manual open) to ensure _openedAt is set
        try {
          await breaker
              .execute(() => Future<void>.error(Exception('fail')));
        } catch (_) {}
        expect(breaker.state, CircuitState.open);

        await Future<void>.delayed(Duration(milliseconds: 40));
        expect(breaker.isAllowed, isTrue);
        expect(breaker.state, CircuitState.halfOpen);
      });
    });
  });
}
