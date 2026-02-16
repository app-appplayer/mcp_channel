/// Session state enumeration.
enum SessionState {
  /// Session is active and accepting events
  active,

  /// Session is temporarily paused
  paused,

  /// Session has expired (timeout)
  expired,

  /// Session was explicitly closed
  closed,
}
