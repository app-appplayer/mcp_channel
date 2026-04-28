import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelIdentity (from mcp_bundle)', () {
    test('creates identity with required fields', () {
      const identity = ChannelIdentity(
        platform: 'slack',
        channelId: 'T123',
      );

      expect(identity.platform, 'slack');
      expect(identity.channelId, 'T123');
      expect(identity.displayName, isNull);
    });

    test('creates identity with display name', () {
      const identity = ChannelIdentity(
        platform: 'slack',
        channelId: 'U123',
        displayName: 'Test User',
      );

      expect(identity.platform, 'slack');
      expect(identity.channelId, 'U123');
      expect(identity.displayName, 'Test User');
    });

    group('equality', () {
      test('equal identities have same hash', () {
        const identity1 = ChannelIdentity(
          platform: 'slack',
          channelId: 'U123',
        );
        const identity2 = ChannelIdentity(
          platform: 'slack',
          channelId: 'U123',
        );

        expect(identity1, equals(identity2));
        expect(identity1.hashCode, equals(identity2.hashCode));
      });

      test('different channelIds are not equal', () {
        const identity1 = ChannelIdentity(
          platform: 'slack',
          channelId: 'U123',
        );
        const identity2 = ChannelIdentity(
          platform: 'slack',
          channelId: 'U456',
        );

        expect(identity1, isNot(equals(identity2)));
      });

      test('different platforms are not equal', () {
        const identity1 = ChannelIdentity(
          platform: 'slack',
          channelId: 'U123',
        );
        const identity2 = ChannelIdentity(
          platform: 'telegram',
          channelId: 'U123',
        );

        expect(identity1, isNot(equals(identity2)));
      });
    });

    group('toJson/fromJson', () {
      test('round-trip serialization works', () {
        const original = ChannelIdentity(
          platform: 'slack',
          channelId: 'T123',
          displayName: 'Test Workspace',
        );

        final json = original.toJson();
        final restored = ChannelIdentity.fromJson(json);

        expect(restored.platform, original.platform);
        expect(restored.channelId, original.channelId);
        expect(restored.displayName, original.displayName);
      });
    });
  });

  group('ChannelIdentityInfo (mcp_channel extension)', () {
    test('user creates user identity info', () {
      final info = ChannelIdentityInfo.user(
        id: 'U123',
        username: 'testuser',
        displayName: 'Test User',
      );

      expect(info.id, 'U123');
      expect(info.type, IdentityType.user);
      expect(info.username, 'testuser');
      expect(info.displayName, 'Test User');
    });

    test('bot creates bot identity info', () {
      final info = ChannelIdentityInfo.bot(
        id: 'B123',
        displayName: 'MyBot',
      );

      expect(info.id, 'B123');
      expect(info.type, IdentityType.bot);
      expect(info.displayName, 'MyBot');
    });

    test('system creates system identity info', () {
      final info = ChannelIdentityInfo.system(
        id: 'SYS',
        displayName: 'System',
      );

      expect(info.id, 'SYS');
      expect(info.type, IdentityType.system);
    });

    test('creates identity info with all fields', () {
      final info = ChannelIdentityInfo.user(
        id: 'U123',
        username: 'testuser',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.png',
        email: 'test@example.com',
        isAdmin: false,
        platformData: const {'team': 'T123'},
      );

      expect(info.id, 'U123');
      expect(info.username, 'testuser');
      expect(info.displayName, 'Test User');
      expect(info.avatarUrl, 'https://example.com/avatar.png');
      expect(info.email, 'test@example.com');
      expect(info.isAdmin, false);
      expect(info.platformData?['team'], 'T123');
    });

    group('equality', () {
      test('equal identities have same hash', () {
        final info1 = ChannelIdentityInfo.user(id: 'U123');
        final info2 = ChannelIdentityInfo.user(id: 'U123');

        expect(info1, equals(info2));
        expect(info1.hashCode, equals(info2.hashCode));
      });

      test('different ids are not equal', () {
        final info1 = ChannelIdentityInfo.user(id: 'U123');
        final info2 = ChannelIdentityInfo.user(id: 'U456');

        expect(info1, isNot(equals(info2)));
      });

      test('different types with same id are not equal', () {
        final user = ChannelIdentityInfo.user(id: 'ID123');
        final bot = ChannelIdentityInfo.bot(id: 'ID123');

        expect(user, isNot(equals(bot)));
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = ChannelIdentityInfo.user(
          id: 'U123',
          displayName: 'Original Name',
        );

        final copy = original.copyWith(displayName: 'New Name');

        expect(copy.id, 'U123');
        expect(copy.displayName, 'New Name');
        expect(original.displayName, 'Original Name');
      });
    });

    group('toJson/fromJson', () {
      test('round-trip serialization works', () {
        final original = ChannelIdentityInfo.user(
          id: 'U123',
          username: 'testuser',
          displayName: 'Test User',
          email: 'test@example.com',
        );

        final json = original.toJson();
        final restored = ChannelIdentityInfo.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.username, original.username);
        expect(restored.displayName, original.displayName);
        expect(restored.email, original.email);
      });

      test('fromJson with unknown type falls back to IdentityType.unknown',
          () {
        final json = {
          'id': 'X999',
          'type': 'alien',
        };

        final info = ChannelIdentityInfo.fromJson(json);

        expect(info.id, 'X999');
        expect(info.type, IdentityType.unknown);
      });

      test('toJson with all optional fields present', () {
        final info = ChannelIdentityInfo.user(
          id: 'U123',
          displayName: 'Alice',
          username: 'alice',
          avatarUrl: 'https://example.com/avatar.png',
          email: 'alice@example.com',
          timezone: 'America/New_York',
          locale: 'en-US',
          isAdmin: true,
          platformData: {'team_id': 'T001', 'role': 'owner'},
        );

        final json = info.toJson();

        expect(json['id'], 'U123');
        expect(json['type'], 'user');
        expect(json['displayName'], 'Alice');
        expect(json['username'], 'alice');
        expect(json['avatarUrl'], 'https://example.com/avatar.png');
        expect(json['email'], 'alice@example.com');
        expect(json['timezone'], 'America/New_York');
        expect(json['locale'], 'en-US');
        expect(json['isAdmin'], isTrue);
        expect(json['platformData'], isNotNull);
        expect(
            (json['platformData'] as Map<String, dynamic>)['team_id'], 'T001');
      });

      test('fromJson round-trip with all fields', () {
        final original = ChannelIdentityInfo.user(
          id: 'U456',
          displayName: 'Bob',
          username: 'bob',
          avatarUrl: 'https://example.com/bob.png',
          email: 'bob@example.com',
          timezone: 'Europe/London',
          locale: 'en-GB',
          isAdmin: false,
          platformData: {'department': 'engineering'},
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
        expect(restored.platformData?['department'], 'engineering');
      });
    });

    group('copyWith (extended)', () {
      test('copies with all fields including timezone, locale, isAdmin, platformData', () {
        final original = ChannelIdentityInfo.user(
          id: 'U123',
          displayName: 'Alice',
          username: 'alice',
          avatarUrl: 'https://example.com/alice.png',
          email: 'alice@example.com',
          timezone: 'US/Pacific',
          locale: 'en-US',
          isAdmin: false,
          platformData: {'level': 1},
        );

        final copy = original.copyWith(
          id: 'U999',
          type: IdentityType.bot,
          displayName: 'Bot Alice',
          username: 'bot_alice',
          avatarUrl: 'https://example.com/bot.png',
          email: 'bot@example.com',
          timezone: 'UTC',
          locale: 'ja-JP',
          isAdmin: true,
          platformData: {'level': 99},
        );

        expect(copy.id, 'U999');
        expect(copy.type, IdentityType.bot);
        expect(copy.displayName, 'Bot Alice');
        expect(copy.username, 'bot_alice');
        expect(copy.avatarUrl, 'https://example.com/bot.png');
        expect(copy.email, 'bot@example.com');
        expect(copy.timezone, 'UTC');
        expect(copy.locale, 'ja-JP');
        expect(copy.isAdmin, isTrue);
        expect(copy.platformData?['level'], 99);
      });
    });

    group('toString', () {
      test('contains id, type name, and displayName', () {
        final info = ChannelIdentityInfo.user(
          id: 'U123',
          displayName: 'Alice',
        );

        final str = info.toString();

        expect(str, contains('U123'));
        expect(str, contains('user'));
        expect(str, contains('Alice'));
      });

      test('shows null displayName when not set', () {
        final info = ChannelIdentityInfo.user(id: 'U123');

        final str = info.toString();

        expect(str, contains('U123'));
        expect(str, contains('null'));
      });
    });
  });
}
