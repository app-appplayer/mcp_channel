import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('FileInfo', () {
    group('constructor', () {
      test('creates FileInfo with required fields only', () {
        const info = FileInfo(id: 'f1', name: 'report.pdf');

        expect(info.id, 'f1');
        expect(info.name, 'report.pdf');
        expect(info.mimeType, isNull);
        expect(info.size, isNull);
        expect(info.url, isNull);
        expect(info.thumbnailUrl, isNull);
      });

      test('creates FileInfo with all fields', () {
        const info = FileInfo(
          id: 'f2',
          name: 'photo.png',
          mimeType: 'image/png',
          size: 2048,
          url: 'https://example.com/photo.png',
          thumbnailUrl: 'https://example.com/photo_thumb.png',
        );

        expect(info.id, 'f2');
        expect(info.name, 'photo.png');
        expect(info.mimeType, 'image/png');
        expect(info.size, 2048);
        expect(info.url, 'https://example.com/photo.png');
        expect(info.thumbnailUrl, 'https://example.com/photo_thumb.png');
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        const original = FileInfo(
          id: 'f1',
          name: 'old.txt',
          mimeType: 'text/plain',
          size: 100,
          url: 'https://example.com/old.txt',
          thumbnailUrl: 'https://example.com/old_thumb.png',
        );

        final copy = original.copyWith(
          id: 'f2',
          name: 'new.txt',
          mimeType: 'text/csv',
          size: 200,
          url: 'https://example.com/new.txt',
          thumbnailUrl: 'https://example.com/new_thumb.png',
        );

        expect(copy.id, 'f2');
        expect(copy.name, 'new.txt');
        expect(copy.mimeType, 'text/csv');
        expect(copy.size, 200);
        expect(copy.url, 'https://example.com/new.txt');
        expect(copy.thumbnailUrl, 'https://example.com/new_thumb.png');
      });

      test('copies with partial fields changed', () {
        const original = FileInfo(
          id: 'f1',
          name: 'report.pdf',
          mimeType: 'application/pdf',
          size: 1024,
          url: 'https://example.com/report.pdf',
          thumbnailUrl: 'https://example.com/report_thumb.png',
        );

        final copy = original.copyWith(name: 'updated_report.pdf');

        expect(copy.id, 'f1');
        expect(copy.name, 'updated_report.pdf');
        expect(copy.mimeType, 'application/pdf');
        expect(copy.size, 1024);
        expect(copy.url, 'https://example.com/report.pdf');
        expect(copy.thumbnailUrl, 'https://example.com/report_thumb.png');
      });

      test('copies with no fields changed returns equivalent object', () {
        const original = FileInfo(id: 'f1', name: 'doc.pdf');
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.name, original.name);
      });
    });

    group('toJson', () {
      test('serializes with all fields present', () {
        const info = FileInfo(
          id: 'f1',
          name: 'image.png',
          mimeType: 'image/png',
          size: 4096,
          url: 'https://example.com/image.png',
          thumbnailUrl: 'https://example.com/image_thumb.png',
        );

        final json = info.toJson();

        expect(json['id'], 'f1');
        expect(json['name'], 'image.png');
        expect(json['mimeType'], 'image/png');
        expect(json['size'], 4096);
        expect(json['url'], 'https://example.com/image.png');
        expect(json['thumbnailUrl'], 'https://example.com/image_thumb.png');
      });

      test('omits null optional fields', () {
        const info = FileInfo(id: 'f1', name: 'doc.txt');

        final json = info.toJson();

        expect(json['id'], 'f1');
        expect(json['name'], 'doc.txt');
        expect(json.containsKey('mimeType'), isFalse);
        expect(json.containsKey('size'), isFalse);
        expect(json.containsKey('url'), isFalse);
        expect(json.containsKey('thumbnailUrl'), isFalse);
      });
    });

    group('fromJson', () {
      test('deserializes with all fields', () {
        final json = {
          'id': 'f1',
          'name': 'video.mp4',
          'mimeType': 'video/mp4',
          'size': 10240,
          'url': 'https://example.com/video.mp4',
          'thumbnailUrl': 'https://example.com/video_thumb.jpg',
        };

        final info = FileInfo.fromJson(json);

        expect(info.id, 'f1');
        expect(info.name, 'video.mp4');
        expect(info.mimeType, 'video/mp4');
        expect(info.size, 10240);
        expect(info.url, 'https://example.com/video.mp4');
        expect(info.thumbnailUrl, 'https://example.com/video_thumb.jpg');
      });

      test('deserializes with required fields only', () {
        final json = {'id': 'f1', 'name': 'data.csv'};

        final info = FileInfo.fromJson(json);

        expect(info.id, 'f1');
        expect(info.name, 'data.csv');
        expect(info.mimeType, isNull);
        expect(info.size, isNull);
        expect(info.url, isNull);
        expect(info.thumbnailUrl, isNull);
      });

      test('round-trip serialization preserves all fields', () {
        const original = FileInfo(
          id: 'f1',
          name: 'archive.zip',
          mimeType: 'application/zip',
          size: 99999,
          url: 'https://example.com/archive.zip',
          thumbnailUrl: 'https://example.com/archive_thumb.png',
        );

        final restored = FileInfo.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.mimeType, original.mimeType);
        expect(restored.size, original.size);
        expect(restored.url, original.url);
        expect(restored.thumbnailUrl, original.thumbnailUrl);
      });
    });

    group('equality', () {
      test('equal when same id and name', () {
        const a = FileInfo(id: 'f1', name: 'doc.pdf');
        const b = FileInfo(id: 'f1', name: 'doc.pdf');

        expect(a == b, isTrue);
      });

      test('equal even when optional fields differ', () {
        const a = FileInfo(id: 'f1', name: 'doc.pdf', mimeType: 'a/b');
        const b = FileInfo(id: 'f1', name: 'doc.pdf', size: 999);

        expect(a == b, isTrue);
      });

      test('not equal when id differs', () {
        const a = FileInfo(id: 'f1', name: 'doc.pdf');
        const b = FileInfo(id: 'f2', name: 'doc.pdf');

        expect(a == b, isFalse);
      });

      test('not equal when name differs', () {
        const a = FileInfo(id: 'f1', name: 'doc.pdf');
        const b = FileInfo(id: 'f1', name: 'other.pdf');

        expect(a == b, isFalse);
      });

      test('not equal to a different type', () {
        const a = FileInfo(id: 'f1', name: 'doc.pdf');

        expect(a == 'not a FileInfo', isFalse);
      });

      test('identical objects are equal', () {
        const a = FileInfo(id: 'f1', name: 'doc.pdf');

        expect(a == a, isTrue);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        const a = FileInfo(id: 'f1', name: 'doc.pdf');
        const b = FileInfo(id: 'f1', name: 'doc.pdf');

        expect(a.hashCode, equals(b.hashCode));
      });

      test('different objects may have different hashCode', () {
        const a = FileInfo(id: 'f1', name: 'doc.pdf');
        const b = FileInfo(id: 'f2', name: 'other.pdf');

        // Not guaranteed but typically true
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });
    });

    group('toString', () {
      test('includes id, name, and mimeType', () {
        const info = FileInfo(
          id: 'f1',
          name: 'report.pdf',
          mimeType: 'application/pdf',
        );

        final str = info.toString();

        expect(str, contains('f1'));
        expect(str, contains('report.pdf'));
        expect(str, contains('application/pdf'));
      });

      test('shows null mimeType when not set', () {
        const info = FileInfo(id: 'f1', name: 'doc.txt');

        final str = info.toString();

        expect(str, contains('f1'));
        expect(str, contains('doc.txt'));
        expect(str, contains('null'));
      });
    });
  });
}
