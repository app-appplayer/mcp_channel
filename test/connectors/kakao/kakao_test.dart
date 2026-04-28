import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

// Import connector-specific types
import 'package:mcp_channel/src/connectors/kakao/kakao.dart';

void main() {
  group('KakaoConfig', () {
    test('creates config with required fields', () {
      final config = KakaoConfig(botId: 'test-bot');

      expect(config.botId, 'test-bot');
      expect(config.channelType, 'kakao');
      expect(config.webhookPath, '/kakao/skill');
      expect(config.validationToken, isNull);
      expect(config.responseTimeout, const Duration(seconds: 5));
      expect(config.debug, isFalse);
      expect(config.autoReconnect, isFalse);
      expect(config.maxReconnectAttempts, 0);
    });

    test('creates config with all fields', () {
      final config = KakaoConfig(
        botId: 'my-bot',
        webhookPath: '/custom/webhook',
        validationToken: 'my-secret-token',
        responseTimeout: const Duration(seconds: 3),
        debug: true,
        autoReconnect: true,
        reconnectDelay: const Duration(seconds: 10),
        maxReconnectAttempts: 5,
      );

      expect(config.botId, 'my-bot');
      expect(config.webhookPath, '/custom/webhook');
      expect(config.validationToken, 'my-secret-token');
      expect(config.responseTimeout, const Duration(seconds: 3));
      expect(config.debug, isTrue);
      expect(config.autoReconnect, isTrue);
      expect(config.reconnectDelay, const Duration(seconds: 10));
      expect(config.maxReconnectAttempts, 5);
    });

    test('copyWith creates new config with updated fields', () {
      final original = KakaoConfig(botId: 'original-bot');
      final copied = original.copyWith(
        botId: 'updated-bot',
        webhookPath: '/new/path',
        validationToken: 'new-token',
        debug: true,
      );

      expect(copied.botId, 'updated-bot');
      expect(copied.webhookPath, '/new/path');
      expect(copied.validationToken, 'new-token');
      expect(copied.debug, isTrue);
      // Unchanged fields should retain original values
      expect(copied.responseTimeout, original.responseTimeout);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith with no arguments returns identical config', () {
      final original = KakaoConfig(
        botId: 'test-bot',
        validationToken: 'token',
        debug: true,
      );
      final copied = original.copyWith();

      expect(copied.botId, original.botId);
      expect(copied.webhookPath, original.webhookPath);
      expect(copied.validationToken, original.validationToken);
      expect(copied.responseTimeout, original.responseTimeout);
      expect(copied.debug, original.debug);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('default reconnectDelay is 5 seconds', () {
      final config = KakaoConfig(botId: 'test-bot');
      expect(config.reconnectDelay, const Duration(seconds: 5));
    });

    test('validationToken defaults to null', () {
      final config = KakaoConfig(botId: 'test-bot');
      expect(config.validationToken, isNull);
    });

    test('debug defaults to false', () {
      final config = KakaoConfig(botId: 'test-bot');
      expect(config.debug, isFalse);
    });
  });

  group('KakaoConnector', () {
    late KakaoConnector connector;

    setUp(() {
      connector = KakaoConnector(
        config: KakaoConfig(botId: 'test-bot-id'),
      );
    });

    test('has correct channel type', () {
      expect(connector.channelType, 'kakao');
    });

    test('has correct identity', () {
      expect(connector.identity.platform, 'kakao');
      expect(connector.identity.channelId, 'test-bot-id');
    });

    test('has kakao capabilities', () {
      final caps = connector.extendedCapabilities;
      expect(caps.text, isTrue);
      expect(caps.richMessages, isFalse);
      expect(caps.attachments, isFalse);
      expect(caps.reactions, isFalse);
      expect(caps.threads, isFalse);
      expect(caps.editing, isFalse);
      expect(caps.deleting, isFalse);
      expect(caps.typingIndicator, isFalse);
      expect(caps.maxMessageLength, 1000);
      expect(caps.supportsFiles, isFalse);
      expect(caps.supportsButtons, isTrue);
      expect(caps.supportsMenus, isFalse);
      expect(caps.supportsModals, isFalse);
      expect(caps.supportsEphemeral, isFalse);
      expect(caps.supportsCommands, isFalse);
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

    test('start transitions to connected', () async {
      await connector.start();
      expect(connector.isRunning, isTrue);
      expect(
        connector.currentConnectionState,
        ConnectionState.connected,
      );
    });

    test('sendTyping throws UnsupportedError', () async {
      await connector.start();

      final conversation = ConversationKey(
        channel: const ChannelIdentity(
          platform: 'kakao',
          channelId: 'test-bot-id',
        ),
        conversationId: 'user-123',
      );

      expect(
        () => connector.sendTyping(conversation),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('edit throws UnsupportedError', () async {
      await connector.start();

      final response = ChannelResponse.text(
        conversation: ConversationKey(
          channel: const ChannelIdentity(
            platform: 'kakao',
            channelId: 'test-bot-id',
          ),
          conversationId: 'user-123',
        ),
        text: 'edited text',
      );

      expect(
        () => connector.edit('msg-1', response),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('delete throws UnsupportedError', () async {
      await connector.start();

      expect(
        () => connector.delete('msg-1'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('react throws UnsupportedError', () async {
      await connector.start();

      expect(
        () => connector.react('msg-1', 'thumbsup'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    group('request validation', () {
      test('rejects request with invalid validation token', () async {
        final validatedConnector = KakaoConnector(
          config: KakaoConfig(
            botId: 'test-bot-id',
            validationToken: 'secret-token',
          ),
        );
        await validatedConnector.start();

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        expect(
          () => validatedConnector.handleSkillRequest(
            payload,
            headers: {'x-kakao-validation': 'wrong-token'},
          ),
          throwsA(isA<ChannelError>().having(
            (e) => e.code,
            'code',
            ChannelErrorCode.permissionDenied,
          )),
        );

        await validatedConnector.dispose();
      });

      test('rejects request with missing validation token header', () async {
        final validatedConnector = KakaoConnector(
          config: KakaoConfig(
            botId: 'test-bot-id',
            validationToken: 'secret-token',
          ),
        );
        await validatedConnector.start();

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        // No headers at all
        expect(
          () => validatedConnector.handleSkillRequest(payload),
          throwsA(isA<ChannelError>()),
        );

        await validatedConnector.dispose();
      });

      test('accepts request with correct validation token', () async {
        final validatedConnector = KakaoConnector(
          config: KakaoConfig(
            botId: 'test-bot-id',
            validationToken: 'secret-token',
          ),
        );
        await validatedConnector.start();

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        validatedConnector.events.listen((event) {
          validatedConnector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'OK',
          ));
        });

        final result = await validatedConnector.handleSkillRequest(
          payload,
          headers: {'x-kakao-validation': 'secret-token'},
        );

        expect(result['version'], '2.0');
        await validatedConnector.dispose();
      });

      test('skips validation when validationToken is null', () async {
        // Default connector has no validation token
        await connector.start();

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        connector.events.listen((event) {
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'OK',
          ));
        });

        // Should succeed without any headers
        final result = await connector.handleSkillRequest(payload);
        expect(result['version'], '2.0');
      });
    });

    group('skill request handling', () {
      final samplePayload = <String, dynamic>{
        'intent': <String, dynamic>{'id': 'intent-1', 'name': 'greeting'},
        'userRequest': <String, dynamic>{
          'timezone': 'Asia/Seoul',
          'utterance': 'Hello',
          'lang': 'ko',
          'user': <String, dynamic>{
            'id': 'user-123',
            'type': 'botUserKey',
            'properties': <String, dynamic>{},
          },
          'block': <String, dynamic>{'id': 'block-1', 'name': 'default'},
        },
        'bot': <String, dynamic>{'id': 'bot-1', 'name': 'Test Bot'},
        'action': <String, dynamic>{
          'name': 'action1',
          'params': <String, dynamic>{'key1': 'val1'},
          'clientExtra': <String, dynamic>{},
        },
        'contexts': <dynamic>[
          <String, dynamic>{
            'name': 'order_flow',
            'lifeSpan': 5,
            'params': <String, dynamic>{'step': 'menu'},
          },
        ],
      };

      test('handleSkillRequest emits event and returns response', () async {
        await connector.start();

        // Listen for events and respond
        connector.events.listen((event) {
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'Response text',
          ));
        });

        final result = await connector.handleSkillRequest(samplePayload);

        expect(result['version'], '2.0');
        expect(result['template'], isNotNull);

        final template = result['template'] as Map<String, dynamic>;
        final outputs = template['outputs'] as List<Map<String, dynamic>>;
        expect(outputs, isNotEmpty);
        expect(outputs.first['simpleText'], isNotNull);

        final simpleText =
            outputs.first['simpleText'] as Map<String, dynamic>;
        expect(simpleText['text'], 'Response text');
      });

      test('handleSkillRequest parses user and utterance correctly',
          () async {
        await connector.start();

        ChannelEvent? capturedEvent;
        connector.events.listen((event) {
          capturedEvent = event;
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'OK',
          ));
        });

        await connector.handleSkillRequest(samplePayload);

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.type, 'message');
        expect(capturedEvent!.text, 'Hello');
        expect(capturedEvent!.userId, 'user-123');
        expect(capturedEvent!.conversation.conversationId, 'user-123');
        expect(capturedEvent!.conversation.channel.platform, 'kakao');
      });

      test('event ID matches design doc format: userId_timestamp', () async {
        await connector.start();

        ChannelEvent? capturedEvent;
        connector.events.listen((event) {
          capturedEvent = event;
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'OK',
          ));
        });

        await connector.handleSkillRequest(samplePayload);

        expect(capturedEvent, isNotNull);
        // Event ID should start with the user ID followed by underscore
        expect(capturedEvent!.id, startsWith('user-123_'));
        // Verify the format is userId_timestamp (no prefix like "kakao_")
        final parts = capturedEvent!.id.split('_');
        // user-123 contains a hyphen, so split by '_' gives
        // ['user-123', '<timestamp>']
        expect(parts.length, 2);
        expect(parts[0], 'user-123');
        // The second part should be a valid millisecondsSinceEpoch
        expect(int.tryParse(parts[1]), isNotNull);
      });

      test('handleSkillRequest includes metadata with contexts', () async {
        await connector.start();

        ChannelEvent? capturedEvent;
        connector.events.listen((event) {
          capturedEvent = event;
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'OK',
          ));
        });

        await connector.handleSkillRequest(samplePayload);

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.metadata?['intent'], 'greeting');
        expect(capturedEvent!.metadata?['params'], isA<Map<String, dynamic>>());
        expect(
          (capturedEvent!.metadata?['params'] as Map)['key1'],
          'val1',
        );
        // Contexts from the request should be in metadata
        final contexts = capturedEvent!.metadata?['contexts'] as List?;
        expect(contexts, isNotNull);
        expect(contexts, isNotEmpty);
        final firstContext = contexts!.first as Map<String, dynamic>;
        expect(firstContext['name'], 'order_flow');
        expect(firstContext['lifeSpan'], 5);
        // Block information should be in metadata
        expect(capturedEvent!.metadata?['block'], isA<Map<String, dynamic>>());
        expect(
          (capturedEvent!.metadata?['block'] as Map)['id'],
          'block-1',
        );
      });

      test('handleSkillRequest returns timeout response when no reply',
          () async {
        // Use a very short timeout for the test
        final timeoutConnector = KakaoConnector(
          config: KakaoConfig(
            botId: 'test-bot-id',
            responseTimeout: const Duration(milliseconds: 100),
          ),
        );
        await timeoutConnector.start();

        // Do not listen or respond, so the request times out
        final result =
            await timeoutConnector.handleSkillRequest(samplePayload);

        expect(result['version'], '2.0');
        final template = result['template'] as Map<String, dynamic>;
        final outputs = template['outputs'] as List<Map<String, dynamic>>;
        expect(outputs, isNotEmpty);

        final simpleText =
            outputs.first['simpleText'] as Map<String, dynamic>;
        expect(simpleText['text'],
            'The request could not be processed in time.');

        await timeoutConnector.dispose();
      });

      test('handleSkillRequest handles payload with missing optional fields',
          () async {
        await connector.start();

        final minimalPayload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-456'},
          },
        };

        connector.events.listen((event) {
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'Minimal response',
          ));
        });

        final result =
            await connector.handleSkillRequest(minimalPayload);

        expect(result['version'], '2.0');
        expect(result['template'], isNotNull);
      });

      test('handleSkillRequest uses config.botId for channelId', () async {
        await connector.start();

        final payloadWithoutBot = <String, dynamic>{
          'userRequest': {
            'utterance': 'Test',
            'user': {'id': 'user-789'},
          },
        };

        ChannelEvent? capturedEvent;
        connector.events.listen((event) {
          capturedEvent = event;
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'OK',
          ));
        });

        await connector.handleSkillRequest(payloadWithoutBot);

        // Config botId is always used for channel identity
        expect(capturedEvent, isNotNull);
        expect(
          capturedEvent!.conversation.channel.channelId,
          'test-bot-id',
        );
      });

      test('sendWithResult returns success for valid response', () async {
        await connector.start();

        connector.events.listen((event) async {
          final response = ChannelResponse.text(
            conversation: event.conversation,
            text: 'Test response',
          );
          final result = await connector.sendWithResult(response);
          expect(result.success, isTrue);
        });

        await connector.handleSkillRequest(samplePayload);
      });
    });

    group('response building', () {
      test('builds simpleText response from text', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'Simple text reply',
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);
        final template = result['template'] as Map<String, dynamic>;
        final outputs = template['outputs'] as List<Map<String, dynamic>>;

        expect(outputs.length, 1);
        expect(outputs.first['simpleText'], {'text': 'Simple text reply'});
      });

      test('builds empty simpleText when no text or blocks', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse(
            conversation: event.conversation,
            type: 'text',
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);
        final template = result['template'] as Map<String, dynamic>;
        final outputs = template['outputs'] as List<Map<String, dynamic>>;

        // Ensures at least one output exists even with empty response
        expect(outputs, isNotEmpty);
        expect(outputs.first['simpleText'], {'text': ''});
      });

      test('builds basicCard response from blocks', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse(
            conversation: event.conversation,
            type: 'card',
            blocks: [
              {
                'type': 'basicCard',
                'title': 'Card Title',
                'description': 'Card description',
                'thumbnail': 'https://example.com/image.jpg',
                'buttons': [
                  {
                    'label': 'Visit',
                    'action': 'webLink',
                    'webLinkUrl': 'https://example.com',
                  },
                ],
              },
            ],
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Show card',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);
        final template = result['template'] as Map<String, dynamic>;
        final outputs = template['outputs'] as List<Map<String, dynamic>>;

        expect(outputs.length, 1);
        final card = outputs.first['basicCard'] as Map<String, dynamic>;
        expect(card['title'], 'Card Title');
        expect(card['description'], 'Card description');
        expect(
            card['thumbnail'], {'imageUrl': 'https://example.com/image.jpg'});
        expect(card['buttons'], isNotNull);
        expect((card['buttons'] as List).first['label'], 'Visit');
      });

      test('builds listCard response from blocks', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse(
            conversation: event.conversation,
            type: 'card',
            blocks: [
              {
                'type': 'listCard',
                'header': 'My List',
                'items': [
                  {'title': 'Item 1', 'description': 'First item'},
                  {'title': 'Item 2', 'description': 'Second item'},
                ],
              },
            ],
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Show list',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);
        final template = result['template'] as Map<String, dynamic>;
        final outputs = template['outputs'] as List<Map<String, dynamic>>;

        expect(outputs.length, 1);
        final listCard = outputs.first['listCard'] as Map<String, dynamic>;
        expect(listCard['header'], {'title': 'My List'});
        final items = listCard['items'] as List;
        expect(items.length, 2);
        expect((items.first as Map)['title'], 'Item 1');
      });

      test('falls back to simpleText for unknown block type', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse(
            conversation: event.conversation,
            type: 'custom',
            blocks: [
              {'type': 'unknownType', 'text': 'Fallback text'},
            ],
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);
        final template = result['template'] as Map<String, dynamic>;
        final outputs = template['outputs'] as List<Map<String, dynamic>>;

        expect(outputs.length, 1);
        expect(outputs.first['simpleText'], {'text': 'Fallback text'});
      });

      test('includes quick replies in response when provided', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'Choose an option:',
            options: {
              'quickReplies': [
                {
                  'label': 'Option A',
                  'action': 'message',
                  'messageText': 'Selected A',
                },
                {
                  'label': 'Option B',
                  'action': 'block',
                  'blockId': 'block-123',
                },
              ],
            },
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);
        final template = result['template'] as Map<String, dynamic>;

        expect(template['quickReplies'], isNotNull);
        final quickReplies = template['quickReplies'] as List;
        expect(quickReplies.length, 2);

        final first = quickReplies[0] as Map<String, dynamic>;
        expect(first['label'], 'Option A');
        expect(first['action'], 'message');
        expect(first['messageText'], 'Selected A');

        final second = quickReplies[1] as Map<String, dynamic>;
        expect(second['label'], 'Option B');
        expect(second['action'], 'block');
        expect(second['blockId'], 'block-123');
      });

      test('includes context values in response when provided', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'What would you like to order?',
            options: {
              'contexts': [
                {
                  'name': 'order_flow',
                  'lifeSpan': 5,
                  'params': {'step': 'menu'},
                },
              ],
            },
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Order',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);

        expect(result['context'], isNotNull);
        final context = result['context'] as Map<String, dynamic>;
        final values = context['values'] as List;
        expect(values.length, 1);

        final firstCtx = values.first as Map<String, dynamic>;
        expect(firstCtx['name'], 'order_flow');
        expect(firstCtx['lifeSpan'], 5);
        expect(firstCtx['params'], {'step': 'menu'});
      });

      test('includes data in response when provided', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'Data response',
            options: {
              'data': {'extraField': 'extraValue'},
            },
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);

        expect(result['data'], isNotNull);
        expect(result['data'], {'extraField': 'extraValue'});
      });

      test('omits context and quickReplies when not provided', () async {
        await connector.start();

        connector.events.listen((event) {
          connector.send(ChannelResponse.text(
            conversation: event.conversation,
            text: 'Plain response',
          ));
        });

        final payload = <String, dynamic>{
          'userRequest': {
            'utterance': 'Hi',
            'user': {'id': 'user-1'},
          },
        };

        final result = await connector.handleSkillRequest(payload);
        final template = result['template'] as Map<String, dynamic>;

        expect(result.containsKey('context'), isFalse);
        expect(result.containsKey('data'), isFalse);
        expect(template.containsKey('quickReplies'), isFalse);
      });
    });

    tearDown(() async {
      await connector.dispose();
    });
  });
}
