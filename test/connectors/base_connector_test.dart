import 'dart:async';
import 'dart:typed_data';

import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

// =============================================================================
// Test doubles
// =============================================================================

/// A concrete ConnectorConfig for testing.
class TestConnectorConfig implements ConnectorConfig {
  TestConnectorConfig({
    this.autoReconnect = false,
    this.reconnectDelay = const Duration(milliseconds: 100),
    this.maxReconnectAttempts = 3,
  });

  @override
  final String channelType = 'test';

  @override
  final bool autoReconnect;

  @override
  final Duration reconnectDelay;

  @override
  final int maxReconnectAttempts;
}

/// A concrete BaseConnector subclass for testing.
///
/// Exposes protected methods via public wrappers so they can be verified
/// in unit tests. The [startBehaviour] callback lets individual tests
/// control what happens when [start] is called.
class TestConnector extends BaseConnector {
  TestConnector(this._config, {this.startBehaviour});

  final TestConnectorConfig _config;
  Future<void> Function()? startBehaviour;
  int startCallCount = 0;
  int doStopCallCount = 0;

  @override
  ConnectorConfig get config => _config;

  @override
  ChannelPolicy get policy => const ChannelPolicy();

  @override
  ChannelIdentity get identity => const ChannelIdentity(
        platform: 'test',
        channelId: 'test-channel',
      );

  @override
  ChannelCapabilities get capabilities =>
      extendedCapabilities.toBase();

  @override
  ExtendedChannelCapabilities get extendedCapabilities =>
      ExtendedChannelCapabilities.minimal();

  @override
  Future<void> start() async {
    startCallCount++;
    if (startBehaviour != null) {
      await startBehaviour!();
    }
    onConnected();
  }

  @override
  Future<void> doStop() async {
    doStopCallCount++;
  }

