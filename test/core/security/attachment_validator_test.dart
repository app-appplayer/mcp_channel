import 'dart:typed_data';

import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('AttachmentValidationResult', () {
    group('sealed class pattern matching', () {
      test('allowed() creates AttachmentAllowed', () {
        final result = AttachmentValidationResult.allowed();

        expect(result, isA<AttachmentAllowed>());
      });

      test('rejected() creates AttachmentRejected with reason', () {
        final result = AttachmentValidationResult.rejected('too large');

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        expect(rejected.reason, 'too large');
      });

      test('exhaustive switch works on sealed hierarchy', () {
        final allowed = AttachmentValidationResult.allowed();
        final rejected = AttachmentValidationResult.rejected('blocked');

        final allowLabel = switch (allowed) {
          AttachmentAllowed() => 'allowed',
          AttachmentRejected(reason: final r) => 'rejected: $r',
        };

        final rejectLabel = switch (rejected) {
          AttachmentAllowed() => 'allowed',
          AttachmentRejected(reason: final r) => 'rejected: $r',
        };

        expect(allowLabel, 'allowed');
        expect(rejectLabel, 'rejected: blocked');
      });
    });
  });

  group('AttachmentValidator', () {
    late AttachmentValidator validator;

    setUp(() {
      validator = const AttachmentValidator();
    });

    group('default config', () {
      test('has expected default values', () {
        expect(validator.maxFileSize, 10 * 1024 * 1024);
        expect(validator.allowedMimeTypes, isEmpty);
        expect(
          validator.blockedMimeTypes,
          {
            'application/x-executable',
            'application/x-msdownload',
            'application/x-sh',
          },
        );
      });
    });

    group('allows valid attachments', () {
      test('allows a normal text file within size limit', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'document.txt',
          mimeType: 'text/plain',
          data: Uint8List(1024),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });

      test('allows attachment without data', () {
        const attachment = Attachment(
          type: AttachmentType.file,
          name: 'remote.csv',
          url: 'https://example.com/data.csv',
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });

      test('allows attachment without mimeType', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'data.bin',
          data: Uint8List(2048),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });
    });

    group('file size validation', () {
      test('rejects file larger than default 10 MB', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'large.zip',
          data: Uint8List(10 * 1024 * 1024 + 1),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        expect(rejected.reason, contains('exceeds maximum'));
      });

      test('allows file exactly at maxFileSize', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'exact.zip',
          data: Uint8List(10 * 1024 * 1024),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });

      test('rejects with custom maxFileSize', () {
        const customValidator = AttachmentValidator(maxFileSize: 100);

        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'small.txt',
          data: Uint8List(101),
        );

        final result = customValidator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        expect(rejected.reason, contains('100'));
      });

      test('skips size check when data is null', () {
        const smallValidator = AttachmentValidator(maxFileSize: 10);

        // URL-only attachment with no data - size check is skipped
        const attachment = Attachment(
          type: AttachmentType.file,
          name: 'huge.bin',
          url: 'https://example.com/huge.bin',
        );

        final result = smallValidator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });
    });

    group('blocked MIME types', () {
      test('rejects application/x-executable', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'program.bin',
          mimeType: 'application/x-executable',
          data: Uint8List(1024),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        expect(rejected.reason, contains('application/x-executable'));
      });

      test('rejects application/x-msdownload', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'installer.exe',
          mimeType: 'application/x-msdownload',
          data: Uint8List(1024),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        expect(rejected.reason, contains('application/x-msdownload'));
      });

      test('rejects application/x-sh', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'script.sh',
          mimeType: 'application/x-sh',
          data: Uint8List(1024),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        expect(rejected.reason, contains('application/x-sh'));
      });
    });

    group('allowed MIME types', () {
      test('allows non-blocked MIME type', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'notes.txt',
          mimeType: 'text/plain',
          data: Uint8List(1024),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });

      test('allows image/png', () {
        final attachment = Attachment(
          type: AttachmentType.image,
          name: 'photo.png',
          mimeType: 'image/png',
          data: Uint8List(4096),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });

      test('allows application/pdf', () {
        final attachment = Attachment(
          type: AttachmentType.document,
          name: 'document.pdf',
          mimeType: 'application/pdf',
          data: Uint8List(2048),
        );

        final result = validator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });
    });

    group('allowedMimeTypes whitelist mode', () {
      const whitelistValidator = AttachmentValidator(
        allowedMimeTypes: {'text/plain', 'application/pdf'},
        blockedMimeTypes: {},
      );

      test('allows MIME type in the whitelist', () {
        final attachment = Attachment(
          type: AttachmentType.document,
          name: 'document.pdf',
          mimeType: 'application/pdf',
          data: Uint8List(1024),
        );

        final result = whitelistValidator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });

      test('rejects MIME type not in the whitelist', () {
        final attachment = Attachment(
          type: AttachmentType.image,
          name: 'photo.png',
          mimeType: 'image/png',
          data: Uint8List(1024),
        );

        final result = whitelistValidator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        expect(rejected.reason, contains('not in allowed list'));
      });

      test('allows attachment without mimeType even in whitelist mode', () {
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'data.txt',
          data: Uint8List(1024),
        );

        final result = whitelistValidator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });

      test('blocked MIME types take precedence over allowed', () {
        const strictValidator = AttachmentValidator(
          allowedMimeTypes: {'text/plain', 'application/x-executable'},
          blockedMimeTypes: {'application/x-executable'},
        );

        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'program.bin',
          mimeType: 'application/x-executable',
          data: Uint8List(1024),
        );

        final result = strictValidator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        expect(rejected.reason, contains('not allowed'));
      });
    });

    group('validation priority order', () {
      test('size is checked before MIME type', () {
        const smallValidator = AttachmentValidator(maxFileSize: 10);

        // File is both too large and has blocked MIME type
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'payload.bin',
          mimeType: 'application/x-executable',
          data: Uint8List(100),
        );

        final result = smallValidator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
        final rejected = result as AttachmentRejected;
        // Size check comes first
        expect(rejected.reason, contains('exceeds maximum'));
      });
    });

    group('custom configuration', () {
      test('custom config with strict size limit', () {
        const strictValidator = AttachmentValidator(
          maxFileSize: 1024,
          allowedMimeTypes: {'application/json', 'text/yaml'},
          blockedMimeTypes: {},
        );

        // Allowed: correct size and MIME type
        final allowedAttachment = Attachment(
          type: AttachmentType.file,
          name: 'config.json',
          mimeType: 'application/json',
          data: Uint8List(512),
        );
        expect(strictValidator.validate(allowedAttachment),
            isA<AttachmentAllowed>());

        // Rejected: exceeds size limit
        final largeAttachment = Attachment(
          type: AttachmentType.file,
          name: 'large.json',
          mimeType: 'application/json',
          data: Uint8List(2048),
        );
        expect(strictValidator.validate(largeAttachment),
            isA<AttachmentRejected>());

        // Rejected: MIME type not in whitelist
        final wrongMimeAttachment = Attachment(
          type: AttachmentType.file,
          name: 'data.json',
          mimeType: 'text/html',
          data: Uint8List(100),
        );
        expect(strictValidator.validate(wrongMimeAttachment),
            isA<AttachmentRejected>());
      });

      test('custom config with zero-size limit rejects all files with data',
          () {
        const zeroSizeValidator = AttachmentValidator(maxFileSize: 0);

        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'tiny.txt',
          data: Uint8List(1),
        );

        final result = zeroSizeValidator.validate(attachment);

        expect(result, isA<AttachmentRejected>());
      });

      test('custom config with empty blocked list allows everything', () {
        const permissiveValidator = AttachmentValidator(
          blockedMimeTypes: {},
        );

        // Even executable MIME type is allowed when not blocked
        final attachment = Attachment(
          type: AttachmentType.file,
          name: 'program.bin',
          mimeType: 'application/x-executable',
          data: Uint8List(1024),
        );

        final result = permissiveValidator.validate(attachment);

        expect(result, isA<AttachmentAllowed>());
      });
    });
  });
}
