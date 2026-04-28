import 'dart:math';

/// Status of a traced span.
enum SpanStatus {
  /// Operation completed successfully
  ok,

  /// Operation failed with an error
  error,

  /// Operation was cancelled
  cancelled,
}

/// A single span within a trace.
///
/// Spans represent units of work and can be nested to form
/// a trace tree.
abstract interface class ChannelSpan {
  /// Unique span identifier
  String get spanId;

  /// Add a timestamped event to this span.
  void addEvent(String name, {Map<String, dynamic>? attributes});

  /// Set the span status.
  void setStatus(SpanStatus status, {String? description});

  /// Set an attribute on this span.
  void setAttribute(String key, dynamic value);

  /// End the span.
  void end();
}

/// Interface for distributed tracing.
///
/// Implementations can push traces to Jaeger, Zipkin,
/// OpenTelemetry, or other tracing systems.
abstract interface class ChannelTracer {
  /// Start a new span.
  ///
  /// [name] - The operation name for this span
  /// [parentSpanId] - Optional parent span ID for creating child spans
  ChannelSpan startSpan(String name, {String? parentSpanId});
}

/// Generate a correlation ID in the format `evt_{timestamp}_{random}`.
String generateCorrelationId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random.secure().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
  return 'evt_${timestamp}_$random';
}

/// Span event recorded by [InMemorySpan].
class SpanEvent {
  const SpanEvent({
    required this.name,
    required this.timestamp,
    this.attributes,
  });

  final String name;
  final DateTime timestamp;
  final Map<String, dynamic>? attributes;
}

/// In-memory span implementation for testing.
class InMemorySpan implements ChannelSpan {
  InMemorySpan({
    required this.spanId,
    required this.name,
    this.parentSpanId,
  }) : startTime = DateTime.now();

  @override
  final String spanId;

  /// Operation name
  final String name;

  /// Parent span ID (null for root spans)
  final String? parentSpanId;

  /// When the span was started
  final DateTime startTime;

  /// When the span was ended (null if still active)
  DateTime? endTime;

  /// Current span status
  SpanStatus status = SpanStatus.ok;

  /// Status description
  String? statusDescription;

  /// Recorded events
  final List<SpanEvent> events = [];

  final Map<String, dynamic> _attributes = {};

  /// All attributes set on this span.
  Map<String, dynamic> get attributes => Map.unmodifiable(_attributes);

  /// Whether this span has been ended.
  bool get isEnded => endTime != null;

  /// Duration of the span (null if not yet ended).
  Duration? get duration => endTime?.difference(startTime);

  @override
  void addEvent(String name, {Map<String, dynamic>? attributes}) {
    events.add(SpanEvent(
      name: name,
      timestamp: DateTime.now(),
      attributes: attributes,
    ));
  }

  @override
  void setAttribute(String key, dynamic value) {
    _attributes[key] = value;
  }

  @override
  void setStatus(SpanStatus status, {String? description}) {
    this.status = status;
    statusDescription = description;
  }

  @override
  void end() {
    endTime = DateTime.now();
  }
}

/// In-memory tracer implementation for testing.
class InMemoryTracer implements ChannelTracer {
  final List<InMemorySpan> _spans = [];
  int _nextId = 0;

  /// All recorded spans.
  List<InMemorySpan> get spans => List.unmodifiable(_spans);

  @override
  ChannelSpan startSpan(String name, {String? parentSpanId}) {
    final span = InMemorySpan(
      spanId: 'span-${_nextId++}',
      name: name,
      parentSpanId: parentSpanId,
    );
    _spans.add(span);
    return span;
  }

  /// Reset all spans.
  void reset() {
    _spans.clear();
    _nextId = 0;
  }
}
