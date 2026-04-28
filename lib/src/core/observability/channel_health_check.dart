import 'package:mcp_bundle/ports.dart';
import 'package:meta/meta.dart';

import '../port/channel_port.dart' show ExtendedChannelPort;

/// Health state of a component.
enum HealthState {
  /// Component is healthy and operational
  healthy,

  /// Component is degraded but still operational
  degraded,

  /// Component is unhealthy and not operational
  unhealthy,
}

/// Health status of a component at a point in time.
@immutable
class HealthStatus {
  HealthStatus({
    required this.state,
    this.description,
    this.details,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? DateTime.now();

  /// Current health state
  final HealthState state;

  /// When this check was performed
  final DateTime checkedAt;

  /// Optional human-readable description
  final String? description;

  /// Optional details (e.g. latency, connection count)
  final Map<String, dynamic>? details;

  @override
  String toString() =>
      'HealthStatus(state: ${state.name}, description: $description)';
}

/// Interface for health checking a channel or component.
abstract interface class ChannelHealthCheck {
  /// Name of the component being checked.
  String get name;

  /// Perform a health check.
  Future<HealthStatus> checkHealth();
}

/// Health check implementation for a channel connector.
///
/// Checks connection status, API availability, and response latency.
/// Uses [ExtendedChannelPort.isRunning] when available.
class ConnectorHealthCheck implements ChannelHealthCheck {
  ConnectorHealthCheck(this._port);

  final ChannelPort _port;

  @override
  String get name => 'connector:${_port.identity.platform}';

  @override
  Future<HealthStatus> checkHealth() async {
    try {
      // Check connection status via ExtendedChannelPort.isRunning
      if (_port case final ExtendedChannelPort extended) {
        if (!extended.isRunning) {
          return HealthStatus(
            state: HealthState.unhealthy,
            description: 'Not connected to platform',
          );
        }

        // Measure API latency
        final latency = await _measureApiLatency(extended);

        if (latency > const Duration(seconds: 5)) {
          return HealthStatus(
            state: HealthState.degraded,
            description: 'High API latency',
            details: {'latency_ms': latency.inMilliseconds},
          );
        }

        return HealthStatus(
          state: HealthState.healthy,
          description: 'Connected and responsive',
        );
      }

      // Base ChannelPort without extended capabilities
      final platform = _port.identity.platform;
      return HealthStatus(
        state: HealthState.healthy,
        description: '$platform connector is operational',
      );
    } catch (e) {
      return HealthStatus(
        state: HealthState.unhealthy,
        description: 'Health check failed: $e',
      );
    }
  }

  /// Measure API latency by performing a lightweight operation.
  Future<Duration> _measureApiLatency(ExtendedChannelPort port) async {
    final stopwatch = Stopwatch()..start();
    // Use getIdentityInfo as a lightweight API probe
    await port.getIdentityInfo('health-check');
    stopwatch.stop();
    return stopwatch.elapsed;
  }
}

/// Aggregates health checks from multiple components.
class ChannelHealthAggregator implements ChannelHealthCheck {
  ChannelHealthAggregator({
    required this.name,
    required List<ChannelHealthCheck> checks,
  }) : _checks = checks;

  @override
  final String name;

  final List<ChannelHealthCheck> _checks;

  @override
  Future<HealthStatus> checkHealth() async {
    // Execute all health checks in parallel
    final results = await Future.wait(
      _checks.map((c) => c.checkHealth().catchError((Object error) =>
        HealthStatus(
          state: HealthState.unhealthy,
          description: 'Health check failed: $error',
        ),
      )),
    );

    // Aggregate: worst state wins
    var worstState = HealthState.healthy;
    final details = <String, dynamic>{};

    for (var i = 0; i < _checks.length; i++) {
      final check = _checks[i];
      final result = results[i];
      details[check.name] = {
        'state': result.state.name,
        'description': result.description,
        ...?result.details,
      };
      if (result.state.index > worstState.index) {
        worstState = result.state;
      }
    }

    return HealthStatus(
      state: worstState,
      description: 'Aggregate health from ${_checks.length} checks',
      details: details,
    );
  }
}
