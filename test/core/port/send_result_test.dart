import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('SendResult', () {
    group('constructor', () {
      test('creates with all fields', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30);
        final error = ChannelError.rateLimited();
        final result = SendResult(
          success: true,
          messageId: 'msg-123',
          error: error,
          timestamp: timestamp,
          platformData: {'ts': '1234567890.123456'},
        );

        expect(result.success, isTrue);
        expect(result.messageId, equals('msg-123'));
        expect(result.error, equals(error));
        expect(result.timestamp, equals(timestamp));
        expect(result.platformData, equals({'ts': '1234567890.123456'}));
      });

      test('creates with only required fields', () {
        const result = SendResult(success: false);

        expect(result.success, isFalse);
        expect(result.messageId, isNull);
        expect(result.error, isNull);
        expect(result.timestamp, isNull);
        expect(result.platformData, isNull);
      });
    });

    group('success factory', () {
      test('creates with messageId', () {
        final result = SendResult.success(messageId: 'msg-456');

        expect(result.success, isTrue);
        expect(result.messageId, equals('msg-456'));
        expect(result.error, isNull);
      });

      test('defaults timestamp to now', () {
        final before = DateTime.now();
        final result = SendResult.success(messageId: 'msg-789');
        final after = DateTime.now();

        expect(result.timestamp, isNotNull);
        expect(
          result.timestamp!.isAfter(before) ||
              result.timestamp!.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          result.timestamp!.isBefore(after) ||
              result.timestamp!.isAtSameMomentAs(after),
          isTrue,
        );
      });

      test('uses provided timestamp', () {
        final timestamp = DateTime(2024, 6, 15, 12, 0);
        final result = SendResult.success(
          messageId: 'msg-1',
          timestamp: timestamp,
        );

        expect(result.timestamp, equals(timestamp));
      });

      test('accepts platformData', () {
        final result = SendResult.success(
          messageId: 'msg-2',
          platformData: {'channel': 'C123', 'ok': true},
        );

        expect(result.platformData, equals({'channel': 'C123', 'ok': true}));
      });
    });

    group('failure factory', () {
      test('creates with error', () {
        final error = ChannelError.networkError(
          message: 'Connection lost',
        );
        final result = SendResult.failure(error: error);

        expect(result.success, isFalse);
        expect(result.error, equals(error));
        expect(result.error!.code, equals(ChannelErrorCode.networkError));
        expect(result.error!.message, equals('Connection lost'));
        expect(result.messageId, isNull);
        expect(result.timestamp, isNull);
      });

      test('accepts platformData', () {
        final error = ChannelError.serverError();
        final result = SendResult.failure(
          error: error,
          platformData: {'statusCode': 500},
        );

        expect(result.platformData, equals({'statusCode': 500}));
      });
    });

    group('fromJson', () {
      test('parses success result with all fields', () {
        final json = {
          'success': true,
          'messageId': 'msg-100',
          'timestamp': '2024-01-15T10:30:00.000',
          'platformData': {'ts': '12345'},
        };

        final result = SendResult.fromJson(json);
        expect(result.success, isTrue);
        expect(result.messageId, equals('msg-100'));
        expect(result.timestamp, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(result.platformData, equals({'ts': '12345'}));
        expect(result.error, isNull);
      });

      test('parses failure result with error', () {
        final json = {
          'success': false,
          'error': {
            'code': 'rate_limited',
            'message': 'Too many requests',
            'retryable': true,
            'retryAfterMs': 5000,
          },
        };

        final result = SendResult.fromJson(json);
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error!.code, equals('rate_limited'));
        expect(result.error!.message, equals('Too many requests'));
        expect(result.error!.retryable, isTrue);
        expect(result.error!.retryAfter, equals(const Duration(seconds: 5)));
      });

      test('parses without error', () {
        final json = {
          'success': true,
          'messageId': 'msg-200',
        };

        final result = SendResult.fromJson(json);
        expect(result.error, isNull);
      });

      test('parses without timestamp', () {
        final json = {
          'success': true,
          'messageId': 'msg-300',
        };

        final result = SendResult.fromJson(json);
        expect(result.timestamp, isNull);
      });

      test('parses timestamp via DateTime.parse', () {
        final json = {
          'success': true,
          'messageId': 'msg-400',
          'timestamp': '2024-06-15T14:30:00.000Z',
        };

        final result = SendResult.fromJson(json);
        expect(result.timestamp, isNotNull);
        expect(result.timestamp!.year, equals(2024));
        expect(result.timestamp!.month, equals(6));
        expect(result.timestamp!.day, equals(15));
      });

      test('parses without platformData', () {
        final json = {
          'success': false,
        };

        final result = SendResult.fromJson(json);
        expect(result.platformData, isNull);
      });

      test('parses with platformData', () {
        final json = {
          'success': true,
          'platformData': {'extra': 'data'},
        };

        final result = SendResult.fromJson(json);
        expect(result.platformData, equals({'extra': 'data'}));
      });

      test('parses without messageId', () {
        final json = {
          'success': false,
        };

        final result = SendResult.fromJson(json);
        expect(result.messageId, isNull);
      });
    });

    group('toJson', () {
      test('serializes success result with all fields', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30);
        final result = SendResult(
          success: true,
          messageId: 'msg-500',
          timestamp: timestamp,
          platformData: {'ok': true},
        );

        final json = result.toJson();
        expect(json['success'], isTrue);
        expect(json['messageId'], equals('msg-500'));
        expect(json['timestamp'], equals(timestamp.toIso8601String()));
        expect(json['platformData'], equals({'ok': true}));
      });

      test('serializes failure result with error', () {
        final error = ChannelError.timeout(message: 'Timed out');
        final result = SendResult.failure(error: error);

        final json = result.toJson();
        expect(json['success'], isFalse);
        expect(json['error'], isA<Map<String, dynamic>>());
        expect(json['error']['code'], equals('timeout'));
        expect(json['error']['message'], equals('Timed out'));
      });

      test('omits messageId when null', () {
        const result = SendResult(success: false);

        final json = result.toJson();
        expect(json.containsKey('messageId'), isFalse);
      });

      test('omits error when null', () {
        final result = SendResult.success(messageId: 'msg-600');

        final json = result.toJson();
        expect(json.containsKey('error'), isFalse);
      });

      test('omits timestamp when null', () {
        const result = SendResult(success: false);

        final json = result.toJson();
        expect(json.containsKey('timestamp'), isFalse);
      });

      test('omits platformData when null', () {
        const result = SendResult(success: true, messageId: 'msg-700');

        final json = result.toJson();
        expect(json.containsKey('platformData'), isFalse);
      });
    });

    group('toString', () {
      test('returns success format', () {
        final result = SendResult.success(messageId: 'msg-800');

        expect(
          result.toString(),
          equals('SendResult.success(messageId: msg-800)'),
        );
      });

      test('returns failure format', () {
        final error = ChannelError.rateLimited();
        final result = SendResult.failure(error: error);

        expect(
          result.toString(),
          equals('SendResult.failure(error: rate_limited)'),
        );
      });

      test('returns failure format with null error', () {
        const result = SendResult(success: false);

        expect(
          result.toString(),
          equals('SendResult.failure(error: null)'),
        );
      });
    });
  });
}
