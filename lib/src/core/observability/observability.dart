/// Observability module for MCP Channel.
library;

export 'channel_health_check.dart';
export 'channel_logger.dart';
export 'channel_metrics.dart';
export 'channel_tracer.dart';

import 'channel_logger.dart';
import 'channel_metrics.dart';
import 'channel_tracer.dart';

/// Combined observability configuration.
class ChannelObserverConfig {
  const ChannelObserverConfig({
    this.metrics,
    this.logger,
    this.tracer,
    this.redactor,
  });

  /// Optional metrics collector.
  final ChannelMetrics? metrics;

  /// Optional logger.
  final ChannelLogger? logger;

  /// Optional tracer.
  final ChannelTracer? tracer;

  /// Optional log data redactor.
  final ChannelLogRedactor? redactor;
}
