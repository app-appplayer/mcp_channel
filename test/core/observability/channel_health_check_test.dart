import 'dart:async';

import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // =========================================================================
  // HealthState enum
  // =========================================================================
  group('HealthState', () {
    test('has healthy value', () {
      expect(HealthState.healthy, isNotNull);
      expect(HealthState.healthy.name, equals('healthy'));
    });

    test('has degraded value', () {
      expect(HealthState.degraded, isNotNull);
      expect(HealthState.degraded.name, equals('degraded'));
    });

    test('has unhealthy value', () {
      expect(HealthState.unhealthy, isNotNull);
      expect(HealthState.unhealthy.name, equals('unhealthy'));
    });

    test('contains exactly three values', () {
      expect(HealthState.values, hasLength(3));
    });

    test('ordering: healthy < degraded < unhealthy by index', () {
      expect(HealthState.healthy.index, lessThan(HealthState.degraded.index));
      expect(HealthState.degraded.index, lessThan(HealthState.unhealthy.index));
    });
  });

  // =========================================================================
  // HealthStatus
  // =========================================================================
  group('HealthStatus', () {
    group('construction', () {
      test('creates with required fields only', () {
        final status = HealthStatus(state: HealthState.healthy);

        expect(status.state, equals(HealthState.healthy));
        expect(status.checkedAt, isNotNull);
        expect(status.description, isNull);
        expect(status.details, isNull);
      });

      test('creates with all fields', () {
        final now = DateTime(2026, 1, 15, 10, 30);
        final status = HealthStatus(
          state: HealthState.degraded,
          checkedAt: now,
          description: 'High latency detected',
          details: const {'latencyMs': 500, 'connections': 42},
        );

        expect(status.state, equals(HealthState.degraded));
        expect(status.checkedAt, equals(now));
        expect(status.description, equals('High latency detected'));
        expect(
          status.details,
          equals({'latencyMs': 500, 'connections': 42}),
        );
      });

      test('creates with description but no details', () {
        final status = HealthStatus(
          state: HealthState.unhealthy,
          description: 'Connection refused',
        );

        expect(status.state, equals(HealthState.unhealthy));
        expect(status.description, equals('Connection refused'));
        expect(status.details, isNull);
      });

      test('creates with details but no description', () {
        final status = HealthStatus(
          state: HealthState.healthy,
          details: const {'uptime': 3600},
        );

        expect(status.description, isNull);
        expect(status.details, equals({'uptime': 3600}));
      });

      test('defaults checkedAt to approximately now', () {
        final before = DateTime.now();
        final status = HealthStatus(state: HealthState.healthy);
        final after = DateTime.now();

        expect(
          status.checkedAt.isAfter(before) ||
              status.checkedAt.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          status.checkedAt.isBefore(after) ||
              status.checkedAt.isAtSameMomentAs(after),
          isTrue,
        );
      });
    });

    group('details map', () {
      test('stores various value types in details', () {
        final status = HealthStatus(
          state: HealthState.healthy,
          details: const {
            'latencyMs': 12,
            'healthy': true,
            'endpoint': 'https://api.example.com',
            'errorCount': 0,
          },
        );

        expect(status.details!['latencyMs'], equals(12));
        expect(status.details!['healthy'], isTrue);
        expect(
          status.details!['endpoint'],
          equals('https://api.example.com'),
        );
        expect(status.details!['errorCount'], equals(0));
      });

      test('stores empty details map', () {
        final status = HealthStatus(
          state: HealthState.healthy,
          details: const {},
        );

        expect(status.details, isNotNull);
        expect(status.details, isEmpty);
      });
    });

    group('toString', () {
      test('returns formatted string with description', () {
        final status = HealthStatus(
          state: HealthState.healthy,
          description: 'All systems operational',
        );

        expect(
          status.toString(),
          equals(
            'HealthStatus(state: healthy, description: All systems operational)',
          ),
        );
      });

      test('returns formatted string without description', () {
        final status = HealthStatus(
          state: HealthState.unhealthy,
        );

        expect(
          status.toString(),
          equals('HealthStatus(state: unhealthy, description: null)'),
        );
      });

      test('returns formatted string for degraded state', () {
        final status = HealthStatus(
          state: HealthState.degraded,
          description: 'Slow response',
        );

        expect(
          status.toString(),
          equals(
            'HealthStatus(state: degraded, description: Slow response)',
          ),
        );
      });
    });
  });

  // =========================================================================
  // ConnectorHealthCheck
  // =========================================================================
  group('ConnectorHealthCheck', () {
    test('exposes name based on port platform', () {
      final port = _TestChannelPort(platform: 'slack');
      final check = ConnectorHealthCheck(port);

      expect(check.name, equals('connector:slack'));
    });

    test('checkHealth returns healthy for valid port', () async {
      final port = _TestChannelPort(platform: 'telegram');
      final check = ConnectorHealthCheck(port);

      final result = await check.checkHealth();

      expect(result.state, equals(HealthState.healthy));
      expect(result.description, contains('telegram'));
      expect(result.description, contains('operational'));
    });

    test('implements ChannelHealthCheck interface', () {
      final port = _TestChannelPort(platform: 'test');
      final check = ConnectorHealthCheck(port);

      expect(check, isA<ChannelHealthCheck>());
    });
  });

  // =========================================================================
  // ChannelHealthAggregator
  // =========================================================================
  group('ChannelHealthAggregator', () {
    /// Helper to create a simple ChannelHealthCheck that returns a fixed state
    _SimpleHealthCheck makeCheck(
      String name,
      HealthState state, {
      String? description,
    }) {
      return _SimpleHealthCheck(
        checkName: name,
        result: HealthStatus(
          state: state,
          description: description,
        ),
      );
    }

    group('checkHealth', () {
      test('returns healthy when all checks are healthy', () async {
        final aggregator = ChannelHealthAggregator(
          name: 'system',
          checks: [
            makeCheck('service-a', HealthState.healthy),
            makeCheck('service-b', HealthState.healthy),
            makeCheck('service-c', HealthState.healthy),
          ],
        );

        final result = await aggregator.checkHealth();

        expect(result.state, equals(HealthState.healthy));
      });

      test('returns healthy for empty check list', () async {
        final aggregator = ChannelHealthAggregator(
          name: 'empty',
          checks: [],
        );

        final result = await aggregator.checkHealth();

        expect(result.state, equals(HealthState.healthy));
      });

      test('returns degraded when one check is degraded', () async {
        final aggregator = ChannelHealthAggregator(
          name: 'system',
          checks: [
            makeCheck('service-a', HealthState.healthy),
            makeCheck('service-b', HealthState.degraded, description: 'Slow'),
            makeCheck('service-c', HealthState.healthy),
          ],
        );

        final result = await aggregator.checkHealth();

        expect(result.state, equals(HealthState.degraded));
      });

      test('returns unhealthy when one check is unhealthy', () async {
        final aggregator = ChannelHealthAggregator(
          name: 'system',
          checks: [
            makeCheck('service-a', HealthState.healthy),
            makeCheck('service-b', HealthState.healthy),
            makeCheck('service-c', HealthState.unhealthy, description: 'Down'),
          ],
        );

        final result = await aggregator.checkHealth();

        expect(result.state, equals(HealthState.unhealthy));
      });

      test('returns unhealthy when both degraded and unhealthy exist',
          () async {
        final aggregator = ChannelHealthAggregator(
          name: 'system',
          checks: [
            makeCheck('service-a', HealthState.degraded),
            makeCheck('service-b', HealthState.unhealthy),
            makeCheck('service-c', HealthState.healthy),
          ],
        );

        final result = await aggregator.checkHealth();

        expect(result.state, equals(HealthState.unhealthy));
      });

      test('catches exceptions and marks as unhealthy', () async {
        final aggregator = ChannelHealthAggregator(
          name: 'system',
          checks: [
            makeCheck('healthy-service', HealthState.healthy),
            _ThrowingHealthCheck(
              checkName: 'failing-service',
              error: Exception('Connection refused'),
            ),
          ],
        );

        final result = await aggregator.checkHealth();

        expect(result.state, equals(HealthState.unhealthy));
        expect(result.details, isNotNull);
        expect(result.details!['failing-service'], isNotNull);
        final failingDetails =
            result.details!['failing-service'] as Map<String, dynamic>;
        expect(failingDetails['state'], equals('unhealthy'));
        expect(
          failingDetails['description'] as String,
          contains('Health check failed'),
        );
      });

      test('includes component details in result', () async {
        final aggregator = ChannelHealthAggregator(
          name: 'system',
          checks: [
            makeCheck('slack', HealthState.healthy,
                description: 'Connected'),
            makeCheck('discord', HealthState.degraded,
                description: 'Slow'),
          ],
        );

        final result = await aggregator.checkHealth();

        expect(result.details, isNotNull);
        final slackDetails =
            result.details!['slack'] as Map<String, dynamic>;
        expect(slackDetails['state'], equals('healthy'));
        expect(slackDetails['description'], equals('Connected'));

        final discordDetails =
            result.details!['discord'] as Map<String, dynamic>;
        expect(discordDetails['state'], equals('degraded'));
        expect(discordDetails['description'], equals('Slow'));
      });

      test('aggregated description includes worst state', () async {
        final aggregator = ChannelHealthAggregator(
          name: 'system',
          checks: [
            makeCheck('a', HealthState.healthy),
            makeCheck('b', HealthState.degraded),
          ],
        );

        final result = await aggregator.checkHealth();

        expect(result.description, contains('2 checks'));
      });
    });

    group('name', () {
      test('exposes the aggregator name', () {
        final aggregator = ChannelHealthAggregator(
          name: 'my-system',
          checks: [],
        );

        expect(aggregator.name, equals('my-system'));
      });
    });

    group('interface conformance', () {
      test('implements ChannelHealthCheck', () {
        final aggregator = ChannelHealthAggregator(
          name: 'system',
          checks: [],
        );

        expect(aggregator, isA<ChannelHealthCheck>());
      });
    });
  });
}

/// Minimal ChannelPort implementation for testing.
class _TestChannelPort extends ChannelPort {
  _TestChannelPort({required String platform})
      : identity = ChannelIdentity(platform: platform, channelId: 'test');

  @override
  final ChannelIdentity identity;

  @override
  ChannelCapabilities get capabilities => const ChannelCapabilities.textOnly();

  @override
  Stream<ChannelEvent> get events => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> send(ChannelResponse response) async {}
}

/// Simple health check implementation for testing.
class _SimpleHealthCheck implements ChannelHealthCheck {
  _SimpleHealthCheck({
    required String checkName,
    required this.result,
  }) : name = checkName;

  @override
  final String name;

  final HealthStatus result;

  @override
  Future<HealthStatus> checkHealth() async => result;
}

/// Health check that throws for testing error handling.
class _ThrowingHealthCheck implements ChannelHealthCheck {
  _ThrowingHealthCheck({
    required String checkName,
    required this.error,
  }) : name = checkName;

  @override
  final String name;

  final Object error;

  @override
  Future<HealthStatus> checkHealth() async => throw error;
}
