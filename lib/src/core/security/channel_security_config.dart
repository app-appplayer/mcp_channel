import 'audit_trail.dart';
import 'content_moderator.dart';
import 'credential_manager.dart';
import 'input_validator.dart';
import 'pii_protector.dart';

/// Configuration for security in ChannelHandler.
class ChannelSecurityConfig {
  const ChannelSecurityConfig({
    this.inputValidator,
    this.contentModerator,
    this.piiProtector,
    this.credentialManager,
    this.auditTrail,
  });

  /// Input validator -- applied before idempotency check.
  final ChannelInputValidator? inputValidator;

  /// Content moderator -- applied to inbound events and outbound responses.
  final ContentModerator? contentModerator;

  /// PII protector -- used for logging-safe serialization.
  final PiiProtector? piiProtector;

  /// Credential manager -- used by connectors for token management.
  final ChannelCredentialManager? credentialManager;

  /// Audit trail -- records security events.
  final ChannelAuditTrail? auditTrail;
}
