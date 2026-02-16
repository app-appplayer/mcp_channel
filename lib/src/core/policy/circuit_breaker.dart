import 'package:meta/meta.dart';

import '../port/channel_error.dart';

/// Circuit breaker state.
enum CircuitState {
  /// Circuit is closed, requests flow normally
  closed,

  /// Circuit is open, requests are rejected
  open,

  /// Circuit is testing recovery
  halfOpen,
}

/// Circuit breaker policy configuration.
@immutable
class CircuitBreakerPolicy {
  /// Number of failures before opening circuit
  final int failureThreshold;

  /// Time window for counting failures
  final Duration failureWindow;

  /// Time to wait before attempting recovery
  final Duration recoveryTimeout;

  /// Number of successful calls to close circuit
  final int successThreshold;

  /// Errors that trigger circuit breaker
  final Set<String> triggerErrors;

  const CircuitBreakerPolicy({
    this.failureThreshold = 5,
    this.failureWindow = const Duration(minutes: 1),
    this.recoveryTimeout = const Duration(seconds: 30),
    this.successThreshold = 3,
    this.triggerErrors = const {
      'network_error',
      'timeout',
      'server_error',
    },
  });

  CircuitBreakerPolicy copyWith({
    int? failureThreshold,
    Duration? failureWindow,
    Duration? recoveryTimeout,
    int? successThreshold,
    Set<String>? triggerErrors,
  }) {
    return CircuitBreakerPolicy(
      failureThreshold: failureThreshold ?? this.failureThreshold,
      failureWindow: failureWindow ?? this.failureWindow,
      recoveryTimeout: recoveryTimeout ?? this.recoveryTimeout,
      successThreshold: successThreshold ?? this.successThreshold,
      triggerErrors: triggerErrors ?? this.triggerErrors,
    );
  }
}

/// Exception thrown when circuit is open.
class CircuitOpenException implements Exception {
  final String circuitName;

  const CircuitOpenException(this.circuitName);

  @override
  String toString() => 'CircuitOpenException: $circuitName is open';
}

/// Circuit breaker implementation.
class CircuitBreaker {
  final CircuitBreakerPolicy _policy;
  final String name;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _openedAt;

  CircuitBreaker(this.name, this._policy);

  /// Current circuit state.
  CircuitState get state => _state;

  /// Check if circuit allows request.
  bool get isAllowed {
    switch (_state) {
      case CircuitState.closed:
        return true;

      case CircuitState.open:
        // Check if recovery timeout has passed
        if (_openedAt != null) {
          final elapsed = DateTime.now().difference(_openedAt!);
          if (elapsed >= _policy.recoveryTimeout) {
            _state = CircuitState.halfOpen;
            _successCount = 0;
            return true;
          }
        }
        return false;

      case CircuitState.halfOpen:
        return true;
    }
  }

  /// Execute operation with circuit breaker protection.
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (!isAllowed) {
      throw CircuitOpenException(name);
    }

    try {
      final result = await operation();
      _recordSuccess();
      return result;
    } catch (error) {
      _recordFailure(error);
      rethrow;
    }
  }

  void _recordSuccess() {
    switch (_state) {
      case CircuitState.closed:
        // Reset failure count on success
        _failureCount = 0;
        break;

      case CircuitState.halfOpen:
        _successCount++;
        if (_successCount >= _policy.successThreshold) {
          // Close circuit after enough successes
          _state = CircuitState.closed;
          _failureCount = 0;
          _successCount = 0;
        }
        break;

      case CircuitState.open:
        // Should not happen
        break;
    }
  }

  void _recordFailure(Object error) {
    // Check if error triggers circuit breaker
    if (error is ChannelError &&
        !_policy.triggerErrors.contains(error.code)) {
      return;
    }

    switch (_state) {
      case CircuitState.closed:
        final now = DateTime.now();

        // Clean up old failures
        if (_lastFailureTime != null) {
          final elapsed = now.difference(_lastFailureTime!);
          if (elapsed > _policy.failureWindow) {
            _failureCount = 0;
          }
        }

        _failureCount++;
        _lastFailureTime = now;

        // Check threshold
        if (_failureCount >= _policy.failureThreshold) {
          _state = CircuitState.open;
          _openedAt = now;
        }
        break;

      case CircuitState.halfOpen:
        // Any failure in half-open reopens circuit
        _state = CircuitState.open;
        _openedAt = DateTime.now();
        _successCount = 0;
        break;

      case CircuitState.open:
        // Already open
        break;
    }
  }

  /// Force circuit to open state.
  void open() {
    _state = CircuitState.open;
    _openedAt = DateTime.now();
  }

  /// Force circuit to closed state.
  void close() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _successCount = 0;
  }

  /// Reset circuit to initial state.
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _successCount = 0;
    _lastFailureTime = null;
    _openedAt = null;
  }
}
