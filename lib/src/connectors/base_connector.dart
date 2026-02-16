import 'dart:async';
import 'dart:typed_data';

import '../core/policy/channel_policy.dart';
import '../core/port/channel_port.dart';
import '../core/port/connection_state.dart';
import '../core/port/conversation_info.dart';
import '../core/types/channel_event.dart';
import '../core/types/channel_identity.dart';
import '../core/types/conversation_key.dart';
import '../core/types/file_info.dart';

/// Base configuration for channel connectors.
abstract class ConnectorConfig {
  /// Channel type identifier.
  String get channelType;

  /// Whether to auto-reconnect on disconnect.
  bool get autoReconnect;

  /// Reconnect delay.
  Duration get reconnectDelay;

  /// Maximum reconnect attempts.
  int get maxReconnectAttempts;
}

/// Base implementation for channel connectors.
///
/// Provides common functionality for implementing platform-specific
/// channel connectors.
abstract class BaseConnector implements ChannelPort {
  final _eventController = StreamController<ChannelEvent>.broadcast();
  final _connectionStateController =
      StreamController<ConnectionState>.broadcast();

  ConnectionState _currentConnectionState = ConnectionState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _disposed = false;

  @override
  Stream<ChannelEvent> get events => _eventController.stream;

  @override
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Get the current connection state.
  ConnectionState get currentConnectionState => _currentConnectionState;

  @override
  bool get isRunning => _currentConnectionState == ConnectionState.connected;

  /// Get connector configuration.
  ConnectorConfig get config;

  /// Get the channel policy for this connector.
  ChannelPolicy get policy;

  /// Update connection state and notify listeners.
  void updateConnectionState(ConnectionState state) {
    if (_currentConnectionState == state) return;
    _currentConnectionState = state;
    _connectionStateController.add(state);
  }

  /// Emit a channel event.
  void emitEvent(ChannelEvent event) {
    if (_disposed) return;
    _eventController.add(event);
  }

  /// Called when connection is established.
  void onConnected() {
    _reconnectAttempts = 0;
    updateConnectionState(ConnectionState.connected);
  }

  /// Called when connection is lost.
  void onDisconnected() {
    updateConnectionState(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  /// Called when an error occurs.
  void onError(Object error) {
    updateConnectionState(ConnectionState.failed);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!config.autoReconnect) return;
    if (_reconnectAttempts >= config.maxReconnectAttempts) return;
    if (_disposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(config.reconnectDelay, () async {
      if (_disposed) return;
      _reconnectAttempts++;
      updateConnectionState(ConnectionState.reconnecting);
      try {
        await start();
      } catch (e) {
        onError(e);
      }
    });
  }

  @override
  Future<void> stop() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    updateConnectionState(ConnectionState.disconnected);
    await doStop();
  }

  /// Platform-specific stop implementation.
  Future<void> doStop();

  /// Dispose of connector resources.
  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _eventController.close();
    await _connectionStateController.close();
  }

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) {
    // Default implementation returns null
    // Subclasses should override with platform-specific implementation
    return Future.value(null);
  }

  @override
  Future<ChannelIdentity?> getIdentity(String userId) {
    // Default implementation returns null
    // Subclasses should override with platform-specific implementation
    return Future.value(null);
  }

  @override
  Future<FileInfo?> uploadFile({
    required ConversationKey conversation,
    required String name,
    required Uint8List data,
    String? mimeType,
  }) {
    // Default implementation returns null
    // Subclasses should override with platform-specific implementation
    return Future.value(null);
  }

  @override
  Future<Uint8List?> downloadFile(String fileId) {
    // Default implementation returns null
    // Subclasses should override with platform-specific implementation
    return Future.value(null);
  }
}

/// Exception thrown by connector operations.
class ConnectorException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const ConnectorException(this.message, {this.code, this.cause});

  @override
  String toString() => code != null
      ? 'ConnectorException[$code]: $message'
      : 'ConnectorException: $message';
}
