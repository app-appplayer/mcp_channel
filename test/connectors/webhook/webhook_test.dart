import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

import 'package:mcp_channel/src/connectors/webhook/webhook.dart';

void main() {
  group('WebhookConfig', () {
    test('creates config with defaults', () {
      const config = WebhookConfig();

      expect(config.channelType, 'webhook');
      expect(config.inboundPath, '/webhook');
      expect(config.auth, isNull);
      expect(config.responseMode, WebhookResponseMode.callback);
      expect(config.enableCors, isFalse);
      expect(config.corsOrigins, isNull);
      expect(config.customHeaders, isNull);
      expect(config.timeout, const Duration(seconds: 30));
    });

    test('creates config with all fields', () {
      final config = WebhookConfig(
        inboundPath: '/api/hook',
        outboundUrl: 'https://example.com/callback',
        auth: const ApiKeyAuth(apiKey: 'key123'),
        format: const WebhookFormat.json(),
        responseMode: WebhookResponseMode.synchronous,
        enableCors: true,
        corsOrigins: ['https://example.com'],
        customHeaders: {'X-Custom': 'value'},
        timeout: const Duration(seconds: 60),
      );

      expect(config.inboundPath, '/api/hook');
      expect(config.outboundUrl, 'https://example.com/callback');
      expect(config.auth, isA<ApiKeyAuth>());
      expect(config.responseMode, WebhookResponseMode.synchronous);
      expect(config.enableCors, isTrue);
      expect(config.corsOrigins, ['https://example.com']);
      expect(config.customHeaders, {'X-Custom': 'value'});
      expect(config.timeout, const Duration(seconds: 60));
    });

    test('copyWith creates updated config', () {
      const original = WebhookConfig();
      final copied = original.copyWith(
        outboundUrl: 'https://example.com/callback',
        auth: const BearerAuth(token: 'token123'),
        responseMode: WebhookResponseMode.both,
        enableCors: true,
      );

      expect(copied.outboundUrl, 'https://example.com/callback');
      expect(copied.auth, isA<BearerAuth>());
      expect(copied.responseMode, WebhookResponseMode.both);
      expect(copied.enableCors, isTrue);
      expect(copied.inboundPath, '/webhook');
    });
  });

  group('WebhookResponseMode', () {
    test('has all required values', () {
      expect(WebhookResponseMode.values, hasLength(3));
      expect(WebhookResponseMode.values, contains(WebhookResponseMode.callback));
      expect(
        WebhookResponseMode.values,
        contains(WebhookResponseMode.synchronous),
      );
      expect(WebhookResponseMode.values, contains(WebhookResponseMode.both));
    });
  });

  group('WebhookAuth', () {
    group('ApiKeyAuth', () {
      test('validates matching API key', () {
        const auth = ApiKeyAuth(apiKey: 'my-secret-key');
        final valid = auth.validate(
          {'X-API-Key': 'my-secret-key'},
          '{}',
        );
        expect(valid, isTrue);
      });

      test('validates case-insensitive header name', () {
        const auth = ApiKeyAuth(apiKey: 'my-key');
        final valid = auth.validate(
          {'x-api-key': 'my-key'},
          '{}',
        );
        expect(valid, isTrue);
      });

      test('rejects invalid API key', () {
        const auth = ApiKeyAuth(apiKey: 'correct-key');
        final valid = auth.validate(
          {'X-API-Key': 'wrong-key'},
          '{}',
        );
        expect(valid, isFalse);
      });

      test('uses custom header name', () {
        const auth = ApiKeyAuth(
          headerName: 'X-Custom-Key',
          apiKey: 'my-key',
        );
        final valid = auth.validate(
          {'X-Custom-Key': 'my-key'},
          '{}',
        );
        expect(valid, isTrue);
      });

      test('applies headers for outgoing requests', () {
        const auth = ApiKeyAuth(apiKey: 'my-key');
        final headers = auth.applyHeaders({'Content-Type': 'application/json'});
        expect(headers['X-API-Key'], 'my-key');
        expect(headers['Content-Type'], 'application/json');
      });
    });

    group('BearerAuth', () {
      test('validates matching bearer token', () {
        const auth = BearerAuth(token: 'my-token');
        final valid = auth.validate(
          {'authorization': 'Bearer my-token'},
          '{}',
        );
        expect(valid, isTrue);
      });

      test('validates Authorization header (capitalized)', () {
        const auth = BearerAuth(token: 'my-token');
        final valid = auth.validate(
          {'Authorization': 'Bearer my-token'},
          '{}',
        );
        expect(valid, isTrue);
      });

      test('rejects invalid bearer token', () {
        const auth = BearerAuth(token: 'correct-token');
        final valid = auth.validate(
          {'authorization': 'Bearer wrong-token'},
          '{}',
        );
        expect(valid, isFalse);
      });

      test('applies headers for outgoing requests', () {
        const auth = BearerAuth(token: 'my-token');
        final headers = auth.applyHeaders({});
        expect(headers['Authorization'], 'Bearer my-token');
      });
    });

    group('HmacAuth', () {
      test('validates correct HMAC-SHA256 signature', () {
        const auth = HmacAuth(secret: 'test-secret');
        const body = '{"event":"test"}';
        final key = utf8.encode('test-secret');
        final bytes = utf8.encode(body);
        final signature = Hmac(sha256, key).convert(bytes).toString();

        final valid = auth.validate(
          {'X-Signature': signature},
          body,
        );
        expect(valid, isTrue);
      });

      test('validates prefixed HMAC signature (sha256=...)', () {
        const auth = HmacAuth(secret: 'test-secret');
        const body = '{"event":"test"}';
        final key = utf8.encode('test-secret');
        final bytes = utf8.encode(body);
        final signature = Hmac(sha256, key).convert(bytes).toString();

        final valid = auth.validate(
          {'X-Signature': 'sha256=$signature'},
          body,
        );
        expect(valid, isTrue);
      });

      test('validates HMAC-SHA1 signature', () {
        const auth = HmacAuth(secret: 'test-secret', algorithm: 'sha1');
        const body = '{"event":"test"}';
        final key = utf8.encode('test-secret');
        final bytes = utf8.encode(body);
        final signature = Hmac(sha1, key).convert(bytes).toString();

        final valid = auth.validate(
          {'X-Signature': signature},
          body,
        );
        expect(valid, isTrue);
      });

      test('rejects invalid HMAC signature', () {
        const auth = HmacAuth(secret: 'test-secret');
        final valid = auth.validate(
          {'X-Signature': 'wrong-signature'},
          '{"event":"test"}',
        );
        expect(valid, isFalse);
      });

      test('rejects missing signature header', () {
        const auth = HmacAuth(secret: 'test-secret');
        final valid = auth.validate({}, '{"event":"test"}');
        expect(valid, isFalse);
      });

      test('uses custom header name', () {
        const auth = HmacAuth(
          secret: 'my-secret',
          headerName: 'X-Hub-Signature',
        );
        const body = 'payload';
        final signature = auth.computeSignature(body);

        final valid = auth.validate(
          {'X-Hub-Signature': signature},
          body,
        );
        expect(valid, isTrue);
      });
    });

    group('BasicAuth', () {
      test('validates correct credentials', () {
        const auth = BasicAuth(username: 'admin', password: 'secret');
        final encoded = base64.encode(utf8.encode('admin:secret'));
        final valid = auth.validate(
          {'authorization': 'Basic $encoded'},
          '{}',
        );
        expect(valid, isTrue);
      });

      test('rejects wrong credentials', () {
        const auth = BasicAuth(username: 'admin', password: 'secret');
        final encoded = base64.encode(utf8.encode('admin:wrong'));
        final valid = auth.validate(
          {'authorization': 'Basic $encoded'},
          '{}',
        );
        expect(valid, isFalse);
      });

      test('rejects missing auth header', () {
        const auth = BasicAuth(username: 'admin', password: 'secret');
        final valid = auth.validate({}, '{}');
        expect(valid, isFalse);
      });

      test('rejects non-Basic auth header', () {
        const auth = BasicAuth(username: 'admin', password: 'secret');
        final valid = auth.validate(
          {'authorization': 'Bearer token'},
          '{}',
        );
        expect(valid, isFalse);
      });

      test('applies headers for outgoing requests', () {
        const auth = BasicAuth(username: 'admin', password: 'secret');
        final headers = auth.applyHeaders({});
        final expected = base64.encode(utf8.encode('admin:secret'));
        expect(headers['Authorization'], 'Basic $expected');
      });
    });
  });

  group('WebhookFormat', () {
    test('json format has correct content type', () {
      const format = WebhookFormat.json();
      expect(format.contentType, 'application/json');
    });

    test('form format has correct content type', () {
      const format = WebhookFormat.form();
      expect(format.contentType, 'application/x-www-form-urlencoded');
    });

    test('custom format uses provided values', () {
      final format = WebhookFormat.custom(
        contentType: 'application/xml',
        parser: (data, headers) => ChannelEvent(
          id: 'test',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'webhook',
              channelId: 'test',
            ),
            conversationId: 'test',
          ),
          type: 'message',
          text: data['raw'] as String?,
          timestamp: DateTime.now(),
        ),
        builder: (response) => '<response>${response.text}</response>',
      );

      expect(format.contentType, 'application/xml');
    });

    test('json parser creates valid event from data', () {
      const format = WebhookFormat.json();
      final event = format.parser(
        {
          'type': 'message',
          'text': 'Hello',
          'userId': 'user-1',
          'channelId': 'chan-1',
          'conversationId': 'conv-1',
        },
        {'content-type': 'application/json'},
      );

      expect(event.type, 'message');
      expect(event.text, 'Hello');
      expect(event.userId, 'user-1');
      expect(event.conversation.conversationId, 'conv-1');
    });
  });

  group('WebhookCapabilityConfig', () {
    test('default config has expected values', () {
      const config = WebhookCapabilityConfig();
      expect(config.threads, isFalse);
      expect(config.buttons, isTrue);
      expect(config.commands, isTrue);
      expect(config.blocks, isTrue);
    });

    test('full config enables all capabilities', () {
      const config = WebhookCapabilityConfig.full();
      expect(config.threads, isTrue);
      expect(config.reactions, isTrue);
      expect(config.files, isTrue);
      expect(config.blocks, isTrue);
      expect(config.buttons, isTrue);
      expect(config.menus, isTrue);
      expect(config.modals, isTrue);
      expect(config.ephemeral, isTrue);
      expect(config.edit, isTrue);
      expect(config.delete, isTrue);
      expect(config.typing, isTrue);
      expect(config.commands, isTrue);
    });

    test('builds capabilities correctly', () {
      const config = WebhookCapabilityConfig(
        threads: true,
        files: true,
        maxFileSize: 1024,
      );
      final caps = config.buildCapabilities();
      expect(caps.threads, isTrue);
      expect(caps.supportsFiles, isTrue);
      expect(caps.maxFileSize, 1024);
      expect(caps.reactions, isFalse);
    });
  });

  group('WebhookConnector', () {
    late WebhookConnector connector;

    setUp(() {
      connector = WebhookConnector(
        config: const WebhookConfig(
          inboundPath: '/api/webhook',
        ),
      );
    });

    test('has correct channel type', () {
      expect(connector.channelType, 'webhook');
    });

    test('has correct identity', () {
      expect(connector.identity.platform, 'webhook');
      expect(connector.identity.channelId, '/api/webhook');
    });

    test('has webhook capabilities', () {
      final caps = connector.extendedCapabilities;
      expect(caps.text, isTrue);
      expect(caps.richMessages, isTrue);
      expect(caps.supportsFiles, isFalse);
      expect(caps.threads, isFalse);
      expect(caps.reactions, isFalse);
    });

    test('starts immediately as connected', () async {
      await connector.start();
      expect(connector.isRunning, isTrue);
    });

    group('request handling', () {
      test('handles JSON payload with no auth', () async {
        await connector.start();

        final payload = {
          'type': 'message',
          'text': 'Hello from webhook',
          'userId': 'user-1',
          'channelId': 'chan-1',
        };

        final response = await connector.handleRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: jsonEncode(payload),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['status'], 'received');
      });

      test('rejects request with invalid auth', () async {
        final authConnector = WebhookConnector(
          config: const WebhookConfig(
            auth: ApiKeyAuth(apiKey: 'secret123'),
          ),
        );
        await authConnector.start();

        final response = await authConnector.handleRequest(
          method: 'POST',
          headers: {'X-API-Key': 'wrong-key'},
          body: '{"text": "hello"}',
        );

        expect(response.statusCode, 403);
        await authConnector.dispose();
      });

      test('rejects request with invalid HMAC', () async {
        final hmacConnector = WebhookConnector(
          config: const WebhookConfig(
            auth: HmacAuth(
              secret: 'secret123',
              headerName: 'X-Signature',
            ),
          ),
        );
        await hmacConnector.start();

        final response = await hmacConnector.handleRequest(
          method: 'POST',
          headers: {'X-Signature': 'invalid_signature'},
          body: '{"text": "hello"}',
        );

        expect(response.statusCode, 403);
        await hmacConnector.dispose();
      });

      test('returns 400 for invalid JSON body', () async {
        await connector.start();

        final response = await connector.handleRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: 'not-valid-json{',
        );

        expect(response.statusCode, 400);
      });
    });

    group('CORS handling', () {
      test('handles OPTIONS preflight request', () async {
        final corsConnector = WebhookConnector(
          config: const WebhookConfig(
            enableCors: true,
          ),
        );
        await corsConnector.start();

        final response = await corsConnector.handleRequest(
          method: 'OPTIONS',
          headers: {},
          body: '',
        );

        expect(response.statusCode, 200);
        expect(
          response.headers['Access-Control-Allow-Origin'],
          '*',
        );
        expect(
          response.headers['Access-Control-Allow-Methods'],
          'POST, OPTIONS',
        );

        await corsConnector.dispose();
      });

      test('uses configured CORS origins', () async {
        final corsConnector = WebhookConnector(
          config: const WebhookConfig(
            enableCors: true,
            corsOrigins: ['https://example.com', 'https://other.com'],
          ),
        );
        await corsConnector.start();

        final response = await corsConnector.handleRequest(
          method: 'OPTIONS',
          headers: {},
          body: '',
        );

        expect(
          response.headers['Access-Control-Allow-Origin'],
          'https://example.com,https://other.com',
        );

        await corsConnector.dispose();
      });

      test('includes CORS headers in normal response when enabled', () async {
        final corsConnector = WebhookConnector(
          config: const WebhookConfig(
            enableCors: true,
          ),
        );
        await corsConnector.start();

        final response = await corsConnector.handleRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'type': 'message', 'text': 'hi'}),
        );

        expect(response.statusCode, 200);
        expect(
          response.headers['Access-Control-Allow-Origin'],
          '*',
        );

        await corsConnector.dispose();
      });

      test('does not include CORS headers when disabled', () async {
        await connector.start();

        final response = await connector.handleRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'type': 'message', 'text': 'hi'}),
        );

        expect(response.headers['Access-Control-Allow-Origin'], isNull);
      });
    });

    group('synchronous response mode', () {
      test('waits for and returns synchronous response', () async {
        final syncConnector = WebhookConnector(
          config: const WebhookConfig(
            responseMode: WebhookResponseMode.synchronous,
            timeout: Duration(seconds: 5),
          ),
        );
        await syncConnector.start();

        // Listen for events and provide a response
        syncConnector.events.listen((event) {
          syncConnector.completeResponse(
            event.id,
            ChannelResponse.text(
              conversation: event.conversation,
              text: 'Echo: ${event.text}',
            ),
          );
        });

        final response = await syncConnector.handleRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'type': 'message',
            'text': 'Hello',
            'userId': 'user-1',
          }),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['text'], 'Echo: Hello');

        await syncConnector.dispose();
      });

      test('times out when no response is provided', () async {
        final syncConnector = WebhookConnector(
          config: const WebhookConfig(
            responseMode: WebhookResponseMode.synchronous,
            timeout: Duration(milliseconds: 100),
          ),
        );
        await syncConnector.start();

        // Do not complete the response, so it times out
        expect(
          () => syncConnector.handleRequest(
            method: 'POST',
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'type': 'message', 'text': 'Hello'}),
          ),
          throwsA(isA<ConnectorException>()),
        );

        await syncConnector.dispose();
      });
    });

    group('auth verification convenience method', () {
      test('verifies valid API key via verifySignature', () {
        final apiKeyConnector = WebhookConnector(
          config: const WebhookConfig(
            auth: ApiKeyAuth(
              headerName: 'X-API-Key',
              apiKey: 'my-api-key',
            ),
          ),
        );

        final valid = apiKeyConnector.verifySignature(
          headers: {'X-API-Key': 'my-api-key'},
          body: '{}',
        );

        expect(valid, isTrue);
      });

      test('rejects invalid API key via verifySignature', () {
        final apiKeyConnector = WebhookConnector(
          config: const WebhookConfig(
            auth: ApiKeyAuth(
              headerName: 'X-API-Key',
              apiKey: 'my-api-key',
            ),
          ),
        );

        final valid = apiKeyConnector.verifySignature(
          headers: {'X-API-Key': 'wrong-key'},
          body: '{}',
        );

        expect(valid, isFalse);
      });

      test('returns true when no auth is configured', () {
        final valid = connector.verifySignature(
          headers: {},
          body: '{}',
        );

        expect(valid, isTrue);
      });
    });

    test('send throws without outbound URL', () {
      expect(
        () => connector.send(ChannelResponse.text(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'webhook',
              channelId: 'test',
            ),
            conversationId: 'conv-1',
          ),
          text: 'Hello',
        )),
        throwsA(isA<ConnectorException>()),
      );
    });

    group('custom headers', () {
      test('includes custom headers in response', () async {
        final customConnector = WebhookConnector(
          config: const WebhookConfig(
            customHeaders: {'X-Request-Id': 'abc-123'},
          ),
        );
        await customConnector.start();

        final response = await customConnector.handleRequest(
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'type': 'message', 'text': 'hi'}),
        );

        expect(response.headers['X-Request-Id'], 'abc-123');

        await customConnector.dispose();
      });
    });

    tearDown(() async {
      await connector.dispose();
    });
  });

  // ===========================================================================
  // Additional WebhookConfig coverage
  // ===========================================================================

  group('WebhookConfig additional coverage', () {
    test('default format is json', () {
      const config = WebhookConfig();
      expect(config.format.contentType, 'application/json');
    });

    test('default autoReconnect is false', () {
      const config = WebhookConfig();
      expect(config.autoReconnect, isFalse);
    });

    test('default reconnectDelay is 5 seconds', () {
      const config = WebhookConfig();
      expect(config.reconnectDelay, const Duration(seconds: 5));
    });

    test('default maxReconnectAttempts is 3', () {
      const config = WebhookConfig();
      expect(config.maxReconnectAttempts, 3);
    });

    test('default capabilityConfig has expected values', () {
      const config = WebhookConfig();
      expect(config.capabilityConfig.threads, isFalse);
      expect(config.capabilityConfig.buttons, isTrue);
      expect(config.capabilityConfig.commands, isTrue);
    });

    test('channelType is webhook', () {
      const config = WebhookConfig();
      expect(config.channelType, 'webhook');
    });

    test('copyWith preserves all fields when no args given', () {
      final original = WebhookConfig(
        inboundPath: '/api/hook',
        outboundUrl: 'https://example.com/callback',
        auth: const ApiKeyAuth(apiKey: 'key'),
        format: const WebhookFormat.form(),
        responseMode: WebhookResponseMode.synchronous,
        enableCors: true,
        corsOrigins: ['https://example.com'],
        customHeaders: {'X-Custom': 'val'},
        timeout: const Duration(seconds: 60),
        capabilityConfig: const WebhookCapabilityConfig.full(),
        autoReconnect: true,
        reconnectDelay: const Duration(seconds: 10),
        maxReconnectAttempts: 5,
      );

      final copied = original.copyWith();

      expect(copied.inboundPath, original.inboundPath);
      expect(copied.outboundUrl, original.outboundUrl);
      expect(copied.auth, isA<ApiKeyAuth>());
      expect(copied.format.contentType, original.format.contentType);
      expect(copied.responseMode, original.responseMode);
      expect(copied.enableCors, original.enableCors);
      expect(copied.corsOrigins, original.corsOrigins);
      expect(copied.customHeaders, original.customHeaders);
      expect(copied.timeout, original.timeout);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith can update inboundPath', () {
      const original = WebhookConfig();
      final copied = original.copyWith(inboundPath: '/new/path');
      expect(copied.inboundPath, '/new/path');
    });

    test('copyWith can update format', () {
      const original = WebhookConfig();
      final copied = original.copyWith(format: const WebhookFormat.form());
      expect(copied.format.contentType, 'application/x-www-form-urlencoded');
    });

    test('copyWith can update timeout', () {
      const original = WebhookConfig();
      final copied = original.copyWith(
        timeout: const Duration(seconds: 120),
      );
      expect(copied.timeout, const Duration(seconds: 120));
    });

    test('copyWith can update corsOrigins', () {
      const original = WebhookConfig();
      final copied = original.copyWith(
        corsOrigins: ['https://a.com', 'https://b.com'],
      );
      expect(copied.corsOrigins, hasLength(2));
    });

    test('copyWith can update customHeaders', () {
      const original = WebhookConfig();
      final copied = original.copyWith(
        customHeaders: {'X-Version': '2'},
      );
      expect(copied.customHeaders?['X-Version'], '2');
    });

    test('copyWith can update capabilityConfig', () {
      const original = WebhookConfig();
      final copied = original.copyWith(
        capabilityConfig: const WebhookCapabilityConfig.full(),
      );
      expect(copied.capabilityConfig.threads, isTrue);
      expect(copied.capabilityConfig.modals, isTrue);
    });

    test('copyWith can update autoReconnect', () {
      const original = WebhookConfig();
      final copied = original.copyWith(autoReconnect: true);
      expect(copied.autoReconnect, isTrue);
    });

    test('copyWith can update reconnectDelay', () {
      const original = WebhookConfig();
      final copied = original.copyWith(
        reconnectDelay: const Duration(seconds: 15),
      );
      expect(copied.reconnectDelay, const Duration(seconds: 15));
    });

    test('copyWith can update maxReconnectAttempts', () {
      const original = WebhookConfig();
      final copied = original.copyWith(maxReconnectAttempts: 10);
      expect(copied.maxReconnectAttempts, 10);
    });
  });

  group('WebhookFormat additional coverage', () {
    test('form format parser creates valid event', () {
      const format = WebhookFormat.form();
      final event = format.parser(
        {
          'type': 'message',
          'text': 'Form data',
          'userId': 'user-1',
          'channelId': 'chan-1',
          'conversationId': 'conv-1',
        },
        {'content-type': 'application/x-www-form-urlencoded'},
      );

      expect(event.type, 'message');
      expect(event.text, 'Form data');
      expect(event.userId, 'user-1');
    });

    test('form format builder creates JSON output', () {
      const format = WebhookFormat.form();
      final output = format.builder(
        ChannelResponse.text(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'webhook',
              channelId: 'test',
            ),
            conversationId: 'conv-1',
          ),
          text: 'Hello form',
        ),
      );

      expect(output, contains('Hello form'));
    });

    test('custom format uses provided parser and builder', () {
      final format = WebhookFormat.custom(
        contentType: 'application/xml',
        parser: (data, headers) => ChannelEvent(
          id: 'custom-1',
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'webhook',
              channelId: 'custom',
            ),
            conversationId: 'custom-conv',
          ),
          type: 'custom_type',
          text: data['raw'] as String?,
          timestamp: DateTime.now(),
        ),
        builder: (response) => '<msg>${response.text}</msg>',
      );

      expect(format.contentType, 'application/xml');

      final event = format.parser(
        {'raw': 'xml content'},
        {'content-type': 'application/xml'},
      );
      expect(event.type, 'custom_type');
      expect(event.text, 'xml content');

      final output = format.builder(
        ChannelResponse.text(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'webhook',
              channelId: 'test',
            ),
            conversationId: 'conv-1',
          ),
          text: 'hello',
        ),
      );
      expect(output, '<msg>hello</msg>');
    });

    test('json parser handles alternative field names', () {
      const format = WebhookFormat.json();

      // eventId instead of id
      final event1 = format.parser(
        {
          'eventId': 'alt-id-1',
          'user_id': 'u1',
          'tenantId': 'tenant-1',
          'roomId': 'room-1',
          'message': 'alt text',
        },
        {},
      );
      expect(event1.id, 'alt-id-1');
      expect(event1.userId, 'u1');
      expect(event1.conversation.channel.channelId, 'tenant-1');
      expect(event1.conversation.conversationId, 'room-1');
      expect(event1.text, 'alt text');

      // event_id alternative
      final event2 = format.parser(
        {'event_id': 'alt-id-2', 'user': 'u2'},
        {},
      );
      expect(event2.id, 'alt-id-2');
      expect(event2.userId, 'u2');

      // conversation_id alternative
      final event3 = format.parser(
        {'conversation_id': 'conv-alt'},
        {},
      );
      expect(event3.conversation.conversationId, 'conv-alt');

      // user_name alternative
      final event4 = format.parser(
        {'user_name': 'Test User'},
        {},
      );
      expect(event4.userName, 'Test User');
    });

    test('json parser uses defaults for missing fields', () {
      const format = WebhookFormat.json();
      final event = format.parser({}, {});

      // id defaults to timestamp-based
      expect(event.id, isNotEmpty);
      // type defaults to message
      expect(event.type, 'message');
      // channelId defaults to 'default'
      expect(event.conversation.channel.channelId, 'default');
      // conversationId defaults to 'default'
      expect(event.conversation.conversationId, 'default');
      expect(event.userId, isNull);
      expect(event.userName, isNull);
    });

    test('json parser handles timestamp field', () {
      const format = WebhookFormat.json();
      final event = format.parser(
        {'timestamp': '2024-06-01T12:00:00Z'},
        {},
      );
      expect(event.timestamp, DateTime.utc(2024, 6, 1, 12));
    });

    test('json parser handles invalid timestamp gracefully', () {
      const format = WebhookFormat.json();
      final event = format.parser(
        {'timestamp': 'not-a-date'},
        {},
      );
      // Falls back to DateTime.now()
      expect(event.timestamp, isA<DateTime>());
    });

    test('json builder includes conversation and text', () {
      const format = WebhookFormat.json();
      final output = format.builder(
        ChannelResponse.text(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'webhook',
              channelId: 'test',
            ),
            conversationId: 'conv-1',
          ),
          text: 'response text',
          replyTo: 'msg-123',
        ),
      );
      expect(output, contains('response text'));
      expect(output, contains('conv-1'));
      expect(output, contains('msg-123'));
    });
  });

  group('WebhookCapabilityConfig additional coverage', () {
    test('default config has expected false values', () {
      const config = WebhookCapabilityConfig();
      expect(config.reactions, isFalse);
      expect(config.files, isFalse);
      expect(config.maxFileSize, isNull);
      expect(config.menus, isFalse);
      expect(config.modals, isFalse);
      expect(config.ephemeral, isFalse);
      expect(config.edit, isFalse);
      expect(config.delete, isFalse);
      expect(config.typing, isFalse);
      expect(config.maxMessageLength, isNull);
    });

    test('full config maxFileSize is 100MB', () {
      const config = WebhookCapabilityConfig.full();
      expect(config.maxFileSize, 100 * 1024 * 1024);
    });

    test('full config maxMessageLength is null', () {
      const config = WebhookCapabilityConfig.full();
      expect(config.maxMessageLength, isNull);
    });

    test('buildCapabilities maps all fields correctly', () {
      const config = WebhookCapabilityConfig(
        threads: true,
        reactions: true,
        files: true,
        maxFileSize: 5000,
        blocks: true,
        buttons: true,
        menus: true,
        modals: true,
        ephemeral: true,
        edit: true,
        delete: true,
        typing: true,
        commands: true,
        maxMessageLength: 10000,
      );

      final caps = config.buildCapabilities();

      expect(caps.text, isTrue);
      expect(caps.richMessages, isTrue);
      expect(caps.attachments, isTrue);
      expect(caps.reactions, isTrue);
      expect(caps.threads, isTrue);
      expect(caps.editing, isTrue);
      expect(caps.deleting, isTrue);
      expect(caps.typingIndicator, isTrue);
      expect(caps.maxMessageLength, 10000);
      expect(caps.supportsFiles, isTrue);
      expect(caps.maxFileSize, 5000);
      expect(caps.supportsButtons, isTrue);
      expect(caps.supportsMenus, isTrue);
      expect(caps.supportsModals, isTrue);
      expect(caps.supportsEphemeral, isTrue);
      expect(caps.supportsCommands, isTrue);
    });

    test('buildCapabilities with minimal config', () {
      const config = WebhookCapabilityConfig();
      final caps = config.buildCapabilities();

      expect(caps.text, isTrue);
      expect(caps.richMessages, isTrue); // blocks default is true
      expect(caps.attachments, isFalse);
      expect(caps.reactions, isFalse);
      expect(caps.threads, isFalse);
      expect(caps.editing, isFalse);
      expect(caps.deleting, isFalse);
      expect(caps.typingIndicator, isFalse);
      expect(caps.maxMessageLength, isNull);
      expect(caps.supportsFiles, isFalse);
      expect(caps.maxFileSize, isNull);
      expect(caps.supportsButtons, isTrue);
      expect(caps.supportsMenus, isFalse);
      expect(caps.supportsModals, isFalse);
      expect(caps.supportsEphemeral, isFalse);
      expect(caps.supportsCommands, isTrue);
    });
  });

  group('WebhookAuth additional coverage', () {
    group('BearerAuth additional', () {
      test('rejects missing authorization header', () {
        const auth = BearerAuth(token: 'my-token');
        final valid = auth.validate({}, '{}');
        expect(valid, isFalse);
      });

      test('rejects non-Bearer authorization header', () {
        const auth = BearerAuth(token: 'my-token');
        final valid = auth.validate(
          {'authorization': 'Basic dXNlcjpwYXNz'},
          '{}',
        );
        expect(valid, isFalse);
      });
    });

    group('ApiKeyAuth additional', () {
      test('rejects missing header entirely', () {
        const auth = ApiKeyAuth(apiKey: 'key123');
        final valid = auth.validate({}, '{}');
        expect(valid, isFalse);
      });

      test('applyHeaders with custom header name', () {
        const auth = ApiKeyAuth(
          headerName: 'X-Custom-Key',
          apiKey: 'custom-key',
        );
        final headers = auth.applyHeaders({});
        expect(headers['X-Custom-Key'], 'custom-key');
      });
    });

    group('HmacAuth additional', () {
      test('applyHeaders returns headers unchanged', () {
        const auth = HmacAuth(secret: 'test');
        final headers = auth.applyHeaders({'Content-Type': 'application/json'});
        expect(headers['Content-Type'], 'application/json');
        expect(headers.length, 1);
      });

      test('computeSignature produces consistent output', () {
        const auth = HmacAuth(secret: 'test-secret');
        final sig1 = auth.computeSignature('hello');
        final sig2 = auth.computeSignature('hello');
        expect(sig1, sig2);
      });

      test('computeSignature with sha1 algorithm', () {
        const auth = HmacAuth(secret: 'test', algorithm: 'sha1');
        final sig = auth.computeSignature('body');
        expect(sig, isNotEmpty);
      });

      test('validates with lowercase header name', () {
        const auth = HmacAuth(
          secret: 'test',
          headerName: 'X-Sig',
        );
        const body = 'test-body';
        final sig = auth.computeSignature(body);

        final valid = auth.validate(
          {'x-sig': sig},
          body,
        );
        expect(valid, isTrue);
      });

      test('rejects mismatched signature length', () {
        const auth = HmacAuth(secret: 'secret');
        final valid = auth.validate(
          {'X-Signature': 'short'},
          'body',
        );
        expect(valid, isFalse);
      });
    });

    group('BasicAuth additional', () {
      test('rejects malformed base64 credentials', () {
        const auth = BasicAuth(username: 'admin', password: 'secret');
        final valid = auth.validate(
          {'authorization': 'Basic not-valid-base64!!!'},
          '{}',
        );
        expect(valid, isFalse);
      });

      test('validates case-insensitive Authorization header', () {
        const auth = BasicAuth(username: 'admin', password: 'secret');
        final encoded = base64.encode(utf8.encode('admin:secret'));
        final valid = auth.validate(
          {'Authorization': 'Basic $encoded'},
          '{}',
        );
        expect(valid, isTrue);
      });
    });
  });
}
