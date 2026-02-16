/// Channel connection state.
enum ConnectionState {
  /// Not connected
  disconnected,

  /// Connecting to platform
  connecting,

  /// Connected and ready
  connected,

  /// Reconnecting after disconnect
  reconnecting,

  /// Connection failed
  failed,
}
