import 'dart:typed_data';

import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('AttachmentType', () {
    test('has all 5 values', () {
      expect(AttachmentType.values, hasLength(5));
      expect(AttachmentType.values, contains(AttachmentType.file));
      expect(AttachmentType.values, contains(AttachmentType.image));
      expect(AttachmentType.values, contains(AttachmentType.video));
      expect(AttachmentType.values, contains(AttachmentType.audio));
      expect(AttachmentType.values, contains(AttachmentType.document));
    });
  });

  group('Attachment', () {
    group('constructor', () {
      test('creates with required fields only', () {
        const att = Attachment(
          type: AttachmentType.file,
          name: 'data.csv',
        );

        expect(att.type, AttachmentType.file);
        expect(att.name, 'data.csv');
        expect(att.url, isNull);
        expect(att.data, isNull);
        expect(att.mimeType, isNull);
      });

      test('creates with all fields', () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final att = Attachment(
          type: AttachmentType.image,
          name: 'photo.png',
          url: 'https://example.com/photo.png',
          data: bytes,
          mimeType: 'image/png',
        );

        expect(att.type, AttachmentType.image);
        expect(att.name, 'photo.png');
        expect(att.url, 'https://example.com/photo.png');
        expect(att.data, bytes);
        expect(att.mimeType, 'image/png');
      });
    });

    group('fromUrl', () {
      test('creates attachment from URL with defaults', () {
        final att = Attachment.fromUrl(
          name: 'file.zip',
          url: 'https://example.com/file.zip',
        );

        expect(att.type, AttachmentType.file);
        expect(att.name, 'file.zip');
        expect(att.url, 'https://example.com/file.zip');
        expect(att.data, isNull);
        expect(att.mimeType, isNull);
      });

      test('creates attachment from URL with custom type and mimeType', () {
        final att = Attachment.fromUrl(
          name: 'song.mp3',
          url: 'https://example.com/song.mp3',
          type: AttachmentType.audio,
          mimeType: 'audio/mpeg',
        );

        expect(att.type, AttachmentType.audio);
        expect(att.name, 'song.mp3');
        expect(att.url, 'https://example.com/song.mp3');
        expect(att.mimeType, 'audio/mpeg');
      });
    });

    group('fromData', () {
      test('creates attachment from binary data with defaults', () {
        final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
        final att = Attachment.fromData(
          name: 'image.jpg',
          data: bytes,
        );

        expect(att.type, AttachmentType.file);
        expect(att.name, 'image.jpg');
        expect(att.data, bytes);
        expect(att.url, isNull);
        expect(att.mimeType, isNull);
      });

      test('creates attachment from binary data with custom type and mimeType', () {
        final bytes = Uint8List.fromList([0x00, 0x01, 0x02]);
        final att = Attachment.fromData(
          name: 'clip.mp4',
          data: bytes,
          type: AttachmentType.video,
          mimeType: 'video/mp4',
        );

        expect(att.type, AttachmentType.video);
        expect(att.name, 'clip.mp4');
        expect(att.data, bytes);
        expect(att.mimeType, 'video/mp4');
      });
    });

    group('image', () {
      test('creates image with default mimeType', () {
        final att = Attachment.image(
          name: 'screenshot.png',
          url: 'https://example.com/screenshot.png',
        );

        expect(att.type, AttachmentType.image);
        expect(att.name, 'screenshot.png');
        expect(att.url, 'https://example.com/screenshot.png');
        expect(att.mimeType, 'image/png');
      });

      test('creates image with custom mimeType', () {
        final att = Attachment.image(
          name: 'photo.jpg',
          url: 'https://example.com/photo.jpg',
          mimeType: 'image/jpeg',
        );

        expect(att.mimeType, 'image/jpeg');
      });

      test('creates image with data', () {
        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final att = Attachment.image(
          name: 'canvas.png',
          data: bytes,
        );

        expect(att.type, AttachmentType.image);
        expect(att.data, bytes);
        expect(att.mimeType, 'image/png');
        expect(att.url, isNull);
      });
    });

    group('document', () {
      test('creates document attachment from URL', () {
        final att = Attachment.document(
          name: 'report.pdf',
          url: 'https://example.com/report.pdf',
          mimeType: 'application/pdf',
        );

        expect(att.type, AttachmentType.document);
        expect(att.name, 'report.pdf');
        expect(att.url, 'https://example.com/report.pdf');
        expect(att.mimeType, 'application/pdf');
      });

      test('creates document attachment from data', () {
        final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
        final att = Attachment.document(
          name: 'invoice.pdf',
          data: bytes,
        );

        expect(att.type, AttachmentType.document);
        expect(att.name, 'invoice.pdf');
        expect(att.data, bytes);
        expect(att.mimeType, isNull);
      });
    });

    group('fromJson', () {
      test('deserializes with known type', () {
        final json = {
          'type': 'image',
          'name': 'photo.png',
          'url': 'https://example.com/photo.png',
          'mimeType': 'image/png',
        };

        final att = Attachment.fromJson(json);

        expect(att.type, AttachmentType.image);
        expect(att.name, 'photo.png');
        expect(att.url, 'https://example.com/photo.png');
        expect(att.mimeType, 'image/png');
        expect(att.data, isNull);
      });

      test('deserializes with unknown type falls back to file', () {
        final json = {
          'type': 'unknown_custom_type',
          'name': 'mystery.dat',
        };

        final att = Attachment.fromJson(json);

        expect(att.type, AttachmentType.file);
        expect(att.name, 'mystery.dat');
      });

      test('deserializes with required fields only', () {
        final json = {
          'type': 'audio',
          'name': 'podcast.mp3',
        };

        final att = Attachment.fromJson(json);

        expect(att.type, AttachmentType.audio);
        expect(att.name, 'podcast.mp3');
        expect(att.url, isNull);
        expect(att.mimeType, isNull);
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final original = Attachment.fromUrl(
          name: 'old.txt',
          url: 'https://example.com/old.txt',
          type: AttachmentType.file,
          mimeType: 'text/plain',
        );

        final bytes = Uint8List.fromList([1, 2, 3]);
        final copy = original.copyWith(
          type: AttachmentType.document,
          name: 'new.pdf',
          url: 'https://example.com/new.pdf',
          data: bytes,
          mimeType: 'application/pdf',
        );

        expect(copy.type, AttachmentType.document);
        expect(copy.name, 'new.pdf');
        expect(copy.url, 'https://example.com/new.pdf');
        expect(copy.data, bytes);
        expect(copy.mimeType, 'application/pdf');
      });

      test('copies with no fields changed preserves values', () {
        final original = Attachment.fromUrl(
          name: 'file.txt',
          url: 'https://example.com/file.txt',
          mimeType: 'text/plain',
        );

        final copy = original.copyWith();

        expect(copy.type, original.type);
        expect(copy.name, original.name);
        expect(copy.url, original.url);
        expect(copy.mimeType, original.mimeType);
      });
    });

    group('toJson', () {
      test('serializes with all serializable fields', () {
        final att = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/doc.pdf',
          type: AttachmentType.document,
          mimeType: 'application/pdf',
        );

        final json = att.toJson();

        expect(json['type'], 'document');
        expect(json['name'], 'doc.pdf');
        expect(json['url'], 'https://example.com/doc.pdf');
        expect(json['mimeType'], 'application/pdf');
      });

      test('data is not serialized to JSON', () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final att = Attachment.fromData(
          name: 'binary.dat',
          data: bytes,
        );

        final json = att.toJson();

        expect(json.containsKey('data'), isFalse);
      });

      test('omits null optional fields', () {
        const att = Attachment(
          type: AttachmentType.file,
          name: 'simple.txt',
        );

        final json = att.toJson();

        expect(json['type'], 'file');
        expect(json['name'], 'simple.txt');
        expect(json.containsKey('url'), isFalse);
        expect(json.containsKey('mimeType'), isFalse);
      });
    });

    group('equality', () {
      test('equal when same type, name, and url', () {
        final a = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/doc.pdf',
          type: AttachmentType.document,
        );
        final b = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/doc.pdf',
          type: AttachmentType.document,
        );

        expect(a == b, isTrue);
      });

      test('not equal when type differs', () {
        final a = Attachment.fromUrl(
          name: 'file.dat',
          url: 'https://example.com/file.dat',
          type: AttachmentType.file,
        );
        final b = Attachment.fromUrl(
          name: 'file.dat',
          url: 'https://example.com/file.dat',
          type: AttachmentType.document,
        );

        expect(a == b, isFalse);
      });

      test('not equal when name differs', () {
        final a = Attachment.fromUrl(
          name: 'a.txt',
          url: 'https://example.com/file',
        );
        final b = Attachment.fromUrl(
          name: 'b.txt',
          url: 'https://example.com/file',
        );

        expect(a == b, isFalse);
      });

      test('not equal when url differs', () {
        final a = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/a.pdf',
        );
        final b = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/b.pdf',
        );

        expect(a == b, isFalse);
      });

      test('not equal to different type object', () {
        final a = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/doc.pdf',
        );

        expect(a == 'not an attachment', isFalse);
      });

      test('identical objects are equal', () {
        final a = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/doc.pdf',
        );

        expect(a == a, isTrue);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        final a = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/doc.pdf',
        );
        final b = Attachment.fromUrl(
          name: 'doc.pdf',
          url: 'https://example.com/doc.pdf',
        );

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains type name and name', () {
        final att = Attachment.fromUrl(
          name: 'photo.jpg',
          url: 'https://example.com/photo.jpg',
          type: AttachmentType.image,
        );

        final str = att.toString();

        expect(str, contains('image'));
        expect(str, contains('photo.jpg'));
      });
    });
  });
}
