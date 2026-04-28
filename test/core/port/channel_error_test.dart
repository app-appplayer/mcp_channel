import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ChannelErrorCode', () {
    test('rateLimited has correct value', () {
      expect(ChannelErrorCode.rateLimited, equals('rate_limited'));
    });

    test('notFound has correct value', () {
      expect(ChannelErrorCode.notFound, equals('not_found'));
    });

    test('permissionDenied has correct value', () {
      expect(ChannelErrorCode.permissionDenied, equals('permission_denied'));
    });

    test('invalidRequest has correct value', () {
      expect(ChannelErrorCode.invalidRequest, equals('invalid_request'));
    });

    test('messageTooLong has correct value', () {
      expect(ChannelErrorCode.messageTooLong, equals('message_too_long'));
    });

    test('fileTooLarge has correct value', () {
      expect(ChannelErrorCode.fileTooLarge, equals('file_too_large'));
    });

    test('networkError has correct value', () {
      expect(ChannelErrorCode.networkError, equals('network_error'));
    });

    test('timeout has correct value', () {
      expect(ChannelErrorCode.timeout, equals('timeout'));
    });

    test('serverError has correct value', () {
      expect(ChannelErrorCode.serverError, equals('server_error'));
    });

    test('unknown has correct value', () {
      expect(ChannelErrorCode.unknown, equals('unknown'));
    });
  });

  group('ChannelError', () {
    group('constructor', () {
      test('creates with all fields', () {
        final error = ChannelError(
          code: 'test_code',
          message: 'test message',
          retryable: true,
          retryAfter: const Duration(seconds: 5),
          platformData: {'key': 'value'},
        );

        expect(error.code, equals('test_code'));
        expect(error.message, equals('test message'));
        expect(error.retryable, isTrue);
        expect(error.retryAfter, equals(const Duration(seconds: 5)));
        expect(error.platformData, equals({'key': 'value'}));
      });

      test('defaults retryable to false', () {
        const error = ChannelError(
          code: 'test',
          message: 'test',
        );
        expect(error.retryable, isFalse);
      });

      test('defaults retryAfter to null', () {
        const error = ChannelError(
          code: 'test',
          message: 'test',
        );
        expect(error.retryAfter, isNull);
      });

      test('defaults platformData to null', () {
        const error = ChannelError(
          code: 'test',
          message: 'test',
        );
        expect(error.platformData, isNull);
      });

      test('implements Exception', () {
        const error = ChannelError(code: 'test', message: 'test');
        expect(error, isA<Exception>());
      });
    });

    group('rateLimited factory', () {
      test('creates with default message', () {
        final error = ChannelError.rateLimited();
        expect(error.code, equals(ChannelErrorCode.rateLimited));
        expect(error.message, equals('Rate limit exceeded'));
        expect(error.retryable, isTrue);
        expect(error.retryAfter, isNull);
        expect(error.platformData, isNull);
      });

      test('creates with custom message', () {
        final error = ChannelError.rateLimited(message: 'Custom rate limit');
        expect(error.message, equals('Custom rate limit'));
      });

      test('creates with retryAfter', () {
        final error = ChannelError.rateLimited(
          retryAfter: const Duration(seconds: 30),
        );
        expect(error.retryAfter, equals(const Duration(seconds: 30)));
      });

      test('creates with platformData', () {
        final error = ChannelError.rateLimited(
          platformData: {'limit': 100},
        );
        expect(error.platformData, equals({'limit': 100}));
      });
    });

    group('notFound factory', () {
      test('creates with default message', () {
        final error = ChannelError.notFound();
        expect(error.code, equals(ChannelErrorCode.notFound));
        expect(error.message, equals('Resource not found'));
        expect(error.retryable, isFalse);
        expect(error.platformData, isNull);
      });

      test('creates with custom message', () {
        final error = ChannelError.notFound(message: 'Channel not found');
        expect(error.message, equals('Channel not found'));
      });

      test('creates with platformData', () {
        final error = ChannelError.notFound(
          platformData: {'resource': 'channel'},
        );
        expect(error.platformData, equals({'resource': 'channel'}));
      });
    });

    group('permissionDenied factory', () {
      test('creates with default message', () {
        final error = ChannelError.permissionDenied();
        expect(error.code, equals(ChannelErrorCode.permissionDenied));
        expect(error.message, equals('Permission denied'));
        expect(error.retryable, isFalse);
        expect(error.platformData, isNull);
      });

      test('creates with custom message', () {
        final error =
            ChannelError.permissionDenied(message: 'Not authorized');
        expect(error.message, equals('Not authorized'));
      });

      test('creates with platformData', () {
        final error = ChannelError.permissionDenied(
          platformData: {'scope': 'read'},
        );
        expect(error.platformData, equals({'scope': 'read'}));
      });
    });

    group('invalidRequest factory', () {
      test('creates with default message', () {
        final error = ChannelError.invalidRequest();
        expect(error.code, equals(ChannelErrorCode.invalidRequest));
        expect(error.message, equals('Invalid request'));
        expect(error.retryable, isFalse);
        expect(error.platformData, isNull);
      });

      test('creates with custom message', () {
        final error =
            ChannelError.invalidRequest(message: 'Missing field');
        expect(error.message, equals('Missing field'));
      });

      test('creates with platformData', () {
        final error = ChannelError.invalidRequest(
          platformData: {'field': 'text'},
        );
        expect(error.platformData, equals({'field': 'text'}));
      });
    });

    group('networkError factory', () {
      test('creates with default message', () {
        final error = ChannelError.networkError();
        expect(error.code, equals(ChannelErrorCode.networkError));
        expect(error.message, equals('Network error'));
        expect(error.retryable, isTrue);
        expect(error.retryAfter, isNull);
        expect(error.platformData, isNull);
      });

      test('creates with custom message', () {
        final error =
            ChannelError.networkError(message: 'Connection refused');
        expect(error.message, equals('Connection refused'));
      });

      test('creates with retryAfter', () {
        final error = ChannelError.networkError(
          retryAfter: const Duration(seconds: 10),
        );
        expect(error.retryAfter, equals(const Duration(seconds: 10)));
      });

      test('creates with platformData', () {
        final error = ChannelError.networkError(
          platformData: {'host': 'api.slack.com'},
        );
        expect(error.platformData, equals({'host': 'api.slack.com'}));
      });
    });

    group('timeout factory', () {
      test('creates with default message', () {
        final error = ChannelError.timeout();
        expect(error.code, equals(ChannelErrorCode.timeout));
        expect(error.message, equals('Operation timed out'));
        expect(error.retryable, isTrue);
        expect(error.retryAfter, isNull);
        expect(error.platformData, isNull);
      });

      test('creates with custom message', () {
        final error =
            ChannelError.timeout(message: 'Request timed out after 30s');
        expect(error.message, equals('Request timed out after 30s'));
      });

      test('creates with retryAfter', () {
        final error = ChannelError.timeout(
          retryAfter: const Duration(seconds: 5),
        );
        expect(error.retryAfter, equals(const Duration(seconds: 5)));
      });

      test('creates with platformData', () {
        final error = ChannelError.timeout(
          platformData: {'operation': 'send'},
        );
        expect(error.platformData, equals({'operation': 'send'}));
      });
    });

    group('serverError factory', () {
      test('creates with default message', () {
        final error = ChannelError.serverError();
        expect(error.code, equals(ChannelErrorCode.serverError));
        expect(error.message, equals('Server error'));
        expect(error.retryable, isTrue);
        expect(error.retryAfter, isNull);
        expect(error.platformData, isNull);
      });

      test('creates with custom message', () {
        final error =
            ChannelError.serverError(message: 'Internal server error');
        expect(error.message, equals('Internal server error'));
      });

      test('creates with retryAfter', () {
        final error = ChannelError.serverError(
          retryAfter: const Duration(minutes: 1),
        );
        expect(error.retryAfter, equals(const Duration(minutes: 1)));
      });

      test('creates with platformData', () {
        final error = ChannelError.serverError(
          platformData: {'statusCode': 500},
        );
        expect(error.platformData, equals({'statusCode': 500}));
      });
    });

    group('unknown factory', () {
      test('creates with default message', () {
        final error = ChannelError.unknown();
        expect(error.code, equals(ChannelErrorCode.unknown));
        expect(error.message, equals('Unknown error'));
        expect(error.retryable, isFalse);
        expect(error.platformData, isNull);
      });

      test('creates with custom message', () {
        final error =
            ChannelError.unknown(message: 'Something unexpected');
        expect(error.message, equals('Something unexpected'));
      });

      test('creates with platformData', () {
        final error = ChannelError.unknown(
          platformData: {'raw': 'error data'},
        );
        expect(error.platformData, equals({'raw': 'error data'}));
      });
    });

    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'code': 'rate_limited',
          'message': 'Too many requests',
          'retryable': true,
          'retryAfterMs': 5000,
          'platformData': {'limit': 100},
        };

        final error = ChannelError.fromJson(json);
        expect(error.code, equals('rate_limited'));
        expect(error.message, equals('Too many requests'));
        expect(error.retryable, isTrue);
        expect(error.retryAfter, equals(const Duration(seconds: 5)));
        expect(error.platformData, equals({'limit': 100}));
      });

      test('parses without retryAfterMs', () {
        final json = {
          'code': 'not_found',
          'message': 'Not found',
          'retryable': false,
        };

        final error = ChannelError.fromJson(json);
        expect(error.retryAfter, isNull);
      });

      test('parses without platformData', () {
        final json = {
          'code': 'unknown',
          'message': 'Error',
        };

        final error = ChannelError.fromJson(json);
        expect(error.platformData, isNull);
      });

      test('defaults retryable to false when not present', () {
        final json = {
          'code': 'unknown',
          'message': 'Error',
        };

        final error = ChannelError.fromJson(json);
        expect(error.retryable, isFalse);
      });

      test('parses retryAfterMs as null when null', () {
        final json = {
          'code': 'test',
          'message': 'test',
          'retryAfterMs': null,
        };

        final error = ChannelError.fromJson(json);
        expect(error.retryAfter, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final error = ChannelError(
          code: 'rate_limited',
          message: 'Too many requests',
          retryable: true,
          retryAfter: const Duration(seconds: 5),
          platformData: {'limit': 100},
        );

        final json = error.toJson();
        expect(json['code'], equals('rate_limited'));
        expect(json['message'], equals('Too many requests'));
        expect(json['retryable'], isTrue);
        expect(json['retryAfterMs'], equals(5000));
        expect(json['platformData'], equals({'limit': 100}));
      });

      test('omits retryAfterMs when null', () {
        const error = ChannelError(
          code: 'test',
          message: 'test',
        );

        final json = error.toJson();
        expect(json.containsKey('retryAfterMs'), isFalse);
      });

      test('omits platformData when null', () {
        const error = ChannelError(
          code: 'test',
          message: 'test',
        );

        final json = error.toJson();
        expect(json.containsKey('platformData'), isFalse);
      });

      test('includes retryAfterMs when retryAfter is set', () {
        final error = ChannelError(
          code: 'test',
          message: 'test',
          retryAfter: const Duration(milliseconds: 1500),
        );

        final json = error.toJson();
        expect(json['retryAfterMs'], equals(1500));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        const error = ChannelError(
          code: 'rate_limited',
          message: 'Too many requests',
        );

        expect(
          error.toString(),
          equals(
              'ChannelError(code: rate_limited, message: Too many requests)'),
        );
      });
    });
  });

  group('ChannelException', () {
    test('constructor stores error', () {
      const error = ChannelError(
        code: 'test_code',
        message: 'test message',
      );
      const exception = ChannelException(error);

      expect(exception.error, equals(error));
      expect(exception.error.code, equals('test_code'));
      expect(exception.error.message, equals('test message'));
    });

    test('implements Exception', () {
      const error = ChannelError(code: 'test', message: 'test');
      const exception = ChannelException(error);
      expect(exception, isA<Exception>());
    });

    test('error getter returns underlying error', () {
      const error = ChannelError(
        code: 'network_error',
        message: 'Connection failed',
        retryable: true,
      );
      const exception = ChannelException(error);

      expect(exception.error.code, equals('network_error'));
      expect(exception.error.message, equals('Connection failed'));
      expect(exception.error.retryable, isTrue);
    });

    test('toString returns formatted string', () {
      const error = ChannelError(
        code: 'rate_limited',
        message: 'Too many requests',
      );
      const exception = ChannelException(error);

      expect(
        exception.toString(),
        equals('ChannelException: Too many requests (rate_limited)'),
      );
    });
  });
}
