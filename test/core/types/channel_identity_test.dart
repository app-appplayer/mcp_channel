import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelIdentity', () {
    group('factory constructors', () {
      test('user creates user identity', () {
        final identity = ChannelIdentity.user(
          id: 'U123',
          displayName: 'John Doe',
          email: 'john@example.com',
        );

        expect(identity.type, IdentityType.user);
        expect(identity.id, 'U123');
        expect(identity.displayName, 'John Doe');
        expect(identity.email, 'john@example.com');
      });

      test('bot creates bot identity', () {
        final identity = ChannelIdentity.bot(
          id: 'B123',
          displayName: 'MyBot',
        );

        expect(identity.type, IdentityType.bot);
        expect(identity.id, 'B123');
        expect(identity.displayName, 'MyBot');
      });

      test('system creates system identity', () {
        final identity = ChannelIdentity.system(
          id: 'SYS',
          displayName: 'System',
        );

        expect(identity.type, IdentityType.system);
        expect(identity.id, 'SYS');
      });
    });

    group('equality', () {
      test('equal identities have same hash', () {
        final identity1 = ChannelIdentity.user(id: 'U123');
        final identity2 = ChannelIdentity.user(id: 'U123');

        expect(identity1, equals(identity2));
        expect(identity1.hashCode, equals(identity2.hashCode));
      });

      test('different identities are not equal', () {
        final identity1 = ChannelIdentity.user(id: 'U123');
        final identity2 = ChannelIdentity.user(id: 'U456');

        expect(identity1, isNot(equals(identity2)));
      });

      test('different types with same id are not equal', () {
        final user = ChannelIdentity.user(id: 'ID123');
        final bot = ChannelIdentity.bot(id: 'ID123');

        expect(user, isNot(equals(bot)));
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = ChannelIdentity.user(
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
        final original = ChannelIdentity.user(
          id: 'U123',
          displayName: 'Test User',
          email: 'test@example.com',
        );

        final json = original.toJson();
        final restored = ChannelIdentity.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.displayName, original.displayName);
        expect(restored.email, original.email);
      });
    });
  });
}
