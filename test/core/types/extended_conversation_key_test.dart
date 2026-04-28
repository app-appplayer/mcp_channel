import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  const channelIdentity = ChannelIdentity(
    platform: 'slack',
    channelId: 'C123',
  );

  final baseConversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'conv-1',
    userId: 'U123',
  );

  group('ExtendedConversationKey', () {
    group('constructor', () {
      test('creates with required base only', () {
        final key = ExtendedConversationKey(base: baseConversation);

        expect(key.base, baseConversation);
        expect(key.tenantId, isNull);
        expect(key.threadId, isNull);
      });

      test('creates with all fields', () {
        final key = ExtendedConversationKey(
          base: baseConversation,
          tenantId: 'T001',
          threadId: 'thread-1',
        );

        expect(key.base, baseConversation);
        expect(key.tenantId, 'T001');
        expect(key.threadId, 'thread-1');
      });
    });

    group('create factory', () {
      test('creates with all components', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
          userId: 'U123',
        );

        expect(key.platform, 'slack');
        expect(key.channelId, 'C123');
        expect(key.conversationId, 'conv-1');
        expect(key.tenantId, 'T001');
        expect(key.threadId, 'thread-1');
        expect(key.userId, 'U123');
      });

      test('creates with required components only', () {
        final key = ExtendedConversationKey.create(
          platform: 'telegram',
          channelId: 'T456',
          conversationId: 'chat-1',
        );

        expect(key.platform, 'telegram');
        expect(key.channelId, 'T456');
        expect(key.conversationId, 'chat-1');
        expect(key.tenantId, isNull);
        expect(key.threadId, isNull);
        expect(key.userId, isNull);
      });
    });

    group('fromBase factory', () {
      test('creates from base ConversationKey', () {
        final key = ExtendedConversationKey.fromBase(baseConversation);

        expect(key.base, baseConversation);
        expect(key.tenantId, isNull);
        expect(key.threadId, isNull);
      });

      test('creates from base with tenantId and threadId', () {
        final key = ExtendedConversationKey.fromBase(
          baseConversation,
          tenantId: 'T002',
          threadId: 'thread-2',
        );

        expect(key.base, baseConversation);
        expect(key.tenantId, 'T002');
        expect(key.threadId, 'thread-2');
      });
    });

    group('fromJson', () {
      test('deserializes with all fields', () {
        final json = {
          'base': {
            'channel': {'platform': 'slack', 'channelId': 'C123'},
            'conversationId': 'conv-1',
            'userId': 'U123',
          },
          'tenantId': 'T001',
          'threadId': 'thread-1',
        };

        final key = ExtendedConversationKey.fromJson(json);

        expect(key.platform, 'slack');
        expect(key.channelId, 'C123');
        expect(key.conversationId, 'conv-1');
        expect(key.userId, 'U123');
        expect(key.tenantId, 'T001');
        expect(key.threadId, 'thread-1');
      });

      test('deserializes without optional fields', () {
        final json = {
          'base': {
            'channel': {'platform': 'telegram', 'channelId': 'T456'},
            'conversationId': 'chat-1',
          },
        };

        final key = ExtendedConversationKey.fromJson(json);

        expect(key.platform, 'telegram');
        expect(key.tenantId, isNull);
        expect(key.threadId, isNull);
      });
    });

    group('getters', () {
      test('platform returns base channel platform', () {
        final key = ExtendedConversationKey(base: baseConversation);
        expect(key.platform, 'slack');
      });

      test('channelId returns base channel channelId', () {
        final key = ExtendedConversationKey(base: baseConversation);
        expect(key.channelId, 'C123');
      });

      test('conversationId returns base conversationId', () {
        final key = ExtendedConversationKey(base: baseConversation);
        expect(key.conversationId, 'conv-1');
      });

      test('userId returns base userId', () {
        final key = ExtendedConversationKey(base: baseConversation);
        expect(key.userId, 'U123');
      });
    });

    group('key getter', () {
      test('without tenantId uses channelId', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );

        expect(key.key, 'slack:C123:conv-1');
      });

      test('with tenantId uses tenantId instead of channelId', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
        );

        expect(key.key, 'slack:T001:conv-1');
      });

      test('with threadId appends threadId', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          threadId: 'thread-1',
        );

        expect(key.key, 'slack:C123:conv-1:thread-1');
      });

      test('with tenantId and threadId', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
        );

        expect(key.key, 'slack:T001:conv-1:thread-1');
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final original = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
        );

        final newBase = ConversationKey(
          channel: const ChannelIdentity(
            platform: 'discord',
            channelId: 'D456',
          ),
          conversationId: 'dc-1',
        );

        final copy = original.copyWith(
          base: newBase,
          tenantId: 'T002',
          threadId: 'thread-2',
        );

        expect(copy.platform, 'discord');
        expect(copy.channelId, 'D456');
        expect(copy.conversationId, 'dc-1');
        expect(copy.tenantId, 'T002');
        expect(copy.threadId, 'thread-2');
      });

      test('copies with no fields changed preserves values', () {
        final original = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
        );

        final copy = original.copyWith();

        expect(copy.platform, original.platform);
        expect(copy.channelId, original.channelId);
        expect(copy.conversationId, original.conversationId);
        expect(copy.tenantId, original.tenantId);
        expect(copy.threadId, original.threadId);
      });
    });

    group('withThread', () {
      test('adds threadId to key', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );

        final threaded = key.withThread('thread-99');

        expect(threaded.threadId, 'thread-99');
        expect(threaded.platform, 'slack');
        expect(threaded.channelId, 'C123');
        expect(threaded.conversationId, 'conv-1');
      });

      test('replaces existing threadId', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          threadId: 'old-thread',
        );

        final threaded = key.withThread('new-thread');

        expect(threaded.threadId, 'new-thread');
      });
    });

    group('withoutThread', () {
      test('removes threadId', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          threadId: 'thread-1',
        );

        final parent = key.withoutThread();

        expect(parent.threadId, isNull);
        expect(parent.platform, 'slack');
        expect(parent.channelId, 'C123');
        expect(parent.conversationId, 'conv-1');
      });

      test('keeps tenantId but removes threadId', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
        );

        final parent = key.withoutThread();

        expect(parent.tenantId, 'T001');
        expect(parent.threadId, isNull);
      });

      test('no-op when threadId is already null', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
        );

        final parent = key.withoutThread();

        expect(parent.tenantId, 'T001');
        expect(parent.threadId, isNull);
      });
    });

    group('toBase', () {
      test('returns the wrapped base ConversationKey', () {
        final key = ExtendedConversationKey(base: baseConversation);

        expect(key.toBase(), baseConversation);
      });
    });

    group('toJson', () {
      test('serializes with all optional fields', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
          userId: 'U123',
        );

        final json = key.toJson();

        expect(json['base'], isNotNull);
        expect(json['tenantId'], 'T001');
        expect(json['threadId'], 'thread-1');
      });

      test('omits null optional fields', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
        );

        final json = key.toJson();

        expect(json['base'], isNotNull);
        expect(json.containsKey('tenantId'), isFalse);
        expect(json.containsKey('threadId'), isFalse);
      });
    });

    group('equality', () {
      test('equal when same base, tenantId, and threadId', () {
        final a = ExtendedConversationKey(
          base: baseConversation,
          tenantId: 'T001',
          threadId: 'thread-1',
        );
        final b = ExtendedConversationKey(
          base: baseConversation,
          tenantId: 'T001',
          threadId: 'thread-1',
        );

        expect(a == b, isTrue);
      });

      test('not equal when different base', () {
        final otherBase = ConversationKey(
          channel: const ChannelIdentity(
            platform: 'discord',
            channelId: 'D456',
          ),
          conversationId: 'dc-1',
        );

        final a = ExtendedConversationKey(base: baseConversation);
        final b = ExtendedConversationKey(base: otherBase);

        expect(a == b, isFalse);
      });

      test('not equal when different tenantId', () {
        final a = ExtendedConversationKey(
          base: baseConversation,
          tenantId: 'T001',
        );
        final b = ExtendedConversationKey(
          base: baseConversation,
          tenantId: 'T002',
        );

        expect(a == b, isFalse);
      });

      test('not equal when different threadId', () {
        final a = ExtendedConversationKey(
          base: baseConversation,
          threadId: 'thread-1',
        );
        final b = ExtendedConversationKey(
          base: baseConversation,
          threadId: 'thread-2',
        );

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        final a = ExtendedConversationKey(base: baseConversation);
        expect(a == a, isTrue);
      });

      test('not equal to different type object', () {
        final a = ExtendedConversationKey(base: baseConversation);
        expect(a == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        final a = ExtendedConversationKey(
          base: baseConversation,
          tenantId: 'T001',
          threadId: 'thread-1',
        );
        final b = ExtendedConversationKey(
          base: baseConversation,
          tenantId: 'T001',
          threadId: 'thread-1',
        );

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains the key string', () {
        final key = ExtendedConversationKey.create(
          platform: 'slack',
          channelId: 'C123',
          conversationId: 'conv-1',
          tenantId: 'T001',
          threadId: 'thread-1',
        );

        final str = key.toString();

        expect(str, contains('slack:T001:conv-1:thread-1'));
      });

      test('contains key string without tenant and thread', () {
        final key = ExtendedConversationKey.create(
          platform: 'telegram',
          channelId: 'T456',
          conversationId: 'chat-1',
        );

        final str = key.toString();

        expect(str, contains('telegram:T456:chat-1'));
      });
    });
  });
}
