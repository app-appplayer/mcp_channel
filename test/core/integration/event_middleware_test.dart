import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Shared test fixtures
  const conv = ConversationKey(
    channel: ChannelIdentity(platform: 'test', channelId: 'ch1'),
    conversationId: 'conv1',
    userId: 'u1',
  );

  ChannelEvent createEvent({
    String? id,
    ConversationKey? conversation,
    String type = 'message',
    String text = 'hello',
    String? userId = 'u1',
  }) {
    return ChannelEvent(
      id: id ?? 'evt-${DateTime.now().microsecondsSinceEpoch}',
      conversation: conversation ?? conv,
      type: type,
      text: text,
      userId: userId,
      timestamp: DateTime.now(),
    );
  }

  Session createSession({String id = 'session-1'}) {
    return Session(
      id: id,
      conversation: conv,
      principal: Principal.basic(
        identity: ChannelIdentityInfo.user(
          id: 'u1',
          displayName: 'Test User',
        ),
        tenantId: 'ch1',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      ),
      state: SessionState.active,
      createdAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // TC-059-01: LoggingMiddleware
  // ---------------------------------------------------------------------------
  group('LoggingMiddleware', () {
    test('calls next and passes event through', () async {
      final logs = <String>[];
      final middleware = LoggingMiddleware((msg, {data}) => logs.add(msg));
      final event = createEvent();
      final session = createSession();

      var nextCalled = false;
      await middleware.handle(event, session, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
      expect(logs, hasLength(2)); // received + processed
      expect(logs.first, contains('type=message'));
      expect(logs.first, contains('conversation=conv1'));
    });

    test('logs timing information', () async {
      final logData = <Map<String, dynamic>?>[];
      final middleware = LoggingMiddleware((msg, {data}) {
        logData.add(data);
      });

      await middleware.handle(createEvent(), createSession(), () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });

      expect(logData, hasLength(2));
      expect(logData[1]?['elapsedMs'], isNotNull);
    });

    test('logs error and rethrows', () async {
      final logs = <String>[];
      final middleware = LoggingMiddleware((msg, {data}) => logs.add(msg));

      expect(
        () => middleware.handle(createEvent(), createSession(), () async {
          throw Exception('test error');
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TC-059-03: EventFilterMiddleware
  // ---------------------------------------------------------------------------
  group('EventFilterMiddleware', () {
    test('calls next when predicate is true', () async {
      final middleware = EventFilterMiddleware((_) => true);

      var nextCalled = false;
      await middleware.handle(createEvent(), createSession(), () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
    });

    test('does not call next when predicate is false', () async {
      final middleware = EventFilterMiddleware((_) => false);

      var nextCalled = false;
      await middleware.handle(createEvent(), createSession(), () async {
        nextCalled = true;
      });

      expect(nextCalled, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-059-05: RateLimitMiddleware
  // ---------------------------------------------------------------------------
  group('RateLimitMiddleware', () {
    test('allows events within limit', () async {
      final middleware = RateLimitMiddleware(maxEventsPerMinute: 3);
      final session = createSession();

      var callCount = 0;
      for (var i = 0; i < 3; i++) {
        await middleware.handle(createEvent(), session, () async {
          callCount++;
        });
      }
      expect(callCount, 3);
    });

    test('drops events exceeding limit for same session', () async {
      final middleware = RateLimitMiddleware(maxEventsPerMinute: 2);
      final session = createSession();

      var callCount = 0;
      for (var i = 0; i < 3; i++) {
        await middleware.handle(createEvent(), session, () async {
          callCount++;
        });
      }
      expect(callCount, 2); // third event dropped
    });

    test('allows events from different sessions independently', () async {
      final middleware = RateLimitMiddleware(maxEventsPerMinute: 1);
      final session1 = createSession(id: 'session-1');
      final session2 = createSession(id: 'session-2');

      var callCount = 0;

      // First event from session1 allowed
      await middleware.handle(createEvent(), session1, () async {
        callCount++;
      });
      expect(callCount, 1);

      // Second event from session1 dropped
      await middleware.handle(createEvent(), session1, () async {
        callCount++;
      });
      expect(callCount, 1);

      // First event from session2 allowed (independent counter)
      await middleware.handle(createEvent(), session2, () async {
        callCount++;
      });
      expect(callCount, 2);
    });

    test('uses default maxEventsPerMinute of 30', () {
      final middleware = RateLimitMiddleware();
      expect(middleware.maxEventsPerMinute, 30);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-059-09: AuthorizationMiddleware
  // ---------------------------------------------------------------------------
  group('AuthorizationMiddleware', () {
    test('calls next when authorized', () async {
      final middleware =
          AuthorizationMiddleware((event, session) async => true);

      var nextCalled = false;
      await middleware.handle(createEvent(), createSession(), () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
    });

    test('does not call next when not authorized', () async {
      final middleware =
          AuthorizationMiddleware((event, session) async => false);

      var nextCalled = false;
      await middleware.handle(createEvent(), createSession(), () async {
        nextCalled = true;
      });

      expect(nextCalled, isFalse);
    });

    test('receives both event and session', () async {
      ChannelEvent? capturedEvent;
      Session? capturedSession;

      final middleware = AuthorizationMiddleware((event, session) async {
        capturedEvent = event;
        capturedSession = session;
        return true;
      });

      final event = createEvent();
      final session = createSession();
      await middleware.handle(event, session, () async {});

      expect(capturedEvent, same(event));
      expect(capturedSession, same(session));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-059-12: Middleware chaining simulation
  // ---------------------------------------------------------------------------
  group('Middleware chaining', () {
    test('chain-of-responsibility executes in order', () async {
      final order = <String>[];

      final middlewares = <EventMiddleware>[
        _TrackingMiddleware('A', order),
        _TrackingMiddleware('B', order),
        _TrackingMiddleware('C', order),
      ];

      final event = createEvent();
      final session = createSession();

      // Build the chain manually (as ChannelHandler does)
      Future<void> runChain(
        List<EventMiddleware> mws,
        Future<void> Function() handler,
      ) async {
        if (mws.isEmpty) {
          await handler();
          return;
        }
        await mws.first.handle(event, session, () async {
          await runChain(mws.sublist(1), handler);
        });
      }

      await runChain(middlewares, () async {
        order.add('handler');
      });

      expect(order, ['A-before', 'B-before', 'C-before', 'handler',
                      'C-after', 'B-after', 'A-after']);
    });

    test('middleware can short-circuit by not calling next', () async {
      final order = <String>[];

      final middlewares = <EventMiddleware>[
        _TrackingMiddleware('A', order),
        EventFilterMiddleware((_) => false), // blocks here
        _TrackingMiddleware('C', order),
      ];

      final event = createEvent();
      final session = createSession();

      Future<void> runChain(
        List<EventMiddleware> mws,
        Future<void> Function() handler,
      ) async {
        if (mws.isEmpty) {
          await handler();
          return;
        }
        await mws.first.handle(event, session, () async {
          await runChain(mws.sublist(1), handler);
        });
      }

      await runChain(middlewares, () async {
        order.add('handler');
      });

      // Only A runs, filter blocks, C and handler never execute
      expect(order, ['A-before', 'A-after']);
    });
  });
}

/// A middleware that tracks before/after execution order.
class _TrackingMiddleware implements EventMiddleware {
  _TrackingMiddleware(this.name, this.order);

  final String name;
  final List<String> order;

  @override
  Future<void> handle(
    ChannelEvent event,
    Session session,
    Future<void> Function() next,
  ) async {
    order.add('$name-before');
    await next();
    order.add('$name-after');
  }
}
