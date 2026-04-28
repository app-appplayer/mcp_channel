import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  ConversationKey makeKey({
    String platform = 'slack',
    String channelId = 'C123',
    String conversationId = 'conv-1',
  }) {
    return ConversationKey(
      channel: ChannelIdentity(platform: platform, channelId: channelId),
      conversationId: conversationId,
    );
  }

  group('ConversationInfo', () {
    group('constructor', () {
      test('creates with all fields', () {
        final key = makeKey();
        final createdAt = DateTime(2024, 1, 15, 10, 30);
        final info = ConversationInfo(
          key: key,
          name: 'general',
          topic: 'General discussion',
          isPrivate: true,
          isGroup: true,
          memberCount: 42,
          createdAt: createdAt,
          platformData: {'archived': false},
        );

        expect(info.key, equals(key));
        expect(info.name, equals('general'));
        expect(info.topic, equals('General discussion'));
        expect(info.isPrivate, isTrue);
        expect(info.isGroup, isTrue);
        expect(info.memberCount, equals(42));
        expect(info.createdAt, equals(createdAt));
        expect(info.platformData, equals({'archived': false}));
      });

      test('defaults isPrivate to false', () {
        final info = ConversationInfo(key: makeKey());
        expect(info.isPrivate, isFalse);
      });

      test('defaults isGroup to false', () {
        final info = ConversationInfo(key: makeKey());
        expect(info.isGroup, isFalse);
      });

      test('defaults optional fields to null', () {
        final info = ConversationInfo(key: makeKey());
        expect(info.name, isNull);
        expect(info.topic, isNull);
        expect(info.memberCount, isNull);
        expect(info.createdAt, isNull);
        expect(info.platformData, isNull);
      });
    });

    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'key': {
            'channel': {
              'platform': 'slack',
              'channelId': 'C123',
            },
            'conversationId': 'conv-1',
          },
          'name': 'general',
          'topic': 'General discussion',
          'isPrivate': true,
          'isGroup': true,
          'memberCount': 42,
          'createdAt': '2024-01-15T10:30:00.000',
          'platformData': {'archived': false},
        };

        final info = ConversationInfo.fromJson(json);
        expect(info.key.conversationId, equals('conv-1'));
        expect(info.key.channel.platform, equals('slack'));
        expect(info.key.channel.channelId, equals('C123'));
        expect(info.name, equals('general'));
        expect(info.topic, equals('General discussion'));
        expect(info.isPrivate, isTrue);
        expect(info.isGroup, isTrue);
        expect(info.memberCount, equals(42));
        expect(info.createdAt, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(info.platformData, equals({'archived': false}));
      });

      test('parses without optional fields', () {
        final json = {
          'key': {
            'channel': {
              'platform': 'telegram',
              'channelId': 'T456',
            },
            'conversationId': 'conv-2',
          },
        };

        final info = ConversationInfo.fromJson(json);
        expect(info.key.conversationId, equals('conv-2'));
        expect(info.name, isNull);
        expect(info.topic, isNull);
        expect(info.isPrivate, isFalse);
        expect(info.isGroup, isFalse);
        expect(info.memberCount, isNull);
        expect(info.createdAt, isNull);
        expect(info.platformData, isNull);
      });

      test('defaults isPrivate to false when null', () {
        final json = {
          'key': {
            'channel': {'platform': 'slack', 'channelId': 'C1'},
            'conversationId': 'c1',
          },
          'isPrivate': null,
        };

        final info = ConversationInfo.fromJson(json);
        expect(info.isPrivate, isFalse);
      });

      test('defaults isGroup to false when null', () {
        final json = {
          'key': {
            'channel': {'platform': 'slack', 'channelId': 'C1'},
            'conversationId': 'c1',
          },
          'isGroup': null,
        };

        final info = ConversationInfo.fromJson(json);
        expect(info.isGroup, isFalse);
      });

      test('parses createdAt via DateTime.parse', () {
        final json = {
          'key': {
            'channel': {'platform': 'slack', 'channelId': 'C1'},
            'conversationId': 'c1',
          },
          'createdAt': '2024-06-15T14:30:00.000Z',
        };

        final info = ConversationInfo.fromJson(json);
        expect(info.createdAt, isNotNull);
        expect(info.createdAt!.year, equals(2024));
        expect(info.createdAt!.month, equals(6));
        expect(info.createdAt!.day, equals(15));
      });

      test('parses without createdAt', () {
        final json = {
          'key': {
            'channel': {'platform': 'slack', 'channelId': 'C1'},
            'conversationId': 'c1',
          },
        };

        final info = ConversationInfo.fromJson(json);
        expect(info.createdAt, isNull);
      });
    });

    group('copyWith', () {
      test('copies with new key', () {
        final info = ConversationInfo(
          key: makeKey(conversationId: 'old'),
          name: 'old-name',
        );
        final newKey = makeKey(conversationId: 'new');
        final copied = info.copyWith(key: newKey);

        expect(copied.key, equals(newKey));
        expect(copied.name, equals('old-name'));
      });

      test('copies with new name', () {
        final info = ConversationInfo(key: makeKey(), name: 'old');
        final copied = info.copyWith(name: 'new-name');
        expect(copied.name, equals('new-name'));
        expect(copied.key, equals(info.key));
      });

      test('copies with new topic', () {
        final info = ConversationInfo(key: makeKey(), topic: 'old');
        final copied = info.copyWith(topic: 'new-topic');
        expect(copied.topic, equals('new-topic'));
      });

      test('copies with new isPrivate', () {
        final info = ConversationInfo(key: makeKey(), isPrivate: false);
        final copied = info.copyWith(isPrivate: true);
        expect(copied.isPrivate, isTrue);
      });

      test('copies with new isGroup', () {
        final info = ConversationInfo(key: makeKey(), isGroup: false);
        final copied = info.copyWith(isGroup: true);
        expect(copied.isGroup, isTrue);
      });

      test('copies with new memberCount', () {
        final info = ConversationInfo(key: makeKey(), memberCount: 5);
        final copied = info.copyWith(memberCount: 10);
        expect(copied.memberCount, equals(10));
      });

      test('copies with new createdAt', () {
        final info = ConversationInfo(
          key: makeKey(),
          createdAt: DateTime(2024, 1, 1),
        );
        final newDate = DateTime(2024, 6, 15);
        final copied = info.copyWith(createdAt: newDate);
        expect(copied.createdAt, equals(newDate));
      });

      test('copies with new platformData', () {
        final info = ConversationInfo(
          key: makeKey(),
          platformData: {'old': true},
        );
        final copied = info.copyWith(platformData: {'new': true});
        expect(copied.platformData, equals({'new': true}));
      });

      test('preserves all fields when no arguments given', () {
        final createdAt = DateTime(2024, 3, 20);
        final info = ConversationInfo(
          key: makeKey(),
          name: 'test',
          topic: 'topic',
          isPrivate: true,
          isGroup: true,
          memberCount: 5,
          createdAt: createdAt,
          platformData: {'key': 'val'},
        );

        final copied = info.copyWith();
        expect(copied.key, equals(info.key));
        expect(copied.name, equals('test'));
        expect(copied.topic, equals('topic'));
        expect(copied.isPrivate, isTrue);
        expect(copied.isGroup, isTrue);
        expect(copied.memberCount, equals(5));
        expect(copied.createdAt, equals(createdAt));
        expect(copied.platformData, equals({'key': 'val'}));
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final createdAt = DateTime(2024, 1, 15, 10, 30);
        final info = ConversationInfo(
          key: makeKey(),
          name: 'general',
          topic: 'General discussion',
          isPrivate: true,
          isGroup: true,
          memberCount: 42,
          createdAt: createdAt,
          platformData: {'archived': false},
        );

        final json = info.toJson();
        expect(json['key'], isA<Map<String, dynamic>>());
        expect(json['name'], equals('general'));
        expect(json['topic'], equals('General discussion'));
        expect(json['isPrivate'], isTrue);
        expect(json['isGroup'], isTrue);
        expect(json['memberCount'], equals(42));
        expect(json['createdAt'], equals(createdAt.toIso8601String()));
        expect(json['platformData'], equals({'archived': false}));
      });

      test('omits name when null', () {
        final info = ConversationInfo(key: makeKey());
        final json = info.toJson();
        expect(json.containsKey('name'), isFalse);
      });

      test('omits topic when null', () {
        final info = ConversationInfo(key: makeKey());
        final json = info.toJson();
        expect(json.containsKey('topic'), isFalse);
      });

      test('always includes isPrivate and isGroup', () {
        final info = ConversationInfo(key: makeKey());
        final json = info.toJson();
        expect(json['isPrivate'], isFalse);
        expect(json['isGroup'], isFalse);
      });

      test('omits memberCount when null', () {
        final info = ConversationInfo(key: makeKey());
        final json = info.toJson();
        expect(json.containsKey('memberCount'), isFalse);
      });

      test('omits createdAt when null', () {
        final info = ConversationInfo(key: makeKey());
        final json = info.toJson();
        expect(json.containsKey('createdAt'), isFalse);
      });

      test('omits platformData when null', () {
        final info = ConversationInfo(key: makeKey());
        final json = info.toJson();
        expect(json.containsKey('platformData'), isFalse);
      });
    });

    group('equality', () {
      test('same key makes equal', () {
        final key = makeKey(conversationId: 'same');
        final info1 = ConversationInfo(key: key, name: 'A');
        final info2 = ConversationInfo(key: key, name: 'B');

        expect(info1, equals(info2));
      });

      test('different key makes not equal', () {
        final info1 = ConversationInfo(
          key: makeKey(conversationId: 'one'),
        );
        final info2 = ConversationInfo(
          key: makeKey(conversationId: 'two'),
        );

        expect(info1, isNot(equals(info2)));
      });

      test('identical instances are equal', () {
        final info = ConversationInfo(key: makeKey());
        expect(info, equals(info));
      });

      test('different type is not equal', () {
        final info = ConversationInfo(key: makeKey());
        expect(info, isNot(equals('not a ConversationInfo')));
      });

      test('same key with different channel is not equal', () {
        final info1 = ConversationInfo(
          key: makeKey(platform: 'slack', conversationId: 'conv-1'),
        );
        final info2 = ConversationInfo(
          key: makeKey(platform: 'discord', conversationId: 'conv-1'),
        );

        expect(info1, isNot(equals(info2)));
      });
    });

    group('hashCode', () {
      test('same key produces same hashCode', () {
        final key = makeKey(conversationId: 'same');
        final info1 = ConversationInfo(key: key, name: 'A');
        final info2 = ConversationInfo(key: key, name: 'B');

        expect(info1.hashCode, equals(info2.hashCode));
      });

      test('different key may produce different hashCode', () {
        final info1 = ConversationInfo(
          key: makeKey(conversationId: 'one'),
        );
        final info2 = ConversationInfo(
          key: makeKey(conversationId: 'two'),
        );

        // Different keys should generally produce different hash codes
        // but hash collisions are theoretically possible
        expect(info1.hashCode, equals(info1.key.hashCode));
        expect(info2.hashCode, equals(info2.key.hashCode));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final info = ConversationInfo(
          key: makeKey(conversationId: 'conv-1'),
          name: 'general',
          isPrivate: true,
        );

        expect(
          info.toString(),
          equals(
              'ConversationInfo(key: conv-1, name: general, isPrivate: true)'),
        );
      });

      test('shows null name', () {
        final info = ConversationInfo(
          key: makeKey(conversationId: 'conv-2'),
        );

        expect(
          info.toString(),
          equals(
              'ConversationInfo(key: conv-2, name: null, isPrivate: false)'),
        );
      });
    });
  });
}
