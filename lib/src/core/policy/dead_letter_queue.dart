import 'package:meta/meta.dart';

/// Callback invoked when a failure is recorded.
typedef FailureHandler = Future<void> Function(FailureRecord record);

/// Record of a failed event for dead letter queue.
@immutable
class FailureRecord {
  const FailureRecord({
    required this.eventId,
    required this.event,
    required this.error,
    required this.stackTrace,
    required this.failedAt,
    required this.attemptCount,
    this.conversationKey,
    this.userId,
    this.metadata,
  });

  factory FailureRecord.fromJson(Map<String, dynamic> json) {
    return FailureRecord(
      eventId: json['eventId'] as String,
      event: Map<String, dynamic>.from(json['event'] as Map),
      error: json['error'] as String,
      stackTrace: json['stackTrace'] as String,
      failedAt: DateTime.parse(json['failedAt'] as String),
      attemptCount: json['attemptCount'] as int,
      conversationKey: json['conversationKey'] as String?,
      userId: json['userId'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  /// Original event ID.
  final String eventId;

  /// Serialized event data for replay.
  final Map<String, dynamic> event;

  /// Error description.
  final String error;

  /// Stack trace at time of failure.
  final String stackTrace;

  /// When the failure occurred.
  final DateTime failedAt;

  /// How many attempts were made.
  final int attemptCount;

  /// Conversation key (for grouping/filtering).
  final String? conversationKey;

  /// User ID who triggered the event.
  final String? userId;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  FailureRecord copyWith({
    String? eventId,
    Map<String, dynamic>? event,
    String? error,
    String? stackTrace,
    DateTime? failedAt,
    int? attemptCount,
    String? conversationKey,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    return FailureRecord(
      eventId: eventId ?? this.eventId,
      event: event ?? this.event,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      failedAt: failedAt ?? this.failedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      conversationKey: conversationKey ?? this.conversationKey,
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'event': event,
        'error': error,
        'stackTrace': stackTrace,
        'failedAt': failedAt.toIso8601String(),
        'attemptCount': attemptCount,
        if (conversationKey != null) 'conversationKey': conversationKey,
        if (userId != null) 'userId': userId,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureRecord &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId;

  @override
  int get hashCode => eventId.hashCode;

  @override
  String toString() =>
      'FailureRecord(eventId: $eventId, attemptCount: $attemptCount, '
      'error: $error)';
}

/// Interface for persisting failed events.
///
/// Implementations can use in-memory storage, database, message queue,
/// or external services (e.g., Redis, SQS, Kafka DLQ).
abstract interface class DeadLetterQueue {
  /// Record a failed event.
  Future<void> enqueue(FailureRecord record);

  /// Retrieve failed events for retry.
  Future<List<FailureRecord>> peek({
    int limit = 10,
    String? conversationKey,
  });

  /// Remove a record after successful retry.
  Future<void> remove(String eventId);

  /// Count of pending failed events.
  Future<int> count();

  /// Clean up old records beyond retention period.
  Future<int> cleanup({required Duration olderThan});
}

/// In-memory implementation of [DeadLetterQueue].
class InMemoryDeadLetterQueue implements DeadLetterQueue {
  final List<FailureRecord> _records = [];

  @override
  Future<void> enqueue(FailureRecord record) async {
    _records.add(record);
  }

  @override
  Future<List<FailureRecord>> peek({
    int limit = 10,
    String? conversationKey,
  }) async {
    final filtered = _records.where((r) =>
        conversationKey == null || r.conversationKey == conversationKey);
    return filtered.take(limit).toList();
  }

  @override
  Future<void> remove(String eventId) async {
    _records.removeWhere((r) => r.eventId == eventId);
  }

  @override
  Future<int> count() async => _records.length;

  @override
  Future<int> cleanup({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final before = _records.length;
    _records.removeWhere((r) => r.failedAt.isBefore(cutoff));
    return before - _records.length;
  }
}
