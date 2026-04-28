import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('IdentityType', () {
    test('has all expected values', () {
      expect(IdentityType.values, hasLength(4));
      expect(IdentityType.values, contains(IdentityType.user));
      expect(IdentityType.values, contains(IdentityType.bot));
      expect(IdentityType.values, contains(IdentityType.system));
      expect(IdentityType.values, contains(IdentityType.unknown));
    });
  });

  group('ChannelIdentityInfo', () {
    test('creates with required fields', () {
      const info = ChannelIdentityInfo(
        id: 'U123',
        type: IdentityType.user,
      );
      expect(info.id, 'U123');
      expect(info.type, IdentityType.user);
      expect(info.displayName, isNull);
      expect(info.username, isNull);
      expect(info.avatarUrl, isNull);
      expect(info.email, isNull);
      expect(info.timezone, isNull);
      expect(info.locale, isNull);
      expect(info.isAdmin, isNull);
      expect(info.platformData, isNull);
    });

    test('creates with all fields', () {
      const info = ChannelIdentityInfo(
        id: 'U123',
        type: IdentityType.user,
        displayName: 'Test User',
        username: 'testuser',
        avatarUrl: 'https://example.com/avatar.png',
        email: 'test@example.com',
        timezone: 'Asia/Seoul',
        locale: 'ko-KR',
        isAdmin: true,
        platformData: {'team': 'dev'},
      );

      expect(info.displayName, 'Test User');
      expect(info.username, 'testuser');
      expect(info.avatarUrl, 'https://example.com/avatar.png');
      expect(info.email, 'test@example.com');
      expect(info.timezone, 'Asia/Seoul');
      expect(info.locale, 'ko-KR');
      expect(info.isAdmin, true);
      expect(info.platformData?['team'], 'dev');
    });

    group('factory constructors', () {
      test('user factory', () {
        final info = ChannelIdentityInfo.user(
          id: 'U1',
          displayName: 'User 1',
          username: 'user1',
          avatarUrl: 'https://avatar.com/1.png',
          email: 'u1@test.com',
          timezone: 'UTC',
          locale: 'en-US',
          isAdmin: false,
          platformData: {'extra': 'data'},
        );

        expect(info.type, IdentityType.user);
        expect(info.id, 'U1');
        expect(info.displayName, 'User 1');
        expect(info.username, 'user1');
        expect(info.email, 'u1@test.com');
      });

      test('user factory with minimal fields', () {
        final info = ChannelIdentityInfo.user(id: 'U1');
        expect(info.type, IdentityType.user);
        expect(info.id, 'U1');
        expect(info.displayName, isNull);
      });

      test('bot factory', () {
        final info = ChannelIdentityInfo.bot(
          id: 'B1',
          displayName: 'Bot',
          platformData: {'bot_type': 'service'},
        );

        expect(info.type, IdentityType.bot);
        expect(info.id, 'B1');
        expect(info.displayName, 'Bot');
        expect(info.platformData?['bot_type'], 'service');
      });

      test('bot factory with minimal fields', () {
        final info = ChannelIdentityInfo.bot(id: 'B1');
        expect(info.type, IdentityType.bot);
        expect(info.username, isNull);
      });

      test('system factory', () {
        final info = ChannelIdentityInfo.system(
          id: 'SYS',
          displayName: 'System',
        );

        expect(info.type, IdentityType.system);
        expect(info.id, 'SYS');
        expect(info.displayName, 'System');
      });

      test('system factory with minimal fields', () {
        final info = ChannelIdentityInfo.system(id: 'SYS');
        expect(info.type, IdentityType.system);
      });
    });

    test('copyWith creates modified copy', () {
      final original = ChannelIdentityInfo.user(
        id: 'U1',
        displayName: 'Original',
        email: 'old@test.com',
      );
      final copy = original.copyWith(
        displayName: 'Modified',
        email: 'new@test.com',
      );

      expect(copy.id, 'U1');
      expect(copy.displayName, 'Modified');
      expect(copy.email, 'new@test.com');
      expect(copy.type, IdentityType.user);
    });

    test('copyWith preserves unmodified fields', () {
      final original = ChannelIdentityInfo.user(
        id: 'U1',
        displayName: 'Name',
        username: 'uname',
        timezone: 'UTC',
      );
      final copy = original.copyWith(displayName: 'New Name');
      expect(copy.username, 'uname');
      expect(copy.timezone, 'UTC');
    });

    group('JSON serialization', () {
      test('serializes with required fields only', () {
        const info = ChannelIdentityInfo(
          id: 'U1',
          type: IdentityType.user,
        );
        final json = info.toJson();
        expect(json['id'], 'U1');
        expect(json['type'], 'user');
        expect(json.containsKey('displayName'), isFalse);
        expect(json.containsKey('username'), isFalse);
        expect(json.containsKey('email'), isFalse);
      });

      test('serializes with all fields', () {
        const info = ChannelIdentityInfo(
          id: 'U1',
          type: IdentityType.user,
          displayName: 'User',
          username: 'user1',
          avatarUrl: 'https://avatar.com/1.png',
          email: 'u1@test.com',
          timezone: 'UTC',
          locale: 'en-US',
          isAdmin: true,
          platformData: {'key': 'value'},
        );
        final json = info.toJson();
        expect(json['displayName'], 'User');
        expect(json['username'], 'user1');
        expect(json['avatarUrl'], 'https://avatar.com/1.png');
        expect(json['email'], 'u1@test.com');
        expect(json['timezone'], 'UTC');
        expect(json['locale'], 'en-US');
        expect(json['isAdmin'], true);
        expect(json['platformData'], {'key': 'value'});
      });

      test('deserializes from JSON', () {
        final info = ChannelIdentityInfo.fromJson({
          'id': 'U1',
          'type': 'user',
          'displayName': 'User',
          'email': 'u1@test.com',
        });
        expect(info.id, 'U1');
        expect(info.type, IdentityType.user);
        expect(info.displayName, 'User');
        expect(info.email, 'u1@test.com');
      });

      test('deserializes unknown type defaults to unknown', () {
        final info = ChannelIdentityInfo.fromJson({
          'id': 'X1',
          'type': 'alien',
        });
        expect(info.type, IdentityType.unknown);
      });

      test('deserializes bot type', () {
        final info = ChannelIdentityInfo.fromJson({
          'id': 'B1',
          'type': 'bot',
        });
        expect(info.type, IdentityType.bot);
      });

      test('round-trip serialization', () {
        const original = ChannelIdentityInfo(
          id: 'U1',
          type: IdentityType.user,
          displayName: 'Test',
          username: 'test',
          avatarUrl: 'https://avatar.com/1.png',
          email: 'test@test.com',
          timezone: 'Asia/Seoul',
          locale: 'ko-KR',
          isAdmin: false,
          platformData: {'extra': 42},
        );
        final restored = ChannelIdentityInfo.fromJson(original.toJson());
        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.displayName, original.displayName);
        expect(restored.username, original.username);
        expect(restored.avatarUrl, original.avatarUrl);
        expect(restored.email, original.email);
        expect(restored.timezone, original.timezone);
        expect(restored.locale, original.locale);
        expect(restored.isAdmin, original.isAdmin);
        expect(restored.platformData?['extra'], 42);
      });
    });

    group('equality', () {
      test('equal by id and type', () {
        final a = ChannelIdentityInfo.user(id: 'U1', displayName: 'Name A');
        final b = ChannelIdentityInfo.user(id: 'U1', displayName: 'Name B');
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different id', () {
        final a = ChannelIdentityInfo.user(id: 'U1');
        final b = ChannelIdentityInfo.user(id: 'U2');
        expect(a, isNot(equals(b)));
      });

      test('different type', () {
        const a = ChannelIdentityInfo(id: 'X1', type: IdentityType.user);
        const b = ChannelIdentityInfo(id: 'X1', type: IdentityType.bot);
        expect(a, isNot(equals(b)));
      });
    });

    test('toString contains id and type', () {
      final info = ChannelIdentityInfo.user(
        id: 'U1',
        displayName: 'Test',
      );
      final str = info.toString();
      expect(str, contains('U1'));
      expect(str, contains('user'));
      expect(str, contains('Test'));
    });
  });
}
