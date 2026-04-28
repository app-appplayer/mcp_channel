import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // Shared test fixtures
  const conv = ConversationKey(
    channel: ChannelIdentity(platform: 'test', channelId: 'ch1'),
    conversationId: 'conv1',
    userId: 'u1',
  );

  final event = ChannelEvent.message(
    id: 'evt-err-1',
    conversation: conv,
    text: 'hello',
    userId: 'u1',
  );

  final session = Session(
    id: 'session-err-1',
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

  final testError = Exception('something went wrong');
  final testStackTrace = StackTrace.current;

  // ---------------------------------------------------------------------------
  // TC-060: FallbackErrorHandler
  // ---------------------------------------------------------------------------
  group('FallbackErrorHandler', () {
    test('returns ChannelResponse with default message', () async {
      const handler = FallbackErrorHandler();
      final response = await handler.handleError(
        testError,
        testStackTrace,
        event,
        session,
      );

      expect(response, isNotNull);
      expect(response!.text,
          'Sorry, something went wrong. Please try again.');
    });

    test('returns ChannelResponse with custom message', () async {
      const handler = FallbackErrorHandler(
        fallbackMessage: 'Oops, something broke!',
      );
      final response = await handler.handleError(
        testError,
        testStackTrace,
        event,
        session,
      );

      expect(response, isNotNull);
      expect(response!.text, 'Oops, something broke!');
    });

    test('response targets the same conversation as the event', () async {
      const handler = FallbackErrorHandler();
      final response = await handler.handleError(
        testError,
        testStackTrace,
        event,
        session,
      );

      expect(response, isNotNull);
      expect(response!.conversation, equals(event.conversation));
      expect(response.conversation.conversationId, 'conv1');
      expect(response.conversation.channel.platform, 'test');
      expect(response.conversation.channel.channelId, 'ch1');
    });

    test('response is text type', () async {
      const handler = FallbackErrorHandler();
      final response = await handler.handleError(
        testError,
        testStackTrace,
        event,
        session,
      );

      expect(response, isNotNull);
      expect(response!.type, 'text');
    });

    test('calls onError callback', () async {
      Object? capturedError;
      StackTrace? capturedStack;

      final handler = FallbackErrorHandler(
        onError: (error, stack) {
          capturedError = error;
          capturedStack = stack;
        },
      );

      await handler.handleError(testError, testStackTrace, event, session);

      expect(capturedError, same(testError));
      expect(capturedStack, same(testStackTrace));
    });

    test('works with different error types', () async {
      const handler = FallbackErrorHandler();
      const expectedMsg =
          'Sorry, something went wrong. Please try again.';

      // Exception
      final r1 = await handler.handleError(
        Exception('exception error'),
        testStackTrace,
        event,
        session,
      );
      expect(r1, isNotNull);
      expect(r1!.text, expectedMsg);

      // Error (ArgumentError)
      final r2 = await handler.handleError(
        ArgumentError('bad argument'),
        testStackTrace,
        event,
        session,
      );
      expect(r2, isNotNull);
      expect(r2!.text, expectedMsg);

      // String error
      final r3 = await handler.handleError(
        'string error',
        testStackTrace,
        event,
        session,
      );
      expect(r3, isNotNull);
      expect(r3!.text, expectedMsg);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-060: SilentErrorHandler
  // ---------------------------------------------------------------------------
  group('SilentErrorHandler', () {
    test('returns null', () async {
      const handler = SilentErrorHandler();
      final response = await handler.handleError(
        testError,
        testStackTrace,
        event,
        session,
      );

      expect(response, isNull);
    });

    test('calls onError callback with error and stackTrace', () async {
      Object? capturedError;
      StackTrace? capturedStackTrace;

      final handler = SilentErrorHandler(
        onError: (error, stackTrace) {
          capturedError = error;
          capturedStackTrace = stackTrace;
        },
      );

      await handler.handleError(testError, testStackTrace, event, session);

      expect(capturedError, same(testError));
      expect(capturedStackTrace, same(testStackTrace));
    });

    test('without onError callback still returns null', () async {
      const handler = SilentErrorHandler();
      final response = await handler.handleError(
        testError,
        testStackTrace,
        event,
        session,
      );

      expect(response, isNull);
    });

    test('works with different error types', () async {
      final capturedErrors = <Object>[];

      final handler = SilentErrorHandler(
        onError: (error, stackTrace) {
          capturedErrors.add(error);
        },
      );

      // Exception
      final r1 = await handler.handleError(
        Exception('exception error'),
        testStackTrace,
        event,
        session,
      );
      expect(r1, isNull);

      // Error (StateError)
      final r2 = await handler.handleError(
        StateError('bad state'),
        testStackTrace,
        event,
        session,
      );
      expect(r2, isNull);

      // String error
      final r3 = await handler.handleError(
        'string error',
        testStackTrace,
        event,
        session,
      );
      expect(r3, isNull);

      expect(capturedErrors, hasLength(3));
      expect(capturedErrors[0], isA<Exception>());
      expect(capturedErrors[1], isA<StateError>());
      expect(capturedErrors[2], 'string error');
    });
  });

  // ---------------------------------------------------------------------------
  // TC-060: Custom ErrorHandler implementation
  // ---------------------------------------------------------------------------
  group('Custom ErrorHandler implementation', () {
    test('custom handler can inspect error and return conditional response',
        () async {
      final handler = _ConditionalErrorHandler();

      // FormatException should get a specific message
      final r1 = await handler.handleError(
        const FormatException('bad input'),
        testStackTrace,
        event,
        session,
      );
      expect(r1, isNotNull);
      expect(r1!.text, 'Invalid format. Please check your input.');
      expect(r1.conversation, equals(event.conversation));
      expect(r1.type, 'text');

      // Other errors return a generic response
      final r2 = await handler.handleError(
        Exception('generic'),
        testStackTrace,
        event,
        session,
      );
      expect(r2, isNotNull);
      expect(r2!.text, 'An unexpected error occurred.');

      // Specific errors can return null (swallow)
      final r3 = await handler.handleError(
        _IgnorableError(),
        testStackTrace,
        event,
        session,
      );
      expect(r3, isNull);
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

/// Custom error handler that returns different responses based on error type.
class _ConditionalErrorHandler implements ErrorHandler {
  @override
  Future<ChannelResponse?> handleError(
    Object error,
    StackTrace stackTrace,
    ChannelEvent event,
    Session session,
  ) async {
    if (error is _IgnorableError) {
      return null;
    }
    if (error is FormatException) {
      return ChannelResponse.text(
        conversation: event.conversation,
        text: 'Invalid format. Please check your input.',
      );
    }
    return ChannelResponse.text(
      conversation: event.conversation,
      text: 'An unexpected error occurred.',
    );
  }
}

/// Marker error type used to test conditional swallowing.
class _IgnorableError extends Error {}
