import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ExtendedChannelCapabilities', () {
    group('constructor', () {
      test('creates with defaults', () {
        const caps = ExtendedChannelCapabilities();

        // Base defaults
        expect(caps.text, isTrue);
        expect(caps.richMessages, isFalse);
        expect(caps.attachments, isFalse);
        expect(caps.reactions, isFalse);
        expect(caps.threads, isFalse);
        expect(caps.editing, isFalse);
        expect(caps.deleting, isFalse);
        expect(caps.typingIndicator, isFalse);
        expect(caps.maxMessageLength, isNull);

        // Extended defaults
        expect(caps.supportsFiles, isFalse);
        expect(caps.maxFileSize, isNull);
        expect(caps.supportsButtons, isFalse);
        expect(caps.supportsMenus, isFalse);
        expect(caps.supportsModals, isFalse);
        expect(caps.supportsEphemeral, isFalse);
        expect(caps.supportsCommands, isFalse);
        expect(caps.maxBlocksPerMessage, isNull);
        expect(caps.supportedAttachments, isEmpty);
        expect(caps.custom, isNull);
      });

      test('creates with all fields set', () {
        const caps = ExtendedChannelCapabilities(
          text: true,
          richMessages: true,
          attachments: true,
          reactions: true,
          threads: true,
          editing: true,
          deleting: true,
          typingIndicator: true,
          maxMessageLength: 5000,
          supportsFiles: true,
          maxFileSize: 1000000,
          supportsButtons: true,
          supportsMenus: true,
          supportsModals: true,
          supportsEphemeral: true,
          supportsCommands: true,
          maxBlocksPerMessage: 20,
          supportedAttachments: {AttachmentType.file, AttachmentType.image},
          custom: {'key': 'value'},
        );

        expect(caps.text, isTrue);
        expect(caps.richMessages, isTrue);
        expect(caps.attachments, isTrue);
        expect(caps.reactions, isTrue);
        expect(caps.threads, isTrue);
        expect(caps.editing, isTrue);
        expect(caps.deleting, isTrue);
        expect(caps.typingIndicator, isTrue);
        expect(caps.maxMessageLength, equals(5000));
        expect(caps.supportsFiles, isTrue);
        expect(caps.maxFileSize, equals(1000000));
        expect(caps.supportsButtons, isTrue);
        expect(caps.supportsMenus, isTrue);
        expect(caps.supportsModals, isTrue);
        expect(caps.supportsEphemeral, isTrue);
        expect(caps.supportsCommands, isTrue);
        expect(caps.maxBlocksPerMessage, equals(20));
        expect(
          caps.supportedAttachments,
          equals({AttachmentType.file, AttachmentType.image}),
        );
        expect(caps.custom, equals({'key': 'value'}));
      });

      test('is a ChannelCapabilities subtype', () {
        const caps = ExtendedChannelCapabilities();
        expect(caps, isA<ChannelCapabilities>());
      });
    });

    group('fromBase factory', () {
      test('propagates all base fields', () {
        const base = ChannelCapabilities(
          text: true,
          richMessages: true,
          attachments: true,
          reactions: true,
          threads: true,
          editing: true,
          deleting: true,
          typingIndicator: true,
          maxMessageLength: 4000,
        );

        final caps = ExtendedChannelCapabilities.fromBase(base);

        expect(caps.text, isTrue);
        expect(caps.richMessages, isTrue);
        expect(caps.attachments, isTrue);
        expect(caps.reactions, isTrue);
        expect(caps.threads, isTrue);
        expect(caps.editing, isTrue);
        expect(caps.deleting, isTrue);
        expect(caps.typingIndicator, isTrue);
        expect(caps.maxMessageLength, equals(4000));
      });

      test('extended fields default to false/null/empty', () {
        const base = ChannelCapabilities();
        final caps = ExtendedChannelCapabilities.fromBase(base);

        expect(caps.supportsFiles, isFalse);
        expect(caps.maxFileSize, isNull);
        expect(caps.supportsButtons, isFalse);
        expect(caps.supportsMenus, isFalse);
        expect(caps.supportsModals, isFalse);
        expect(caps.supportsEphemeral, isFalse);
        expect(caps.supportsCommands, isFalse);
        expect(caps.maxBlocksPerMessage, isNull);
        expect(caps.supportedAttachments, isEmpty);
        expect(caps.custom, isNull);
      });

      test('accepts extended fields', () {
        const base = ChannelCapabilities();
        final caps = ExtendedChannelCapabilities.fromBase(
          base,
          supportsFiles: true,
          maxFileSize: 5000000,
          supportsButtons: true,
          supportsMenus: true,
          supportsModals: true,
          supportsEphemeral: true,
          supportsCommands: true,
          maxBlocksPerMessage: 10,
          supportedAttachments: {AttachmentType.image, AttachmentType.video},
          custom: {'extra': true},
        );

        expect(caps.supportsFiles, isTrue);
        expect(caps.maxFileSize, equals(5000000));
        expect(caps.supportsButtons, isTrue);
        expect(caps.supportsMenus, isTrue);
        expect(caps.supportsModals, isTrue);
        expect(caps.supportsEphemeral, isTrue);
        expect(caps.supportsCommands, isTrue);
        expect(caps.maxBlocksPerMessage, equals(10));
        expect(
          caps.supportedAttachments,
          equals({AttachmentType.image, AttachmentType.video}),
        );
        expect(caps.custom, equals({'extra': true}));
      });
    });

    group('platform factories', () {
      group('slack', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.slack();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isTrue);
          expect(caps.attachments, isTrue);
          expect(caps.reactions, isTrue);
          expect(caps.threads, isTrue);
          expect(caps.editing, isTrue);
          expect(caps.deleting, isTrue);
          expect(caps.typingIndicator, isFalse);
          expect(caps.maxMessageLength, equals(40000));
          expect(caps.supportsFiles, isTrue);
          expect(caps.maxFileSize, equals(1024 * 1024 * 1024));
          expect(caps.supportsButtons, isTrue);
          expect(caps.supportsMenus, isTrue);
          expect(caps.supportsModals, isTrue);
          expect(caps.supportsEphemeral, isTrue);
          expect(caps.supportsCommands, isTrue);
          expect(caps.maxBlocksPerMessage, equals(50));
          expect(caps.supportedAttachments, contains(AttachmentType.file));
          expect(caps.supportedAttachments, contains(AttachmentType.image));
          expect(caps.supportedAttachments, contains(AttachmentType.video));
          expect(caps.supportedAttachments, contains(AttachmentType.audio));
          expect(
              caps.supportedAttachments, contains(AttachmentType.document));
          expect(caps.custom, isNotNull);
          expect(caps.custom!['supportsBlockKit'], isTrue);
          expect(caps.custom!['supportsWorkflows'], isTrue);
          expect(caps.custom!['supportsShortcuts'], isTrue);
          expect(caps.custom!['supportsHomeTab'], isTrue);
        });
      });

      group('discord', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.discord();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isTrue);
          expect(caps.attachments, isTrue);
          expect(caps.reactions, isTrue);
          expect(caps.threads, isTrue);
          expect(caps.editing, isTrue);
          expect(caps.deleting, isTrue);
          expect(caps.typingIndicator, isTrue);
          expect(caps.maxMessageLength, equals(2000));
          expect(caps.supportsFiles, isTrue);
          expect(caps.maxFileSize, equals(25 * 1024 * 1024));
          expect(caps.supportsButtons, isTrue);
          expect(caps.supportsMenus, isTrue);
          expect(caps.supportsModals, isTrue);
          expect(caps.supportsEphemeral, isTrue);
          expect(caps.supportsCommands, isTrue);
          expect(caps.maxBlocksPerMessage, equals(10));
          expect(caps.supportedAttachments, contains(AttachmentType.file));
          expect(caps.supportedAttachments, contains(AttachmentType.image));
          expect(caps.supportedAttachments, contains(AttachmentType.video));
          expect(caps.supportedAttachments, contains(AttachmentType.audio));
          expect(
              caps.supportedAttachments, contains(AttachmentType.document));
          expect(caps.custom, isNull);
        });
      });

      group('telegram', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.telegram();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isFalse);
          expect(caps.attachments, isTrue);
          expect(caps.reactions, isTrue);
          expect(caps.threads, isTrue);
          expect(caps.editing, isTrue);
          expect(caps.deleting, isTrue);
          expect(caps.typingIndicator, isTrue);
          expect(caps.maxMessageLength, equals(4096));
          expect(caps.supportsFiles, isTrue);
          expect(caps.maxFileSize, equals(50 * 1024 * 1024));
          expect(caps.supportsButtons, isTrue);
          expect(caps.supportsMenus, isTrue);
          expect(caps.supportsModals, isFalse);
          expect(caps.supportsEphemeral, isFalse);
          expect(caps.supportsCommands, isTrue);
          expect(caps.supportedAttachments, contains(AttachmentType.file));
          expect(caps.supportedAttachments, contains(AttachmentType.image));
          expect(caps.supportedAttachments, contains(AttachmentType.video));
          expect(caps.supportedAttachments, contains(AttachmentType.audio));
          expect(
              caps.supportedAttachments, contains(AttachmentType.document));
          expect(caps.custom, isNull);
        });
      });

      group('teams', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.teams();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isTrue);
          expect(caps.attachments, isTrue);
          expect(caps.reactions, isTrue);
          expect(caps.threads, isTrue);
          expect(caps.editing, isTrue);
          expect(caps.deleting, isTrue);
          expect(caps.typingIndicator, isTrue);
          expect(caps.maxMessageLength, equals(28000));
          expect(caps.supportsFiles, isTrue);
          expect(caps.maxFileSize, equals(25 * 1024 * 1024));
          expect(caps.supportsButtons, isTrue);
          expect(caps.supportsMenus, isTrue);
          expect(caps.supportsModals, isTrue);
          expect(caps.supportsEphemeral, isFalse);
          expect(caps.supportsCommands, isTrue);
          expect(caps.supportedAttachments, contains(AttachmentType.file));
          expect(caps.supportedAttachments, contains(AttachmentType.image));
          expect(caps.supportedAttachments.length, equals(2));
          expect(caps.custom, isNotNull);
          expect(caps.custom!['supportsAdaptiveCards'], isTrue);
          expect(caps.custom!['supportsTaskModules'], isTrue);
          expect(caps.custom!['supportsMeetings'], isTrue);
          expect(caps.custom!['supportsMessageExtensions'], isTrue);
        });
      });

      group('email', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.email();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isFalse);
          expect(caps.attachments, isTrue);
          expect(caps.reactions, isFalse);
          expect(caps.threads, isTrue);
          expect(caps.editing, isFalse);
          expect(caps.deleting, isFalse);
          expect(caps.typingIndicator, isFalse);
          expect(caps.maxMessageLength, isNull);
          expect(caps.supportsFiles, isTrue);
          expect(caps.maxFileSize, equals(25 * 1024 * 1024));
          expect(caps.supportsButtons, isFalse);
          expect(caps.supportsMenus, isFalse);
          expect(caps.supportsModals, isFalse);
          expect(caps.supportsEphemeral, isFalse);
          expect(caps.supportsCommands, isTrue);
          expect(caps.supportedAttachments, contains(AttachmentType.file));
          expect(caps.supportedAttachments, contains(AttachmentType.image));
          expect(
              caps.supportedAttachments, contains(AttachmentType.document));
          expect(caps.supportedAttachments.length, equals(3));
          expect(caps.custom, isNotNull);
          expect(caps.custom!['supportsHtml'], isTrue);
          expect(caps.custom!['supportsAsync'], isTrue);
          expect(
              caps.custom!['avgResponseTime'], equals('minutes to hours'));
        });
      });

      group('webhook', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.webhook();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isTrue);
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
          expect(caps.supportedAttachments, isEmpty);
          expect(caps.custom, isNull);
        });
      });

      group('wecom', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.wecom();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isTrue);
          expect(caps.attachments, isTrue);
          expect(caps.reactions, isFalse);
          expect(caps.threads, isFalse);
          expect(caps.editing, isFalse);
          expect(caps.deleting, isTrue);
          expect(caps.typingIndicator, isFalse);
          expect(caps.maxMessageLength, equals(2048));
          expect(caps.supportsFiles, isTrue);
          expect(caps.maxFileSize, equals(20 * 1024 * 1024));
          expect(caps.supportsButtons, isTrue);
          expect(caps.supportsMenus, isTrue);
          expect(caps.supportsModals, isFalse);
          expect(caps.supportsEphemeral, isFalse);
          expect(caps.supportsCommands, isTrue);
          expect(caps.supportedAttachments, contains(AttachmentType.file));
          expect(caps.supportedAttachments, contains(AttachmentType.image));
          expect(caps.supportedAttachments, contains(AttachmentType.video));
          expect(caps.supportedAttachments, contains(AttachmentType.audio));
          expect(caps.supportedAttachments.length, equals(4));
          expect(caps.custom, isNotNull);
          expect(caps.custom!['supportsMarkdown'], isTrue);
          expect(caps.custom!['supportsTextCard'], isTrue);
          expect(caps.custom!['supportsNewsCard'], isTrue);
          expect(caps.custom!['supportsInteractiveCard'], isTrue);
        });
      });

      group('youtube', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.youtube();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isFalse);
          expect(caps.attachments, isFalse);
          expect(caps.reactions, isFalse);
          expect(caps.threads, isTrue);
          expect(caps.editing, isTrue);
          expect(caps.deleting, isTrue);
          expect(caps.typingIndicator, isFalse);
          expect(caps.maxMessageLength, equals(10000));
          expect(caps.supportsFiles, isFalse);
          expect(caps.maxFileSize, isNull);
          expect(caps.supportsButtons, isFalse);
          expect(caps.supportsMenus, isFalse);
          expect(caps.supportsModals, isFalse);
          expect(caps.supportsEphemeral, isFalse);
          expect(caps.supportsCommands, isTrue);
          expect(caps.supportedAttachments, isEmpty);
          expect(caps.custom, isNotNull);
          expect(caps.custom!['isPublic'], isTrue);
          expect(caps.custom!['requiresOAuth'], isTrue);
          expect(caps.custom!['quotaLimited'], isTrue);
          expect(caps.custom!['liveChatMaxLength'], equals(200));
        });
      });

      group('kakao', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.kakao();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isFalse);
          expect(caps.attachments, isFalse);
          expect(caps.reactions, isFalse);
          expect(caps.threads, isFalse);
          expect(caps.editing, isFalse);
          expect(caps.deleting, isFalse);
          expect(caps.typingIndicator, isFalse);
          expect(caps.maxMessageLength, equals(1000));
          expect(caps.supportsFiles, isFalse);
          expect(caps.maxFileSize, isNull);
          expect(caps.supportsButtons, isTrue);
          expect(caps.supportsMenus, isFalse);
          expect(caps.supportsModals, isFalse);
          expect(caps.supportsEphemeral, isFalse);
          expect(caps.supportsCommands, isFalse);
          expect(caps.supportedAttachments, isEmpty);
          expect(caps.custom, isNotNull);
          expect(caps.custom!['templateBased'], isTrue);
          expect(caps.custom!['requiresApproval'], isTrue);
          expect(caps.custom!['userInitiatedOnly'], isTrue);
        });
      });

      group('minimal', () {
        test('has correct key fields', () {
          final caps = ExtendedChannelCapabilities.minimal();

          expect(caps.text, isTrue);
          expect(caps.richMessages, isFalse);
          expect(caps.attachments, isFalse);
          expect(caps.reactions, isFalse);
          expect(caps.threads, isFalse);
          expect(caps.editing, isFalse);
          expect(caps.deleting, isFalse);
          expect(caps.typingIndicator, isFalse);
          expect(caps.maxMessageLength, equals(2000));
          expect(caps.supportsFiles, isFalse);
          expect(caps.maxFileSize, isNull);
          expect(caps.supportsButtons, isFalse);
          expect(caps.supportsMenus, isFalse);
          expect(caps.supportsModals, isFalse);
          expect(caps.supportsEphemeral, isFalse);
          expect(caps.supportsCommands, isFalse);
          expect(caps.maxBlocksPerMessage, isNull);
          expect(caps.supportedAttachments, isEmpty);
          expect(caps.custom, isNull);
        });
      });
    });

    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'text': true,
          'richMessages': true,
          'attachments': true,
          'reactions': true,
          'threads': true,
          'editing': true,
          'deleting': true,
          'typingIndicator': true,
          'maxMessageLength': 5000,
          'supportsFiles': true,
          'maxFileSize': 1000000,
          'supportsButtons': true,
          'supportsMenus': true,
          'supportsModals': true,
          'supportsEphemeral': true,
          'supportsCommands': true,
          'maxBlocksPerMessage': 20,
          'supportedAttachments': ['file', 'image', 'video'],
          'custom': {'key': 'value'},
        };

        final caps = ExtendedChannelCapabilities.fromJson(json);
        expect(caps.text, isTrue);
        expect(caps.richMessages, isTrue);
        expect(caps.attachments, isTrue);
        expect(caps.reactions, isTrue);
        expect(caps.threads, isTrue);
        expect(caps.editing, isTrue);
        expect(caps.deleting, isTrue);
        expect(caps.typingIndicator, isTrue);
        expect(caps.maxMessageLength, equals(5000));
        expect(caps.supportsFiles, isTrue);
        expect(caps.maxFileSize, equals(1000000));
        expect(caps.supportsButtons, isTrue);
        expect(caps.supportsMenus, isTrue);
        expect(caps.supportsModals, isTrue);
        expect(caps.supportsEphemeral, isTrue);
        expect(caps.supportsCommands, isTrue);
        expect(caps.maxBlocksPerMessage, equals(20));
        expect(
          caps.supportedAttachments,
          equals({
            AttachmentType.file,
            AttachmentType.image,
            AttachmentType.video,
          }),
        );
        expect(caps.custom, equals({'key': 'value'}));
      });

      test('defaults boolean fields when missing', () {
        final json = <String, dynamic>{};

        final caps = ExtendedChannelCapabilities.fromJson(json);
        expect(caps.text, isTrue);
        expect(caps.richMessages, isFalse);
        expect(caps.attachments, isFalse);
        expect(caps.reactions, isFalse);
        expect(caps.threads, isFalse);
        expect(caps.editing, isFalse);
        expect(caps.deleting, isFalse);
        expect(caps.typingIndicator, isFalse);
        expect(caps.supportsFiles, isFalse);
        expect(caps.supportsButtons, isFalse);
        expect(caps.supportsMenus, isFalse);
        expect(caps.supportsModals, isFalse);
        expect(caps.supportsEphemeral, isFalse);
        expect(caps.supportsCommands, isFalse);
      });

      test('defaults nullable fields to null when missing', () {
        final json = <String, dynamic>{};

        final caps = ExtendedChannelCapabilities.fromJson(json);
        expect(caps.maxMessageLength, isNull);
        expect(caps.maxFileSize, isNull);
        expect(caps.maxBlocksPerMessage, isNull);
        expect(caps.custom, isNull);
      });

      test('defaults supportedAttachments to empty set when null', () {
        final json = <String, dynamic>{};

        final caps = ExtendedChannelCapabilities.fromJson(json);
        expect(caps.supportedAttachments, isEmpty);
      });

      test('parses supportedAttachments list', () {
        final json = {
          'supportedAttachments': ['file', 'image', 'audio', 'document'],
        };

        final caps = ExtendedChannelCapabilities.fromJson(json);
        expect(caps.supportedAttachments, contains(AttachmentType.file));
        expect(caps.supportedAttachments, contains(AttachmentType.image));
        expect(caps.supportedAttachments, contains(AttachmentType.audio));
        expect(
            caps.supportedAttachments, contains(AttachmentType.document));
        expect(caps.supportedAttachments.length, equals(4));
      });

      test('falls back to AttachmentType.file for unknown attachment type',
          () {
        final json = {
          'supportedAttachments': ['unknown_type', 'also_unknown'],
        };

        final caps = ExtendedChannelCapabilities.fromJson(json);
        expect(caps.supportedAttachments, contains(AttachmentType.file));
        // Both unknowns map to file, which is a set, so only one entry
        expect(caps.supportedAttachments.length, equals(1));
      });

      test('handles mix of known and unknown attachment types', () {
        final json = {
          'supportedAttachments': ['image', 'nonexistent', 'video'],
        };

        final caps = ExtendedChannelCapabilities.fromJson(json);
        expect(caps.supportedAttachments, contains(AttachmentType.image));
        expect(caps.supportedAttachments, contains(AttachmentType.file));
        expect(caps.supportedAttachments, contains(AttachmentType.video));
      });

      test('parses boolean fields with null values using defaults', () {
        final json = {
          'text': null,
          'richMessages': null,
          'attachments': null,
          'reactions': null,
          'threads': null,
          'editing': null,
          'deleting': null,
          'typingIndicator': null,
          'supportsFiles': null,
          'supportsButtons': null,
          'supportsMenus': null,
          'supportsModals': null,
          'supportsEphemeral': null,
          'supportsCommands': null,
        };

        final caps = ExtendedChannelCapabilities.fromJson(json);
        expect(caps.text, isTrue);
        expect(caps.richMessages, isFalse);
        expect(caps.attachments, isFalse);
        expect(caps.reactions, isFalse);
        expect(caps.threads, isFalse);
        expect(caps.editing, isFalse);
        expect(caps.deleting, isFalse);
        expect(caps.typingIndicator, isFalse);
        expect(caps.supportsFiles, isFalse);
        expect(caps.supportsButtons, isFalse);
        expect(caps.supportsMenus, isFalse);
        expect(caps.supportsModals, isFalse);
        expect(caps.supportsEphemeral, isFalse);
        expect(caps.supportsCommands, isFalse);
      });
    });

    group('toBase', () {
      test('returns ChannelCapabilities with base fields only', () {
        final caps = ExtendedChannelCapabilities.slack();
        final base = caps.toBase();

        expect(base, isA<ChannelCapabilities>());
        expect(base, isNot(isA<ExtendedChannelCapabilities>()));
        expect(base.text, equals(caps.text));
        expect(base.richMessages, equals(caps.richMessages));
        expect(base.attachments, equals(caps.attachments));
        expect(base.reactions, equals(caps.reactions));
        expect(base.threads, equals(caps.threads));
        expect(base.editing, equals(caps.editing));
        expect(base.deleting, equals(caps.deleting));
        expect(base.typingIndicator, equals(caps.typingIndicator));
        expect(base.maxMessageLength, equals(caps.maxMessageLength));
      });

      test('does not include extended fields', () {
        final caps = ExtendedChannelCapabilities.slack();
        final base = caps.toBase();
        final json = base.toJson();

        expect(json.containsKey('supportsFiles'), isFalse);
        expect(json.containsKey('maxFileSize'), isFalse);
        expect(json.containsKey('supportsButtons'), isFalse);
        expect(json.containsKey('supportsMenus'), isFalse);
        expect(json.containsKey('supportsModals'), isFalse);
        expect(json.containsKey('supportsEphemeral'), isFalse);
        expect(json.containsKey('supportsCommands'), isFalse);
        expect(json.containsKey('maxBlocksPerMessage'), isFalse);
        expect(json.containsKey('supportedAttachments'), isFalse);
        expect(json.containsKey('custom'), isFalse);
      });
    });

    group('copyWith', () {
      test('copies with new text', () {
        final caps = ExtendedChannelCapabilities.slack();
        final copied = caps.copyWith(text: false);
        expect(copied.text, isFalse);
        expect(copied.richMessages, equals(caps.richMessages));
      });

      test('copies with new richMessages', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(richMessages: true);
        expect(copied.richMessages, isTrue);
      });

      test('copies with new attachments', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(attachments: true);
        expect(copied.attachments, isTrue);
      });

      test('copies with new reactions', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(reactions: true);
        expect(copied.reactions, isTrue);
      });

      test('copies with new threads', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(threads: true);
        expect(copied.threads, isTrue);
      });

      test('copies with new editing', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(editing: true);
        expect(copied.editing, isTrue);
      });

      test('copies with new deleting', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(deleting: true);
        expect(copied.deleting, isTrue);
      });

      test('copies with new typingIndicator', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(typingIndicator: true);
        expect(copied.typingIndicator, isTrue);
      });

      test('copies with new maxMessageLength', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(maxMessageLength: 9999);
        expect(copied.maxMessageLength, equals(9999));
      });

      test('copies with new supportsFiles', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(supportsFiles: true);
        expect(copied.supportsFiles, isTrue);
      });

      test('copies with new maxFileSize', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(maxFileSize: 5000);
        expect(copied.maxFileSize, equals(5000));
      });

      test('copies with new supportsButtons', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(supportsButtons: true);
        expect(copied.supportsButtons, isTrue);
      });

      test('copies with new supportsMenus', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(supportsMenus: true);
        expect(copied.supportsMenus, isTrue);
      });

      test('copies with new supportsModals', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(supportsModals: true);
        expect(copied.supportsModals, isTrue);
      });

      test('copies with new supportsEphemeral', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(supportsEphemeral: true);
        expect(copied.supportsEphemeral, isTrue);
      });

      test('copies with new supportsCommands', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(supportsCommands: true);
        expect(copied.supportsCommands, isTrue);
      });

      test('copies with new maxBlocksPerMessage', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(maxBlocksPerMessage: 25);
        expect(copied.maxBlocksPerMessage, equals(25));
      });

      test('copies with new supportedAttachments', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(
          supportedAttachments: {AttachmentType.audio, AttachmentType.video},
        );
        expect(
          copied.supportedAttachments,
          equals({AttachmentType.audio, AttachmentType.video}),
        );
      });

      test('copies with new custom', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final copied = caps.copyWith(custom: {'newKey': 'newVal'});
        expect(copied.custom, equals({'newKey': 'newVal'}));
      });

      test('preserves all fields when no arguments given', () {
        final caps = ExtendedChannelCapabilities.slack();
        final copied = caps.copyWith();

        expect(copied.text, equals(caps.text));
        expect(copied.richMessages, equals(caps.richMessages));
        expect(copied.attachments, equals(caps.attachments));
        expect(copied.reactions, equals(caps.reactions));
        expect(copied.threads, equals(caps.threads));
        expect(copied.editing, equals(caps.editing));
        expect(copied.deleting, equals(caps.deleting));
        expect(copied.typingIndicator, equals(caps.typingIndicator));
        expect(copied.maxMessageLength, equals(caps.maxMessageLength));
        expect(copied.supportsFiles, equals(caps.supportsFiles));
        expect(copied.maxFileSize, equals(caps.maxFileSize));
        expect(copied.supportsButtons, equals(caps.supportsButtons));
        expect(copied.supportsMenus, equals(caps.supportsMenus));
        expect(copied.supportsModals, equals(caps.supportsModals));
        expect(copied.supportsEphemeral, equals(caps.supportsEphemeral));
        expect(copied.supportsCommands, equals(caps.supportsCommands));
        expect(
            copied.maxBlocksPerMessage, equals(caps.maxBlocksPerMessage));
        expect(copied.supportedAttachments,
            equals(caps.supportedAttachments));
        expect(copied.custom, equals(caps.custom));
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final caps = ExtendedChannelCapabilities.slack();
        final json = caps.toJson();

        expect(json['text'], isTrue);
        expect(json['richMessages'], isTrue);
        expect(json['attachments'], isTrue);
        expect(json['reactions'], isTrue);
        expect(json['threads'], isTrue);
        expect(json['editing'], isTrue);
        expect(json['deleting'], isTrue);
        expect(json['typingIndicator'], isFalse);
        expect(json['maxMessageLength'], equals(40000));
        expect(json['supportsFiles'], isTrue);
        expect(json['maxFileSize'], equals(1024 * 1024 * 1024));
        expect(json['supportsButtons'], isTrue);
        expect(json['supportsMenus'], isTrue);
        expect(json['supportsModals'], isTrue);
        expect(json['supportsEphemeral'], isTrue);
        expect(json['supportsCommands'], isTrue);
        expect(json['maxBlocksPerMessage'], equals(50));
        expect(json['supportedAttachments'], isA<List>());
        expect(json['custom'], isNotNull);
      });

      test('serializes supportedAttachments as name list', () {
        const caps = ExtendedChannelCapabilities(
          supportedAttachments: {
            AttachmentType.file,
            AttachmentType.image,
          },
        );

        final json = caps.toJson();
        final attachments = json['supportedAttachments'] as List;
        expect(attachments, contains('file'));
        expect(attachments, contains('image'));
      });

      test('omits maxMessageLength when null', () {
        const caps = ExtendedChannelCapabilities();
        final json = caps.toJson();
        expect(json.containsKey('maxMessageLength'), isFalse);
      });

      test('omits maxFileSize when null', () {
        const caps = ExtendedChannelCapabilities();
        final json = caps.toJson();
        expect(json.containsKey('maxFileSize'), isFalse);
      });

      test('omits maxBlocksPerMessage when null', () {
        const caps = ExtendedChannelCapabilities();
        final json = caps.toJson();
        expect(json.containsKey('maxBlocksPerMessage'), isFalse);
      });

      test('omits custom when null', () {
        const caps = ExtendedChannelCapabilities();
        final json = caps.toJson();
        expect(json.containsKey('custom'), isFalse);
      });

      test('includes custom when present', () {
        const caps = ExtendedChannelCapabilities(
          custom: {'myKey': 42},
        );
        final json = caps.toJson();
        expect(json['custom'], equals({'myKey': 42}));
      });

      test('always includes boolean fields', () {
        const caps = ExtendedChannelCapabilities();
        final json = caps.toJson();

        expect(json.containsKey('text'), isTrue);
        expect(json.containsKey('richMessages'), isTrue);
        expect(json.containsKey('attachments'), isTrue);
        expect(json.containsKey('reactions'), isTrue);
        expect(json.containsKey('threads'), isTrue);
        expect(json.containsKey('editing'), isTrue);
        expect(json.containsKey('deleting'), isTrue);
        expect(json.containsKey('typingIndicator'), isTrue);
        expect(json.containsKey('supportsFiles'), isTrue);
        expect(json.containsKey('supportsButtons'), isTrue);
        expect(json.containsKey('supportsMenus'), isTrue);
        expect(json.containsKey('supportsModals'), isTrue);
        expect(json.containsKey('supportsEphemeral'), isTrue);
        expect(json.containsKey('supportsCommands'), isTrue);
      });

      test('always includes supportedAttachments', () {
        const caps = ExtendedChannelCapabilities();
        final json = caps.toJson();
        expect(json.containsKey('supportedAttachments'), isTrue);
        expect(json['supportedAttachments'], isA<List>());
        expect((json['supportedAttachments'] as List), isEmpty);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final caps = ExtendedChannelCapabilities.slack();
        final str = caps.toString();

        expect(str, contains('ExtendedChannelCapabilities('));
        expect(str, contains('text: true'));
        expect(str, contains('richMessages: true'));
        expect(str, contains('threads: true'));
        expect(str, contains('reactions: true'));
        expect(str, contains('files: true'));
        expect(str, contains('buttons: true'));
      });

      test('reflects minimal capabilities', () {
        final caps = ExtendedChannelCapabilities.minimal();
        final str = caps.toString();

        expect(str, contains('text: true'));
        expect(str, contains('richMessages: false'));
        expect(str, contains('threads: false'));
        expect(str, contains('reactions: false'));
        expect(str, contains('files: false'));
        expect(str, contains('buttons: false'));
      });
    });
  });
}
