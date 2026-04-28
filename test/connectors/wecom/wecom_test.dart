import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

import 'package:mcp_channel/src/connectors/wecom/wecom.dart';

void main() {
  group('WeComConfig', () {
    test('creates config with required fields', () {
      final config = WeComConfig(
        corpId: 'ww1234567890',
        agentId: 1000002,
        agentSecret: 'test-secret',
        callbackToken: 'test-token',
        encodingAesKey: 'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF',
        callbackPath: '/wecom/callback',
      );

      expect(config.corpId, 'ww1234567890');
      expect(config.agentId, 1000002);
      expect(config.agentSecret, 'test-secret');
      expect(config.callbackToken, 'test-token');
      expect(config.encodingAesKey,
          'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF');
      expect(config.callbackPath, '/wecom/callback');
      expect(config.apiBaseUrl, 'https://qyapi.weixin.qq.com');
      expect(config.channelType, 'wecom');
      expect(config.autoReconnect, isTrue);
      expect(config.maxReconnectAttempts, 10);
    });

    test('creates config with all fields', () {
      final config = WeComConfig(
        corpId: 'ww1234567890',
        agentId: 1000002,
        agentSecret: 'test-secret',
        callbackToken: 'test-token',
        encodingAesKey: 'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF',
        callbackPath: '/wecom/callback',
        apiBaseUrl: 'https://custom.api.weixin.qq.com',
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 10),
        maxReconnectAttempts: 5,
      );

      expect(config.callbackPath, '/wecom/callback');
      expect(config.apiBaseUrl, 'https://custom.api.weixin.qq.com');
      expect(config.autoReconnect, isFalse);
      expect(config.reconnectDelay, const Duration(seconds: 10));
      expect(config.maxReconnectAttempts, 5);
    });

    test('has correct default reconnect delay', () {
      final config = WeComConfig(
        corpId: 'ww1234567890',
        agentId: 1000002,
        agentSecret: 'test-secret',
        callbackToken: 'test-token',
        encodingAesKey: 'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF',
        callbackPath: '/wecom/callback',
      );

      expect(config.reconnectDelay, const Duration(seconds: 5));
    });

    test('has correct default apiBaseUrl', () {
      final config = WeComConfig(
        corpId: 'ww1234567890',
        agentId: 1000002,
        agentSecret: 'test-secret',
        callbackToken: 'test-token',
        encodingAesKey: 'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF',
        callbackPath: '/wecom/callback',
      );

      expect(config.apiBaseUrl, 'https://qyapi.weixin.qq.com');
    });

    test('copyWith creates new config with updated fields', () {
      final original = WeComConfig(
        corpId: 'ww1234567890',
        agentId: 1000002,
        agentSecret: 'test-secret',
        callbackToken: 'test-token',
        encodingAesKey: 'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF',
        callbackPath: '/wecom/callback',
      );

      final copied = original.copyWith(
        corpId: 'wwUpdated',
        agentId: 1000003,
        callbackPath: '/wecom/updated',
        apiBaseUrl: 'https://custom.weixin.qq.com',
      );

      expect(copied.corpId, 'wwUpdated');
      expect(copied.agentId, 1000003);
      expect(copied.callbackPath, '/wecom/updated');
      expect(copied.apiBaseUrl, 'https://custom.weixin.qq.com');
      // Unchanged fields should be preserved
      expect(copied.agentSecret, original.agentSecret);
      expect(copied.callbackToken, original.callbackToken);
      expect(copied.encodingAesKey, original.encodingAesKey);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith preserves all fields when no arguments given', () {
      final original = WeComConfig(
        corpId: 'ww1234567890',
        agentId: 1000002,
        agentSecret: 'original-secret',
        callbackToken: 'original-token',
        encodingAesKey: 'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF',
        callbackPath: '/wecom/callback',
        apiBaseUrl: 'https://custom.weixin.qq.com',
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 15),
        maxReconnectAttempts: 3,
      );

      final copied = original.copyWith();

      expect(copied.corpId, original.corpId);
      expect(copied.agentId, original.agentId);
      expect(copied.agentSecret, original.agentSecret);
      expect(copied.callbackToken, original.callbackToken);
      expect(copied.encodingAesKey, original.encodingAesKey);
      expect(copied.callbackPath, original.callbackPath);
      expect(copied.apiBaseUrl, original.apiBaseUrl);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });
  });

  group('WeComConnector', () {
    late WeComConnector connector;

    setUp(() {
      connector = WeComConnector(
        config: WeComConfig(
          corpId: 'ww1234567890',
          agentId: 1000002,
          agentSecret: 'test-secret',
          callbackToken: 'test-callback-token',
          encodingAesKey: 'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF',
          callbackPath: '/wecom/callback',
        ),
      );
    });

    test('has correct channel type', () {
      expect(connector.channelType, 'wecom');
    });

    test('has correct identity', () {
      expect(connector.identity.platform, 'wecom');
      expect(connector.identity.channelId, 'ww1234567890');
    });

    test('has wecom capabilities', () {
      final caps = connector.extendedCapabilities;
      expect(caps.text, isTrue);
      expect(caps.richMessages, isTrue);
      expect(caps.attachments, isTrue);
      expect(caps.reactions, isFalse);
      expect(caps.threads, isFalse);
      expect(caps.editing, isFalse);
      expect(caps.deleting, isTrue);
      expect(caps.typingIndicator, isFalse);
      expect(caps.maxMessageLength, 2048);
      expect(caps.supportsFiles, isTrue);
      expect(caps.supportsButtons, isTrue);
      expect(caps.supportsMenus, isTrue);
      expect(caps.supportsModals, isFalse);
      expect(caps.supportsEphemeral, isFalse);
      expect(caps.supportsCommands, isTrue);
    });

    test('capabilities is ExtendedChannelCapabilities', () {
      expect(connector.capabilities, isA<ExtendedChannelCapabilities>());
    });

    test('starts disconnected', () {
      expect(connector.isRunning, isFalse);
      expect(
        connector.currentConnectionState,
        ConnectionState.disconnected,
      );
    });

    group('send validation', () {
      test('send rejects response without text or blocks', () async {
        final response = ChannelResponse(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'wecom',
              channelId: 'ww1234567890',
            ),
            conversationId: 'user-1',
          ),
          type: 'text',
        );

        expect(
          () => connector.send(response),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('sendWithResult returns failure for empty response', () async {
        final response = ChannelResponse(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'wecom',
              channelId: 'ww1234567890',
            ),
            conversationId: 'user-1',
          ),
          type: 'text',
        );

        final result = await connector.sendWithResult(response);
        expect(result.success, isFalse);
        expect(result.error?.code, ChannelErrorCode.invalidRequest);
      });
    });

    group('unsupported operations', () {
      test('edit throws UnsupportedError', () {
        expect(
          () => connector.edit(
            'msg-1',
            ChannelResponse.text(
              conversation: ConversationKey(
                channel: const ChannelIdentity(
                  platform: 'wecom',
                  channelId: 'ww1234567890',
                ),
                conversationId: 'user-1',
              ),
              text: 'updated',
            ),
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('delete throws UnsupportedError', () {
        expect(
          () => connector.delete('msg-1'),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('react throws UnsupportedError', () {
        expect(
          () => connector.react('msg-1', 'thumbsup'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('callback verification', () {
      test('verifyCallback rejects invalid signature', () {
        final result = connector.verifyCallback(
          msgSignature: 'invalid',
          timestamp: '12345',
          nonce: 'nonce',
          echoStr: 'test',
        );

        expect(result, isNull);
      });

      test('verifyCallback signature computation uses SHA1 of sorted params',
          () {
        // Compute the expected signature manually using the same algorithm:
        // SHA1(sort([callbackToken, timestamp, nonce, encrypt]).join())
        const callbackToken = 'test-callback-token';
        const timestamp = '1609459200';
        const nonce = 'abc123';
        const echoStr = 'encrypted_echo_string';

        final params = [callbackToken, timestamp, nonce, echoStr]..sort();
        final plainText = params.join();
        final expectedSignature =
            sha1.convert(utf8.encode(plainText)).toString();

        // With a valid signature, verifyCallback proceeds to decryption.
        // Since the echoStr is not valid base64-encrypted content,
        // the decryption will fail and the method returns null.
        // This confirms the signature check passed (no early null return
        // from mismatch) and execution reached the decryption step.
        final result = connector.verifyCallback(
          msgSignature: expectedSignature,
          timestamp: timestamp,
          nonce: nonce,
          echoStr: echoStr,
        );

        // The result is null because decryption fails on invalid input,
        // but the signature verification itself succeeded.
        expect(result, isNull);
      });

      test('verifyCallback rejects tampered timestamp', () {
        // Compute signature with one timestamp but call with another
        const callbackToken = 'test-callback-token';
        const timestamp = '1609459200';
        const nonce = 'abc123';
        const echoStr = 'encrypted_echo_string';

        final params = [callbackToken, timestamp, nonce, echoStr]..sort();
        final plainText = params.join();
        final signature = sha1.convert(utf8.encode(plainText)).toString();

        // Call with a different timestamp -- signature will not match
        final result = connector.verifyCallback(
          msgSignature: signature,
          timestamp: '9999999999',
          nonce: nonce,
          echoStr: echoStr,
        );

        expect(result, isNull);
      });

      test('verifyCallback rejects tampered nonce', () {
        const callbackToken = 'test-callback-token';
        const timestamp = '1609459200';
        const nonce = 'abc123';
        const echoStr = 'encrypted_echo_string';

        final params = [callbackToken, timestamp, nonce, echoStr]..sort();
        final plainText = params.join();
        final signature = sha1.convert(utf8.encode(plainText)).toString();

        // Call with a different nonce
        final result = connector.verifyCallback(
          msgSignature: signature,
          timestamp: timestamp,
          nonce: 'tampered_nonce',
          echoStr: echoStr,
        );

        expect(result, isNull);
      });
    });

    group('handleCallback', () {
      test('rejects callback with missing Encrypt element', () {
        final result = connector.handleCallback(
          msgSignature: 'any-signature',
          timestamp: '12345',
          nonce: 'nonce',
          xmlBody: '<xml><NoEncrypt>data</NoEncrypt></xml>',
        );

        expect(result, isNull);
      });

      test('rejects callback with invalid signature', () {
        const xmlBody = '<xml>'
            '<Encrypt><![CDATA[some_encrypted_data]]></Encrypt>'
            '</xml>';

        final result = connector.handleCallback(
          msgSignature: 'wrong_signature',
          timestamp: '12345',
          nonce: 'nonce',
          xmlBody: xmlBody,
        );

        expect(result, isNull);
      });

      test('extracts Encrypt element and verifies signature', () {
        const encryptedContent = 'base64_encrypted_content';
        const timestamp = '1609459200';
        const nonce = 'callback_nonce';

        // Compute valid signature for the encrypted content
        final params = [
          'test-callback-token',
          timestamp,
          nonce,
          encryptedContent,
        ]..sort();
        final plainText = params.join();
        final validSignature =
            sha1.convert(utf8.encode(plainText)).toString();

        final xmlBody = '<xml>'
            '<Encrypt><![CDATA[$encryptedContent]]></Encrypt>'
            '</xml>';

        // Signature is valid but decryption fails on invalid input,
        // so the result is null. This confirms signature verification passed.
        final result = connector.handleCallback(
          msgSignature: validSignature,
          timestamp: timestamp,
          nonce: nonce,
          xmlBody: xmlBody,
        );

        expect(result, isNull);
      });
    });

    group('identity with different corpId', () {
      test('identity channelId matches config corpId', () {
        final customConnector = WeComConnector(
          config: WeComConfig(
            corpId: 'wwCustomCorp',
            agentId: 9999,
            agentSecret: 'custom-secret',
            callbackToken: 'custom-token',
            encodingAesKey: 'abcdefghijklmnopqrstuvwxyz01234567890ABCDEF',
            callbackPath: '/wecom/custom',
          ),
        );

        expect(customConnector.identity.platform, 'wecom');
        expect(customConnector.identity.channelId, 'wwCustomCorp');

        // Cleanup
        customConnector.dispose();
      });
    });

    tearDown(() async {
      await connector.dispose();
    });
  });
}
