import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // =========================================================================
  // ChannelLogEntry
  // =========================================================================
  group('ChannelLogEntry', () {
    test('stores all required fields', () {
      final timestamp = DateTime.utc(2025, 6, 15, 10, 30, 0);
      final entry = ChannelLogEntry(
        level: 'info',
        message: 'test message',
        timestamp: timestamp,
      );

      expect(entry.level, 'info');
      expect(entry.message, 'test message');
      expect(entry.timestamp, timestamp);
      expect(entry.component, isNull);
      expect(entry.correlationId, isNull);
      expect(entry.data, isNull);
      expect(entry.error, isNull);
      expect(entry.stackTrace, isNull);
    });

    test('stores error and stackTrace', () {
      final timestamp = DateTime.utc(2025, 6, 15, 10, 30, 0);
      final testError = StateError('something failed');
      final testStack = StackTrace.current;

      final entry = ChannelLogEntry(
        level: 'error',
        message: 'error occurred',
        timestamp: timestamp,
        error: testError,
        stackTrace: testStack,
      );

      expect(entry.error, testError);
      expect(entry.stackTrace, testStack);
    });

    test('stores component and correlationId', () {
      final timestamp = DateTime.utc(2025, 6, 15, 10, 30, 0);
      final entry = ChannelLogEntry(
        level: 'debug',
        message: 'with metadata',
        timestamp: timestamp,
        component: 'session-manager',
        correlationId: 'corr-123',
      );

      expect(entry.component, 'session-manager');
      expect(entry.correlationId, 'corr-123');
    });

    test('stores data map', () {
      final timestamp = DateTime.utc(2025, 6, 15, 10, 30, 0);
      final entry = ChannelLogEntry(
        level: 'debug',
        message: 'with data',
        timestamp: timestamp,
        data: {'key': 'value', 'count': 42},
      );

      expect(entry.data, {'key': 'value', 'count': 42});
    });

    test('toString returns formatted string with level and timestamp', () {
      final timestamp = DateTime.utc(2025, 6, 15, 10, 30, 0);
      final entry = ChannelLogEntry(
        level: 'warn',
        message: 'disk space low',
        timestamp: timestamp,
      );

      expect(
        entry.toString(),
        'WARN [$timestamp]: disk space low',
      );
    });

    test('toString uses uppercase level name', () {
      final timestamp = DateTime.utc(2025, 1, 1);
      final entry = ChannelLogEntry(
        level: 'debug',
        message: 'trace',
        timestamp: timestamp,
      );

      expect(entry.toString(), startsWith('DEBUG'));
    });
  });

  // =========================================================================
  // InMemoryChannelLogger
  // =========================================================================
  group('InMemoryChannelLogger', () {
    late InMemoryChannelLogger logger;

    setUp(() {
      logger = InMemoryChannelLogger();
    });

    // -----------------------------------------------------------------------
    // debug / info / warn / error methods
    // -----------------------------------------------------------------------
    group('logging methods', () {
      test('debug() logs at debug level', () {
        logger.debug('debug message');

        expect(logger.entries, hasLength(1));
        expect(logger.entries.first.level, 'debug');
        expect(logger.entries.first.message, 'debug message');
      });

      test('info() logs at info level', () {
        logger.info('info message');

        expect(logger.entries, hasLength(1));
        expect(logger.entries.first.level, 'info');
        expect(logger.entries.first.message, 'info message');
      });

      test('warn() logs at warn level', () {
        logger.warn('warning message');

        expect(logger.entries, hasLength(1));
        expect(logger.entries.first.level, 'warn');
        expect(logger.entries.first.message, 'warning message');
      });

      test('error() logs at error level', () {
        logger.error('error message');

        expect(logger.entries, hasLength(1));
        expect(logger.entries.first.level, 'error');
        expect(logger.entries.first.message, 'error message');
      });

      test('error() passes error and stackTrace through', () {
        const testError = FormatException('bad format');
        final testStack = StackTrace.current;

        logger.error(
          'error with details',
          error: testError,
          stackTrace: testStack,
        );

        expect(logger.entries.first.error, testError);
        expect(logger.entries.first.stackTrace, testStack);
      });

      test('records timestamp on each entry', () {
        final before = DateTime.now();
        logger.debug('timed');
        final after = DateTime.now();

        final ts = logger.entries.first.timestamp;
        expect(
          ts.isAfter(before) || ts.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          ts.isBefore(after) || ts.isAtSameMomentAs(after),
          isTrue,
        );
      });

      test('records multiple entries in order', () {
        logger.debug('first');
        logger.info('second');
        logger.error('third');

        expect(logger.entries, hasLength(3));
        expect(logger.entries[0].message, 'first');
        expect(logger.entries[1].message, 'second');
        expect(logger.entries[2].message, 'third');
      });
    });

    // -----------------------------------------------------------------------
    // Named parameters: component, correlationId, data
    // -----------------------------------------------------------------------
    group('named parameters', () {
      test('debug passes component and correlationId', () {
        logger.debug(
          'test',
          component: 'router',
          correlationId: 'req-001',
        );

        expect(logger.entries.first.component, 'router');
        expect(logger.entries.first.correlationId, 'req-001');
      });

      test('info passes data through', () {
        logger.info('test', data: {'key': 'value'});

        expect(logger.entries.first.data, {'key': 'value'});
      });

      test('warn passes all named parameters', () {
        logger.warn(
          'test',
          component: 'policy',
          correlationId: 'req-002',
          data: {'retries': 3},
        );

        final entry = logger.entries.first;
        expect(entry.component, 'policy');
        expect(entry.correlationId, 'req-002');
        expect(entry.data, {'retries': 3});
      });

      test('error passes component, correlationId, and data', () {
        logger.error(
          'failed',
          component: 'connector',
          correlationId: 'req-003',
          data: {'platform': 'slack'},
        );

        final entry = logger.entries.first;
        expect(entry.component, 'connector');
        expect(entry.correlationId, 'req-003');
        expect(entry.data, {'platform': 'slack'});
      });
    });

    // -----------------------------------------------------------------------
    // clear
    // -----------------------------------------------------------------------
    group('clear', () {
      test('removes all entries', () {
        logger.info('message 1');
        logger.warn('message 2');
        logger.error('message 3');

        expect(logger.entries, hasLength(3));

        logger.clear();

        expect(logger.entries, isEmpty);
      });

      test('allows new entries after clear', () {
        logger.info('before clear');
        logger.clear();
        logger.debug('after clear');

        expect(logger.entries, hasLength(1));
        expect(logger.entries.first.message, 'after clear');
      });
    });

    // -----------------------------------------------------------------------
    // entries getter returns unmodifiable list
    // -----------------------------------------------------------------------
    group('entries getter', () {
      test('returns entries as unmodifiable list', () {
        logger.info('test');

        expect(
          () => logger.entries.add(ChannelLogEntry(
            level: 'info',
            message: 'injected',
            timestamp: DateTime.now(),
          )),
          throwsUnsupportedError,
        );
      });
    });

    // -----------------------------------------------------------------------
    // Interface conformance
    // -----------------------------------------------------------------------
    group('interface conformance', () {
      test('implements ChannelLogger', () {
        expect(logger, isA<ChannelLogger>());
      });
    });
  });

  // =========================================================================
  // ChannelLogRedactor
  // =========================================================================
  group('ChannelLogRedactor', () {
    late ChannelLogRedactor redactor;

    setUp(() {
      redactor = const ChannelLogRedactor();
    });

    // -----------------------------------------------------------------------
    // Default redacted fields
    // -----------------------------------------------------------------------
    group('default redacted fields', () {
      test('redacts text', () {
        final result = redactor.redact({'text': 'hello world'});
        expect(result['text'], '[REDACTED]');
      });

      test('redacts content', () {
        final result = redactor.redact({'content': 'secret stuff'});
        expect(result['content'], '[REDACTED]');
      });

      test('redacts token', () {
        final result = redactor.redact({'token': 'abc123'});
        expect(result['token'], '[REDACTED]');
      });

      test('redacts apiKey', () {
        final result = redactor.redact({'apiKey': 'key-abc'});
        expect(result['apiKey'], '[REDACTED]');
      });

      test('redacts password', () {
        final result = redactor.redact({'password': 'secret123'});
        expect(result['password'], '[REDACTED]');
      });
    });

    // -----------------------------------------------------------------------
    // Preserves non-sensitive keys
    // -----------------------------------------------------------------------
    group('preserves non-sensitive keys', () {
      test('keeps non-sensitive values unchanged', () {
        final result = redactor.redact({
          'channel': 'slack',
          'userId': 'U123',
          'platform': 'telegram',
        });

        expect(result['channel'], 'slack');
        expect(result['userId'], 'U123');
        expect(result['platform'], 'telegram');
      });

      test('preserves original map keys', () {
        final input = {
          'token': 'secret',
          'channel': 'slack',
          'userId': 'U123',
        };
        final result = redactor.redact(input);

        expect(result.keys, containsAll(['token', 'channel', 'userId']));
        expect(result['token'], '[REDACTED]');
        expect(result['channel'], 'slack');
        expect(result['userId'], 'U123');
      });
    });

    // -----------------------------------------------------------------------
    // Dot-notation path redaction
    // -----------------------------------------------------------------------
    group('dot-notation path redaction', () {
      test('redacts metadata.email via dot-notation path', () {
        final result = redactor.redact({
          'metadata': <String, dynamic>{
            'email': 'user@example.com',
            'role': 'admin',
          },
        });

        final metadata = result['metadata'] as Map<String, dynamic>;
        expect(metadata['email'], '[REDACTED]');
        expect(metadata['role'], 'admin');
      });

      test('redacts metadata.phone via dot-notation path', () {
        final result = redactor.redact({
          'metadata': <String, dynamic>{
            'phone': '+1-555-1234',
            'department': 'engineering',
          },
        });

        final metadata = result['metadata'] as Map<String, dynamic>;
        expect(metadata['phone'], '[REDACTED]');
        expect(metadata['department'], 'engineering');
      });
    });

    // -----------------------------------------------------------------------
    // Recursive nested map redaction
    // -----------------------------------------------------------------------
    group('recursive nested map redaction', () {
      test('redacts sensitive keys in nested maps', () {
        final result = redactor.redact({
          'config': <String, dynamic>{
            'token': 'nested-secret',
            'host': 'api.example.com',
          },
        });

        final nested = result['config'] as Map<String, dynamic>;
        expect(nested['token'], '[REDACTED]');
        expect(nested['host'], 'api.example.com');
      });

      test('redacts deeply nested maps', () {
        final result = redactor.redact({
          'level1': <String, dynamic>{
            'level2': <String, dynamic>{
              'password': 'deep-secret',
              'name': 'test',
            },
          },
        });

        final level1 = result['level1'] as Map<String, dynamic>;
        final level2 = level1['level2'] as Map<String, dynamic>;
        expect(level2['password'], '[REDACTED]');
        expect(level2['name'], 'test');
      });

      test('handles mix of sensitive and non-sensitive at multiple levels', () {
        final result = redactor.redact({
          'token': 'top-secret',
          'data': <String, dynamic>{
            'apiKey': 'nested-key',
            'value': 42,
          },
          'info': 'safe',
        });

        expect(result['token'], '[REDACTED]');
        expect(result['info'], 'safe');
        final data = result['data'] as Map<String, dynamic>;
        expect(data['apiKey'], '[REDACTED]');
        expect(data['value'], 42);
      });
    });

    // -----------------------------------------------------------------------
    // Custom redacted fields
    // -----------------------------------------------------------------------
    group('custom redacted fields', () {
      test('redacts custom fields', () {
        const customRedactor = ChannelLogRedactor(
          redactedFields: {'ssn', 'credit_card'},
        );

        final result = customRedactor.redact({
          'ssn': '123-45-6789',
          'credit_card': '4111-1111-1111-1111',
          'name': 'John Doe',
        });

        expect(result['ssn'], '[REDACTED]');
        expect(result['credit_card'], '[REDACTED]');
        expect(result['name'], 'John Doe');
      });

      test('does not redact default keys when custom fields are provided', () {
        const customRedactor = ChannelLogRedactor(
          redactedFields: {'custom_field'},
        );

        final result = customRedactor.redact({
          'token': 'should-not-be-redacted',
          'custom_field': 'should-be-redacted',
        });

        expect(result['token'], 'should-not-be-redacted');
        expect(result['custom_field'], '[REDACTED]');
      });
    });

    // -----------------------------------------------------------------------
    // Custom replacement string
    // -----------------------------------------------------------------------
    group('custom replacement', () {
      test('uses custom replacement string', () {
        const customRedactor = ChannelLogRedactor(
          replacement: '[HIDDEN]',
        );

        final result = customRedactor.redact({'token': 'abc'});
        expect(result['token'], '[HIDDEN]');
      });
    });

    // -----------------------------------------------------------------------
    // Default replacement string
    // -----------------------------------------------------------------------
    group('default replacement', () {
      test('uses [REDACTED] as default replacement', () {
        final result = redactor.redact({'password': 'secret'});
        expect(result['password'], '[REDACTED]');
      });
    });
  });

  // =========================================================================
  // InMemoryChannelLogger with redactor
  // =========================================================================
  group('InMemoryChannelLogger with redactor', () {
    test('applies redaction to data when redactor is present', () {
      final logger = InMemoryChannelLogger(
        redactor: const ChannelLogRedactor(),
      );

      logger.info(
        'auth event',
        data: {'token': 'secret-token', 'channel': 'slack'},
      );

      final entry = logger.entries.first;
      expect(entry.data!['token'], '[REDACTED]');
      expect(entry.data!['channel'], 'slack');
    });

    test('applies redaction to nested data', () {
      final logger = InMemoryChannelLogger(
        redactor: const ChannelLogRedactor(),
      );

      logger.warn(
        'config loaded',
        data: {
          'settings': <String, dynamic>{
            'password': 'db-pass',
            'host': 'localhost',
          },
        },
      );

      final entry = logger.entries.first;
      final settings = entry.data!['settings'] as Map<String, dynamic>;
      expect(settings['password'], '[REDACTED]');
      expect(settings['host'], 'localhost');
    });

    test('does not apply redaction when data is null', () {
      final logger = InMemoryChannelLogger(
        redactor: const ChannelLogRedactor(),
      );

      logger.info('no data');

      expect(logger.entries.first.data, isNull);
    });

    test('passes data as-is when no redactor is set', () {
      final logger = InMemoryChannelLogger();

      logger.info(
        'unredacted',
        data: {'token': 'visible-token', 'channel': 'slack'},
      );

      final entry = logger.entries.first;
      expect(entry.data!['token'], 'visible-token');
      expect(entry.data!['channel'], 'slack');
    });

    test('redaction works with all logging methods', () {
      final logger = InMemoryChannelLogger(
        redactor: const ChannelLogRedactor(),
      );

      logger.info('via info', data: {'password': 'pw123', 'user': 'admin'});
      logger.debug(
        'via debug',
        data: {'apiKey': 'key-abc', 'action': 'read'},
      );

      expect(logger.entries[0].data!['password'], '[REDACTED]');
      expect(logger.entries[0].data!['user'], 'admin');
      expect(logger.entries[1].data!['apiKey'], '[REDACTED]');
      expect(logger.entries[1].data!['action'], 'read');
    });
  });
}
