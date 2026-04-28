import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

import 'package:mcp_channel/src/connectors/teams/teams.dart';

void main() {
  group('TeamsConfig', () {
    test('creates config with required fields', () {
      final config = TeamsConfig(
        appId: 'test-app-id',
        appPassword: 'test-app-password',
      );

      expect(config.appId, 'test-app-id');
      expect(config.appPassword, 'test-app-password');
      expect(config.channelType, 'teams');
      expect(config.tenantId, isNull);
      expect(config.serviceUrl, 'https://smba.trafficmanager.net/teams');
      expect(config.graphScopes, isEmpty);
      expect(config.enableProactive, isFalse);
      expect(config.autoReconnect, isTrue);
      expect(config.reconnectDelay, const Duration(seconds: 5));
      expect(config.maxReconnectAttempts, 10);
    });

    test('creates config with all fields', () {
      final config = TeamsConfig(
        appId: 'app-123',
        appPassword: 'secret-456',
        tenantId: 'tenant-789',
        serviceUrl: 'https://custom.service.url/teams',
        graphScopes: ['User.Read', 'Files.ReadWrite'],
        enableProactive: true,
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 15),
        maxReconnectAttempts: 3,
      );

      expect(config.appId, 'app-123');
      expect(config.appPassword, 'secret-456');
      expect(config.tenantId, 'tenant-789');
      expect(config.serviceUrl, 'https://custom.service.url/teams');
      expect(config.graphScopes, ['User.Read', 'Files.ReadWrite']);
      expect(config.enableProactive, isTrue);
      expect(config.autoReconnect, isFalse);
      expect(config.reconnectDelay, const Duration(seconds: 15));
      expect(config.maxReconnectAttempts, 3);
    });

    test('copyWith creates updated config preserving unchanged fields', () {
      final original = TeamsConfig(
        appId: 'original-app',
        appPassword: 'original-pass',
        tenantId: 'original-tenant',
      );

      final copied = original.copyWith(
        tenantId: 'new-tenant',
        autoReconnect: false,
      );

      expect(copied.appId, 'original-app');
      expect(copied.appPassword, 'original-pass');
      expect(copied.tenantId, 'new-tenant');
      expect(copied.autoReconnect, isFalse);
      expect(copied.serviceUrl, original.serviceUrl);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith can update all fields', () {
      final original = TeamsConfig(
        appId: 'old-app',
        appPassword: 'old-pass',
      );

      final copied = original.copyWith(
        appId: 'new-app',
        appPassword: 'new-pass',
        tenantId: 'new-tenant',
        serviceUrl: 'https://new.service.url',
        graphScopes: ['Mail.Read'],
        enableProactive: true,
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 30),
        maxReconnectAttempts: 5,
      );

      expect(copied.appId, 'new-app');
      expect(copied.appPassword, 'new-pass');
      expect(copied.tenantId, 'new-tenant');
      expect(copied.serviceUrl, 'https://new.service.url');
      expect(copied.graphScopes, ['Mail.Read']);
      expect(copied.enableProactive, isTrue);
      expect(copied.autoReconnect, isFalse);
      expect(copied.reconnectDelay, const Duration(seconds: 30));
      expect(copied.maxReconnectAttempts, 5);
    });

    test('isSingleTenant returns true when tenantId is set', () {
      final singleTenant = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
        tenantId: 'my-tenant',
      );

      expect(singleTenant.isSingleTenant, isTrue);
    });

    test('isSingleTenant returns false when tenantId is null', () {
      final multiTenant = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );

      expect(multiTenant.isSingleTenant, isFalse);
    });

    test('tokenEndpoint uses tenant-specific URL for single-tenant', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
        tenantId: 'my-tenant-id',
      );

      expect(
        config.tokenEndpoint,
        'https://login.microsoftonline.com/my-tenant-id/oauth2/v2.0/token',
      );
    });

    test('tokenEndpoint uses botframework.com URL for multi-tenant', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );

      expect(
        config.tokenEndpoint,
        'https://login.microsoftonline.com/botframework.com/oauth2/v2.0/token',
      );
    });
  });

  group('TeamsConnector', () {
    late TeamsConnector connector;

    setUp(() {
      connector = TeamsConnector(
        config: TeamsConfig(
          appId: 'test-app-id',
          appPassword: 'test-app-password',
        ),
      );
    });

    test('has correct channel type', () {
      expect(connector.channelType, 'teams');
    });

    test('has correct identity', () {
      expect(connector.identity.platform, 'teams');
      expect(connector.identity.channelId, 'test-app-id');
      expect(connector.identity.displayName, 'Teams Bot');
    });

    test('has teams capabilities', () {
      final caps = connector.extendedCapabilities;
      expect(caps.text, isTrue);
      expect(caps.richMessages, isTrue);
      expect(caps.attachments, isTrue);
      expect(caps.reactions, isTrue);
      expect(caps.threads, isTrue);
      expect(caps.editing, isTrue);
      expect(caps.deleting, isTrue);
      expect(caps.typingIndicator, isTrue);
      expect(caps.maxMessageLength, 28000);
      expect(caps.supportsFiles, isTrue);
      expect(caps.maxFileSize, 25 * 1024 * 1024);
      expect(caps.supportsButtons, isTrue);
      expect(caps.supportsMenus, isTrue);
      expect(caps.supportsModals, isTrue);
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

    group('activity parsing', () {
      test('parses message activity', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-123',
          'from': {'id': 'user-1', 'name': 'Test User'},
          'conversation': {'id': 'conv-1'},
          'timestamp': '2024-01-01T00:00:00Z',
          'text': 'Hello Teams',
          'channelData': {
            'tenant': {'id': 'tenant-1'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'message');
        expect(event.id, 'msg-123');
        expect(event.text, 'Hello Teams');
        expect(event.userId, 'user-1');
        expect(event.userName, 'Test User');
        expect(event.conversation.conversationId, 'conv-1');
        expect(event.conversation.channel.platform, 'teams');
        expect(event.conversation.channel.channelId, 'tenant-1');
        expect(
          event.timestamp,
          DateTime.utc(2024, 1, 1),
        );
      });

      test('parses message activity without optional fields', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'conversation': {'id': 'conv-2'},
          'text': 'Minimal message',
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'message');
        expect(event.text, 'Minimal message');
        expect(event.conversation.conversationId, 'conv-2');
        // Without channelData tenant, falls back to config tenantId (null)
        // then to 'unknown'
        expect(event.conversation.channel.channelId, 'unknown');
      });

      test('parses invoke activity', () {
        final activity = <String, dynamic>{
          'type': 'invoke',
          'id': 'invoke-1',
          'name': 'composeExtension/query',
          'value': {'commandId': 'searchCmd', 'queryText': 'test'},
          'from': {'id': 'user-2', 'name': 'Invoker'},
          'conversation': {'id': 'conv-3'},
          'timestamp': '2024-06-15T12:30:00Z',
          'channelData': {
            'tenant': {'id': 'tenant-2'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'command');
        expect(event.id, 'invoke-1');
        expect(event.text, '/composeExtension/query');
        expect(event.userId, 'user-2');
        expect(event.userName, 'Invoker');
        expect(event.conversation.conversationId, 'conv-3');
        expect(event.conversation.channel.channelId, 'tenant-2');
        expect(event.metadata?['command'], 'composeExtension/query');
        expect(event.metadata?['invoke_value'], isA<Map<String, dynamic>>());
        expect(
          (event.metadata?['invoke_value'] as Map)['commandId'],
          'searchCmd',
        );
      });

      test('parses invoke activity without name or value', () {
        final activity = <String, dynamic>{
          'type': 'invoke',
          'id': 'invoke-2',
          'from': {'id': 'user-3'},
          'conversation': {'id': 'conv-4'},
          'channelData': {
            'tenant': {'id': 'tenant-3'},
          },
        };

        final event = connector.handleActivity(activity);

        // Empty invoke name does not start with 'composeExtension',
        // so it maps to 'button' per design doc
        expect(event.type, 'button');
        expect(event.text, '/');
        expect(event.metadata?['command'], '');
        expect(event.metadata?['invoke_value'], isEmpty);
      });

      test('parses task/fetch invoke as button event', () {
        final activity = <String, dynamic>{
          'type': 'invoke',
          'id': 'invoke-tf-1',
          'name': 'task/fetch',
          'value': {'data': 'open-dialog'},
          'from': {'id': 'user-20', 'name': 'TaskUser'},
          'conversation': {'id': 'conv-20'},
          'timestamp': '2024-08-01T10:00:00Z',
          'channelData': {
            'tenant': {'id': 'tenant-20'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'button');
        expect(event.text, '/task/fetch');
        expect(event.userId, 'user-20');
        expect(event.metadata?['command'], 'task/fetch');
      });

      test('parses task/submit invoke as button event', () {
        final activity = <String, dynamic>{
          'type': 'invoke',
          'id': 'invoke-ts-1',
          'name': 'task/submit',
          'value': {
            'data': {'field1': 'value1'},
          },
          'from': {'id': 'user-21', 'name': 'SubmitUser'},
          'conversation': {'id': 'conv-21'},
          'timestamp': '2024-08-01T10:05:00Z',
          'channelData': {
            'tenant': {'id': 'tenant-21'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'button');
        expect(event.text, '/task/submit');
        expect(event.userId, 'user-21');
        expect(event.metadata?['command'], 'task/submit');
      });

      test('parses actionableMessage invoke as button event', () {
        final activity = <String, dynamic>{
          'type': 'invoke',
          'id': 'invoke-am-1',
          'name': 'actionableMessage/executeAction',
          'value': {'actionId': 'approve'},
          'from': {'id': 'user-22', 'name': 'ActionUser'},
          'conversation': {'id': 'conv-22'},
          'channelData': {
            'tenant': {'id': 'tenant-22'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'button');
        expect(event.text, '/actionableMessage/executeAction');
      });

      test('parses reaction activity with reactionsAdded', () {
        final activity = <String, dynamic>{
          'type': 'messageReaction',
          'id': 'react-1',
          'from': {'id': 'user-4', 'name': 'Reactor'},
          'conversation': {'id': 'conv-5'},
          'timestamp': '2024-03-10T08:00:00Z',
          'replyToId': 'target-msg-1',
          'reactionsAdded': [
            {'type': 'like'},
          ],
          'channelData': {
            'tenant': {'id': 'tenant-4'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'reaction');
        expect(event.text, 'like');
        expect(event.userId, 'user-4');
        expect(event.userName, 'Reactor');
        expect(event.conversation.conversationId, 'conv-5');
        expect(event.metadata?['target_message_id'], 'target-msg-1');
        expect(event.metadata?['reactions_added'], isNotEmpty);
      });

      test('parses reaction activity without reactionsAdded', () {
        final activity = <String, dynamic>{
          'type': 'messageReaction',
          'id': 'react-2',
          'from': {'id': 'user-5'},
          'conversation': {'id': 'conv-6'},
          'channelData': {
            'tenant': {'id': 'tenant-5'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'reaction');
        expect(event.text, isNull);
      });

      test('parses conversationUpdate activity with membersAdded (join)', () {
        final activity = <String, dynamic>{
          'type': 'conversationUpdate',
          'id': 'update-1',
          'from': {'id': 'user-6', 'name': 'Joiner'},
          'conversation': {'id': 'conv-7'},
          'timestamp': '2024-05-20T14:00:00Z',
          'membersAdded': [
            {'id': 'user-6', 'name': 'Joiner'},
            {'id': 'user-7', 'name': 'Another Joiner'},
          ],
          'channelData': {
            'tenant': {'id': 'tenant-6'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'join');
        expect(event.userId, 'user-6');
        expect(event.userName, 'Joiner');
        expect(event.conversation.conversationId, 'conv-7');
        expect(event.metadata?['members_added'], hasLength(2));
        expect(event.metadata?['members_removed'], isEmpty);
      });

      test('parses conversationUpdate activity with membersRemoved (leave)',
          () {
        final activity = <String, dynamic>{
          'type': 'conversationUpdate',
          'id': 'update-2',
          'from': {'id': 'user-8', 'name': 'Leaver'},
          'conversation': {'id': 'conv-8'},
          'timestamp': '2024-07-01T09:30:00Z',
          'membersRemoved': [
            {'id': 'user-8', 'name': 'Leaver'},
          ],
          'channelData': {
            'tenant': {'id': 'tenant-7'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'leave');
        expect(event.userId, 'user-8');
        expect(event.metadata?['members_removed'], hasLength(1));
        expect(event.metadata?['members_added'], isEmpty);
      });

      test(
          'parses conversationUpdate activity without members '
          '(conversation_update)', () {
        final activity = <String, dynamic>{
          'type': 'conversationUpdate',
          'id': 'update-3',
          'from': {'id': 'user-9'},
          'conversation': {'id': 'conv-9'},
          'channelData': {
            'tenant': {'id': 'tenant-8'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'conversation_update');
        expect(event.metadata?['members_added'], isEmpty);
        expect(event.metadata?['members_removed'], isEmpty);
      });

      test('parses unknown activity type', () {
        final activity = <String, dynamic>{
          'type': 'installationUpdate',
          'id': 'unknown-1',
          'from': {'id': 'user-10', 'name': 'System'},
          'conversation': {'id': 'conv-10'},
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'unknown');
        expect(event.id, 'unknown-1');
        expect(event.userId, 'user-10');
        expect(event.userName, 'System');
        expect(event.conversation.conversationId, 'conv-10');
        // Unknown activity uses config.appId as channelId
        expect(event.conversation.channel.channelId, 'test-app-id');
      });

      test('parses activity with null type', () {
        final activity = <String, dynamic>{
          'id': 'null-type-1',
          'from': {'id': 'user-11'},
          'conversation': {'id': 'conv-11'},
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'unknown');
      });

      test('parses message activity with attachments', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-attach-1',
          'from': {'id': 'user-12', 'name': 'Uploader'},
          'conversation': {'id': 'conv-12'},
          'timestamp': '2024-02-14T10:00:00Z',
          'text': 'Here is a file',
          'attachments': [
            {
              'contentType': 'image/png',
              'contentUrl': 'https://files.teams.com/image.png',
              'name': 'screenshot.png',
            },
            {
              'contentType': 'application/pdf',
              'contentUrl': 'https://files.teams.com/doc.pdf',
              'name': 'report.pdf',
            },
          ],
          'channelData': {
            'tenant': {'id': 'tenant-9'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.type, 'message');
        expect(event.text, 'Here is a file');
        expect(event.attachments, isNotNull);
        expect(event.attachments, hasLength(2));

        // First attachment: image
        final imageAttachment = event.attachments![0];
        expect(imageAttachment.type, 'image');
        expect(imageAttachment.url, 'https://files.teams.com/image.png');
        expect(imageAttachment.filename, 'screenshot.png');
        expect(imageAttachment.mimeType, 'image/png');

        // Second attachment: file (PDF)
        final fileAttachment = event.attachments![1];
        expect(fileAttachment.type, 'file');
        expect(fileAttachment.url, 'https://files.teams.com/doc.pdf');
        expect(fileAttachment.filename, 'report.pdf');
        expect(fileAttachment.mimeType, 'application/pdf');
      });

      test('parses message activity with video attachment', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-video-1',
          'from': {'id': 'user-13'},
          'conversation': {'id': 'conv-13'},
          'text': 'Check this video',
          'attachments': [
            {
              'contentType': 'video/mp4',
              'contentUrl': 'https://files.teams.com/video.mp4',
              'name': 'clip.mp4',
            },
          ],
          'channelData': {
            'tenant': {'id': 'tenant-10'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.attachments, isNotNull);
        expect(event.attachments, hasLength(1));
        expect(event.attachments![0].type, 'video');
        expect(event.attachments![0].mimeType, 'video/mp4');
      });

      test('parses message activity with audio attachment', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-audio-1',
          'from': {'id': 'user-14'},
          'conversation': {'id': 'conv-14'},
          'text': 'Voice memo',
          'attachments': [
            {
              'contentType': 'audio/ogg',
              'contentUrl': 'https://files.teams.com/voice.ogg',
              'name': 'memo.ogg',
            },
          ],
          'channelData': {
            'tenant': {'id': 'tenant-11'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.attachments, isNotNull);
        expect(event.attachments, hasLength(1));
        expect(event.attachments![0].type, 'audio');
        expect(event.attachments![0].mimeType, 'audio/ogg');
      });

      test('parses message activity without attachments', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-no-attach',
          'from': {'id': 'user-15'},
          'conversation': {'id': 'conv-15'},
          'text': 'Plain text only',
          'channelData': {
            'tenant': {'id': 'tenant-12'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.attachments, isNull);
      });

      test('parses message with empty attachment list', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-empty-attach',
          'from': {'id': 'user-16'},
          'conversation': {'id': 'conv-16'},
          'text': 'No files here',
          'attachments': <dynamic>[],
          'channelData': {
            'tenant': {'id': 'tenant-13'},
          },
        };

        final event = connector.handleActivity(activity);

        expect(event.attachments, isNull);
      });

      test('caches serviceUrl when provided', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-svc-1',
          'from': {'id': 'user-17'},
          'conversation': {'id': 'conv-17'},
          'text': 'With service URL',
          'channelData': {
            'tenant': {'id': 'tenant-14'},
          },
        };

        // Should not throw even with a custom service URL
        final event = connector.handleActivity(
          activity,
          serviceUrl: 'https://custom.botframework.com',
        );

        expect(event.type, 'message');
        expect(event.text, 'With service URL');
      });

      test('tenant falls back to config tenantId', () {
        final connectorWithTenant = TeamsConnector(
          config: TeamsConfig(
            appId: 'tenant-app',
            appPassword: 'tenant-pass',
            tenantId: 'config-tenant',
          ),
        );

        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-fallback',
          'from': {'id': 'user-18'},
          'conversation': {'id': 'conv-18'},
          'text': 'Tenant fallback test',
          // No channelData.tenant
        };

        final event = connectorWithTenant.handleActivity(activity);

        expect(event.conversation.channel.channelId, 'config-tenant');

        connectorWithTenant.dispose();
      });

      test('metadata contains original activity', () {
        final activity = <String, dynamic>{
          'type': 'message',
          'id': 'msg-meta-1',
          'from': {'id': 'user-19', 'name': 'MetaUser'},
          'conversation': {'id': 'conv-19'},
          'timestamp': '2024-04-01T00:00:00Z',
          'text': 'Check metadata',
          'channelData': {
            'tenant': {'id': 'tenant-15'},
          },
          'customField': 'customValue',
        };

        final event = connector.handleActivity(activity);

        expect(event.metadata, isNotNull);
        expect(event.metadata?['type'], 'message');
        expect(event.metadata?['customField'], 'customValue');
        expect(event.metadata?['id'], 'msg-meta-1');
      });
    });

    group('task module handling', () {
      test('handleTaskSubmit emits button event with submitted data', () async {
        final activity = <String, dynamic>{
          'type': 'invoke',
          'id': 'task-submit-1',
          'name': 'task/submit',
          'from': {'id': 'user-30', 'name': 'Submitter'},
          'conversation': {'id': 'conv-30'},
          'timestamp': '2024-09-01T12:00:00Z',
          'value': {
            'data': {
              'field1': 'answer1',
              'field2': 'answer2',
            },
          },
          'channelData': {
            'tenant': {'id': 'tenant-30'},
          },
        };

        // Listen for events before calling handleTaskSubmit
        final eventFuture = connector.events.first;
        connector.handleTaskSubmit(activity);
        final event = await eventFuture;

        expect(event.type, 'button');
        expect(event.id, 'task-submit-1');
        expect(event.userId, 'user-30');
        expect(event.userName, 'Submitter');
        expect(event.conversation.conversationId, 'conv-30');
        expect(event.conversation.channel.channelId, 'tenant-30');
        expect(event.metadata?['action_id'], 'task_submit');
        expect(event.metadata?['values'], isA<Map<String, dynamic>>());
        expect(
          (event.metadata?['values'] as Map)['field1'],
          'answer1',
        );
      });
    });

    group('proactive messaging', () {
      test('sendProactiveMessage throws when proactive is disabled', () async {
        // Default config has enableProactive = false
        final reference = <String, dynamic>{
          'serviceUrl': 'https://smba.trafficmanager.net/teams',
          'conversation': {'id': 'conv-p1'},
          'bot': {'id': 'bot-1'},
          'user': {'id': 'user-p1'},
        };

        final response = ChannelResponse.text(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'teams',
              channelId: 'test-app-id',
            ),
            conversationId: 'conv-p1',
          ),
          text: 'Proactive hello',
        );

        expect(
          () => connector.sendProactiveMessage(
            reference: reference,
            response: response,
          ),
          throwsA(isA<ConnectorException>()),
        );
      });
    });

    group('message payload building', () {
      test('send rejects response without text or blocks', () async {
        final response = ChannelResponse(
          conversation: ConversationKey(
            channel: const ChannelIdentity(
              platform: 'teams',
              channelId: 'test-app-id',
            ),
            conversationId: 'conv-1',
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
              platform: 'teams',
              channelId: 'test-app-id',
            ),
            conversationId: 'conv-1',
          ),
          type: 'text',
        );

        final result = await connector.sendWithResult(response);
        expect(result.success, isFalse);
        expect(result.error?.code, ChannelErrorCode.invalidRequest);
      });
    });

    tearDown(() async {
      await connector.dispose();
    });
  });

  // ===========================================================================
  // Additional TeamsConfig coverage
  // ===========================================================================

  group('TeamsConfig additional coverage', () {
    test('default graphScopes is empty', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      expect(config.graphScopes, isEmpty);
    });

    test('default enableProactive is false', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      expect(config.enableProactive, isFalse);
    });

    test('default serviceUrl is teams traffic manager', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      expect(
        config.serviceUrl,
        'https://smba.trafficmanager.net/teams',
      );
    });

    test('tokenEndpoint for single-tenant uses tenant-specific URL', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
        tenantId: 'specific-tenant',
      );
      expect(
        config.tokenEndpoint,
        'https://login.microsoftonline.com/specific-tenant/oauth2/v2.0/token',
      );
    });

    test('tokenEndpoint for multi-tenant uses botframework.com', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      expect(
        config.tokenEndpoint,
        'https://login.microsoftonline.com/botframework.com/oauth2/v2.0/token',
      );
    });

    test('isSingleTenant is true when tenantId is set', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
        tenantId: 'tenant-123',
      );
      expect(config.isSingleTenant, isTrue);
    });

    test('isSingleTenant is false when tenantId is null', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      expect(config.isSingleTenant, isFalse);
    });

    test('copyWith preserves all fields when no args given', () {
      final original = TeamsConfig(
        appId: 'orig-app',
        appPassword: 'orig-pass',
        tenantId: 'orig-tenant',
        serviceUrl: 'https://custom.service.url',
        graphScopes: ['User.Read'],
        enableProactive: true,
        autoReconnect: false,
        reconnectDelay: const Duration(seconds: 20),
        maxReconnectAttempts: 7,
      );

      final copied = original.copyWith();

      expect(copied.appId, original.appId);
      expect(copied.appPassword, original.appPassword);
      expect(copied.tenantId, original.tenantId);
      expect(copied.serviceUrl, original.serviceUrl);
      expect(copied.graphScopes, original.graphScopes);
      expect(copied.enableProactive, original.enableProactive);
      expect(copied.autoReconnect, original.autoReconnect);
      expect(copied.reconnectDelay, original.reconnectDelay);
      expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
    });

    test('copyWith can update graphScopes', () {
      final original = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      final copied = original.copyWith(
        graphScopes: ['User.Read', 'Files.ReadWrite', 'Mail.Send'],
      );
      expect(
        copied.graphScopes,
        ['User.Read', 'Files.ReadWrite', 'Mail.Send'],
      );
    });

    test('copyWith can update enableProactive', () {
      final original = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      final copied = original.copyWith(enableProactive: true);
      expect(copied.enableProactive, isTrue);
    });

    test('copyWith can update serviceUrl', () {
      final original = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      final copied = original.copyWith(
        serviceUrl: 'https://other.service.url/teams',
      );
      expect(copied.serviceUrl, 'https://other.service.url/teams');
    });

    test('channelType is always teams', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
      );
      expect(config.channelType, 'teams');
    });

    test('graphScopes preserves order', () {
      final config = TeamsConfig(
        appId: 'app-1',
        appPassword: 'pass-1',
        graphScopes: ['Mail.Read', 'User.Read', 'Files.ReadWrite'],
      );
      expect(
        config.graphScopes,
        orderedEquals(['Mail.Read', 'User.Read', 'Files.ReadWrite']),
      );
    });
  });
}
