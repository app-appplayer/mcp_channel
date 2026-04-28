import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

/// Helper to create a test ChannelEvent with the given text.
ChannelEvent _testEvent(String text) {
  return ChannelEvent.message(
    id: 'test-${text.hashCode}',
    conversation: const ConversationKey(
      channel: ChannelIdentity(platform: 'test', channelId: 'ch1'),
      conversationId: 'conv1',
      userId: 'u1',
    ),
    text: text,
  );
}

/// Helper to create a test ChannelResponse with the given text.
ChannelResponse _testResponse(String text) {
  return ChannelResponse.text(
    conversation: const ConversationKey(
      channel: ChannelIdentity(platform: 'test', channelId: 'ch1'),
      conversationId: 'conv1',
      userId: 'u1',
    ),
    text: text,
  );
}

/// Test helper: a validator that always allows the event.
class _AllowValidator implements ChannelInputValidator {
  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    return ValidationResult.allow();
  }
}

/// Test helper: a validator that sanitizes by uppercasing the event text.
class _UpperCaseSanitizer implements ChannelInputValidator {
  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    final upperText = event.text?.toUpperCase() ?? '';
    final sanitized = _testEvent(upperText);
    return ValidationResult.sanitize(sanitized);
  }
}

/// Test helper: a validator that strips HTML angle brackets from event text.
class _StripBracketsSanitizer implements ChannelInputValidator {
  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    final text = event.text ?? '';
    final sanitized = text.replaceAll(RegExp(r'[<>]'), '');
    if (sanitized != text) {
      return ValidationResult.sanitize(_testEvent(sanitized));
    }
    return ValidationResult.allow();
  }
}

/// Test helper: a validator that always rejects with the given reason.
class _RejectValidator implements ChannelInputValidator {
  const _RejectValidator(this.reason, {this.rejectionResponse});

  final String reason;
  final ChannelResponse? rejectionResponse;

  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    return ValidationResult.reject(
      reason: reason,
      rejectionResponse: rejectionResponse,
    );
  }
}

/// Test helper: a validator that rejects events containing a forbidden word.
class _ForbiddenWordValidator implements ChannelInputValidator {
  const _ForbiddenWordValidator(this.forbidden);

  final String forbidden;

  @override
  Future<ValidationResult> validateEvent(ChannelEvent event) async {
    final text = event.text ?? '';
    if (text.contains(forbidden)) {
      return ValidationResult.reject(
        reason: 'contains forbidden word: $forbidden',
      );
    }
    return ValidationResult.allow();
  }
}

