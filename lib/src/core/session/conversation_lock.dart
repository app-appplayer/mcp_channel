import 'dart:async';

import 'package:mcp_bundle/ports.dart';

/// Serializes operations per conversation key.
///
/// Events for the same conversation are processed one at a time.
/// Events for different conversations can be processed concurrently.
///
/// Uses a queue-based approach to avoid race conditions between
/// the await point and lock acquisition. Each conversation key
/// maintains a Future chain that serializes operations.
class ConversationLock {
  final Map<String, Future<void>> _queues = {};

  /// Acquire a lock for the conversation and execute the operation.
  ///
  /// If another operation is in progress for this conversation,
  /// the new operation is chained after it (FIFO ordering).
  /// Different conversations execute concurrently.
  Future<T> withLock<T>(
    ConversationKey conversation,
    Future<T> Function() operation,
  ) async {
    final key = _keyOf(conversation);

    // Chain this operation after any pending operations for this key.
    // This is synchronous (no await between read and write of _queues),
    // so there is no race condition in the Dart event loop.
    final previous = _queues[key] ?? Future.value();

    final completer = Completer<void>();
    _queues[key] = completer.future;

    // Wait for the previous operation to complete (ignore its errors)
    await previous.catchError((_) {});

    try {
      final result = await operation();
      return result;
    } finally {
      // Clean up if this is the last operation in the queue
      if (_queues[key] == completer.future) {
        _queues.remove(key);
      }
      completer.complete();
    }
  }

  String _keyOf(ConversationKey conv) =>
      '${conv.channel.platform}:${conv.channel.channelId}:${conv.conversationId}';
}
