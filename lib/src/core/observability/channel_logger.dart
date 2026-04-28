/// Interface for channel-specific logging.
///
/// Implementations can delegate to `package:logging`, `dart:developer`,
/// or other logging frameworks.
abstract interface class ChannelLogger {
  /// Log a debug message.
  void debug(
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
  });

  /// Log an info message.
  void info(
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
  });

  /// Log a warning message.
  void warn(
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
  });

  /// Log an error message.
  void error(
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Log entry recorded by [InMemoryChannelLogger].
class ChannelLogEntry {
  const ChannelLogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.component,
    this.correlationId,
    this.data,
    this.error,
    this.stackTrace,
  });

  final String level;
  final String message;
  final DateTime timestamp;
  final String? component;
  final String? correlationId;
  final Map<String, dynamic>? data;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      '${level.toUpperCase()} [$timestamp]: $message';
}

/// Redactor that removes sensitive data from log context.
class ChannelLogRedactor {
  const ChannelLogRedactor({
    this.redactedFields = const {
      'text',
      'content',
      'token',
      'apiKey',
      'password',
      'metadata.email',
      'metadata.phone',
    },
    this.replacement = '[REDACTED]',
  });

  /// Field paths to redact from log data (supports dot-notation)
  final Set<String> redactedFields;

  /// Replacement string for redacted values
  final String replacement;

  /// Redact sensitive fields from a data map.
  Map<String, dynamic> redact(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      result[entry.key] = _redactField(entry.key, entry.value, '');
    }
    return result;
  }

  dynamic _redactField(String key, dynamic value, String parentPath) {
    final fullPath = parentPath.isEmpty ? key : '$parentPath.$key';

    // Check if this exact path should be redacted
    if (redactedFields.contains(fullPath) || redactedFields.contains(key)) {
      return replacement;
    }

    // Recurse into nested maps
    if (value is Map<String, dynamic>) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key] = _redactField(entry.key, entry.value, fullPath);
      }
      return result;
    }

    return value;
  }
}

/// In-memory logger implementation for testing.
class InMemoryChannelLogger implements ChannelLogger {
  InMemoryChannelLogger({this.redactor});

  /// Optional redactor for sensitive data
  final ChannelLogRedactor? redactor;

  final List<ChannelLogEntry> _entries = [];

  /// All recorded log entries.
  List<ChannelLogEntry> get entries => List.unmodifiable(_entries);

  void _log(
    String level,
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final redactedData =
        data != null && redactor != null ? redactor!.redact(data) : data;

    _entries.add(ChannelLogEntry(
      level: level,
      message: message,
      timestamp: DateTime.now(),
      component: component,
      correlationId: correlationId,
      data: redactedData,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  @override
  void debug(
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
  }) =>
      _log('debug', message,
          component: component, correlationId: correlationId, data: data);

  @override
  void info(
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
  }) =>
      _log('info', message,
          component: component, correlationId: correlationId, data: data);

  @override
  void warn(
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
  }) =>
      _log('warn', message,
          component: component, correlationId: correlationId, data: data);

  @override
  void error(
    String message, {
    String? component,
    String? correlationId,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log('error', message,
          component: component,
          correlationId: correlationId,
          data: data,
          error: error,
          stackTrace: stackTrace);

  /// Clear all recorded entries.
  void clear() => _entries.clear();
}
