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
    });
  });
}
