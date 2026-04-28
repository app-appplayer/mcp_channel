import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('Embed', () {
    group('constructor', () {
      test('creates with all fields', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30);
        final fields = [
          const EmbedField(name: 'Key', value: 'Val', inline: true),
        ];

        final embed = Embed(
          title: 'Title',
          description: 'Description',
          url: 'https://example.com',
          color: '#FF0000',
          imageUrl: 'https://example.com/image.png',
          thumbnailUrl: 'https://example.com/thumb.png',
          author: 'Author',
          footer: 'Footer',
          timestamp: timestamp,
          fields: fields,
        );

        expect(embed.title, 'Title');
        expect(embed.description, 'Description');
        expect(embed.url, 'https://example.com');
        expect(embed.color, '#FF0000');
        expect(embed.imageUrl, 'https://example.com/image.png');
        expect(embed.thumbnailUrl, 'https://example.com/thumb.png');
        expect(embed.author, 'Author');
        expect(embed.footer, 'Footer');
        expect(embed.timestamp, timestamp);
        expect(embed.fields, hasLength(1));
      });

      test('creates with no fields (all null)', () {
        const embed = Embed();

        expect(embed.title, isNull);
        expect(embed.description, isNull);
        expect(embed.url, isNull);
        expect(embed.color, isNull);
        expect(embed.imageUrl, isNull);
        expect(embed.thumbnailUrl, isNull);
        expect(embed.author, isNull);
        expect(embed.footer, isNull);
        expect(embed.timestamp, isNull);
        expect(embed.fields, isNull);
      });

      test('creates with empty fields list', () {
        const embed = Embed(
          title: 'Title',
          description: 'Desc',
          fields: [],
        );

        expect(embed.fields, isEmpty);
      });
    });

    group('fromJson', () {
      test('deserializes with all fields', () {
        final json = {
          'title': 'Title',
          'description': 'Desc',
          'url': 'https://example.com',
          'color': '#00FF00',
          'imageUrl': 'https://example.com/img.png',
          'thumbnailUrl': 'https://example.com/thumb.png',
          'author': 'Author',
          'footer': 'Footer',
          'timestamp': '2024-01-15T10:30:00.000',
          'fields': [
            {'name': 'Key', 'value': 'Val', 'inline': true},
          ],
        };

        final embed = Embed.fromJson(json);

        expect(embed.title, 'Title');
        expect(embed.description, 'Desc');
        expect(embed.url, 'https://example.com');
        expect(embed.color, '#00FF00');
        expect(embed.imageUrl, 'https://example.com/img.png');
        expect(embed.thumbnailUrl, 'https://example.com/thumb.png');
        expect(embed.author, 'Author');
        expect(embed.footer, 'Footer');
        expect(embed.timestamp, DateTime(2024, 1, 15, 10, 30));
        expect(embed.fields, hasLength(1));
        expect(embed.fields![0].name, 'Key');
        expect(embed.fields![0].value, 'Val');
        expect(embed.fields![0].inline, isTrue);
      });

      test('deserializes with no optional fields', () {
        final json = <String, dynamic>{};

        final embed = Embed.fromJson(json);

        expect(embed.title, isNull);
        expect(embed.description, isNull);
        expect(embed.fields, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final embed = Embed(
          title: 'Title',
          description: 'Desc',
          url: 'https://example.com',
          color: '#FF0000',
          imageUrl: 'https://example.com/img.png',
          thumbnailUrl: 'https://example.com/thumb.png',
          author: 'Author',
          footer: 'Footer',
          timestamp: DateTime(2024, 1, 15, 10, 30),
          fields: const [
            EmbedField(name: 'Key', value: 'Val', inline: true),
          ],
        );

        final json = embed.toJson();

        expect(json['title'], 'Title');
        expect(json['description'], 'Desc');
        expect(json['url'], 'https://example.com');
        expect(json['color'], '#FF0000');
        expect(json['imageUrl'], 'https://example.com/img.png');
        expect(json['thumbnailUrl'], 'https://example.com/thumb.png');
        expect(json['author'], 'Author');
        expect(json['footer'], 'Footer');
        expect(json['timestamp'], contains('2024-01-15'));
        expect(json['fields'], hasLength(1));
      });

      test('omits null fields', () {
        const embed = Embed(title: 'Only Title');

        final json = embed.toJson();

        expect(json['title'], 'Only Title');
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('url'), isFalse);
        expect(json.containsKey('color'), isFalse);
        expect(json.containsKey('imageUrl'), isFalse);
        expect(json.containsKey('thumbnailUrl'), isFalse);
        expect(json.containsKey('author'), isFalse);
        expect(json.containsKey('footer'), isFalse);
        expect(json.containsKey('timestamp'), isFalse);
        expect(json.containsKey('fields'), isFalse);
      });
    });

    group('round-trip serialization', () {
      test('toJson then fromJson preserves data', () {
        final original = Embed(
          title: 'Title',
          description: 'Desc',
          url: 'https://example.com',
          color: '#FF0000',
          author: 'Author',
          footer: 'Footer',
          timestamp: DateTime(2024, 1, 15, 10, 30),
          fields: const [
            EmbedField(name: 'K', value: 'V', inline: true),
          ],
        );

        final restored = Embed.fromJson(original.toJson());

        expect(restored.title, original.title);
        expect(restored.description, original.description);
        expect(restored.url, original.url);
        expect(restored.color, original.color);
        expect(restored.author, original.author);
        expect(restored.footer, original.footer);
        expect(restored.fields, hasLength(1));
        expect(restored.fields![0].name, 'K');
        expect(restored.fields![0].value, 'V');
        expect(restored.fields![0].inline, isTrue);
      });
    });

    group('copyWith', () {
      test('copies with title changed', () {
        const original = Embed(title: 'Old', description: 'Desc');
        final copy = original.copyWith(title: 'New');

        expect(copy.title, 'New');
        expect(copy.description, 'Desc');
      });

      test('copies with no changes preserves values', () {
        const original = Embed(title: 'Title', color: '#FF0000');
        final copy = original.copyWith();

        expect(copy.title, 'Title');
        expect(copy.color, '#FF0000');
      });
    });

    group('equality', () {
      test('equal when same title and description', () {
        const a = Embed(title: 'T', description: 'D');
        const b = Embed(title: 'T', description: 'D', color: '#FF0000');

        expect(a == b, isTrue);
      });

      test('not equal when title differs', () {
        const a = Embed(title: 'A');
        const b = Embed(title: 'B');

        expect(a == b, isFalse);
      });

      test('not equal when description differs', () {
        const a = Embed(title: 'T', description: 'A');
        const b = Embed(title: 'T', description: 'B');

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        const a = Embed(title: 'T');
        expect(a == a, isTrue);
      });

      test('not equal to different type object', () {
        const a = Embed(title: 'T');
        expect(a == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        const a = Embed(title: 'T', description: 'D');
        const b = Embed(title: 'T', description: 'D');

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains title and description', () {
        const embed = Embed(title: 'My Title', description: 'My Desc');

        final str = embed.toString();

        expect(str, contains('My Title'));
        expect(str, contains('My Desc'));
      });
    });
  });

  group('EmbedField', () {
    group('constructor', () {
      test('creates with required fields and default inline', () {
        const field = EmbedField(name: 'Key', value: 'Val');

        expect(field.name, 'Key');
        expect(field.value, 'Val');
        expect(field.inline, isFalse);
      });

      test('creates with inline true', () {
        const field = EmbedField(name: 'Key', value: 'Val', inline: true);

        expect(field.inline, isTrue);
      });

      test('creates with empty name', () {
        const field = EmbedField(name: '', value: 'Val');

        expect(field.name, '');
      });
    });

    group('fromJson', () {
      test('deserializes with all fields', () {
        final json = {'name': 'Key', 'value': 'Val', 'inline': true};

        final field = EmbedField.fromJson(json);

        expect(field.name, 'Key');
        expect(field.value, 'Val');
        expect(field.inline, isTrue);
      });

      test('deserializes without inline defaults to false', () {
        final json = {'name': 'Key', 'value': 'Val'};

        final field = EmbedField.fromJson(json);

        expect(field.inline, isFalse);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const field = EmbedField(name: 'Key', value: 'Val', inline: true);

        final json = field.toJson();

        expect(json['name'], 'Key');
        expect(json['value'], 'Val');
        expect(json['inline'], isTrue);
      });

      test('serializes default inline as false', () {
        const field = EmbedField(name: 'Key', value: 'Val');

        final json = field.toJson();

        expect(json['inline'], isFalse);
      });
    });

    group('round-trip serialization', () {
      test('toJson then fromJson preserves data', () {
        const original = EmbedField(name: 'K', value: 'V', inline: true);

        final restored = EmbedField.fromJson(original.toJson());

        expect(restored.name, original.name);
        expect(restored.value, original.value);
        expect(restored.inline, original.inline);
      });
    });

    group('copyWith', () {
      test('copies with name changed', () {
        const original = EmbedField(name: 'Old', value: 'Val');
        final copy = original.copyWith(name: 'New');

        expect(copy.name, 'New');
        expect(copy.value, 'Val');
      });

      test('copies with inline changed', () {
        const original = EmbedField(name: 'K', value: 'V');
        final copy = original.copyWith(inline: true);

        expect(copy.inline, isTrue);
      });

      test('copies with no changes preserves values', () {
        const original = EmbedField(name: 'K', value: 'V', inline: true);
        final copy = original.copyWith();

        expect(copy.name, 'K');
        expect(copy.value, 'V');
        expect(copy.inline, isTrue);
      });
    });

    group('equality', () {
      test('equal when same name and value', () {
        const a = EmbedField(name: 'K', value: 'V');
        const b = EmbedField(name: 'K', value: 'V', inline: true);

        expect(a == b, isTrue);
      });

      test('not equal when name differs', () {
        const a = EmbedField(name: 'A', value: 'V');
        const b = EmbedField(name: 'B', value: 'V');

        expect(a == b, isFalse);
      });

      test('not equal when value differs', () {
        const a = EmbedField(name: 'K', value: 'A');
        const b = EmbedField(name: 'K', value: 'B');

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        const a = EmbedField(name: 'K', value: 'V');
        expect(a == a, isTrue);
      });

      test('not equal to different type object', () {
        const a = EmbedField(name: 'K', value: 'V');
        expect(a == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        const a = EmbedField(name: 'K', value: 'V');
        const b = EmbedField(name: 'K', value: 'V');

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains name, value, and inline', () {
        const field = EmbedField(name: 'Key', value: 'Val', inline: true);

        final str = field.toString();

        expect(str, contains('Key'));
        expect(str, contains('Val'));
        expect(str, contains('true'));
      });
    });
  });
}
