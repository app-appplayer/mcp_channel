import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelCredential', () {
    test('construction assigns all fields correctly', () {
      final issuedAt = DateTime(2024, 1, 1);
      final expiresAt = DateTime(2030, 1, 1);

      final credential = ChannelCredential(
        value: 'xoxb-secret-123',
        platform: 'slack',
        issuedAt: issuedAt,
        expiresAt: expiresAt,
      );

      expect(credential.value, equals('xoxb-secret-123'));
      expect(credential.platform, equals('slack'));
      expect(credential.issuedAt, equals(issuedAt));
      expect(credential.expiresAt, equals(expiresAt));
    });

    test('expiresAt defaults to null', () {
      final credential = ChannelCredential(
        value: 'key-abc',
        platform: 'telegram',
        issuedAt: DateTime(2024, 1, 1),
      );

      expect(credential.expiresAt, isNull);
    });

    group('isExpired', () {
      test('returns false when expiresAt is in the future', () {
        final credential = ChannelCredential(
          value: 'secret',
          platform: 'slack',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(credential.isExpired, isFalse);
      });

      test('returns true when expiresAt is in the past', () {
        final credential = ChannelCredential(
          value: 'secret',
          platform: 'slack',
          issuedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(credential.isExpired, isTrue);
      });

      test('returns false when expiresAt is null', () {
        final credential = ChannelCredential(
          value: 'secret',
          platform: 'slack',
          issuedAt: DateTime.now(),
        );

        expect(credential.isExpired, isFalse);
      });
    });

    group('isExpiringSoon', () {
      test('returns true when credential expires within default buffer', () {
        final credential = ChannelCredential(
          value: 'secret',
          platform: 'slack',
          issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
          expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        );

        // Default buffer is 5 minutes, credential expires in 3 minutes
        expect(credential.isExpiringSoon(), isTrue);
      });

      test('returns false when credential expires well after buffer', () {
        final credential = ChannelCredential(
          value: 'secret',
          platform: 'slack',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(credential.isExpiringSoon(), isFalse);
      });

      test('returns true with custom buffer', () {
        final credential = ChannelCredential(
          value: 'secret',
          platform: 'slack',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        // With a 2-hour buffer, credential expiring in 1 hour is "soon"
        expect(
          credential.isExpiringSoon(buffer: const Duration(hours: 2)),
          isTrue,
        );
      });

      test('returns false when expiresAt is null', () {
        final credential = ChannelCredential(
          value: 'secret',
          platform: 'slack',
          issuedAt: DateTime.now(),
        );

        expect(credential.isExpiringSoon(), isFalse);
      });
    });
  });

  group('InMemoryCredentialManager', () {
    late InMemoryCredentialManager manager;

    setUp(() {
      manager = InMemoryCredentialManager();
    });

    group('store and getCredential', () {
      test('stores and retrieves credential by platform', () async {
        final credential = ChannelCredential(
          value: 'xoxb-123',
          platform: 'slack',
          issuedAt: DateTime.now(),
        );

        manager.store(credential);

        final retrieved = await manager.getCredential('slack');

        expect(retrieved.value, equals('xoxb-123'));
        expect(retrieved.platform, equals('slack'));
      });

      test('throws StateError when no credential exists', () async {
        expect(
          () => manager.getCredential('unknown'),
          throwsA(isA<StateError>()),
        );
      });

      test('overwrites existing credential for same platform', () async {
        final first = ChannelCredential(
          value: 'old-token',
          platform: 'slack',
          issuedAt: DateTime.now(),
        );
        final second = ChannelCredential(
          value: 'new-token',
          platform: 'slack',
          issuedAt: DateTime.now(),
        );

        manager.store(first);
        manager.store(second);

        final retrieved = await manager.getCredential('slack');
        expect(retrieved.value, equals('new-token'));
      });
    });

    group('refreshCredential', () {
      test('refreshes with same value but new issuedAt', () async {
        final originalIssuedAt = DateTime(2024, 1, 1);
        final credential = ChannelCredential(
          value: 'xoxb-123',
          platform: 'slack',
          issuedAt: originalIssuedAt,
        );

        manager.store(credential);

        final refreshed = await manager.refreshCredential('slack');

        expect(refreshed.value, equals('xoxb-123'));
        expect(refreshed.platform, equals('slack'));
        // issuedAt should be updated to a more recent time
        expect(refreshed.issuedAt.isAfter(originalIssuedAt), isTrue);
      });

      test('preserves expiresAt on refresh', () async {
        final expiresAt = DateTime(2030, 6, 15);
        final credential = ChannelCredential(
          value: 'token-abc',
          platform: 'discord',
          issuedAt: DateTime(2024, 1, 1),
          expiresAt: expiresAt,
        );

        manager.store(credential);

        final refreshed = await manager.refreshCredential('discord');

        expect(refreshed.expiresAt, equals(expiresAt));
      });

      test('throws StateError when no credential to refresh', () async {
        expect(
          () => manager.refreshCredential('unknown'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('rotateCredential', () {
      test('rotates credential with rotated_ prefix', () async {
        final credential = ChannelCredential(
          value: 'old-value',
          platform: 'slack',
          issuedAt: DateTime(2024, 1, 1),
        );

        manager.store(credential);

        final rotated = await manager.rotateCredential('slack');

        expect(rotated.value, equals('rotated_old-value'));
        expect(rotated.platform, equals('slack'));
      });

      test('preserves expiresAt on rotation', () async {
        final expiresAt = DateTime(2030, 6, 15);
        final credential = ChannelCredential(
          value: 'old-secret',
          platform: 'discord',
          issuedAt: DateTime(2024, 1, 1),
          expiresAt: expiresAt,
        );

        manager.store(credential);

        final rotated = await manager.rotateCredential('discord');

        expect(rotated.value, equals('rotated_old-secret'));
        expect(rotated.expiresAt, equals(expiresAt));
      });

      test('updates stored credential after rotation', () async {
        final credential = ChannelCredential(
          value: 'original',
          platform: 'slack',
          issuedAt: DateTime(2024, 1, 1),
        );

        manager.store(credential);
        await manager.rotateCredential('slack');

        final retrieved = await manager.getCredential('slack');
        expect(retrieved.value, equals('rotated_original'));
      });

      test('throws StateError when no credential to rotate', () async {
        expect(
          () => manager.rotateCredential('unknown'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('isExpiringSoon', () {
      test('returns false when no credential exists', () async {
        final result = await manager.isExpiringSoon('unknown');

        expect(result, isFalse);
      });

      test('returns true when credential is expiring soon', () async {
        final credential = ChannelCredential(
          value: 'expiring-token',
          platform: 'slack',
          issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
          expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        );

        manager.store(credential);

        // Default buffer is 5 minutes, credential expires in 3 minutes
        final result = await manager.isExpiringSoon('slack');
        expect(result, isTrue);
      });

      test('returns false when credential is not expiring soon', () async {
        final credential = ChannelCredential(
          value: 'valid-token',
          platform: 'slack',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        manager.store(credential);

        final result = await manager.isExpiringSoon('slack');
        expect(result, isFalse);
      });

      test('supports custom buffer duration', () async {
        final credential = ChannelCredential(
          value: 'token',
          platform: 'slack',
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        manager.store(credential);

        // With a 2-hour buffer, credential expiring in 1 hour is "soon"
        final result = await manager.isExpiringSoon(
          'slack',
          buffer: const Duration(hours: 2),
        );
        expect(result, isTrue);
      });

      test('returns false for non-expiring credential', () async {
        final credential = ChannelCredential(
          value: 'permanent-token',
          platform: 'slack',
          issuedAt: DateTime.now(),
        );

        manager.store(credential);

        final result = await manager.isExpiringSoon('slack');
        expect(result, isFalse);
      });
    });

    test('implements ChannelCredentialManager', () {
      expect(manager, isA<ChannelCredentialManager>());
    });
  });
}
