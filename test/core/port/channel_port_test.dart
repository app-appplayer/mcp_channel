import 'dart:async';
import 'dart:typed_data';

import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

/// Concrete implementation for testing BaseExtendedChannelPort.
class _TestPort extends BaseExtendedChannelPort {
  final StreamController<ChannelEvent> _eventsController =
      StreamController.broadcast();
  final StreamController<ExtendedChannelEvent> _extEventsController =
      StreamController.broadcast();
  final StreamController<ConnectionState> _connController =
      StreamController.broadcast();

  final List<SendResult> sendResults;
  int sendCallCount = 0;

  _TestPort({List<SendResult>? results})
      : sendResults = results ?? [SendResult.success(messageId: 'msg_1')];

  @override
  String get channelType => identity.platform;

  @override
  Stream<ChannelEvent> get events => _eventsController.stream;

  @override
  Stream<ExtendedChannelEvent> get extendedEvents =>
      _extEventsController.stream;

  @override
  Stream<ConnectionState> get connectionState => _connController.stream;

  @override
  ExtendedChannelCapabilities get extendedCapabilities =>
      ExtendedChannelCapabilities.minimal();

  @override
  ChannelIdentity get identity =>
      ChannelIdentity(platform: 'test', channelId: 'ch_1');

  @override
  Future<void> start() async {
    isRunning = true;
  }

  @override
  Future<void> stop() async {
    isRunning = false;
  }

  @override
  Future<void> dispose() async {
    await _eventsController.close();
    await _extEventsController.close();
    await _connController.close();
  }

  @override
  Future<void> send(ChannelResponse response) async {}

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    final index = sendCallCount % sendResults.length;
    sendCallCount++;
    return sendResults[index];
  }

  @override
  Future<List<SendResult>> sendBatch(List<ChannelResponse> responses) async {
    final results = <SendResult>[];
    for (final r in responses) {
      results.add(await sendWithResult(r));
    }
    return results;
  }

  @override
  Future<ChannelIdentityInfo?> getIdentityInfo(String userId) async => null;

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) async => null;

  @override
  Future<FileInfo?> uploadFile({
    required ConversationKey conversation,
    required String name,
    required Uint8List data,
    String? mimeType,
  }) async =>
      null;

  @override
  Future<Uint8List?> downloadFile(String fileId) async => null;
}

void main() {
  final conversation = ConversationKey(
    channel: ChannelIdentity(platform: 'test', channelId: 'ch_1'),
    conversationId: 'conv_1',
    userId: 'U1',
  );

  group('BaseExtendedChannelPort', () {
    late _TestPort port;

    setUp(() {
      port = _TestPort();
    });

    tearDown(() async {
      await port.dispose();
    });

    test('isRunning defaults to false', () {
      expect(port.isRunning, false);
    });

    test('start sets isRunning to true', () async {
      await port.start();
      expect(port.isRunning, true);
    });

    test('stop sets isRunning to false', () async {
      await port.start();
      await port.stop();
      expect(port.isRunning, false);
    });

    test('capabilities returns base from extended', () {
      final caps = port.capabilities;
      expect(caps, isNotNull);
    });

    test('channelType returns identity platform', () {
      expect(port.channelType, 'test');
    });

    group('sendText', () {
      test('sends text response', () async {
        final result = await port.sendText(conversation, 'hello');
        expect(result.success, true);
        expect(port.sendCallCount, 1);
      });

      test('sends text with replyTo', () async {
        final result = await port.sendText(
          conversation,
          'reply',
          replyTo: 'msg_0',
        );
        expect(result.success, true);
      });
    });

    group('sendWithRetry', () {
      test('returns success on first try', () async {
        final result = await port.sendWithRetry(
          ChannelResponse.text(
            conversation: conversation,
            text: 'test',
          ),
        );
        expect(result.success, true);
        expect(port.sendCallCount, 1);
      });

      test('stops on non-retryable error', () async {
        final errorPort = _TestPort(results: [
          SendResult.failure(
            error: ChannelError.permissionDenied(message: 'denied'),
          ),
        ]);

        final result = await errorPort.sendWithRetry(
          ChannelResponse.text(conversation: conversation, text: 'x'),
          maxRetries: 3,
        );

        expect(result.success, false);
        // 1 attempt + 1 final attempt = 2 at most, but non-retryable should stop at 1
        expect(errorPort.sendCallCount, 1);
        await errorPort.dispose();
      });

      test('retries on retryable error then succeeds', () async {
        final retryPort = _TestPort(results: [
          SendResult.failure(
            error: ChannelError.rateLimited(
              retryAfter: const Duration(milliseconds: 10),
            ),
          ),
          SendResult.success(messageId: 'msg_2'),
        ]);

        final result = await retryPort.sendWithRetry(
          ChannelResponse.text(conversation: conversation, text: 'x'),
          maxRetries: 3,
        );

        expect(result.success, true);
        expect(retryPort.sendCallCount, 2);
        await retryPort.dispose();
      });
    });

    group('default method implementations', () {
      test('sendTyping does nothing', () async {
        await port.sendTyping(conversation);
      });

      test('edit throws UnsupportedError', () {
        expect(
          () => port.edit(
            'msg_1',
            ChannelResponse.text(conversation: conversation, text: 'x'),
          ),
          throwsUnsupportedError,
        );
      });

      test('delete throws UnsupportedError', () {
        expect(
          () => port.delete('msg_1'),
          throwsUnsupportedError,
        );
      });

      test('react throws UnsupportedError', () {
        expect(
          () => port.react('msg_1', '👍'),
          throwsUnsupportedError,
        );
      });
    });
  });

  group('ConnectionState', () {
    test('has all expected values', () {
      expect(ConnectionState.values, hasLength(5));
      expect(
          ConnectionState.values, contains(ConnectionState.disconnected));
      expect(ConnectionState.values, contains(ConnectionState.connecting));
      expect(ConnectionState.values, contains(ConnectionState.connected));
      expect(
          ConnectionState.values, contains(ConnectionState.reconnecting));
      expect(ConnectionState.values, contains(ConnectionState.failed));
    });
  });
}
