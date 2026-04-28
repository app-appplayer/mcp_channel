import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

/// Simple test validator.
class _TestValidator implements ChannelInputValidator {
  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    return const AllowResult();
  }
}

/// Simple test moderator.
class _TestModerator implements ContentModerator {
  @override
  Future<ModerationResult> moderateInbound(ChannelEvent event) async {
    return ModerationResult(action: ModerationAction.allow);
  }

  @override
  Future<ModerationResult> moderateOutbound(ChannelResponse response) async {
    return ModerationResult(action: ModerationAction.allow);
  }
}

/// Simple test PII protector.
class _TestPiiProtector implements PiiProtector {
  @override
  List<PiiDetection> detectPii(String text) => [];

  @override
  ChannelEvent protectEvent(ChannelEvent event) => event;

  @override
  ChannelResponse protectResponse(ChannelResponse response) => response;
}

/// Simple test audit trail.
class _TestAuditTrail extends InMemoryAuditTrail {}

void main() {
  group('ChannelSecurityConfig', () {
    test('creates with all null (defaults)', () {
      const config = ChannelSecurityConfig();
      expect(config.inputValidator, isNull);
      expect(config.contentModerator, isNull);
      expect(config.piiProtector, isNull);
      expect(config.credentialManager, isNull);
      expect(config.auditTrail, isNull);
    });

    test('creates with all components', () {
      final config = ChannelSecurityConfig(
        inputValidator: _TestValidator(),
        contentModerator: _TestModerator(),
        piiProtector: _TestPiiProtector(),
        credentialManager: InMemoryCredentialManager(),
        auditTrail: _TestAuditTrail(),
      );

      expect(config.inputValidator, isNotNull);
      expect(config.contentModerator, isNotNull);
      expect(config.piiProtector, isNotNull);
      expect(config.credentialManager, isNotNull);
      expect(config.auditTrail, isNotNull);
    });

    test('components are independently optional', () {
      final config = ChannelSecurityConfig(
        inputValidator: _TestValidator(),
      );

      expect(config.inputValidator, isNotNull);
      expect(config.contentModerator, isNull);
      expect(config.piiProtector, isNull);
    });
  });
}
