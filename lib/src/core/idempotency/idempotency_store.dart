import 'idempotency_record.dart';
import 'idempotency_result.dart';
import 'idempotency_status.dart';

/// Interface for idempotency record storage.
abstract class IdempotencyStore {
  /// Check if event exists and get record.
  Future<IdempotencyRecord?> get(String eventId);

  /// Try to acquire processing lock.
  /// Returns true if lock acquired, false if already exists.
  Future<bool> tryAcquire(
    String eventId, {
    required String lockHolder,
    required Duration lockTimeout,
    required Duration recordTtl,
  });

  /// Complete processing and store result.
  Future<void> complete(
    String eventId,
    IdempotencyResult result,
  );

  /// Mark processing as failed.
  Future<void> fail(
    String eventId,
    String error,
  );

  /// Release lock without completing.
  Future<void> release(String eventId);

  /// Clean up expired records.
  Future<int> cleanup();
}

/// In-memory implementation of IdempotencyStore.
class InMemoryIdempotencyStore implements IdempotencyStore {
  final Map<String, IdempotencyRecord> _records = {};

  @override
  Future<IdempotencyRecord?> get(String eventId) async {
    final record = _records[eventId];
    if (record == null) return null;

    // Check expiration
    if (record.isExpired) {
      _records.remove(eventId);
      return null;
    }

    return record;
  }

  @override
  Future<bool> tryAcquire(
    String eventId, {
    required String lockHolder,
    required Duration lockTimeout,
    required Duration recordTtl,
  }) async {
    final existing = _records[eventId];

    // Check if already processing with valid lock
    if (existing != null &&
        existing.status == IdempotencyStatus.processing &&
        existing.isLockValid) {
      return false;
    }

    // Acquire lock
    final now = DateTime.now();
    _records[eventId] = IdempotencyRecord(
      eventId: eventId,
      status: IdempotencyStatus.processing,
      createdAt: now,
      expiresAt: now.add(recordTtl),
      lockHolder: lockHolder,
      lockExpiresAt: now.add(lockTimeout),
    );

    return true;
  }

  @override
  Future<void> complete(
    String eventId,
    IdempotencyResult result,
  ) async {
    final existing = _records[eventId];
    if (existing == null) return;

    _records[eventId] = IdempotencyRecord(
      eventId: eventId,
      status: IdempotencyStatus.completed,
      result: result,
      createdAt: existing.createdAt,
      completedAt: DateTime.now(),
      expiresAt: existing.expiresAt,
    );
  }

  @override
  Future<void> fail(String eventId, String error) async {
    final existing = _records[eventId];
    if (existing == null) return;

    _records[eventId] = IdempotencyRecord(
      eventId: eventId,
      status: IdempotencyStatus.failed,
      result: IdempotencyResult.failure(error: error),
      createdAt: existing.createdAt,
      completedAt: DateTime.now(),
      expiresAt: existing.expiresAt,
    );
  }

  @override
  Future<void> release(String eventId) async {
    _records.remove(eventId);
  }

  @override
  Future<int> cleanup() async {
    final now = DateTime.now();
    final expired = _records.entries
        .where((e) => now.isAfter(e.value.expiresAt))
        .map((e) => e.key)
        .toList();

    for (final id in expired) {
      _records.remove(id);
    }

    return expired.length;
  }

  /// Clear all records (for testing).
  void clear() {
    _records.clear();
  }

  /// Get total record count.
  int get count => _records.length;
}
