import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // =========================================================================
  // SpanStatus enum
  // =========================================================================
  group('SpanStatus', () {
    test('has expected values', () {
      expect(SpanStatus.values, hasLength(3));
      expect(SpanStatus.values, contains(SpanStatus.ok));
      expect(SpanStatus.values, contains(SpanStatus.error));
      expect(SpanStatus.values, contains(SpanStatus.cancelled));
    });

    test('ok has index 0', () {
      expect(SpanStatus.ok.index, equals(0));
    });

    test('error has index 1', () {
      expect(SpanStatus.error.index, equals(1));
    });

    test('cancelled has index 2', () {
      expect(SpanStatus.cancelled.index, equals(2));
    });
  });

  // =========================================================================
  // generateCorrelationId
  // =========================================================================
  group('generateCorrelationId', () {
    test('returns string starting with evt_ prefix', () {
      final id = generateCorrelationId();

      expect(id, startsWith('evt_'));
    });

    test('returns string matching evt_{timestamp}_{hex} format', () {
      final id = generateCorrelationId();
      final pattern = RegExp(r'^evt_\d+_[0-9a-f]{4}$');

      expect(pattern.hasMatch(id), isTrue);
    });

    test('returns unique values on successive calls', () {
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        ids.add(generateCorrelationId());
      }

      // All 100 generated IDs should be unique
      expect(ids.length, equals(100));
    });

    test('contains a timestamp component', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final id = generateCorrelationId();
      final after = DateTime.now().millisecondsSinceEpoch;

      // Extract the timestamp part between first and second underscore
      final parts = id.split('_');
      expect(parts.length, equals(3));

      final timestamp = int.parse(parts[1]);
      expect(timestamp, greaterThanOrEqualTo(before));
      expect(timestamp, lessThanOrEqualTo(after));
    });
  });

  // =========================================================================
  // InMemoryTracer
  // =========================================================================
  group('InMemoryTracer', () {
    late InMemoryTracer tracer;

    setUp(() {
      tracer = InMemoryTracer();
    });

    group('startSpan', () {
      test('creates a root span with the given name', () {
        final span = tracer.startSpan('test.operation');

        expect(span, isA<InMemorySpan>());
        final memorySpan = span as InMemorySpan;
        expect(memorySpan.name, equals('test.operation'));
        expect(memorySpan.spanId, equals('span-0'));
      });

      test('creates root span with null parentSpanId', () {
        final span = tracer.startSpan('root.operation') as InMemorySpan;

        expect(span.parentSpanId, isNull);
      });

      test('creates child span when parentSpanId is provided', () {
        final parent = tracer.startSpan('parent.operation');
        final child = tracer.startSpan(
          'child.operation',
          parentSpanId: parent.spanId,
        ) as InMemorySpan;

        expect(child.parentSpanId, equals(parent.spanId));
        expect(child.name, equals('child.operation'));
      });

      test('child span has different spanId from parent', () {
        final parent = tracer.startSpan('parent');
        final child = tracer.startSpan(
          'child',
          parentSpanId: parent.spanId,
        );

        expect(child.spanId, isNot(equals(parent.spanId)));
      });
    });

    group('spans', () {
      test('records all created spans', () {
        tracer.startSpan('op1');
        tracer.startSpan('op2');
        tracer.startSpan('op3');

        expect(tracer.spans, hasLength(3));
        expect(tracer.spans[0].name, equals('op1'));
        expect(tracer.spans[1].name, equals('op2'));
        expect(tracer.spans[2].name, equals('op3'));
      });

      test('records both root and child spans', () {
        final root = tracer.startSpan('root');
        tracer.startSpan('child', parentSpanId: root.spanId);

        expect(tracer.spans, hasLength(2));
      });

      test('returns unmodifiable list', () {
        tracer.startSpan('op');

        expect(
          () => tracer.spans.add(InMemorySpan(
            spanId: 'fake',
            name: 'fake',
          )),
          throwsUnsupportedError,
        );
      });
    });

    group('reset', () {
      test('clears all spans', () {
        tracer.startSpan('op1');
        tracer.startSpan('op2');
        expect(tracer.spans, hasLength(2));

        tracer.reset();

        expect(tracer.spans, isEmpty);
      });

      test('resets span ID counter', () {
        tracer.startSpan('before-reset');
        expect(tracer.spans[0].spanId, equals('span-0'));

        tracer.reset();

        final span = tracer.startSpan('after-reset');
        expect(span.spanId, equals('span-0'));
      });
    });

    group('sequential IDs', () {
      test('assigns sequential span IDs', () {
        final span0 = tracer.startSpan('op0');
        final span1 = tracer.startSpan('op1');
        final span2 = tracer.startSpan('op2');
        final span3 = tracer.startSpan(
          'op3',
          parentSpanId: span0.spanId,
        );
        final span4 = tracer.startSpan('op4');

        expect(span0.spanId, equals('span-0'));
        expect(span1.spanId, equals('span-1'));
        expect(span2.spanId, equals('span-2'));
        expect(span3.spanId, equals('span-3'));
        expect(span4.spanId, equals('span-4'));
      });
    });
  });

  // =========================================================================
  // InMemorySpan
  // =========================================================================
  group('InMemorySpan', () {
    late InMemorySpan span;

    setUp(() {
      span = InMemorySpan(
        spanId: 'test-span',
        name: 'test.operation',
      );
    });

    group('setAttribute', () {
      test('stores a string attribute', () {
        span.setAttribute('key', 'value');

        expect(span.attributes['key'], equals('value'));
      });

      test('stores a numeric attribute', () {
        span.setAttribute('count', 42);

        expect(span.attributes['count'], equals(42));
      });

      test('overwrites existing attribute with same key', () {
        span.setAttribute('key', 'first');
        span.setAttribute('key', 'second');

        expect(span.attributes['key'], equals('second'));
      });

      test('stores multiple attributes', () {
        span.setAttribute('a', 1);
        span.setAttribute('b', 'two');
        span.setAttribute('c', true);

        expect(span.attributes, hasLength(3));
        expect(span.attributes['a'], equals(1));
        expect(span.attributes['b'], equals('two'));
        expect(span.attributes['c'], equals(true));
      });

      test('accepts dynamic values', () {
        span.setAttribute('list', [1, 2, 3]);
        span.setAttribute('map', {'nested': true});
        span.setAttribute('null_val', null);

        expect(span.attributes['list'], equals([1, 2, 3]));
        expect(span.attributes['map'], equals({'nested': true}));
        expect(span.attributes.containsKey('null_val'), isTrue);
      });
    });

    group('addEvent', () {
      test('adds an event with name only', () {
        span.addEvent('request.start');

        expect(span.events, hasLength(1));
        expect(span.events.first.name, 'request.start');
        expect(span.events.first.timestamp, isNotNull);
        expect(span.events.first.attributes, isNull);
      });

      test('adds an event with attributes', () {
        span.addEvent(
          'request.complete',
          attributes: {'statusCode': 200, 'bytes': 1024},
        );

        expect(span.events, hasLength(1));
        expect(span.events.first.name, 'request.complete');
        expect(span.events.first.attributes!['statusCode'], 200);
        expect(span.events.first.attributes!['bytes'], 1024);
      });

      test('accumulates multiple events', () {
        span.addEvent('event1');
        span.addEvent('event2');
        span.addEvent('event3');

        expect(span.events, hasLength(3));
        expect(span.events[0].name, 'event1');
        expect(span.events[1].name, 'event2');
        expect(span.events[2].name, 'event3');
      });
    });

    group('setStatus', () {
      test('changes status to cancelled', () {
        span.setStatus(SpanStatus.cancelled);

        expect(span.status, equals(SpanStatus.cancelled));
      });

      test('changes status to error', () {
        span.setStatus(SpanStatus.error);

        expect(span.status, equals(SpanStatus.error));
      });

      test('changes status back to ok', () {
        span.setStatus(SpanStatus.error);
        span.setStatus(SpanStatus.ok);

        expect(span.status, equals(SpanStatus.ok));
      });

      test('default status is ok', () {
        expect(span.status, equals(SpanStatus.ok));
      });

      test('stores status description', () {
        span.setStatus(SpanStatus.error, description: 'Connection refused');

        expect(span.status, equals(SpanStatus.error));
        expect(span.statusDescription, equals('Connection refused'));
      });

      test('description is null when not provided', () {
        span.setStatus(SpanStatus.ok);

        expect(span.statusDescription, isNull);
      });
    });

    group('end', () {
      test('sets endTime', () {
        expect(span.endTime, isNull);

        span.end();

        expect(span.endTime, isNotNull);
      });

      test('endTime is at or after startTime', () {
        span.end();

        expect(
          span.endTime!.isAfter(span.startTime) ||
              span.endTime!.isAtSameMomentAs(span.startTime),
          isTrue,
        );
      });
    });

    group('isEnded', () {
      test('returns false before end is called', () {
        expect(span.isEnded, isFalse);
      });

      test('returns true after end is called', () {
        span.end();

        expect(span.isEnded, isTrue);
      });
    });

    group('duration', () {
      test('returns null before end is called', () {
        expect(span.duration, isNull);
      });

      test('returns non-null Duration after end is called', () {
        span.end();

        expect(span.duration, isNotNull);
        expect(span.duration, isA<Duration>());
      });

      test('returns non-negative duration', () {
        span.end();

        expect(span.duration!.isNegative, isFalse);
      });
    });

    group('constructor', () {
      test('sets spanId and name', () {
        final s = InMemorySpan(
          spanId: 'my-span',
          name: 'my.op',
        );

        expect(s.spanId, equals('my-span'));
        expect(s.name, equals('my.op'));
      });

      test('parentSpanId defaults to null', () {
        final s = InMemorySpan(
          spanId: 's1',
          name: 'op',
        );

        expect(s.parentSpanId, isNull);
      });

      test('accepts parentSpanId', () {
        final s = InMemorySpan(
          spanId: 's1',
          name: 'op',
          parentSpanId: 'parent-1',
        );

        expect(s.parentSpanId, equals('parent-1'));
      });

      test('sets startTime to approximately now', () {
        final before = DateTime.now();
        final s = InMemorySpan(
          spanId: 's1',
          name: 'op',
        );
        final after = DateTime.now();

        expect(
          s.startTime.isAfter(before) ||
              s.startTime.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          s.startTime.isBefore(after) ||
              s.startTime.isAtSameMomentAs(after),
          isTrue,
        );
      });

      test('initializes events as empty list', () {
        expect(span.events, isEmpty);
      });

      test('attributes map is unmodifiable via getter', () {
        expect(
          () => span.attributes['key'] = 'value',
          throwsUnsupportedError,
        );
      });
    });
  });

  // =========================================================================
  // SpanEvent
  // =========================================================================
  group('SpanEvent', () {
    test('stores name and timestamp', () {
      final now = DateTime.now();
      final event = SpanEvent(name: 'test', timestamp: now);

      expect(event.name, 'test');
      expect(event.timestamp, now);
      expect(event.attributes, isNull);
    });

    test('stores optional attributes', () {
      final event = SpanEvent(
        name: 'test',
        timestamp: DateTime.now(),
        attributes: {'key': 'value'},
      );

      expect(event.attributes, {'key': 'value'});
    });
  });
}
