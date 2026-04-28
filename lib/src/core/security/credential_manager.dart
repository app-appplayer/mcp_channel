/// A platform credential with metadata.
class ChannelCredential {
  const ChannelCredential({
    required this.value,
    required this.platform,
    required this.issuedAt,
    this.expiresAt,
  });

  /// The credential value (token, key, secret).
  final String value;

  /// The platform this credential belongs to.
  final String platform;

  /// When this credential was last refreshed.
  final DateTime issuedAt;

  /// When this credential expires. Null means non-expiring.
  final DateTime? expiresAt;

  /// Whether this credential has expired.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Whether this credential expires within [buffer] of now.
  bool isExpiringSoon({Duration buffer = const Duration(minutes: 5)}) =>
      expiresAt != null &&
      DateTime.now().add(buffer).isAfter(expiresAt!);
}

/// Manages platform credentials (API tokens, OAuth tokens, webhook secrets).
///
/// Handles secure storage, automatic refresh, and rotation of credentials.
/// The application provides the storage backend (encrypted file, vault,
/// environment variables, etc.).
abstract interface class ChannelCredentialManager {
  /// Get the current credential for a platform.
  ///
  /// Returns the active credential, refreshing if expired.
  Future<ChannelCredential> getCredential(String platform);

  /// Force refresh a credential before expiry.
  Future<ChannelCredential> refreshCredential(String platform);

  /// Rotate a credential (generate new, invalidate old).
  Future<ChannelCredential> rotateCredential(String platform);

  /// Check if a credential is close to expiry.
  Future<bool> isExpiringSoon(String platform, {Duration buffer});
}

/// In-memory credential manager for testing.
class InMemoryCredentialManager implements ChannelCredentialManager {
  final Map<String, ChannelCredential> _credentials = {};

  /// Store a credential for testing.
  void store(ChannelCredential credential) {
    _credentials[credential.platform] = credential;
  }

  @override
  Future<ChannelCredential> getCredential(String platform) async {
    final cred = _credentials[platform];
    if (cred == null) {
      throw StateError('No credential configured for platform $platform');
    }
    return cred;
  }

  @override
  Future<ChannelCredential> refreshCredential(String platform) async {
    final existing = _credentials[platform];
    if (existing == null) {
      throw StateError('No credential configured for platform $platform');
    }
    final refreshed = ChannelCredential(
      value: existing.value,
      platform: platform,
      issuedAt: DateTime.now(),
      expiresAt: existing.expiresAt,
    );
    _credentials[platform] = refreshed;
    return refreshed;
  }

  @override
  Future<ChannelCredential> rotateCredential(String platform) async {
    final existing = _credentials[platform];
    if (existing == null) {
      throw StateError('No credential configured for platform $platform');
    }
    final rotated = ChannelCredential(
      value: 'rotated_${existing.value}',
      platform: platform,
      issuedAt: DateTime.now(),
      expiresAt: existing.expiresAt,
    );
    _credentials[platform] = rotated;
    return rotated;
  }

  @override
  Future<bool> isExpiringSoon(
    String platform, {
    Duration buffer = const Duration(minutes: 5),
  }) async {
    final cred = _credentials[platform];
    if (cred == null) return false;
    return cred.isExpiringSoon(buffer: buffer);
  }
}
