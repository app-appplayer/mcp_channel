import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // =========================================================================
  // ChannelMetricsConfig
  // =========================================================================
  group('ChannelMetricsConfig', () {
    test('stores required metrics field', () {
      final metrics = InMemoryChannelMetrics();
      final config = ChannelMetricsConfig(metrics: metrics);

      expect(config.metrics, same(metrics));
      expect(config.reportingInterval, isNull);
      expect(config.platformLabel, isNull);
    });

    test('accepts all optional fields', () {
      final metrics = InMemoryChannelMetrics();
      final config = ChannelMetricsConfig(
        metrics: metrics,
        reportingInterval: const Duration(seconds: 30),
        platformLabel: 'slack',
      );

      expect(config.metrics, same(metrics));
      expect(config.reportingInterval, const Duration(seconds: 30));
      expect(config.platformLabel, 'slack');
    });
  });

  // =========================================================================
  // InMemoryChannelMetrics
  // =========================================================================
  group('InMemoryChannelMetrics', () {
    late InMemoryChannelMetrics metrics;

    setUp(() {
      metrics = InMemoryChannelMetrics();
    });

    // Helper to create a ConversationKey
    ConversationKey makeKey(String platform, String convId) {
      return ConversationKey(
        channel: ChannelIdentity(platform: platform, channelId: 'ch-1'),
        conversationId: convId,
      );
    }

    // -----------------------------------------------------------------------
    // recordMessageSent
    // -----------------------------------------------------------------------
    group('recordMessageSent', () {
      test('increments counter for platform', () {
        metrics.recordMessageSent('slack', makeKey('slack', 'c1'));

        expect(metrics.counters['message_sent:slack'], 1);
      });

      test('accumulates on repeated calls', () {
        final key = makeKey('slack', 'c1');
        metrics.recordMessageSent('slack', key);
        metrics.recordMessageSent('slack', key);
        metrics.recordMessageSent('slack', key);

        expect(metrics.counters['message_sent:slack'], 3);
      });

      test('tracks different platforms separately', () {
        metrics.recordMessageSent('slack', makeKey('slack', 'c1'));
        metrics.recordMessageSent('discord', makeKey('discord', 'c2'));
        metrics.recordMessageSent('discord', makeKey('discord', 'c3'));

        expect(metrics.counters['message_sent:slack'], 1);
        expect(metrics.counters['message_sent:discord'], 2);
      });
    });

    // -----------------------------------------------------------------------
    // recordMessageReceived
    // -----------------------------------------------------------------------
    group('recordMessageReceived', () {
      test('increments counter for platform', () {
        metrics.recordMessageReceived('telegram', makeKey('telegram', 'c1'));

        expect(metrics.counters['message_received:telegram'], 1);
      });

      test('accumulates on repeated calls', () {
        final key = makeKey('slack', 'c1');
        metrics.recordMessageReceived('slack', key);
        metrics.recordMessageReceived('slack', key);

        expect(metrics.counters['message_received:slack'], 2);
      });
    });

    // -----------------------------------------------------------------------
    // recordMessageFailed
    // -----------------------------------------------------------------------
    group('recordMessageFailed', () {
      test('increments counter for platform without error type', () {
        metrics.recordMessageFailed('slack', makeKey('slack', 'c1'));

        expect(metrics.counters['message_failed:slack'], 1);
      });

      test('increments counter with error type', () {
        metrics.recordMessageFailed(
          'slack',
          makeKey('slack', 'c1'),
          errorType: 'TIMEOUT',
        );

        expect(metrics.counters['message_failed:slack:TIMEOUT'], 1);
      });

      test('tracks different error types separately', () {
        final key = makeKey('slack', 'c1');
        metrics.recordMessageFailed('slack', key, errorType: 'TIMEOUT');
        metrics.recordMessageFailed('slack', key, errorType: 'RATE_LIMIT');
        metrics.recordMessageFailed('slack', key, errorType: 'TIMEOUT');

        expect(metrics.counters['message_failed:slack:TIMEOUT'], 2);
        expect(metrics.counters['message_failed:slack:RATE_LIMIT'], 1);
      });
    });

    // -----------------------------------------------------------------------
    // recordLatency
    // -----------------------------------------------------------------------
    group('recordLatency', () {
      test('records latency for an operation', () {
        metrics.recordLatency('send', const Duration(milliseconds: 150));

        expect(metrics.latencies['send'], isNotNull);
        expect(metrics.latencies['send']!.length, 1);
        expect(
          metrics.latencies['send']!.first,
          const Duration(milliseconds: 150),
        );
      });

      test('accumulates multiple latency observations', () {
        metrics.recordLatency('process', const Duration(milliseconds: 100));
        metrics.recordLatency('process', const Duration(milliseconds: 200));
        metrics.recordLatency('process', const Duration(milliseconds: 300));

        expect(metrics.latencies['process'], hasLength(3));
        expect(metrics.latencies['process']![0],
            const Duration(milliseconds: 100));
        expect(metrics.latencies['process']![1],
            const Duration(milliseconds: 200));
        expect(metrics.latencies['process']![2],
            const Duration(milliseconds: 300));
      });

      test('tracks different operations separately', () {
        metrics.recordLatency('send', const Duration(milliseconds: 50));
        metrics.recordLatency('receive', const Duration(milliseconds: 75));

        expect(metrics.latencies['send'], hasLength(1));
        expect(metrics.latencies['receive'], hasLength(1));
      });
    });

    // -----------------------------------------------------------------------
    // recordSessionCreated / recordSessionExpired
    // -----------------------------------------------------------------------
    group('session tracking', () {
      test('recordSessionCreated increments counter', () {
        metrics.recordSessionCreated();
        metrics.recordSessionCreated();

        expect(metrics.counters['session_created'], 2);
      });

      test('recordSessionExpired increments counter', () {
        metrics.recordSessionExpired();

        expect(metrics.counters['session_expired'], 1);
      });
    });

    // -----------------------------------------------------------------------
    // recordRateLimitHit
    // -----------------------------------------------------------------------
    group('recordRateLimitHit', () {
      test('increments counter for platform', () {
        metrics.recordRateLimitHit('slack');

        expect(metrics.counters['rate_limit_hit:slack'], 1);
      });

      test('accumulates on repeated calls', () {
        metrics.recordRateLimitHit('discord');
        metrics.recordRateLimitHit('discord');
        metrics.recordRateLimitHit('discord');

        expect(metrics.counters['rate_limit_hit:discord'], 3);
      });
    });

    // -----------------------------------------------------------------------
    // recordCircuitBreakerStateChange
    // -----------------------------------------------------------------------
    group('recordCircuitBreakerStateChange', () {
      test('records event in circuit breaker events list', () {
        metrics.recordCircuitBreakerStateChange('slack-cb', 'open');

        expect(metrics.circuitBreakerEvents, hasLength(1));
        expect(metrics.circuitBreakerEvents.first, 'slack-cb:open');
      });

      test('records multiple state changes in order', () {
        metrics.recordCircuitBreakerStateChange('cb1', 'open');
        metrics.recordCircuitBreakerStateChange('cb1', 'half-open');
        metrics.recordCircuitBreakerStateChange('cb1', 'closed');

        expect(metrics.circuitBreakerEvents, hasLength(3));
        expect(metrics.circuitBreakerEvents[0], 'cb1:open');
        expect(metrics.circuitBreakerEvents[1], 'cb1:half-open');
        expect(metrics.circuitBreakerEvents[2], 'cb1:closed');
      });
    });

    // -----------------------------------------------------------------------
    // Unmodifiable getters
    // -----------------------------------------------------------------------
    group('unmodifiable getters', () {
      test('counters getter returns unmodifiable map', () {
        metrics.recordSessionCreated();

        expect(
          () => metrics.counters['hack'] = 99,
          throwsUnsupportedError,
        );
      });

      test('latencies getter returns unmodifiable map', () {
        metrics.recordLatency('op', const Duration(milliseconds: 10));

        expect(
          () => metrics.latencies['hack'] = [],
          throwsUnsupportedError,
        );
      });

      test('circuitBreakerEvents getter returns unmodifiable list', () {
        metrics.recordCircuitBreakerStateChange('cb', 'open');

        expect(
          () => metrics.circuitBreakerEvents.add('hack'),
          throwsUnsupportedError,
        );
      });
    });

    // -----------------------------------------------------------------------
    // reset
    // -----------------------------------------------------------------------
    group('reset', () {
      test('clears all counters, latencies, and circuit breaker events', () {
        metrics.recordMessageSent('slack', makeKey('slack', 'c1'));
        metrics.recordLatency('op', const Duration(milliseconds: 50));
        metrics.recordCircuitBreakerStateChange('cb', 'open');
        metrics.recordSessionCreated();
        metrics.recordRateLimitHit('slack');

        // Verify non-empty before reset
        expect(metrics.counters, isNotEmpty);
        expect(metrics.latencies, isNotEmpty);
        expect(metrics.circuitBreakerEvents, isNotEmpty);

        metrics.reset();

        expect(metrics.counters, isEmpty);
        expect(metrics.latencies, isEmpty);
        expect(metrics.circuitBreakerEvents, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // Interface conformance
    // -----------------------------------------------------------------------
    group('interface conformance', () {
      test('implements ChannelMetrics', () {
        expect(metrics, isA<ChannelMetrics>());
      });
    });
  });
}