void main() {
  // TC-067: InputValidator tests
  group('ValidationResult', () {
    group('AllowResult', () {
      test('factory creates AllowResult instance', () {
        final result = ValidationResult.allow();

        expect(result, isA<AllowResult>());
      });
    });

    group('SanitizeResult', () {
      test('factory creates SanitizeResult with sanitizedEvent', () {
        final event = _testEvent('cleaned text');
        final result = ValidationResult.sanitize(event);

        expect(result, isA<SanitizeResult>());
        expect(
          (result as SanitizeResult).sanitizedEvent.text,
          equals('cleaned text'),
        );
      });

      test('sanitizedEvent preserves full event structure', () {
        final event = _testEvent('sanitized content');
        final result = ValidationResult.sanitize(event);

        final sanitized = (result as SanitizeResult).sanitizedEvent;
        expect(sanitized.conversation.channel.platform, equals('test'));
        expect(sanitized.conversation.conversationId, equals('conv1'));
        expect(sanitized.type, equals('message'));
      });
    });

    group('RejectResult', () {
      test('factory creates RejectResult with reason', () {
        final result = ValidationResult.reject(reason: 'too long');

        expect(result, isA<RejectResult>());
        expect((result as RejectResult).reason, equals('too long'));
      });

      test('rejectionResponse is null by default', () {
        final result = ValidationResult.reject(reason: 'invalid');

        expect((result as RejectResult).rejectionResponse, isNull);
      });

      test('rejectionResponse can be provided', () {
        final response = _testResponse('Your input was rejected.');
        final result = ValidationResult.reject(
          reason: 'malicious content',
          rejectionResponse: response,
        );

        final reject = result as RejectResult;
        expect(reject.reason, equals('malicious content'));
        expect(reject.rejectionResponse, isNotNull);
        expect(reject.rejectionResponse!.text, equals('Your input was rejected.'));
      });
    });

    group('pattern matching', () {
      test('matches all three sealed subtypes exhaustively', () {
        final event = _testEvent('safe');
        final allow = ValidationResult.allow();
        final sanitize = ValidationResult.sanitize(event);
        final reject = ValidationResult.reject(reason: 'bad');

        // Pattern match on AllowResult
        final allowLabel = switch (allow) {
          AllowResult() => 'allowed',
          SanitizeResult() => 'sanitized',
          RejectResult() => 'rejected',
        };
        expect(allowLabel, equals('allowed'));

        // Pattern match on SanitizeResult with field extraction
        final sanitizeLabel = switch (sanitize) {
          AllowResult() => 'allowed',
          SanitizeResult(:final sanitizedEvent) =>
            'sanitized:${sanitizedEvent.text}',
          RejectResult() => 'rejected',
        };
        expect(sanitizeLabel, equals('sanitized:safe'));

        // Pattern match on RejectResult with field extraction
        final rejectLabel = switch (reject) {
          AllowResult() => 'allowed',
          SanitizeResult() => 'sanitized',
          RejectResult(:final reason) => 'rejected:$reason',
        };
        expect(rejectLabel, equals('rejected:bad'));
      });

      test('extracts rejectionResponse from RejectResult via pattern', () {
        final response = _testResponse('Not allowed.');
        final result = ValidationResult.reject(
          reason: 'blocked',
          rejectionResponse: response,
        );

        final extracted = switch (result) {
          AllowResult() => null,
          SanitizeResult() => null,
          RejectResult(:final rejectionResponse) => rejectionResponse?.text,
        };
        expect(extracted, equals('Not allowed.'));
      });
    });
  });

  group('ChannelInputValidator', () {
    test('custom validator returning allow', () async {
      final validator = _AllowValidator();

      final result = await validator.validateEvent(_testEvent('hello world'));

      expect(result, isA<AllowResult>());
    });

    test('custom validator returning sanitize with event', () async {
      final validator = _StripBracketsSanitizer();

      final result = await validator.validateEvent(
        _testEvent('<script>alert("xss")</script>'),
      );

      expect(result, isA<SanitizeResult>());
      expect(
        (result as SanitizeResult).sanitizedEvent.text,
        equals('scriptalert("xss")/script'),
      );
    });

    test('custom validator returning sanitize preserves event type', () async {
      final validator = _UpperCaseSanitizer();

      final result = await validator.validateEvent(_testEvent('hello'));

      expect(result, isA<SanitizeResult>());
      final sanitizedEvent = (result as SanitizeResult).sanitizedEvent;
      expect(sanitizedEvent.text, equals('HELLO'));
      expect(sanitizedEvent.type, equals('message'));
    });

    test('custom validator returning reject', () async {
      const validator = _RejectValidator('input is malicious');

      final result = await validator.validateEvent(_testEvent('anything'));

      expect(result, isA<RejectResult>());
      expect(
        (result as RejectResult).reason,
        equals('input is malicious'),
      );
    });

    test('custom validator returning reject with response', () async {
      final response = _testResponse('Rejected.');
      final validator = _RejectValidator(
        'policy violation',
        rejectionResponse: response,
      );

      final result = await validator.validateEvent(_testEvent('bad content'));

      expect(result, isA<RejectResult>());
      final reject = result as RejectResult;
      expect(reject.reason, equals('policy violation'));
      expect(reject.rejectionResponse?.text, equals('Rejected.'));
    });

    test('forbidden word validator rejects matching input', () async {
      const validator = _ForbiddenWordValidator('alert');

      final result = await validator.validateEvent(
        _testEvent('<alert>danger</alert>'),
      );

      expect(result, isA<RejectResult>());
      expect(
        (result as RejectResult).reason,
        equals('contains forbidden word: alert'),
      );
    });

    test('forbidden word validator allows non-matching input', () async {
      const validator = _ForbiddenWordValidator('alert');

      final result = await validator.validateEvent(
        _testEvent('safe content here'),
      );

      expect(result, isA<AllowResult>());
    });

    test('sanitizer allows clean input unchanged', () async {
      final validator = _StripBracketsSanitizer();

      final result = await validator.validateEvent(
        _testEvent('no brackets here'),
      );

      expect(result, isA<AllowResult>());
    });
  });
}
