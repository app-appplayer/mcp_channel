import 'dart:async';

import 'package:meta/meta.dart';

/// Timeout policy configuration.
@immutable
class TimeoutPolicy {
  const TimeoutPolicy({
    this.connectionTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 30),
    this.operationTimeout = const Duration(minutes: 2),
    this.idleTimeout = const Duration(minutes: 5),
  });

  /// Connection establishment timeout
  final Duration connectionTimeout;

  /// Individual request timeout
  final Duration requestTimeout;

  /// Overall operation timeout (including retries)
  final Duration operationTimeout;

  /// Idle timeout (for long-polling/websocket)
  final Duration idleTimeout;

  TimeoutPolicy copyWith({
    Duration? connectionTimeout,
    Duration? requestTimeout,
    Duration? operationTimeout,
    Duration? idleTimeout,
  }) {
    return TimeoutPolicy(
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      operationTimeout: operationTimeout ?? this.operationTimeout,
      idleTimeout: idleTimeout ?? this.idleTimeout,
    );
  }
}

/// Exception thrown when an operation times out.
class OperationTimeoutException implements Exception {
  const OperationTimeoutException(this.operation, this.timeout);

  final String operation;
  final Duration timeout;

  @override
  String toString() =>
      'OperationTimeoutException: $operation timed out after ${timeout.inMilliseconds}ms';
}

/// Utility for applying timeouts to operations.
class TimeoutExecutor {
  TimeoutExecutor(this._policy);

  final TimeoutPolicy _policy;

  /// Execute operation with request timeout.
  Future<T> withRequestTimeout<T>(Future<T> Function() operation) {
    return _withTimeout(operation, _policy.requestTimeout, 'request');
  }

  /// Execute operation with operation timeout.
  Future<T> withOperationTimeout<T>(Future<T> Function() operation) {
    return _withTimeout(operation, _policy.operationTimeout, 'operation');
  }

  /// Execute operation with connection timeout.
  Future<T> withConnectionTimeout<T>(Future<T> Function() operation) {
    return _withTimeout(operation, _policy.connectionTimeout, 'connection');
  }

  /// Execute operation with custom timeout.
  Future<T> withTimeout<T>(
    Future<T> Function() operation,
    Duration timeout, {
    String name = 'operation',
  }) {
    return _withTimeout(operation, timeout, name);
  }

  Future<T> _withTimeout<T>(
    Future<T> Function() operation,
    Duration timeout,
    String name,
  ) {
    return operation().timeout(
      timeout,
      onTimeout: () => throw OperationTimeoutException(name, timeout),
    );
  }
}
