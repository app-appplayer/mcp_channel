import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Shared fixtures
  const channelIdentity = ChannelIdentity(
    platform: 'slack',
    channelId: 'T123',
  );

  final conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'C456',
    userId: 'U123',
  );

  group('ChannelResponseType', () {
    test('has all 9 values', () {
      expect(ChannelResponseType.values, hasLength(9));
      expect(ChannelResponseType.values, contains(ChannelResponseType.text));
      expect(ChannelResponseType.values, contains(ChannelResponseType.rich));
      expect(ChannelResponseType.values, contains(ChannelResponseType.file));
      expect(ChannelResponseType.values, contains(ChannelResponseType.link));
      expect(ChannelResponseType.values, contains(ChannelResponseType.update));
      expect(ChannelResponseType.values, contains(ChannelResponseType.delete));
      expect(
          ChannelResponseType.values, contains(ChannelResponseType.ephemeral));
      expect(
          ChannelResponseType.values, contains(ChannelResponseType.reaction));
      expect(ChannelResponseType.values, contains(ChannelResponseType.typing));
    });
  });

  group('Embed', () {
    group('constructor', () {
      test('creates with all fields', () {
        final ts = DateTime(2024, 6, 15, 12, 0);
        final embed = Embed(
          title: 'My Embed',
          description: 'A description',
          url: 'https://example.com',
          color: '#FF0000',
          imageUrl: 'https://example.com/img.png',
          thumbnailUrl: 'https://example.com/thumb.png',
          author: 'Bot',
          footer: 'Footer text',
          timestamp: ts,
          fields: [
            const EmbedField(name: 'F1', value: 'V1', inline: true),
          ],
        );

        expect(embed.title, 'My Embed');
        expect(embed.description, 'A description');
        expect(embed.url, 'https://example.com');
        expect(embed.color, '#FF0000');
        expect(embed.imageUrl, 'https://example.com/img.png');
        expect(embed.thumbnailUrl, 'https://example.com/thumb.png');
        expect(embed.author, 'Bot');
        expect(embed.footer, 'Footer text');
        expect(embed.timestamp, ts);
        expect(embed.fields, hasLength(1));
      });

      test('creates with no fields (all null)', () {
        const embed = Embed();

        expect(embed.title, isNull);
        expect(embed.description, isNull);
        expect(embed.url, isNull);
        expect(embed.color, isNull);
        expect(embed.imageUrl, isNull);
        expect(embed.thumbnailUrl, isNull);
        expect(embed.author, isNull);
        expect(embed.footer, isNull);
        expect(embed.timestamp, isNull);
        expect(embed.fields, isNull);
      });
    });

    group('fromJson', () {
      test('deserializes all fields including timestamp and fields list', () {
        final json = {
          'title': 'Title',
          'description': 'Desc',
          'url': 'https://example.com',
          'color': '#00FF00',
          'imageUrl': 'https://example.com/img.png',
          'thumbnailUrl': 'https://example.com/thumb.png',
          'author': 'Author',
          'footer': 'Footer',
          'timestamp': '2024-06-15T12:00:00.000',
          'fields': [
            {'name': 'Field1', 'value': 'Val1', 'inline': true},
            {'name': 'Field2', 'value': 'Val2'},
          ],
        };

        final embed = Embed.fromJson(json);

        expect(embed.title, 'Title');
        expect(embed.description, 'Desc');
        expect(embed.url, 'https://example.com');
        expect(embed.color, '#00FF00');
        expect(embed.imageUrl, 'https://example.com/img.png');
        expect(embed.thumbnailUrl, 'https://example.com/thumb.png');
        expect(embed.author, 'Author');
        expect(embed.footer, 'Footer');
        expect(embed.timestamp, DateTime(2024, 6, 15, 12, 0));
        expect(embed.fields, hasLength(2));
        expect(embed.fields![0].name, 'Field1');
        expect(embed.fields![0].inline, isTrue);
        expect(embed.fields![1].inline, isFalse);
      });

      test('deserializes with no optional fields', () {
        final json = <String, dynamic>{};

        final embed = Embed.fromJson(json);

        expect(embed.title, isNull);
        expect(embed.timestamp, isNull);
        expect(embed.fields, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final ts = DateTime(2024, 3, 20, 10, 30);
        final embed = Embed(
          title: 'T',
          description: 'D',
          url: 'https://u.com',
          color: '#0000FF',
          imageUrl: 'https://u.com/i.png',
          thumbnailUrl: 'https://u.com/th.png',
          author: 'A',
          footer: 'F',
          timestamp: ts,
          fields: [
            const EmbedField(name: 'N', value: 'V', inline: true),
          ],
        );

        final json = embed.toJson();

        expect(json['title'], 'T');
        expect(json['description'], 'D');
        expect(json['url'], 'https://u.com');
        expect(json['color'], '#0000FF');
        expect(json['imageUrl'], 'https://u.com/i.png');
        expect(json['thumbnailUrl'], 'https://u.com/th.png');
        expect(json['author'], 'A');
        expect(json['footer'], 'F');
        expect(json['timestamp'], ts.toIso8601String());
        expect((json['fields'] as List), hasLength(1));
      });

      test('omits null fields', () {
        const embed = Embed(title: 'Only Title');

        final json = embed.toJson();

        expect(json['title'], 'Only Title');
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('url'), isFalse);
        expect(json.containsKey('color'), isFalse);
        expect(json.containsKey('imageUrl'), isFalse);
        expect(json.containsKey('thumbnailUrl'), isFalse);
        expect(json.containsKey('author'), isFalse);
        expect(json.containsKey('footer'), isFalse);
        expect(json.containsKey('timestamp'), isFalse);
        expect(json.containsKey('fields'), isFalse);
      });
    });
  });

  group('EmbedField', () {
    group('constructor', () {
      test('creates with required fields and default inline', () {
        const field = EmbedField(name: 'Status', value: 'Active');

        expect(field.name, 'Status');
        expect(field.value, 'Active');
        expect(field.inline, isFalse);
      });

      test('creates with inline true', () {
        const field = EmbedField(name: 'Count', value: '42', inline: true);

        expect(field.inline, isTrue);
      });
    });

    group('fromJson', () {
      test('deserializes with all fields', () {
        final json = {'name': 'N', 'value': 'V', 'inline': true};

        final field = EmbedField.fromJson(json);

        expect(field.name, 'N');
        expect(field.value, 'V');
        expect(field.inline, isTrue);
      });

      test('deserializes with default inline false when missing', () {
        final json = {'name': 'N', 'value': 'V'};

        final field = EmbedField.fromJson(json);

        expect(field.inline, isFalse);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const field = EmbedField(name: 'Key', value: 'Val', inline: true);

        final json = field.toJson();

        expect(json['name'], 'Key');
        expect(json['value'], 'Val');
        expect(json['inline'], isTrue);
      });
    });
  });

  group('ExtendedChannelResponse', () {
    group('constructor', () {
      test('creates with required fields and defaults', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );

        final response = ExtendedChannelResponse(base: base);

        expect(response.base, base);
        expect(response.extendedConversation, isNull);
        expect(response.responseType, ChannelResponseType.text);
        expect(response.blocks, isNull);
        expect(response.attachments, isNull);
        expect(response.embeds, isNull);
        expect(response.targetMessageId, isNull);
        expect(response.ephemeral, isFalse);
        expect(response.ephemeralUserId, isNull);
        expect(response.reaction, isNull);
      });
    });

    group('fromBase', () {
      test('creates from base with _parseResponseType for known type', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );

        final response = ExtendedChannelResponse.fromBase(base);

        expect(response.base, base);
        expect(response.responseType, ChannelResponseType.text);
      });

      test('creates from base with all optional params', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );
        final blocks = [ContentBlock.header(text: 'Title')];
        final attachments = [
          Attachment.fromUrl(name: 'doc.pdf', url: 'https://example.com/doc.pdf'),
        ];
        final embeds = [const Embed(title: 'Embed Title')];

        final response = ExtendedChannelResponse.fromBase(
          base,
          extendedConversation: extConv,
          responseType: ChannelResponseType.rich,
          blocks: blocks,
          attachments: attachments,
          embeds: embeds,
          targetMessageId: 'msg-1',
          ephemeral: true,
          ephemeralUserId: 'U123',
          reaction: 'thumbsup',
        );

        expect(response.extendedConversation, extConv);
        expect(response.responseType, ChannelResponseType.rich);
        expect(response.blocks, hasLength(1));
        expect(response.attachments, hasLength(1));
        expect(response.embeds, hasLength(1));
        expect(response.targetMessageId, 'msg-1');
        expect(response.ephemeral, isTrue);
        expect(response.ephemeralUserId, 'U123');
        expect(response.reaction, 'thumbsup');
      });

      test('parses unknown response type to text', () {
        final base = ChannelResponse(
          conversation: conversation,
          type: 'nonexistent_custom_type',
        );

        final response = ExtendedChannelResponse.fromBase(base);

        expect(response.responseType, ChannelResponseType.text);
      });
    });

    group('text factory', () {
      test('creates text response', () {
        final response = ExtendedChannelResponse.text(
          conversation: conversation,
          text: 'Hello!',
        );

        expect(response.responseType, ChannelResponseType.text);
        expect(response.text, 'Hello!');
        expect(response.conversation, conversation);
      });

      test('creates text response with replyTo and options', () {
        final response = ExtendedChannelResponse.text(
          conversation: conversation,
          text: 'Reply',
          replyTo: 'msg-99',
          options: {'unfurl_links': false},
        );

        expect(response.replyTo, 'msg-99');
        expect(response.options?['unfurl_links'], false);
      });

      test('creates text response with extendedConversation', () {
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          threadId: 'thread-1',
        );

        final response = ExtendedChannelResponse.text(
          conversation: conversation,
          text: 'Threaded reply',
          extendedConversation: extConv,
        );

        expect(response.extendedConversation, extConv);
      });
    });

    group('rich factory', () {
      test('creates rich response with blocks', () {
        final blocks = [
          ContentBlock.header(text: 'Title'),
          ContentBlock.section(text: 'Body text'),
          ContentBlock.divider(),
        ];

        final response = ExtendedChannelResponse.rich(
          conversation: conversation,
          blocks: blocks,
          text: 'Fallback text',
        );

        expect(response.responseType, ChannelResponseType.rich);
        expect(response.blocks, hasLength(3));
        expect(response.text, 'Fallback text');
        // Verify blocks are mapped to base response
        expect(response.base.blocks, hasLength(3));
      });

      test('creates rich response with replyTo and options', () {
        final blocks = [ContentBlock.header(text: 'H')];

        final response = ExtendedChannelResponse.rich(
          conversation: conversation,
          blocks: blocks,
          replyTo: 'msg-1',
          options: {'thread_broadcast': true},
        );

        expect(response.replyTo, 'msg-1');
        expect(response.options?['thread_broadcast'], true);
      });

      test('creates rich response with extendedConversation', () {
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );
        final blocks = [ContentBlock.header(text: 'H')];

        final response = ExtendedChannelResponse.rich(
          conversation: conversation,
          blocks: blocks,
          extendedConversation: extConv,
        );

        expect(response.extendedConversation, extConv);
      });
    });

    group('ephemeral factory', () {
      test('creates ephemeral response', () {
        final response = ExtendedChannelResponse.ephemeral(
          conversation: conversation,
          userId: 'U123',
          text: 'Only you can see this',
        );

        expect(response.responseType, ChannelResponseType.ephemeral);
        expect(response.ephemeral, isTrue);
        expect(response.ephemeralUserId, 'U123');
        expect(response.text, 'Only you can see this');
      });

      test('creates ephemeral response with options merging', () {
        final response = ExtendedChannelResponse.ephemeral(
          conversation: conversation,
          userId: 'U456',
          text: 'Secret',
          options: {'custom_key': 'custom_value'},
        );

        expect(response.options?['ephemeral'], true);
        expect(response.options?['ephemeralUserId'], 'U456');
        expect(response.options?['custom_key'], 'custom_value');
      });

      test('creates ephemeral response with blocks and extendedConversation',
          () {
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );
        final blocks = [ContentBlock.header(text: 'Secret Info')];

        final response = ExtendedChannelResponse.ephemeral(
          conversation: conversation,
          userId: 'U123',
          text: 'Hidden',
          blocks: blocks,
          extendedConversation: extConv,
        );

        expect(response.blocks, hasLength(1));
        expect(response.extendedConversation, extConv);
      });
    });

    group('typing factory', () {
      test('creates typing indicator response', () {
        final response = ExtendedChannelResponse.typing(
          conversation: conversation,
        );

        expect(response.responseType, ChannelResponseType.typing);
        expect(response.type, 'typing');
      });

      test('creates typing with extendedConversation', () {
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );

        final response = ExtendedChannelResponse.typing(
          conversation: conversation,
          extendedConversation: extConv,
        );

        expect(response.extendedConversation, extConv);
      });
    });

    group('reaction factory', () {
      test('creates reaction response', () {
        final response = ExtendedChannelResponse.reaction(
          conversation: conversation,
          targetMessageId: 'msg-1',
          reaction: 'thumbsup',
        );

        expect(response.responseType, ChannelResponseType.reaction);
        expect(response.targetMessageId, 'msg-1');
        expect(response.reaction, 'thumbsup');
        expect(response.type, 'reaction');
      });

      test('creates reaction with options merging', () {
        final response = ExtendedChannelResponse.reaction(
          conversation: conversation,
          targetMessageId: 'msg-2',
          reaction: 'heart',
          options: {'custom': 'value'},
        );

        expect(response.options?['targetMessageId'], 'msg-2');
        expect(response.options?['reaction'], 'heart');
        expect(response.options?['custom'], 'value');
      });

      test('creates reaction with extendedConversation', () {
        final extConv = ExtendedConversationKey.create(
          platform: 'discord',
          channelId: 'D123',
          conversationId: 'dc-1',
        );

        final response = ExtendedChannelResponse.reaction(
          conversation: conversation,
          targetMessageId: 'msg-3',
          reaction: 'star',
          extendedConversation: extConv,
        );

        expect(response.extendedConversation, extConv);
      });
    });

    group('fromJson', () {
      test('deserializes with all optional fields', () {
        final baseJson = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        ).toJson();

        final extConvJson = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        ).toJson();

        final json = {
          'base': baseJson,
          'extendedConversation': extConvJson,
          'responseType': 'rich',
          'blocks': [
            {
              'type': 'header',
              'content': {'text': 'Title'},
            },
          ],
          'attachments': [
            {'type': 'file', 'name': 'doc.pdf', 'url': 'https://example.com/doc.pdf'},
          ],
          'embeds': [
            {'title': 'Embed', 'description': 'A embed'},
          ],
          'targetMessageId': 'msg-1',
          'ephemeral': true,
          'ephemeralUserId': 'U123',
          'reaction': 'thumbsup',
        };

        final response = ExtendedChannelResponse.fromJson(json);

        expect(response.text, 'Hello');
        expect(response.extendedConversation, isNotNull);
        expect(response.responseType, ChannelResponseType.rich);
        expect(response.blocks, hasLength(1));
        expect(response.blocks![0].type, ContentBlockType.header);
        expect(response.attachments, hasLength(1));
        expect(response.attachments![0].name, 'doc.pdf');
        expect(response.embeds, hasLength(1));
        expect(response.embeds![0].title, 'Embed');
        expect(response.targetMessageId, 'msg-1');
        expect(response.ephemeral, isTrue);
        expect(response.ephemeralUserId, 'U123');
        expect(response.reaction, 'thumbsup');
      });

      test('deserializes with minimal fields and default ephemeral false', () {
        final baseJson = ChannelResponse.text(
          conversation: conversation,
          text: 'Hi',
        ).toJson();

        final json = {
          'base': baseJson,
          'responseType': 'text',
        };

        final response = ExtendedChannelResponse.fromJson(json);

        expect(response.text, 'Hi');
        expect(response.responseType, ChannelResponseType.text);
        expect(response.blocks, isNull);
        expect(response.attachments, isNull);
        expect(response.embeds, isNull);
        expect(response.ephemeral, isFalse);
        expect(response.ephemeralUserId, isNull);
        expect(response.reaction, isNull);
        expect(response.targetMessageId, isNull);
        expect(response.extendedConversation, isNull);
      });

      test('deserializes unknown response type to text', () {
        final baseJson = ChannelResponse.text(
          conversation: conversation,
          text: 'test',
        ).toJson();

        final json = {
          'base': baseJson,
          'responseType': 'unknown_custom_type',
        };

        final response = ExtendedChannelResponse.fromJson(json);

        expect(response.responseType, ChannelResponseType.text);
      });
    });

    group('delegating getters', () {
      test('conversation delegates to base', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hi',
        );
        final response = ExtendedChannelResponse(base: base);

        expect(response.conversation, conversation);
      });

      test('text delegates to base', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello!',
        );
        final response = ExtendedChannelResponse(base: base);

        expect(response.text, 'Hello!');
      });

      test('replyTo delegates to base', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'reply',
          replyTo: 'msg-99',
        );
        final response = ExtendedChannelResponse(base: base);

        expect(response.replyTo, 'msg-99');
      });

      test('type delegates to base', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hi',
        );
        final response = ExtendedChannelResponse(base: base);

        expect(response.type, 'text');
      });

      test('options delegates to base', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hi',
          options: {'key': 'value'},
        );
        final response = ExtendedChannelResponse(base: base);

        expect(response.options, {'key': 'value'});
      });
    });

    group('toBase', () {
      test('returns the wrapped base response', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hi',
        );
        final response = ExtendedChannelResponse(base: base);

        expect(response.toBase(), base);
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final base1 = ChannelResponse.text(
          conversation: conversation,
          text: 'Old',
        );
        final response = ExtendedChannelResponse(base: base1);

        final base2 = ChannelResponse.text(
          conversation: conversation,
          text: 'New',
        );
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );
        final blocks = [ContentBlock.header(text: 'H')];
        final attachments = [
          Attachment.fromUrl(name: 'a.pdf', url: 'https://example.com/a.pdf'),
        ];
        final embeds = [const Embed(title: 'E')];

        final copy = response.copyWith(
          base: base2,
          extendedConversation: extConv,
          responseType: ChannelResponseType.rich,
          blocks: blocks,
          attachments: attachments,
          embeds: embeds,
          targetMessageId: 'msg-new',
          ephemeral: true,
          ephemeralUserId: 'U999',
          reaction: 'fire',
        );

        expect(copy.base, base2);
        expect(copy.extendedConversation, extConv);
        expect(copy.responseType, ChannelResponseType.rich);
        expect(copy.blocks, hasLength(1));
        expect(copy.attachments, hasLength(1));
        expect(copy.embeds, hasLength(1));
        expect(copy.targetMessageId, 'msg-new');
        expect(copy.ephemeral, isTrue);
        expect(copy.ephemeralUserId, 'U999');
        expect(copy.reaction, 'fire');
      });

      test('copies with no fields changed preserves values', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final response = ExtendedChannelResponse(
          base: base,
          responseType: ChannelResponseType.text,
          ephemeral: false,
        );

        final copy = response.copyWith();

        expect(copy.base, response.base);
        expect(copy.responseType, response.responseType);
        expect(copy.ephemeral, response.ephemeral);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final extConv = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );
        final blocks = [ContentBlock.header(text: 'H')];
        final attachments = [
          Attachment.fromUrl(name: 'a.pdf', url: 'https://example.com/a.pdf'),
        ];
        final embeds = [const Embed(title: 'E')];

        final response = ExtendedChannelResponse(
          base: base,
          extendedConversation: extConv,
          responseType: ChannelResponseType.rich,
          blocks: blocks,
          attachments: attachments,
          embeds: embeds,
          targetMessageId: 'msg-1',
          ephemeral: true,
          ephemeralUserId: 'U123',
          reaction: 'star',
        );

        final json = response.toJson();

        expect(json['base'], isNotNull);
        expect(json['extendedConversation'], isNotNull);
        expect(json['responseType'], 'rich');
        expect(json['blocks'], hasLength(1));
        expect(json['attachments'], hasLength(1));
        expect(json['embeds'], hasLength(1));
        expect(json['targetMessageId'], 'msg-1');
        expect(json['ephemeral'], isTrue);
        expect(json['ephemeralUserId'], 'U123');
        expect(json['reaction'], 'star');
      });

      test('omits null optional fields', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final response = ExtendedChannelResponse(base: base);

        final json = response.toJson();

        expect(json['base'], isNotNull);
        expect(json['responseType'], 'text');
        expect(json['ephemeral'], isFalse);
        expect(json.containsKey('extendedConversation'), isFalse);
        expect(json.containsKey('blocks'), isFalse);
        expect(json.containsKey('attachments'), isFalse);
        expect(json.containsKey('embeds'), isFalse);
        expect(json.containsKey('targetMessageId'), isFalse);
        expect(json.containsKey('ephemeralUserId'), isFalse);
        expect(json.containsKey('reaction'), isFalse);
      });
    });

    group('_parseResponseType', () {
      test('parses all known types correctly via fromBase', () {
        for (final responseType in ChannelResponseType.values) {
          final base = ChannelResponse(
            conversation: conversation,
            type: responseType.name,
          );

          final response = ExtendedChannelResponse.fromBase(base);
          expect(response.responseType, responseType);
        }
      });

      test('parses unknown type string to text', () {
        final base = ChannelResponse(
          conversation: conversation,
          type: 'totally_custom',
        );

        final response = ExtendedChannelResponse.fromBase(base);
        expect(response.responseType, ChannelResponseType.text);
      });
    });

    group('equality', () {
      test('equal when same base and targetMessageId', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );

        final a = ExtendedChannelResponse(
          base: base,
          targetMessageId: 'msg-1',
        );
        final b = ExtendedChannelResponse(
          base: base,
          targetMessageId: 'msg-1',
          ephemeral: true,
        );

        expect(a == b, isTrue);
      });

      test('not equal when different base', () {
        final base1 = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final base2 = ChannelResponse.text(
          conversation: conversation,
          text: 'World',
        );

        final a = ExtendedChannelResponse(base: base1);
        final b = ExtendedChannelResponse(base: base2);

        // ChannelResponse does not override == so may differ by reference
        expect(a == b, isFalse);
      });

      test('not equal when different targetMessageId', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );

        final a = ExtendedChannelResponse(
          base: base,
          targetMessageId: 'msg-1',
        );
        final b = ExtendedChannelResponse(
          base: base,
          targetMessageId: 'msg-2',
        );

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final response = ExtendedChannelResponse(base: base);

        expect(response == response, isTrue);
      });

      test('not equal to different type object', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final response = ExtendedChannelResponse(base: base);

        expect(response == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );

        final a = ExtendedChannelResponse(
          base: base,
          targetMessageId: 'msg-1',
        );
        final b = ExtendedChannelResponse(
          base: base,
          targetMessageId: 'msg-1',
        );

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains responseType name and conversationId', () {
        final base = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final response = ExtendedChannelResponse(base: base);

        final str = response.toString();

        expect(str, contains('text'));
        expect(str, contains('C456'));
      });
    });
  });
}