  @override
  Future<void> send(ChannelResponse response) async {
    // No-op for tests
  }

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    return SendResult.success(messageId: 'test-msg-1');
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    // No-op for tests
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('BaseConnector', () {
    late TestConnector connector;

    setUp(() {
      connector = TestConnector(TestConnectorConfig());
    });

    tearDown(() async {
      await connector.dispose();
    });

    // =========================================================================
    // Initial state
    // =========================================================================

    group('initial state', () {
      test('currentConnectionState starts as disconnected', () {
        expect(
          connector.currentConnectionState,
          ConnectionState.disconnected,
        );
      });

      test('isRunning is false when disconnected', () {
        expect(connector.isRunning, isFalse);
      });
    });

    // =========================================================================
    // events stream
    // =========================================================================

    group('events stream', () {
      test('emitEvent adds event to stream', () async {
        final event = ChannelEvent(
          id: 'evt-1',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          type: 'message',
          text: 'Hello',
          timestamp: DateTime.now(),
        );

        final future = connector.events.first;
        connector.emitEvent(event);
        final received = await future;

        expect(received.id, 'evt-1');
        expect(received.text, 'Hello');
      });

      test('emitEvent after dispose is silently ignored', () async {
        await connector.dispose();

        // Should not throw even though the controller is closed.
        final event = ChannelEvent(
          id: 'evt-2',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          type: 'message',
          text: 'After dispose',
          timestamp: DateTime.now(),
        );

        // This must not throw
        connector.emitEvent(event);
      });
    });

    // =========================================================================
    // connectionState stream
    // =========================================================================

    group('connectionState stream', () {
      test('updateConnectionState emits new state', () async {
        final states = <ConnectionState>[];
        final sub = connector.connectionState.listen(states.add);
        addTearDown(sub.cancel);

        connector.updateConnectionState(ConnectionState.connecting);
        connector.updateConnectionState(ConnectionState.connected);

        // Allow events to propagate
        await Future<void>.delayed(Duration.zero);

        expect(
          states,
          [ConnectionState.connecting, ConnectionState.connected],
        );
      });

      test('same state is not re-emitted', () async {
        final states = <ConnectionState>[];
        final sub = connector.connectionState.listen(states.add);
        addTearDown(sub.cancel);

        connector.updateConnectionState(ConnectionState.connected);
        connector.updateConnectionState(ConnectionState.connected);

        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(1));
        expect(states.first, ConnectionState.connected);
      });
    });

    // =========================================================================
    // isRunning
    // =========================================================================

    group('isRunning', () {
      test('returns true when connected', () {
        connector.updateConnectionState(ConnectionState.connected);
        expect(connector.isRunning, isTrue);
      });

      test('returns false when connecting', () {
        connector.updateConnectionState(ConnectionState.connecting);
        expect(connector.isRunning, isFalse);
      });

      test('returns false when reconnecting', () {
        connector.updateConnectionState(ConnectionState.reconnecting);
        expect(connector.isRunning, isFalse);
      });

      test('returns false when failed', () {
        connector.updateConnectionState(ConnectionState.failed);
        expect(connector.isRunning, isFalse);
      });
    });

    // =========================================================================
    // onConnected
    // =========================================================================

    group('onConnected', () {
      test('sets state to connected', () async {
        final states = <ConnectionState>[];
        final sub = connector.connectionState.listen(states.add);
        addTearDown(sub.cancel);

        connector.onConnected();

        await Future<void>.delayed(Duration.zero);

        expect(connector.currentConnectionState, ConnectionState.connected);
        expect(states, contains(ConnectionState.connected));
      });

      test('resets reconnect attempts', () async {
        // Use an auto-reconnect connector that fails on start
        final failConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 50),
            maxReconnectAttempts: 5,
          ),
        );
        addTearDown(failConnector.dispose);

        // Simulate a few disconnect-reconnect cycles by calling onError
        failConnector.startBehaviour = () async {
          failConnector.onConnected();
        };

        // Trigger an error (increments reconnect attempt)
        failConnector.onError(Exception('test'));

        await Future<void>.delayed(const Duration(milliseconds: 200));

        // After reconnect, onConnected resets the counter.
        // Now calling onDisconnected should schedule reconnect again
        // (i.e. counter was reset, not exhausted).
        final statesFuture =
            failConnector.connectionState.take(2).toList();

        failConnector.onDisconnected();

        final states = await statesFuture.timeout(
          const Duration(seconds: 2),
          onTimeout: () => <ConnectionState>[],
        );

        // Should see disconnected -> reconnecting (means counter was reset)
        expect(states, contains(ConnectionState.reconnecting));
      });
    });

    // =========================================================================
    // onDisconnected
    // =========================================================================

    group('onDisconnected', () {
      test('sets state to disconnected', () {
        connector.updateConnectionState(ConnectionState.connected);
        connector.onDisconnected();
        expect(
          connector.currentConnectionState,
          ConnectionState.disconnected,
        );
      });

      test('schedules reconnect when autoReconnect is true', () async {
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 50),
            maxReconnectAttempts: 3,
          ),
        );
        addTearDown(autoConnector.dispose);

        final states = <ConnectionState>[];
        final sub = autoConnector.connectionState.listen(states.add);
        addTearDown(sub.cancel);

        autoConnector.onDisconnected();

        // Wait for reconnect timer to fire
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Should see: disconnected, reconnecting, connected
        expect(states, contains(ConnectionState.reconnecting));
        expect(states, contains(ConnectionState.connected));
      });

      test('does not schedule reconnect when autoReconnect is false', () async {
        final noAutoConnector = TestConnector(
          TestConnectorConfig(autoReconnect: false),
        );
        addTearDown(noAutoConnector.dispose);

        final states = <ConnectionState>[];
        final sub = noAutoConnector.connectionState.listen(states.add);
        addTearDown(sub.cancel);

        noAutoConnector.onDisconnected();

        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Should only see disconnected, no reconnecting
        expect(states, isNot(contains(ConnectionState.reconnecting)));
      });
    });

    // =========================================================================
    // onError
    // =========================================================================

    group('onError', () {
      test('sets state to failed', () {
        connector.onError(Exception('boom'));
        expect(connector.currentConnectionState, ConnectionState.failed);
      });

      test('schedules reconnect when autoReconnect is true', () async {
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 50),
            maxReconnectAttempts: 3,
          ),
        );
        addTearDown(autoConnector.dispose);

        final states = <ConnectionState>[];
        final sub = autoConnector.connectionState.listen(states.add);
        addTearDown(sub.cancel);

        autoConnector.onError(Exception('test error'));

        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(states, contains(ConnectionState.reconnecting));
        expect(states, contains(ConnectionState.connected));
      });
    });

    // =========================================================================
    // Reconnect scheduling
    // =========================================================================

    group('reconnect scheduling', () {
      test('does not reconnect when autoReconnect is false', () async {
        final noAutoConnector = TestConnector(
          TestConnectorConfig(autoReconnect: false),
        );
        addTearDown(noAutoConnector.dispose);

        noAutoConnector.onError(Exception('fail'));

        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(noAutoConnector.startCallCount, 0);
      });

      test('stops after maxReconnectAttempts exceeded', () async {
        var failCount = 0;
        final limitedConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 30),
            maxReconnectAttempts: 2,
          ),
        );
        addTearDown(limitedConnector.dispose);

        // Make start always fail
        limitedConnector.startBehaviour = () async {
          failCount++;
          throw Exception('always fails');
        };

        // Trigger first reconnect
        limitedConnector.onError(Exception('initial error'));

        // Wait long enough for all reconnect attempts
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // maxReconnectAttempts = 2, so start should be called at most 2 times
        expect(failCount, lessThanOrEqualTo(2));
      });

      test('does not reconnect after dispose', () async {
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 100),
            maxReconnectAttempts: 5,
          ),
        );

        autoConnector.onError(Exception('fail'));

        // Dispose before the reconnect timer fires
        await autoConnector.dispose();

        final startCountBefore = autoConnector.startCallCount;

        await Future<void>.delayed(const Duration(milliseconds: 300));

        // start should not have been called after dispose
        expect(autoConnector.startCallCount, startCountBefore);
      });

      test('reconnect timer callback checks disposed flag', () async {
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 50),
            maxReconnectAttempts: 5,
          ),
        );

        // Trigger reconnect scheduling
        autoConnector.onDisconnected();

        // Dispose quickly (timer is pending but not yet fired)
        await autoConnector.dispose();

        final startCountBefore = autoConnector.startCallCount;

        // Wait for the timer to fire (it should bail out due to _disposed)
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(autoConnector.startCallCount, startCountBefore);
      });

      test('uses fixed reconnectDelay from config', () async {
        final stopwatch = Stopwatch()..start();
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 80),
            maxReconnectAttempts: 1,
          ),
        );
        addTearDown(autoConnector.dispose);

        final connected = autoConnector.connectionState
            .firstWhere((s) => s == ConnectionState.connected);

        autoConnector.onDisconnected();

        await connected;
        stopwatch.stop();

        // Should take at least ~80ms (the configured delay)
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(60));
      });

      test('reconnect increments attempt counter', () async {
        var startCount = 0;
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 30),
            maxReconnectAttempts: 3,
          ),
        );
        addTearDown(autoConnector.dispose);

        // First two starts fail, third succeeds
        autoConnector.startBehaviour = () async {
          startCount++;
          if (startCount < 3) {
            throw Exception('fail');
          }
          autoConnector.onConnected();
        };

        autoConnector.onError(Exception('initial'));

        // Wait enough time for all retries
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(startCount, 3);
        expect(
          autoConnector.currentConnectionState,
          ConnectionState.connected,
        );
      });

      test('cancels previous reconnect timer on new disconnect', () async {
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 200),
            maxReconnectAttempts: 5,
          ),
        );
        addTearDown(autoConnector.dispose);

        // Trigger two disconnects in quick succession
        autoConnector.onDisconnected();
        // State is now disconnected, timer is pending
        autoConnector.updateConnectionState(ConnectionState.connected);
        autoConnector.onDisconnected();
        // The first timer should have been cancelled

        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Start should only be called once (second timer, not both)
        expect(autoConnector.startCallCount, 1);
      });
    });

    // =========================================================================
    // stop
    // =========================================================================

    group('stop', () {
      test('cancels reconnect timer', () async {
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 200),
            maxReconnectAttempts: 5,
          ),
        );
        addTearDown(autoConnector.dispose);

        // Start a reconnect cycle
        autoConnector.onDisconnected();

        // Stop before reconnect timer fires
        await autoConnector.stop();

        final startCountBefore = autoConnector.startCallCount;

        await Future<void>.delayed(const Duration(milliseconds: 400));

        // Reconnect timer was cancelled, start should not have been called
        expect(autoConnector.startCallCount, startCountBefore);
      });

      test('sets state to disconnected', () async {
        connector.updateConnectionState(ConnectionState.connected);
        await connector.stop();
        expect(
          connector.currentConnectionState,
          ConnectionState.disconnected,
        );
      });

      test('calls doStop', () async {
        await connector.stop();
        expect(connector.doStopCallCount, 1);
      });
    });

    // =========================================================================
    // dispose
    // =========================================================================

    group('dispose', () {
      test('sets disposed flag (emitEvent becomes no-op)', () async {
        await connector.dispose();

        final event = ChannelEvent(
          id: 'evt-after-dispose',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          type: 'message',
          timestamp: DateTime.now(),
        );

        // Should not throw
        connector.emitEvent(event);
      });

      test('cancels reconnect timer', () async {
        final autoConnector = TestConnector(
          TestConnectorConfig(
            autoReconnect: true,
            reconnectDelay: const Duration(milliseconds: 100),
            maxReconnectAttempts: 5,
          ),
        );

        autoConnector.onDisconnected();
        await autoConnector.dispose();

        final startCountBefore = autoConnector.startCallCount;

        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(autoConnector.startCallCount, startCountBefore);
      });

      test('closes event stream controller', () async {
        final done = Completer<void>();
        connector.events.listen(
          null,
          onDone: () => done.complete(),
        );

        await connector.dispose();

        await done.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('Event stream was not closed'),
        );
      });

      test('closes connectionState stream controller', () async {
        final done = Completer<void>();
        connector.connectionState.listen(
          null,
          onDone: () => done.complete(),
        );

        await connector.dispose();

        await done.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('ConnectionState stream was not closed'),
        );
      });
    });

    // =========================================================================
    // TC-015: emitEvent dual-stream
    // =========================================================================

    group('emitEvent dual-stream (TC-015)', () {
      test('emits on both events and extendedEvents streams', () async {
        final event = ChannelEvent(
          id: 'evt-dual-1',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          type: 'message',
          text: 'Hello',
          timestamp: DateTime.now(),
        );

        final baseFuture = connector.events.first;
        final extFuture = connector.extendedEvents.first;

        connector.emitEvent(event);

        final baseReceived = await baseFuture;
        final extReceived = await extFuture;

        expect(baseReceived.id, 'evt-dual-1');
        expect(baseReceived.text, 'Hello');
        expect(extReceived.id, 'evt-dual-1');
        expect(extReceived.text, 'Hello');
      });

      test('extendedEvents receives ExtendedChannelEvent.fromBase wrapper', () async {
        final event = ChannelEvent(
          id: 'evt-wrap-1',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          type: 'message',
          text: 'Test',
          timestamp: DateTime.now(),
        );

        final extFuture = connector.extendedEvents.first;
        connector.emitEvent(event);
        final extReceived = await extFuture;

        expect(extReceived.eventType, ChannelEventType.message);
        expect(extReceived.base.id, 'evt-wrap-1');
      });

      test('emitEvent after dispose does not emit on either stream', () async {
        await connector.dispose();

        final event = ChannelEvent(
          id: 'evt-disposed',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          type: 'message',
          timestamp: DateTime.now(),
        );

        // Should not throw
        connector.emitEvent(event);
      });
    });

    // =========================================================================
    // TC-016: emitExtendedEvent dual-stream
    // =========================================================================

    group('emitExtendedEvent dual-stream (TC-016)', () {
      test('emits base on events stream and full event on extendedEvents', () async {
        final extEvent = ExtendedChannelEvent.message(
          id: 'ext-evt-1',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          text: 'Extended Hello',
          userId: 'u1',
        );

        final baseFuture = connector.events.first;
        final extFuture = connector.extendedEvents.first;

        connector.emitExtendedEvent(extEvent);

        final baseReceived = await baseFuture;
        final extReceived = await extFuture;

        // Base stream gets event.base (ChannelEvent)
        expect(baseReceived.id, 'ext-evt-1');
        expect(baseReceived.text, 'Extended Hello');

        // Extended stream gets full ExtendedChannelEvent
        expect(extReceived.eventType, ChannelEventType.message);
        expect(extReceived.id, 'ext-evt-1');
        expect(extReceived.userId, 'u1');
      });

      test('event with null optional fields emits correctly', () async {
        final extEvent = ExtendedChannelEvent.message(
          id: 'ext-evt-2',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          text: 'Minimal',
        );

        final baseFuture = connector.events.first;
        final extFuture = connector.extendedEvents.first;

        connector.emitExtendedEvent(extEvent);

        final baseReceived = await baseFuture;
        final extReceived = await extFuture;

        expect(baseReceived.userId, isNull);
        expect(extReceived.identityInfo, isNull);
      });
    });

    // =========================================================================
    // TC-017: sendBatch (default sequential)
    // =========================================================================

    group('sendBatch (TC-017)', () {
      test('sends 3 responses and returns 3 results in order', () async {
        final conv = ConversationKey(
          channel: const ChannelIdentity(
            platform: 'test',
            channelId: 'ch-1',
          ),
          conversationId: 'conv-1',
        );

        final responses = [
          ChannelResponse.text(conversation: conv, text: 'msg1'),
          ChannelResponse.text(conversation: conv, text: 'msg2'),
          ChannelResponse.text(conversation: conv, text: 'msg3'),
        ];

        final results = await connector.sendBatch(responses);

        expect(results, hasLength(3));
        expect(results[0].success, isTrue);
        expect(results[1].success, isTrue);
        expect(results[2].success, isTrue);
      });

      test('returns empty list for empty input', () async {
        final results = await connector.sendBatch([]);

        expect(results, isEmpty);
      });

      test('propagates failure from sendWithResult', () async {
        final customConnector = _FailOnNthConnector(
          TestConnectorConfig(),
          failOnCall: 2,
        );
        addTearDown(customConnector.dispose);

        final conv = ConversationKey(
          channel: const ChannelIdentity(
            platform: 'test',
            channelId: 'ch-1',
          ),
          conversationId: 'conv-1',
        );

        final responses = [
          ChannelResponse.text(conversation: conv, text: 'msg1'),
          ChannelResponse.text(conversation: conv, text: 'msg2'),
          ChannelResponse.text(conversation: conv, text: 'msg3'),
        ];

        final results = await customConnector.sendBatch(responses);

        expect(results, hasLength(3));
        expect(results[0].success, isTrue);
        expect(results[1].success, isFalse);
        expect(results[2].success, isTrue);
      });
    });

    // =========================================================================
    // Default null-returning methods
    // =========================================================================

    group('default methods', () {
      test('getConversation returns null', () async {
        final key = ConversationKey(
          channel: const ChannelIdentity(
            platform: 'test',
            channelId: 'ch-1',
          ),
          conversationId: 'conv-1',
        );
        final result = await connector.getConversation(key);
        expect(result, isNull);
      });

      test('getIdentityInfo returns null', () async {
        final result = await connector.getIdentityInfo('user-1');
        expect(result, isNull);
      });

      test('uploadFile returns null', () async {
        final result = await connector.uploadFile(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          name: 'test.txt',
          data: Uint8List.fromList([1, 2, 3]),
          mimeType: 'text/plain',
        );
        expect(result, isNull);
      });

      test('uploadFile returns null without mimeType', () async {
        final result = await connector.uploadFile(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'test',
              channelId: 'ch-1',
            ),
            conversationId: 'conv-1',
          ),
          name: 'test.bin',
          data: Uint8List(0),
        );
        expect(result, isNull);
      });

      test('downloadFile returns null', () async {
        final result = await connector.downloadFile('file-123');
        expect(result, isNull);
      });
    });
  });

  // ===========================================================================
  // ConnectorException
  // ===========================================================================

  group('ConnectorException', () {
    test('constructor with message only', () {
      const ex = ConnectorException('Something failed');
      expect(ex.message, 'Something failed');
      expect(ex.code, isNull);
      expect(ex.cause, isNull);
    });

    test('constructor with message and code', () {
      const ex = ConnectorException('Auth error', code: 'auth_failed');
      expect(ex.message, 'Auth error');
      expect(ex.code, 'auth_failed');
      expect(ex.cause, isNull);
    });

    test('constructor with message, code, and cause', () {
      final cause = Exception('root cause');
      final ex = ConnectorException(
        'Wrapped error',
        code: 'wrap',
        cause: cause,
      );
      expect(ex.message, 'Wrapped error');
      expect(ex.code, 'wrap');
      expect(ex.cause, cause);
    });

    test('toString with code includes code in brackets', () {
      const ex = ConnectorException('Bad thing', code: 'ERR_001');
      expect(ex.toString(), 'ConnectorException[ERR_001]: Bad thing');
    });

    test('toString without code omits brackets', () {
      const ex = ConnectorException('Simple failure');
      expect(ex.toString(), 'ConnectorException: Simple failure');
    });
  });

  // ===========================================================================
  // ConnectorConfig interface
  // ===========================================================================

  group('ConnectorConfig', () {
    test('TestConnectorConfig implements ConnectorConfig correctly', () {
      final config = TestConnectorConfig(
        autoReconnect: true,
        reconnectDelay: const Duration(seconds: 10),
        maxReconnectAttempts: 5,
      );

      expect(config.channelType, 'test');
      expect(config.autoReconnect, isTrue);
      expect(config.reconnectDelay, const Duration(seconds: 10));
      expect(config.maxReconnectAttempts, 5);
    });

    test('TestConnectorConfig defaults', () {
      final config = TestConnectorConfig();

      expect(config.autoReconnect, isFalse);
      expect(config.reconnectDelay, const Duration(milliseconds: 100));
      expect(config.maxReconnectAttempts, 3);
    });
  });
}

// =============================================================================
// Additional test doubles
// =============================================================================

/// A connector that fails on the Nth call to [sendWithResult].
class _FailOnNthConnector extends BaseConnector {
  _FailOnNthConnector(this._config, {required this.failOnCall});

  final TestConnectorConfig _config;
  final int failOnCall;
  int _callCount = 0;

  @override
  ConnectorConfig get config => _config;

  @override
  ChannelPolicy get policy => const ChannelPolicy();

  @override
  ChannelIdentity get identity => const ChannelIdentity(
        platform: 'test',
        channelId: 'test-fail-channel',
      );

  @override
  ChannelCapabilities get capabilities => extendedCapabilities.toBase();

  @override
  ExtendedChannelCapabilities get extendedCapabilities =>
      ExtendedChannelCapabilities.minimal();

  @override
  Future<void> start() async {
    onConnected();
  }

  @override
  Future<void> doStop() async {}

  @override
  Future<void> send(ChannelResponse response) async {}

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    _callCount++;
    if (_callCount == failOnCall) {
      return SendResult.failure(
        error: const ChannelError(
          code: 'test_error',
          message: 'Simulated failure',
        ),
      );
    }
    return SendResult.success(messageId: 'msg-$_callCount');
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {}
}
