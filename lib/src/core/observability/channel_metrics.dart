import 'package:mcp_bundle/ports.dart';

/// Configuration for channel metrics collection.
class ChannelMetricsConfig {
  const ChannelMetricsConfig({
    required this.metrics,
    this.reportingInterval,
    this.platformLabel,
  });

  /// The metrics implementation to use.
  final ChannelMetrics metrics;

  /// Optional interval for periodic metrics reporting.
  final Duration? reportingInterval;

  /// Optional platform label applied to all metrics.
  final String? platformLabel;
}

/// Interface for collecting channel metrics.
///
/// Implementations can push metrics to Prometheus, StatsD,
/// CloudWatch, or other monitoring systems.
abstract interface class ChannelMetrics {
  /// Record a message sent to a platform.
  void recordMessageSent(String platform, ConversationKey conversation);

  /// Record a message received from a platform.
  void recordMessageReceived(String platform, ConversationKey conversation);

  /// Record a message processing failure.
  void recordMessageFailed(
    String platform,
    ConversationKey conversation, {
    String? errorType,
  });

  /// Record operation latency.
  void recordLatency(String operation, Duration duration);

  /// Record a new session creation.
  void recordSessionCreated();

  /// Record a session expiration.
  void recordSessionExpired();

  /// Record a rate limit hit.
  void recordRateLimitHit(String platform);

  /// Record a circuit breaker state change.
  void recordCircuitBreakerStateChange(String name, String newState);
}

/// In-memory metrics implementation for testing and development.
class InMemoryChannelMetrics implements ChannelMetrics {
  final Map<String, int> _counters = {};
  final Map<String, List<Duration>> _latencies = {};
  final List<String> _circuitBreakerEvents = [];

  /// Get all recorded counters.
  Map<String, int> get counters => Map.unmodifiable(_counters);

  /// Get all recorded latencies.
  Map<String, List<Duration>> get latencies => Map.unmodifiable(_latencies);

  /// Get circuit breaker events.
  List<String> get circuitBreakerEvents =>
      List.unmodifiable(_circuitBreakerEvents);

  void _increment(String key) {
    _counters[key] = (_counters[key] ?? 0) + 1;
  }

  @override
  void recordMessageSent(String platform, ConversationKey conversation) {
    _increment('message_sent:$platform');
  }

  @override
  void recordMessageReceived(String platform, ConversationKey conversation) {
    _increment('message_received:$platform');
  }

  @override
  void recordMessageFailed(
    String platform,
    ConversationKey conversation, {
    String? errorType,
  }) {
    final key = errorType != null
        ? 'message_failed:$platform:$errorType'
        : 'message_failed:$platform';
    _increment(key);
  }

  @override
  void recordLatency(String operation, Duration duration) {
    _latencies.putIfAbsent(operation, () => []).add(duration);
  }

  @override
  void recordSessionCreated() {
    _increment('session_created');
  }

  @override
  void recordSessionExpired() {
    _increment('session_expired');
  }

  @override
  void recordRateLimitHit(String platform) {
    _increment('rate_limit_hit:$platform');
  }

  @override
  void recordCircuitBreakerStateChange(String name, String newState) {
    _circuitBreakerEvents.add('$name:$newState');
  }

  /// Reset all metrics (for testing).
  void reset() {
    _counters.clear();
    _latencies.clear();
    _circuitBreakerEvents.clear();
  }
}
