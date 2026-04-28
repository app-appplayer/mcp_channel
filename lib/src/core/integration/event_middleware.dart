import 'dart:async';

import 'package:mcp_bundle/ports.dart';

import '../session/session.dart';

/// Middleware that can intercept, filter, or transform channel events
/// using a chain-of-responsibility pattern.
///
/// Each middleware receives the event, the session, and a `next` callback.
/// Calling `next()` passes control to the next middleware in the chain.
/// Not calling `next()` stops the pipeline (e.g., for filtering or authorization).
abstract interface class EventMiddleware {
  /// Handle an incoming event.
  ///
  /// [event] - The incoming channel event
  /// [session] - The session associated with the event
  /// [next] - Callback to pass control to the next middleware
  Future<void> handle(
    ChannelEvent event,
    Session session,
    Future<void> Function() next,
  );
}

/// Middleware that logs events passing through the pipeline.
///
/// Measures processing time with a Stopwatch and logs errors.
class LoggingMiddleware implements EventMiddleware {
  const LoggingMiddleware(this._log);

  final void Function(String message, {Map<String, dynamic>? data}) _log;

  @override
  Future<void> handle(
    ChannelEvent event,
    Session session,
    Future<void> Function() next,
  ) async {
    final stopwatch = Stopwatch()..start();
    _log(
      'Event received: type=${event.type}, '
      'conversation=${event.conversation.conversationId}',
      data: {'sessionId': session.id},
    );

    try {
      await next();
      stopwatch.stop();
      _log(
        'Event processed in ${stopwatch.elapsedMilliseconds}ms',
        data: {
          'sessionId': session.id,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      _log(
        'Event processing failed after ${stopwatch.elapsedMilliseconds}ms: '
        '$error',
        data: {
          'sessionId': session.id,
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      rethrow;
    }
  }
}

/// Middleware that filters events based on a predicate.
///
/// Events that do not match the predicate are dropped (next is not called).
class EventFilterMiddleware implements EventMiddleware {
  const EventFilterMiddleware(this._shouldProcess);

  final bool Function(ChannelEvent event) _shouldProcess;

  @override
  Future<void> handle(
    ChannelEvent event,
    Session session,
    Future<void> Function() next,
  ) async {
    if (_shouldProcess(event)) {
      await next();
    }
  }
}

/// Middleware that applies rate limiting per session.
///
/// Drops events if a session exceeds [maxEventsPerMinute]
/// within a one-minute window.
class RateLimitMiddleware implements EventMiddleware {
  RateLimitMiddleware({this.maxEventsPerMinute = 30});

  /// Maximum events allowed per session per minute
  final int maxEventsPerMinute;

  final Map<String, List<DateTime>> _eventTimestamps = {};

  @override
  Future<void> handle(
    ChannelEvent event,
    Session session,
    Future<void> Function() next,
  ) async {
    final key = session.id;
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 1));

    final timestamps = _eventTimestamps.putIfAbsent(key, () => []);
    timestamps.removeWhere((t) => t.isBefore(cutoff));

    if (timestamps.length >= maxEventsPerMinute) {
      return;
    }

    timestamps.add(now);
    await next();
  }
}

/// Middleware that rejects events from unauthorized users.
///
/// Uses a callback to determine if the event's user is authorized.
class AuthorizationMiddleware implements EventMiddleware {
  const AuthorizationMiddleware(this._authorize);

  final Future<bool> Function(ChannelEvent event, Session session) _authorize;

  @override
  Future<void> handle(
    ChannelEvent event,
    Session session,
    Future<void> Function() next,
  ) async {
    final authorized = await _authorize(event, session);
    if (authorized) {
      await next();
    }
  }
}
