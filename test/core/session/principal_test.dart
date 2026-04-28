import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('Principal', () {
    final identity = ChannelIdentityInfo.user(
      id: 'U123',
      displayName: 'Test User',
    );
    final tenantId = 'T123';
    final now = DateTime.utc(2025, 1, 15, 10, 0, 0);

    group('constructor', () {
      test('creates principal with all fields', () {
        final expiresAt = now.add(const Duration(hours: 24));
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user', 'moderator'},
          permissions: const {'read', 'write'},
          authenticatedAt: now,
          expiresAt: expiresAt,
        );

        expect(principal.identity, identity);
        expect(principal.tenantId, tenantId);
        expect(principal.roles, {'user', 'moderator'});
        expect(principal.permissions, {'read', 'write'});
        expect(principal.authenticatedAt, now);
        expect(principal.expiresAt, expiresAt);
      });

      test('creates principal without expiresAt', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal.expiresAt, isNull);
      });
    });

    group('basic factory', () {
      test('creates principal with user role and empty permissions', () {
        final principal = Principal.basic(
          identity: identity,
          tenantId: tenantId,
        );

        expect(principal.identity, identity);
        expect(principal.tenantId, tenantId);
        expect(principal.roles, {'user'});
        expect(principal.permissions, isEmpty);
        expect(principal.authenticatedAt, isNotNull);
        expect(principal.expiresAt, isNull);
      });

      test('creates principal with custom permissions and expiresAt', () {
        final expiresAt = DateTime.now().add(const Duration(hours: 1));
        final principal = Principal.basic(
          identity: identity,
          tenantId: tenantId,
          permissions: {'read'},
          expiresAt: expiresAt,
        );

        expect(principal.permissions, {'read'});
        expect(principal.expiresAt, expiresAt);
      });
    });

    group('admin factory', () {
      test('creates principal with user and admin roles', () {
        final principal = Principal.admin(
          identity: identity,
          tenantId: tenantId,
        );

        expect(principal.identity, identity);
        expect(principal.tenantId, tenantId);
        expect(principal.roles, {'user', 'admin'});
        expect(principal.permissions, {'*'});
        expect(principal.authenticatedAt, isNotNull);
        expect(principal.expiresAt, isNull);
      });

      test('creates admin principal with custom permissions and expiresAt',
          () {
        final expiresAt = DateTime.now().add(const Duration(hours: 12));
        final principal = Principal.admin(
          identity: identity,
          tenantId: tenantId,
          permissions: {'admin.write', 'admin.read'},
          expiresAt: expiresAt,
        );

        expect(principal.permissions, {'admin.write', 'admin.read'});
        expect(principal.expiresAt, expiresAt);
      });
    });

    group('fromJson', () {
      test('parses all fields from JSON including expiresAt', () {
        final expiresAt = now.add(const Duration(hours: 24));
        final json = {
          'identity': {'id': 'U123', 'type': 'user', 'displayName': 'Test User'},
          'tenantId': 'T123',
          'roles': ['user', 'moderator'],
          'permissions': ['read', 'write'],
          'authenticatedAt': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
        };

        final principal = Principal.fromJson(json);

        expect(principal.identity.id, 'U123');
        expect(principal.tenantId, 'T123');
        expect(principal.roles, {'user', 'moderator'});
        expect(principal.permissions, {'read', 'write'});
        expect(principal.authenticatedAt, now);
        expect(principal.expiresAt, expiresAt);
      });

      test('parses JSON without expiresAt', () {
        final json = {
          'identity': {'id': 'U123', 'type': 'user'},
          'tenantId': 'T123',
          'roles': ['user'],
          'permissions': [],
          'authenticatedAt': now.toIso8601String(),
        };

        final principal = Principal.fromJson(json);

        expect(principal.expiresAt, isNull);
        expect(principal.roles, {'user'});
        expect(principal.permissions, isEmpty);
      });
    });

    group('hasRole', () {
      test('returns true when principal has the role', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user', 'admin'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal.hasRole('user'), isTrue);
        expect(principal.hasRole('admin'), isTrue);
      });

      test('returns false when principal does not have the role', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal.hasRole('admin'), isFalse);
        expect(principal.hasRole('moderator'), isFalse);
      });
    });

    group('hasAnyRole', () {
      test('returns true when intersection is found', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user', 'moderator'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal.hasAnyRole({'admin', 'moderator'}), isTrue);
        expect(principal.hasAnyRole({'user'}), isTrue);
      });

      test('returns false when no intersection', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal.hasAnyRole({'admin', 'moderator'}), isFalse);
        expect(principal.hasAnyRole(<String>{}), isFalse);
      });
    });

    group('hasPermission', () {
      test('returns true for specific permission', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {'read', 'write'},
          authenticatedAt: now,
        );

        expect(principal.hasPermission('read'), isTrue);
        expect(principal.hasPermission('write'), isTrue);
      });

      test('returns false for missing specific permission', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {'read'},
          authenticatedAt: now,
        );

        expect(principal.hasPermission('write'), isFalse);
        expect(principal.hasPermission('delete'), isFalse);
      });

      test('wildcard * matches any permission', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'admin'},
          permissions: const {'*'},
          authenticatedAt: now,
        );

        expect(principal.hasPermission('read'), isTrue);
        expect(principal.hasPermission('write'), isTrue);
        expect(principal.hasPermission('delete'), isTrue);
        expect(principal.hasPermission('anything'), isTrue);
      });
    });

    group('isExpired', () {
      test('returns false when expiresAt is null', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
          expiresAt: null,
        );

        expect(principal.isExpired, isFalse);
      });

      test('returns false when expiresAt is in the future', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );

        expect(principal.isExpired, isFalse);
      });

      test('returns true when expiresAt is in the past', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: DateTime.now().subtract(const Duration(hours: 48)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(principal.isExpired, isTrue);
      });
    });

    group('isAdmin', () {
      test('returns true when admin role is present', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user', 'admin'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal.isAdmin, isTrue);
      });

      test('returns false when admin role is absent', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal.isAdmin, isFalse);
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final original = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        final newIdentity = ChannelIdentityInfo.user(
          id: 'U999',
          displayName: 'New User',
        );
        final newExpiresAt = now.add(const Duration(hours: 48));
        final newAuthAt = now.add(const Duration(hours: 1));

        final copied = original.copyWith(
          identity: newIdentity,
          tenantId: 'T999',
          roles: {'admin'},
          permissions: {'*'},
          authenticatedAt: newAuthAt,
          expiresAt: newExpiresAt,
        );

        expect(copied.identity, newIdentity);
        expect(copied.tenantId, 'T999');
        expect(copied.roles, {'admin'});
        expect(copied.permissions, {'*'});
        expect(copied.authenticatedAt, newAuthAt);
        expect(copied.expiresAt, newExpiresAt);
      });

      test('retains original values when no overrides', () {
        final expiresAt = now.add(const Duration(hours: 24));
        final original = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user', 'moderator'},
          permissions: const {'read'},
          authenticatedAt: now,
          expiresAt: expiresAt,
        );

        final copied = original.copyWith();

        expect(copied.identity, identity);
        expect(copied.tenantId, tenantId);
        expect(copied.roles, {'user', 'moderator'});
        expect(copied.permissions, {'read'});
        expect(copied.authenticatedAt, now);
        expect(copied.expiresAt, expiresAt);
      });
    });

    group('toJson', () {
      test('serializes all fields including expiresAt', () {
        final expiresAt = now.add(const Duration(hours: 24));
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {'read'},
          authenticatedAt: now,
          expiresAt: expiresAt,
        );

        final json = principal.toJson();

        expect(json['identity'], isA<Map<String, dynamic>>());
        expect(json['tenantId'], tenantId);
        expect(json['roles'], isA<List>());
        expect((json['roles'] as List).contains('user'), isTrue);
        expect(json['permissions'], isA<List>());
        expect((json['permissions'] as List).contains('read'), isTrue);
        expect(json['authenticatedAt'], now.toIso8601String());
        expect(json['expiresAt'], expiresAt.toIso8601String());
      });

      test('omits expiresAt when null', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        final json = principal.toJson();

        expect(json.containsKey('expiresAt'), isFalse);
      });
    });

    group('equality', () {
      test('equal when same identity and tenantId', () {
        final principal1 = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        final principal2 = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'admin'},
          permissions: const {'*'},
          authenticatedAt: now.add(const Duration(hours: 1)),
        );

        expect(principal1 == principal2, isTrue);
      });

      test('not equal when different identity', () {
        final otherIdentity = ChannelIdentityInfo.user(
          id: 'U999',
          displayName: 'Other User',
        );

        final principal1 = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        final principal2 = Principal(
          identity: otherIdentity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal1 == principal2, isFalse);
      });

      test('not equal when different tenantId', () {
        final principal1 = Principal(
          identity: identity,
          tenantId: 'T123',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        final principal2 = Principal(
          identity: identity,
          tenantId: 'T999',
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal1 == principal2, isFalse);
      });

      test('not equal to different type', () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        expect(principal == Object(), isFalse);
      });
    });

    group('hashCode', () {
      test('same for equal principals', () {
        final principal1 = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        final principal2 = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'admin'},
          permissions: const {'*'},
          authenticatedAt: now.add(const Duration(hours: 1)),
        );

        expect(principal1.hashCode, principal2.hashCode);
      });

      test('different for different principals', () {
        final otherIdentity = ChannelIdentityInfo.user(
          id: 'U999',
          displayName: 'Other User',
        );

        final principal1 = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        final principal2 = Principal(
          identity: otherIdentity,
          tenantId: tenantId,
          roles: const {'user'},
          permissions: const {},
          authenticatedAt: now,
        );

        // Hash codes are likely different (not guaranteed but highly probable)
        expect(principal1.hashCode, isNot(principal2.hashCode));
      });
    });

    group('toString', () {
      test('returns formatted string with identity id, tenantId, and roles',
          () {
        final principal = Principal(
          identity: identity,
          tenantId: tenantId,
          roles: const {'user', 'admin'},
          permissions: const {},
          authenticatedAt: now,
        );

        final str = principal.toString();

        expect(str, contains('Principal'));
        expect(str, contains('U123'));
        expect(str, contains('T123'));
        expect(str, contains('user'));
        expect(str, contains('admin'));
      });
    });
  });
}
