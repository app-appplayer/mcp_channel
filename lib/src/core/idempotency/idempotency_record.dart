import 'package:meta/meta.dart';

import 'idempotency_result.dart';
import 'idempotency_status.dart';

/// Record of an idempotent operation.
@immutable
class IdempotencyRecord {
  const IdempotencyRecord({
    required this.eventId,
    required this.status,
    this.result,
    required this.createdAt,
    this.completedAt,
    required this.expiresAt,
    this.lockHolder,
    this.lockExpiresAt,
  });

  factory IdempotencyRecord.fromJson(Map<String, dynamic> json) {
    return IdempotencyRecord(
      eventId: json['eventId'] as String,
      status: IdempotencyStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => IdempotencyStatus.expired,
      ),
      result: json['result'] != null
          ? IdempotencyResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      lockHolder: json['lockHolder'] as String?,
      lockExpiresAt: json['lockExpiresAt'] != null
          ? DateTime.parse(json['lockExpiresAt'] as String)
          : null,
    );
  }

  /// Event ID (unique key)
  final String eventId;

  /// Record status
  final IdempotencyStatus status;

  /// Processing result (if completed)
  final IdempotencyResult? result;

  /// Creation timestamp
  final DateTime createdAt;

  /// Completion timestamp
  final DateTime? completedAt;

  /// Expiration timestamp
  final DateTime expiresAt;

  /// Lock holder ID (for distributed processing)
  final String? lockHolder;

  /// Lock expiration
  final DateTime? lockExpiresAt;

  /// Check if the lock is still valid.
  bool get isLockValid =>
      lockExpiresAt != null && DateTime.now().isBefore(lockExpiresAt!);

  /// Check if the record is expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  IdempotencyRecord copyWith({
    String? eventId,
    IdempotencyStatus? status,
    IdempotencyResult? result,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? expiresAt,
    String? lockHolder,
    DateTime? lockExpiresAt,
  }) {
    return IdempotencyRecord(
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lockHolder: lockHolder ?? this.lockHolder,
      lockExpiresAt: lockExpiresAt ?? this.lockExpiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'status': status.name,
        if (result != null) 'result': result!.toJson(),
        'createdAt': createdAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        if (lockHolder != null) 'lockHolder': lockHolder,
        if (lockExpiresAt != null)
          'lockExpiresAt': lockExpiresAt!.toIso8601String(),
      };

  @override
  String toString() =>
      'IdempotencyRecord(eventId: $eventId, status: ${status.name})';
}
