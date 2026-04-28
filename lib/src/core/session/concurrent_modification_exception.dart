/// Thrown when a session save fails due to version mismatch.
class ConcurrentModificationException implements Exception {
  const ConcurrentModificationException({
    required this.sessionId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  /// The session ID that had a version conflict
  final String sessionId;

  /// The version that was expected
  final int expectedVersion;

  /// The actual version found in the store
  final int actualVersion;

  @override
  String toString() =>
      'ConcurrentModificationException: session $sessionId '
      'expected version $expectedVersion, found $actualVersion';
}
