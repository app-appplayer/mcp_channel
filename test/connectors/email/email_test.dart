import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

// Import connector-specific types
import 'package:mcp_channel/src/connectors/email/email.dart';

void main() {
  group('EmailProvider', () {
    test('has imap value', () {
      expect(EmailProvider.imap, isNotNull);
      expect(EmailProvider.imap.name, 'imap');
    });

    test('has gmail value', () {
      expect(EmailProvider.gmail, isNotNull);
      expect(EmailProvider.gmail.name, 'gmail');
    });

    test('has outlook value', () {
      expect(EmailProvider.outlook, isNotNull);
      expect(EmailProvider.outlook.name, 'outlook');
    });

    test('has webhook value', () {
      expect(EmailProvider.webhook, isNotNull);
      expect(EmailProvider.webhook.name, 'webhook');
    });

    test('has exactly four values', () {
      expect(EmailProvider.values, hasLength(4));
      expect(
        EmailProvider.values,
        containsAll([
          EmailProvider.imap,
          EmailProvider.gmail,
          EmailProvider.outlook,
          EmailProvider.webhook,
        ]),
      );
    });
  });

  group('ImapConfig', () {
    test('creates config with required fields', () {
      final config = ImapConfig(
        host: 'imap.example.com',
        username: 'user',
        password: 'pass',
      );

      expect(config.host, 'imap.example.com');
      expect(config.port, 993);
      expect(config.useSsl, isTrue);
      expect(config.username, 'user');
      expect(config.password, 'pass');
      expect(config.folder, 'INBOX');
    });

    test('creates config with all fields', () {
      final config = ImapConfig(
        host: 'imap.example.com',
        port: 143,
        useSsl: false,
        username: 'user',
        password: 'pass',
        folder: 'Archive',
      );

      expect(config.port, 143);
      expect(config.useSsl, isFalse);
      expect(config.folder, 'Archive');
    });

    test('copyWith updates fields', () {
      final original = ImapConfig(
        host: 'imap.example.com',
        username: 'user',
        password: 'pass',
      );
      final copied = original.copyWith(port: 143, useSsl: false);

      expect(copied.host, 'imap.example.com');
      expect(copied.port, 143);
      expect(copied.useSsl, isFalse);
      expect(copied.username, 'user');
    });

    test('toJson and fromJson round-trip', () {
      final original = ImapConfig(
        host: 'imap.example.com',
        port: 993,
        useSsl: true,
        username: 'user',
        password: 'pass',
        folder: 'INBOX',
      );
      final json = original.toJson();
      final restored = ImapConfig.fromJson(json);

      expect(restored.host, original.host);
      expect(restored.port, original.port);
      expect(restored.useSsl, original.useSsl);
      expect(restored.username, original.username);
      expect(restored.password, original.password);
      expect(restored.folder, original.folder);
    });
  });

  group('SmtpConfig', () {
    test('creates config with required fields', () {
      final config = SmtpConfig(
        host: 'smtp.example.com',
        username: 'user',
        password: 'pass',
      );

      expect(config.host, 'smtp.example.com');
      expect(config.port, 587);
      expect(config.useSsl, isTrue);
      expect(config.username, 'user');
      expect(config.password, 'pass');
    });

    test('creates config with all fields', () {
      final config = SmtpConfig(
        host: 'smtp.example.com',
        port: 465,
        useSsl: true,
        username: 'user',
        password: 'pass',
      );

      expect(config.port, 465);
    });

    test('copyWith updates fields', () {
      final original = SmtpConfig(
        host: 'smtp.example.com',
        username: 'user',
        password: 'pass',
      );
      final copied = original.copyWith(port: 25, useSsl: false);

      expect(copied.host, 'smtp.example.com');
      expect(copied.port, 25);
      expect(copied.useSsl, isFalse);
    });

    test('toJson and fromJson round-trip', () {
      final original = SmtpConfig(
        host: 'smtp.example.com',
        port: 587,
        useSsl: true,
        username: 'user',
        password: 'pass',
      );
      final json = original.toJson();
      final restored = SmtpConfig.fromJson(json);

      expect(restored.host, original.host);
      expect(restored.port, original.port);
      expect(restored.useSsl, original.useSsl);
      expect(restored.username, original.username);
      expect(restored.password, original.password);
    });
  });

  group('GmailConfig', () {
    test('creates config with required fields', () {
      final config = GmailConfig(
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
      );

      expect(config.clientId, 'client-id');
      expect(config.clientSecret, 'client-secret');
      expect(config.refreshToken, 'refresh-token');
      expect(config.labelFilter, ['INBOX']);
      expect(config.useWatch, isFalse);
    });

    test('creates config with all fields', () {
      final config = GmailConfig(
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
        labelFilter: ['INBOX', 'IMPORTANT'],
        useWatch: true,
      );

      expect(config.labelFilter, ['INBOX', 'IMPORTANT']);
      expect(config.useWatch, isTrue);
    });

    test('copyWith updates fields', () {
      final original = GmailConfig(
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
      );
      final copied = original.copyWith(useWatch: true);

      expect(copied.clientId, 'client-id');
      expect(copied.useWatch, isTrue);
    });

    test('toJson and fromJson round-trip', () {
      final original = GmailConfig(
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
        labelFilter: ['INBOX'],
        useWatch: false,
      );
      final json = original.toJson();
      final restored = GmailConfig.fromJson(json);

      expect(restored.clientId, original.clientId);
      expect(restored.clientSecret, original.clientSecret);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.labelFilter, original.labelFilter);
      expect(restored.useWatch, original.useWatch);
    });
  });

  group('OutlookConfig', () {
    test('creates config with required fields', () {
      final config = OutlookConfig(
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
      );

      expect(config.clientId, 'client-id');
      expect(config.clientSecret, 'client-secret');
      expect(config.refreshToken, 'refresh-token');
      expect(config.tenantId, isNull);
    });

    test('creates config with tenantId', () {
      final config = OutlookConfig(
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
        tenantId: 'my-tenant',
      );

      expect(config.tenantId, 'my-tenant');
    });

    test('copyWith updates fields', () {
      final original = OutlookConfig(
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
      );
      final copied = original.copyWith(tenantId: 'new-tenant');

      expect(copied.clientId, 'client-id');
      expect(copied.tenantId, 'new-tenant');
    });

    test('toJson and fromJson round-trip', () {
      final original = OutlookConfig(
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
        tenantId: 'my-tenant',
      );
      final json = original.toJson();
      final restored = OutlookConfig.fromJson(json);

      expect(restored.clientId, original.clientId);
      expect(restored.clientSecret, original.clientSecret);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.tenantId, original.tenantId);
    });
  });

  group('InboundWebhookConfig', () {
    test('creates config with required fields', () {
      final config = InboundWebhookConfig(path: '/webhooks/email');

      expect(config.path, '/webhooks/email');
      expect(config.secret, isNull);
    });

    test('creates config with secret', () {
      final config = InboundWebhookConfig(
        path: '/webhooks/email',
        secret: 'my-secret',
      );

      expect(config.path, '/webhooks/email');
      expect(config.secret, 'my-secret');
    });

    test('copyWith updates fields', () {
      final original = InboundWebhookConfig(path: '/webhooks/email');
      final copied = original.copyWith(secret: 'new-secret');

      expect(copied.path, '/webhooks/email');
      expect(copied.secret, 'new-secret');
    });

    test('toJson and fromJson round-trip', () {
      final original = InboundWebhookConfig(
        path: '/webhooks/email',
        secret: 'my-secret',
      );
      final json = original.toJson();
      final restored = InboundWebhookConfig.fromJson(json);

      expect(restored.path, original.path);
      expect(restored.secret, original.secret);
    });
  });

  group('EmailConfig', () {
    test('creates config with required fields (gmail)', () {
      final config = EmailConfig(
        provider: EmailProvider.gmail,
        botEmail: 'bot@example.com',
        credentials: {
          'clientId': 'test-client-id',
          'clientSecret': 'test-client-secret',
          'refreshToken': 'test-refresh-token',
        },
      );

      expect(config.provider, EmailProvider.gmail);
      expect(config.botEmail, 'bot@example.com');
      expect(config.credentials['clientId'], 'test-client-id');
      expect(config.credentials['clientSecret'], 'test-client-secret');
      expect(config.credentials['refreshToken'], 'test-refresh-token');
      expect(config.channelType, 'email');
    });

    test('creates config with required fields (outlook)', () {
      final config = EmailConfig(
        provider: EmailProvider.outlook,
        botEmail: 'bot@outlook.com',
        credentials: {
          'clientId': 'outlook-client-id',
          'clientSecret': 'outlook-client-secret',
          'refreshToken': 'outlook-refresh-token',
        },
      );

      expect(config.provider, EmailProvider.outlook);
      expect(config.botEmail, 'bot@outlook.com');
      expect(config.credentials['clientId'], 'outlook-client-id');
      expect(config.channelType, 'email');
    });

    test('creates config with IMAP provider', () {
      final config = EmailConfig(
        provider: EmailProvider.imap,
        botEmail: 'bot@example.com',
        imap: ImapConfig(
          host: 'imap.example.com',
          username: 'bot@example.com',
          password: 'pass',
        ),
        smtp: SmtpConfig(
          host: 'smtp.example.com',
          username: 'bot@example.com',
          password: 'pass',
        ),
      );

      expect(config.provider, EmailProvider.imap);
      expect(config.imap, isNotNull);
      expect(config.imap!.host, 'imap.example.com');
      expect(config.smtp, isNotNull);
      expect(config.smtp!.host, 'smtp.example.com');
    });

    test('creates config with webhook provider', () {
      final config = EmailConfig(
        provider: EmailProvider.webhook,
        botEmail: 'bot@example.com',
        inboundWebhook: InboundWebhookConfig(
          path: '/webhooks/email',
          secret: 'wh-secret',
        ),
      );

      expect(config.provider, EmailProvider.webhook);
      expect(config.inboundWebhook, isNotNull);
      expect(config.inboundWebhook!.path, '/webhooks/email');
      expect(config.inboundWebhook!.secret, 'wh-secret');
    });

    test('has correct defaults', () {
      final config = EmailConfig(
        provider: EmailProvider.gmail,
        botEmail: 'bot@example.com',
        credentials: {
          'clientId': 'id',
          'clientSecret': 'secret',
          'refreshToken': 'token',
        },
      );

      expect(config.pollingInterval, const Duration(seconds: 60));
      expect(config.subjectCommandPrefix, isNull);
      expect(config.fromName, isNull);
      expect(config.imap, isNull);
      expect(config.smtp, isNull);
      expect(config.gmailConfig, isNull);
      expect(config.outlookConfig, isNull);
      expect(config.inboundWebhook, isNull);
      expect(config.autoReconnect, isFalse);
      expect(config.reconnectDelay, const Duration(seconds: 30));
      expect(config.maxReconnectAttempts, 3);
    });

    test('creates config with all fields', () {
      final config = EmailConfig(
        provider: EmailProvider.gmail,
        botEmail: 'bot@example.com',
        credentials: {
          'clientId': 'full-client-id',
          'clientSecret': 'full-secret',
          'refreshToken': 'full-refresh',
          'accessToken': 'current-access-token',
          'tokenEndpoint': 'https://custom.endpoint/token',
        },
        imap: ImapConfig(
          host: 'imap.example.com',
          username: 'user',
          password: 'pass',
        ),
        smtp: SmtpConfig(
          host: 'smtp.example.com',
          username: 'user',
          password: 'pass',
        ),
        gmailConfig: GmailConfig(
          clientId: 'gmail-cid',
          clientSecret: 'gmail-cs',
          refreshToken: 'gmail-rt',
        ),
        outlookConfig: OutlookConfig(
          clientId: 'outlook-cid',
          clientSecret: 'outlook-cs',
          refreshToken: 'outlook-rt',
        ),
        inboundWebhook: InboundWebhookConfig(path: '/wh'),
        pollingInterval: const Duration(seconds: 120),
        subjectCommandPrefix: '/mcp',
        fromName: 'My Bot',
        autoReconnect: true,
        reconnectDelay: const Duration(seconds: 15),
        maxReconnectAttempts: 5,
      );

      expect(config.provider, EmailProvider.gmail);
      expect(config.botEmail, 'bot@example.com');
      expect(config.credentials['clientId'], 'full-client-id');
      expect(config.credentials['accessToken'], 'current-access-token');
      expect(config.credentials['tokenEndpoint'],
          'https://custom.endpoint/token');
      expect(config.imap, isNotNull);
      expect(config.smtp, isNotNull);
      expect(config.gmailConfig, isNotNull);
      expect(config.outlookConfig, isNotNull);
      expect(config.inboundWebhook, isNotNull);
      expect(config.pollingInterval, const Duration(seconds: 120));
      expect(config.subjectCommandPrefix, '/mcp');
      expect(config.fromName, 'My Bot');
      expect(config.autoReconnect, isTrue);
      expect(config.reconnectDelay, const Duration(seconds: 15));
      expect(config.maxReconnectAttempts, 5);
    });

    test('channelType is always email', () {
      final gmail = EmailConfig(
        provider: EmailProvider.gmail,
        botEmail: 'bot@gmail.com',
        credentials: {
          'clientId': 'id',
          'clientSecret': 's',
          'refreshToken': 't',
        },
      );
      final outlook = EmailConfig(
        provider: EmailProvider.outlook,
        botEmail: 'bot@outlook.com',
        credentials: {
          'clientId': 'id',
          'clientSecret': 's',
          'refreshToken': 't',
        },
      );
      final imap = EmailConfig(
        provider: EmailProvider.imap,
        botEmail: 'bot@example.com',
      );
      final webhook = EmailConfig(
        provider: EmailProvider.webhook,
        botEmail: 'bot@example.com',
      );

      expect(gmail.channelType, 'email');
      expect(outlook.channelType, 'email');
      expect(imap.channelType, 'email');
      expect(webhook.channelType, 'email');
    });

    group('copyWith', () {
      late EmailConfig original;

      setUp(() {
        original = EmailConfig(
          provider: EmailProvider.gmail,
          botEmail: 'original@example.com',
          credentials: {
            'clientId': 'orig-id',
            'clientSecret': 'orig-secret',
            'refreshToken': 'orig-token',
          },
          pollingInterval: const Duration(seconds: 60),
          fromName: 'Original Bot',
          autoReconnect: false,
          reconnectDelay: const Duration(seconds: 30),
          maxReconnectAttempts: 3,
        );
      });

      test('creates new config with updated provider', () {
        final copied = original.copyWith(provider: EmailProvider.outlook);

        expect(copied.provider, EmailProvider.outlook);
        expect(copied.credentials, original.credentials);
        expect(copied.botEmail, original.botEmail);
      });

      test('creates new config with updated credentials', () {
        final newCreds = {
          'clientId': 'new-id',
          'clientSecret': 'new-secret',
          'refreshToken': 'new-token',
        };
        final copied = original.copyWith(credentials: newCreds);

        expect(copied.credentials['clientId'], 'new-id');
        expect(copied.provider, original.provider);
      });

      test('creates new config with updated polling interval', () {
        final copied = original.copyWith(
          pollingInterval: const Duration(seconds: 180),
        );

        expect(copied.pollingInterval, const Duration(seconds: 180));
        expect(copied.botEmail, original.botEmail);
      });

      test('creates new config with updated botEmail and fromName', () {
        final copied = original.copyWith(
          botEmail: 'new@example.com',
          fromName: 'New Bot',
        );

        expect(copied.botEmail, 'new@example.com');
        expect(copied.fromName, 'New Bot');
        expect(copied.provider, original.provider);
      });

      test('creates new config with updated reconnect settings', () {
        final copied = original.copyWith(
          autoReconnect: true,
          reconnectDelay: const Duration(seconds: 10),
          maxReconnectAttempts: 7,
        );

        expect(copied.autoReconnect, isTrue);
        expect(copied.reconnectDelay, const Duration(seconds: 10));
        expect(copied.maxReconnectAttempts, 7);
      });

      test('creates new config with subjectCommandPrefix', () {
        final copied = original.copyWith(subjectCommandPrefix: '/mcp');

        expect(copied.subjectCommandPrefix, '/mcp');
        expect(copied.botEmail, original.botEmail);
      });

      test('creates new config with sub-configs', () {
        final copied = original.copyWith(
          imap: ImapConfig(
            host: 'imap.test.com',
            username: 'u',
            password: 'p',
          ),
          smtp: SmtpConfig(
            host: 'smtp.test.com',
            username: 'u',
            password: 'p',
          ),
          gmailConfig: GmailConfig(
            clientId: 'gc',
            clientSecret: 'gs',
            refreshToken: 'gr',
          ),
          outlookConfig: OutlookConfig(
            clientId: 'oc',
            clientSecret: 'os',
            refreshToken: 'or',
          ),
          inboundWebhook: InboundWebhookConfig(path: '/wh'),
        );

        expect(copied.imap!.host, 'imap.test.com');
        expect(copied.smtp!.host, 'smtp.test.com');
        expect(copied.gmailConfig!.clientId, 'gc');
        expect(copied.outlookConfig!.clientId, 'oc');
        expect(copied.inboundWebhook!.path, '/wh');
      });

      test('preserves all fields when no arguments provided', () {
        final copied = original.copyWith();

        expect(copied.provider, original.provider);
        expect(copied.botEmail, original.botEmail);
        expect(copied.credentials, original.credentials);
        expect(copied.pollingInterval, original.pollingInterval);
        expect(copied.fromName, original.fromName);
        expect(copied.autoReconnect, original.autoReconnect);
        expect(copied.reconnectDelay, original.reconnectDelay);
        expect(copied.maxReconnectAttempts, original.maxReconnectAttempts);
      });
    });
  });

  group('EmailConnector', () {
    test('has correct channel type', () {
      final connector = EmailConnector(
        config: EmailConfig(
          provider: EmailProvider.gmail,
          botEmail: 'bot@example.com',
          credentials: {
            'clientId': 'id',
            'clientSecret': 's',
            'refreshToken': 't',
          },
        ),
      );

      expect(connector.channelType, 'email');
    });

    group('identity', () {
      test('uses botEmail as channelId', () {
        final connector = EmailConnector(
          config: EmailConfig(
            provider: EmailProvider.gmail,
            botEmail: 'bot@example.com',
            credentials: {
              'clientId': 'id',
              'clientSecret': 's',
              'refreshToken': 't',
            },
            fromName: 'Test Bot',
          ),
        );

        expect(connector.identity.platform, 'email');
        expect(connector.identity.channelId, 'bot@example.com');
        expect(connector.identity.displayName, 'Test Bot');
      });

      test('uses default displayName when fromName is not provided', () {
        final connector = EmailConnector(
          config: EmailConfig(
            provider: EmailProvider.gmail,
            botEmail: 'bot@example.com',
            credentials: {
              'clientId': 'id',
              'clientSecret': 's',
              'refreshToken': 't',
            },
          ),
        );

        expect(connector.identity.platform, 'email');
        expect(connector.identity.channelId, 'bot@example.com');
        expect(connector.identity.displayName, 'Email Connector');
      });

      test('has correct identity for outlook provider', () {
        final connector = EmailConnector(
          config: EmailConfig(
            provider: EmailProvider.outlook,
            botEmail: 'outlook-bot@example.com',
            credentials: {
              'clientId': 'id',
              'clientSecret': 's',
              'refreshToken': 't',
            },
          ),
        );

        expect(connector.identity.platform, 'email');
        expect(connector.identity.channelId, 'outlook-bot@example.com');
      });

      test('has correct identity for imap provider', () {
        final connector = EmailConnector(
          config: EmailConfig(
            provider: EmailProvider.imap,
            botEmail: 'imap-bot@example.com',
          ),
        );

        expect(connector.identity.platform, 'email');
        expect(connector.identity.channelId, 'imap-bot@example.com');
      });
    });

    group('capabilities', () {
      late EmailConnector connector;

      setUp(() {
        connector = EmailConnector(
          config: EmailConfig(
            provider: EmailProvider.gmail,
            botEmail: 'bot@example.com',
            credentials: {
              'clientId': 'id',
              'clientSecret': 's',
              'refreshToken': 't',
            },
          ),
        );
      });

      test('capabilities is ExtendedChannelCapabilities', () {
        expect(connector.capabilities, isA<ExtendedChannelCapabilities>());
      });

      test('has correct text and messaging capabilities', () {
        final caps = connector.extendedCapabilities;

        expect(caps.text, isTrue);
        expect(caps.richMessages, isFalse);
        expect(caps.attachments, isTrue);
      });

      test('supports threads', () {
        final caps = connector.extendedCapabilities;

        expect(caps.threads, isTrue);
      });

      test('does not support reactions', () {
        final caps = connector.extendedCapabilities;

        expect(caps.reactions, isFalse);
      });

      test('does not support editing or deleting', () {
        final caps = connector.extendedCapabilities;

        expect(caps.editing, isFalse);
        expect(caps.deleting, isFalse);
      });

      test('does not support typing indicator', () {
        final caps = connector.extendedCapabilities;

        expect(caps.typingIndicator, isFalse);
      });

      test('supports files with 25MB limit', () {
        final caps = connector.extendedCapabilities;

        expect(caps.supportsFiles, isTrue);
        expect(caps.maxFileSize, 25 * 1024 * 1024);
      });

      test('does not support interactive UI elements', () {
        final caps = connector.extendedCapabilities;

        expect(caps.supportsButtons, isFalse);
        expect(caps.supportsMenus, isFalse);
        expect(caps.supportsModals, isFalse);
        expect(caps.supportsEphemeral, isFalse);
        expect(caps.supportsCommands, isTrue);
      });

      test('supports file, image, and document attachment types', () {
        final caps = connector.extendedCapabilities;

        expect(
          caps.supportedAttachments,
          containsAll([
            AttachmentType.file,
            AttachmentType.image,
            AttachmentType.document,
          ]),
        );
        expect(caps.supportedAttachments, hasLength(3));
      });

      tearDown(() async {
        await connector.dispose();
      });
    });

    test('starts disconnected', () {
      final connector = EmailConnector(
        config: EmailConfig(
          provider: EmailProvider.gmail,
          botEmail: 'bot@example.com',
          credentials: {
            'clientId': 'id',
            'clientSecret': 's',
            'refreshToken': 't',
          },
        ),
      );

      expect(connector.isRunning, isFalse);
      expect(
        connector.currentConnectionState,
        ConnectionState.disconnected,
      );
    });

    test('config is accessible on connector', () {
      final config = EmailConfig(
        provider: EmailProvider.outlook,
        botEmail: 'test@example.com',
        credentials: {
          'clientId': 'id',
          'clientSecret': 's',
          'refreshToken': 't',
        },
        pollingInterval: const Duration(seconds: 90),
      );
      final connector = EmailConnector(config: config);

      expect(connector.config.provider, EmailProvider.outlook);
      expect(connector.config.botEmail, 'test@example.com');
      expect(connector.config.pollingInterval, const Duration(seconds: 90));
    });

    group('command parsing', () {
      late EmailConnector connector;

      setUp(() {
        connector = EmailConnector(
          config: EmailConfig(
            provider: EmailProvider.imap,
            botEmail: 'bot@example.com',
            subjectCommandPrefix: '/mcp',
          ),
        );
      });

      test('parseSubjectCommand returns null when subject does not match', () {
        final result = connector.parseSubjectCommand(
          messageId: 'msg-1',
          from: 'user@example.com',
          subject: 'Hello world',
          textBody: 'Some body',
          prefix: '/mcp',
        );

        expect(result, isNull);
      });

      test('parseSubjectCommand parses command from subject', () {
        final result = connector.parseSubjectCommand(
          messageId: 'msg-1',
          from: 'User Name <user@corp.com>',
          subject: '/mcp analyze report',
          textBody: 'Please analyze the attached report.',
          prefix: '/mcp',
        );

        expect(result, isNotNull);
        expect(result!.eventType, ChannelEventType.command);
        expect(result.command, 'analyze');
        expect(result.commandArgs, ['report']);
        expect(result.userId, 'user@corp.com');
        expect(result.conversation.channel.channelId, 'corp.com');
      });

      test('parseSubjectCommand uses sender domain as channelId', () {
        final result = connector.parseSubjectCommand(
          messageId: 'msg-2',
          from: 'alice@acme.org',
          subject: '/mcp status',
          textBody: null,
          prefix: '/mcp',
        );

        expect(result, isNotNull);
        expect(result!.conversation.channel.channelId, 'acme.org');
      });

      test('parseBodyCommand returns null when no mcp block present', () {
        final result = connector.parseBodyCommand(
          messageId: 'msg-3',
          from: 'user@example.com',
          textBody: 'Just a regular email body.',
        );

        expect(result, isNull);
      });

      test('parseBodyCommand parses command from mcp code block', () {
        final result = connector.parseBodyCommand(
          messageId: 'msg-4',
          from: 'User <user@company.io>',
          textBody: 'Hello,\n\n```mcp\ncall toolName param1=value1\n```\n\nThanks!',
        );

        expect(result, isNotNull);
        expect(result!.eventType, ChannelEventType.command);
        expect(result.command, 'call');
        expect(result.commandArgs, ['toolName', 'param1=value1']);
        expect(result.userId, 'user@company.io');
        expect(result.conversation.channel.channelId, 'company.io');
      });

      tearDown(() async {
        await connector.dispose();
      });
    });
  });

  // ===========================================================================
  // Additional email sub-config coverage
  // ===========================================================================

  group('SmtpConfig additional coverage', () {
    test('copyWith preserves all fields when no args given', () {
      final original = SmtpConfig(
        host: 'smtp.example.com',
        port: 465,
        useSsl: false,
        username: 'user',
        password: 'pass',
      );
      final copied = original.copyWith();

      expect(copied.host, original.host);
      expect(copied.port, original.port);
      expect(copied.useSsl, original.useSsl);
      expect(copied.username, original.username);
      expect(copied.password, original.password);
    });

    test('copyWith can update host', () {
      final original = SmtpConfig(
        host: 'smtp.old.com',
        username: 'u',
        password: 'p',
      );
      final copied = original.copyWith(host: 'smtp.new.com');
      expect(copied.host, 'smtp.new.com');
    });

    test('copyWith can update username and password', () {
      final original = SmtpConfig(
        host: 'smtp.example.com',
        username: 'old-user',
        password: 'old-pass',
      );
      final copied = original.copyWith(username: 'new-user', password: 'new-pass');
      expect(copied.username, 'new-user');
      expect(copied.password, 'new-pass');
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {
        'host': 'smtp.test.com',
        'username': 'user',
        'password': 'pass',
      };
      final config = SmtpConfig.fromJson(json);
      expect(config.host, 'smtp.test.com');
      expect(config.port, 587);
      expect(config.useSsl, isTrue);
    });
  });

  group('ImapConfig additional coverage', () {
    test('copyWith preserves all fields when no args given', () {
      final original = ImapConfig(
        host: 'imap.example.com',
        port: 143,
        useSsl: false,
        username: 'user',
        password: 'pass',
        folder: 'Sent',
      );
      final copied = original.copyWith();

      expect(copied.host, original.host);
      expect(copied.port, original.port);
      expect(copied.useSsl, original.useSsl);
      expect(copied.username, original.username);
      expect(copied.password, original.password);
      expect(copied.folder, original.folder);
    });

    test('copyWith can update host', () {
      final original = ImapConfig(
        host: 'imap.old.com',
        username: 'u',
        password: 'p',
      );
      final copied = original.copyWith(host: 'imap.new.com');
      expect(copied.host, 'imap.new.com');
    });

    test('copyWith can update username and password', () {
      final original = ImapConfig(
        host: 'imap.example.com',
        username: 'old-user',
        password: 'old-pass',
      );
      final copied = original.copyWith(username: 'new-user', password: 'new-pass');
      expect(copied.username, 'new-user');
      expect(copied.password, 'new-pass');
    });

    test('copyWith can update folder', () {
      final original = ImapConfig(
        host: 'imap.example.com',
        username: 'u',
        password: 'p',
      );
      final copied = original.copyWith(folder: 'Archive');
      expect(copied.folder, 'Archive');
    });

    test('toJson includes folder when not null', () {
      final config = ImapConfig(
        host: 'imap.example.com',
        username: 'u',
        password: 'p',
        folder: 'INBOX',
      );
      final json = config.toJson();
      expect(json['folder'], 'INBOX');
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {
        'host': 'imap.test.com',
        'username': 'user',
        'password': 'pass',
      };
      final config = ImapConfig.fromJson(json);
      expect(config.host, 'imap.test.com');
      expect(config.port, 993);
      expect(config.useSsl, isTrue);
      expect(config.folder, 'INBOX');
    });
  });

  group('GmailConfig additional coverage', () {
    test('copyWith preserves all fields when no args given', () {
      final original = GmailConfig(
        clientId: 'cid',
        clientSecret: 'cs',
        refreshToken: 'rt',
        labelFilter: ['IMPORTANT'],
        useWatch: true,
      );
      final copied = original.copyWith();

      expect(copied.clientId, original.clientId);
      expect(copied.clientSecret, original.clientSecret);
      expect(copied.refreshToken, original.refreshToken);
      expect(copied.labelFilter, original.labelFilter);
      expect(copied.useWatch, original.useWatch);
    });

    test('copyWith can update clientId', () {
      final original = GmailConfig(
        clientId: 'old',
        clientSecret: 'cs',
        refreshToken: 'rt',
      );
      final copied = original.copyWith(clientId: 'new');
      expect(copied.clientId, 'new');
    });

    test('copyWith can update clientSecret', () {
      final original = GmailConfig(
        clientId: 'cid',
        clientSecret: 'old',
        refreshToken: 'rt',
      );
      final copied = original.copyWith(clientSecret: 'new');
      expect(copied.clientSecret, 'new');
    });

    test('copyWith can update refreshToken', () {
      final original = GmailConfig(
        clientId: 'cid',
        clientSecret: 'cs',
        refreshToken: 'old',
      );
      final copied = original.copyWith(refreshToken: 'new');
      expect(copied.refreshToken, 'new');
    });

    test('copyWith can update labelFilter', () {
      final original = GmailConfig(
        clientId: 'cid',
        clientSecret: 'cs',
        refreshToken: 'rt',
      );
      final copied = original.copyWith(labelFilter: ['SPAM', 'TRASH']);
      expect(copied.labelFilter, ['SPAM', 'TRASH']);
    });

    test('fromJson handles missing labelFilter', () {
      final json = {
        'clientId': 'cid',
        'clientSecret': 'cs',
        'refreshToken': 'rt',
      };
      final config = GmailConfig.fromJson(json);
      expect(config.labelFilter, ['INBOX']);
      expect(config.useWatch, isFalse);
    });

    test('fromJson with all fields', () {
      final json = {
        'clientId': 'cid',
        'clientSecret': 'cs',
        'refreshToken': 'rt',
        'labelFilter': ['INBOX', 'STARRED'],
        'useWatch': true,
      };
      final config = GmailConfig.fromJson(json);
      expect(config.labelFilter, ['INBOX', 'STARRED']);
      expect(config.useWatch, isTrue);
    });
  });

  group('OutlookConfig additional coverage', () {
    test('copyWith preserves all fields when no args given', () {
      final original = OutlookConfig(
        clientId: 'cid',
        clientSecret: 'cs',
        refreshToken: 'rt',
        tenantId: 'tid',
      );
      final copied = original.copyWith();

      expect(copied.clientId, original.clientId);
      expect(copied.clientSecret, original.clientSecret);
      expect(copied.refreshToken, original.refreshToken);
      expect(copied.tenantId, original.tenantId);
    });

    test('copyWith can update clientId', () {
      final original = OutlookConfig(
        clientId: 'old',
        clientSecret: 'cs',
        refreshToken: 'rt',
      );
      final copied = original.copyWith(clientId: 'new');
      expect(copied.clientId, 'new');
    });

    test('copyWith can update clientSecret', () {
      final original = OutlookConfig(
        clientId: 'cid',
        clientSecret: 'old',
        refreshToken: 'rt',
      );
      final copied = original.copyWith(clientSecret: 'new');
      expect(copied.clientSecret, 'new');
    });

    test('copyWith can update refreshToken', () {
      final original = OutlookConfig(
        clientId: 'cid',
        clientSecret: 'cs',
        refreshToken: 'old',
      );
      final copied = original.copyWith(refreshToken: 'new');
      expect(copied.refreshToken, 'new');
    });

    test('toJson excludes tenantId when null', () {
      final config = OutlookConfig(
        clientId: 'cid',
        clientSecret: 'cs',
        refreshToken: 'rt',
      );
      final json = config.toJson();
      expect(json.containsKey('tenantId'), isFalse);
    });

    test('toJson includes tenantId when present', () {
      final config = OutlookConfig(
        clientId: 'cid',
        clientSecret: 'cs',
        refreshToken: 'rt',
        tenantId: 'my-tenant',
      );
      final json = config.toJson();
      expect(json['tenantId'], 'my-tenant');
    });

    test('fromJson without tenantId', () {
      final json = {
        'clientId': 'cid',
        'clientSecret': 'cs',
        'refreshToken': 'rt',
      };
      final config = OutlookConfig.fromJson(json);
      expect(config.tenantId, isNull);
    });
  });

  group('InboundWebhookConfig additional coverage', () {
    test('copyWith preserves all fields when no args given', () {
      final original = InboundWebhookConfig(
        path: '/wh/email',
        secret: 'sec',
      );
      final copied = original.copyWith();

      expect(copied.path, original.path);
      expect(copied.secret, original.secret);
    });

    test('copyWith can update path', () {
      final original = InboundWebhookConfig(path: '/old');
      final copied = original.copyWith(path: '/new');
      expect(copied.path, '/new');
    });

    test('toJson excludes secret when null', () {
      final config = InboundWebhookConfig(path: '/wh');
      final json = config.toJson();
      expect(json.containsKey('secret'), isFalse);
    });

    test('toJson includes secret when present', () {
      final config = InboundWebhookConfig(path: '/wh', secret: 'my-secret');
      final json = config.toJson();
      expect(json['secret'], 'my-secret');
    });

    test('fromJson without secret', () {
      final json = {'path': '/webhooks/email'};
      final config = InboundWebhookConfig.fromJson(json);
      expect(config.path, '/webhooks/email');
      expect(config.secret, isNull);
    });

    test('fromJson with secret', () {
      final json = {'path': '/webhooks/email', 'secret': 'wh-secret'};
      final config = InboundWebhookConfig.fromJson(json);
      expect(config.secret, 'wh-secret');
    });
  });

  group('EmailConfig additional coverage', () {
    test('default credentials is empty map', () {
      final config = EmailConfig(
        provider: EmailProvider.imap,
        botEmail: 'bot@example.com',
      );
      expect(config.credentials, isEmpty);
    });

    test('channelType is email for all providers', () {
      for (final provider in EmailProvider.values) {
        final config = EmailConfig(
          provider: provider,
          botEmail: 'bot@example.com',
        );
        expect(config.channelType, 'email');
      }
    });
  });
}
