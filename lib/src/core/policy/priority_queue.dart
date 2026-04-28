import 'package:mcp_bundle/ports.dart' show ChannelResponse;
import 'package:meta/meta.dart';

/// Priority levels for queued messages.
/// Lower numeric value means higher priority.
enum MessagePriority {
  /// System-critical messages (health checks, admin commands).
  critical(0),

  /// High priority (direct user requests, interactive responses).
  high(1),

  /// Normal priority (regular messages).
  normal(2),

  /// Low priority (background notifications, batch messages).
  low(3);

  const MessagePriority(this.value);

  /// Numeric value (lower = higher priority).
  final int value;
}

/// A message queued for later delivery when rate limited.
@immutable
class QueuedMessage {
  const QueuedMessage({
    required this.response,
    required this.priority,
    required this.enqueuedAt,
    this.conversationKey,
    this.userId,
    this.deadline,
  });

  /// The response to send.
  final ChannelResponse response;

  /// Message priority.
  final MessagePriority priority;

  /// When the message was queued.
  final DateTime enqueuedAt;

  /// Conversation context.
  final String? conversationKey;

  /// User context.
  final String? userId;

  /// Deadline after which this message should be dropped.
  final DateTime? deadline;

  /// Whether this message has expired.
  bool get isExpired =>
      deadline != null && DateTime.now().isAfter(deadline!);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedMessage &&
          runtimeType == other.runtimeType &&
          response == other.response &&
          priority == other.priority &&
          enqueuedAt == other.enqueuedAt;

  @override
  int get hashCode => Object.hash(response, priority, enqueuedAt);

  @override
  String toString() =>
      'QueuedMessage(priority: ${priority.name}, enqueuedAt: $enqueuedAt)';
}

/// Priority queue for rate-limited messages.
///
/// Messages are ordered by priority (lower value = higher priority)
/// and expired messages are automatically skipped on dequeue.
class PriorityMessageQueue {
  final List<QueuedMessage> _queue = [];

  /// Add a message to the queue.
  void enqueue(QueuedMessage message) {
    var insertIndex = _queue.length;
    for (var i = 0; i < _queue.length; i++) {
      if (message.priority.value < _queue[i].priority.value) {
        insertIndex = i;
        break;
      }
    }
    _queue.insert(insertIndex, message);
  }

  /// Get the next message to process (highest priority first).
  /// Expired messages are automatically skipped.
  QueuedMessage? dequeue() {
    while (_queue.isNotEmpty) {
      final message = _queue.removeAt(0);
      if (!message.isExpired) return message;
    }
    return null;
  }

  /// Number of queued messages.
  int get length => _queue.length;

  /// Whether the queue is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Remove expired messages.
  int purgeExpired() {
    final before = _queue.length;
    _queue.removeWhere((m) => m.isExpired);
    return before - _queue.length;
  }
}
