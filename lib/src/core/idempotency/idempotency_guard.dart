import 'dart:async';

import 'package:uuid/uuid.dart';

import '../types/channel_event.dart';
import 'idempotency_config.dart';
import 'idempotency_result.dart';
import 'idempotency_status.dart';
import 'idempotency_store.dart';

/// High-level guard for idempotent event processing.
class IdempotencyGuard {
  final IdempotencyStore _store;
  final IdempotencyConfig _config;
  final String _instanceId;
  Timer? _cleanupTimer;

  IdempotencyGuard(
    this._store, {
    IdempotencyConfig? config,
    String? instanceId,
  })  : _config = config ?? const IdempotencyConfig(),
        _instanceId = instanceId ?? const Uuid().v4();

  /// Get the instance ID.
  String get instanceId => _instanceId;

  /// Process event with idempotency guarantee.
  Future<IdempotencyResult> process(
    ChannelEvent event,
    Future<IdempotencyResult> Function() processor,
  ) {
    return processWithKey(event.eventId, processor);
  }

  /// Process with a custom idempotency key.
  Future<IdempotencyResult> processWithKey(
    String key,
    Future<IdempotencyResult> Function() processor,
  ) async {
    // Check for existing record
    final existing = await _store.get(key);

    if (existing != null) {
      switch (existing.status) {
        case IdempotencyStatus.completed:
          // Return cached result
          return existing.result!;

        case IdempotencyStatus.failed:
          if (_config.retryFailed) {
            // Allow retry of failed events
            break;
          }
          return IdempotencyResult.failure(
            error: 'Event previously failed: ${existing.result?.error}',
          );

        case IdempotencyStatus.processing:
          // Check if lock is still valid
          if (existing.isLockValid) {
            // Still processing by another instance
            return IdempotencyResult.failure(
              error: 'Event is being processed by another instance',
            );
          }
          // Lock expired, allow retry
          break;

        case IdempotencyStatus.expired:
          // Allow reprocessing
          break;
      }
    }

    // Try to acquire lock
    final acquired = await _store.tryAcquire(
      key,
      lockHolder: _instanceId,
      lockTimeout: _config.lockTimeout,
      recordTtl: _config.recordTtl,
    );

    if (!acquired) {
      return IdempotencyResult.failure(
        error: 'Failed to acquire processing lock',
      );
    }

    try {
      // Process the event
      final result = await processor();

      // Store result
      await _store.complete(key, result);

      return result;
    } catch (e) {
      // Store failure
      final error = 'Processing error: $e';
      await _store.fail(key, error);

      return IdempotencyResult.failure(error: error);
    }
  }

  /// Check if an event has already been processed.
  Future<bool> isProcessed(String eventId) async {
    final record = await _store.get(eventId);
    return record != null && record.status == IdempotencyStatus.completed;
  }

  /// Get the result of a previously processed event.
  Future<IdempotencyResult?> getResult(String eventId) async {
    final record = await _store.get(eventId);
    if (record == null || record.status != IdempotencyStatus.completed) {
      return null;
    }
    return record.result;
  }

  /// Start periodic cleanup.
  void startCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_config.cleanupInterval, (_) async {
      await _store.cleanup();
    });
  }

  /// Stop periodic cleanup.
  void stopCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Manually trigger cleanup.
  Future<int> cleanup() {
    return _store.cleanup();
  }

  /// Dispose the guard.
  void dispose() {
    stopCleanup();
  }
}
