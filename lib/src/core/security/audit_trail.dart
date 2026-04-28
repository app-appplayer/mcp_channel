import 'package:meta/meta.dart';

/// Audit action categories.
enum AuditAction {
  /// Message sent or received.
  messageSendReceive,

  /// Authentication attempt (connect, token refresh).
  authentication,

  /// Authorization check (allowed or denied).
  authorization,

  /// Content moderation action.
  contentModeration,

  /// Session lifecycle (create, expire, migrate).
  sessionLifecycle,

  /// Credential operation (refresh, rotate).
  credentialOperation,

  /// Input validation (reject, sanitize).
  inputValidation,

  /// Configuration change.
  configurationChange,

  /// Error or security event.
  securityEvent,
}

/// Outcome of an audited action.
enum AuditOutcome {
  success,
  failure,
  denied,
  error,
}

/// An immutable audit record.
@immutable
class AuditRecord {
  const AuditRecord({
    required this.actor,
    required this.action,
    required this.resource,
    required this.outcome,
    required this.timestamp,
    this.context,
    this.correlationId,
  });

  /// Who performed the action (user ID, system, bot).
  final String actor;

  /// What action was performed.
  final AuditAction action;

  /// What resource was affected.
  final String resource;

  /// The outcome of the action.
  final AuditOutcome outcome;

  /// When the action occurred.
  final DateTime timestamp;

  /// Additional context (platform, session ID, etc.).
  final Map<String, dynamic>? context;

  /// Correlation ID linking to the event trace.
  final String? correlationId;
}

/// Records security-relevant events for compliance and forensics.
///
/// All audit records are immutable and append-only. The application
/// provides the storage backend (database, log file, SIEM, etc.).
abstract interface class ChannelAuditTrail {
  /// Record an audit event.
  Future<void> recordEvent(AuditRecord record);

  /// Query audit records (for review/investigation).
  Future<List<AuditRecord>> query({
    String? actor,
    String? action,
    DateTime? after,
    DateTime? before,
    int limit = 100,
  });
}

/// In-memory audit trail for testing.
class InMemoryAuditTrail implements ChannelAuditTrail {
  final List<AuditRecord> _records = [];

  /// All recorded audit records.
  List<AuditRecord> get records => List.unmodifiable(_records);

  @override
  Future<void> recordEvent(AuditRecord record) async {
    _records.add(record);
  }

  @override
  Future<List<AuditRecord>> query({
    String? actor,
    String? action,
    DateTime? after,
    DateTime? before,
    int limit = 100,
  }) async {
    final filtered = _records.where((r) {
      if (actor != null && r.actor != actor) return false;
      if (action != null && r.action.name != action) return false;
      if (after != null && r.timestamp.isBefore(after)) return false;
      if (before != null && r.timestamp.isAfter(before)) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }

  /// Clear all records (for testing).
  void clear() => _records.clear();
}
