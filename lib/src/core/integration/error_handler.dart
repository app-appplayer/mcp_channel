import 'package:mcp_bundle/ports.dart';

import '../session/session.dart';

/// Interface for handling errors that occur during event processing.
///
/// When event processing throws an exception, the error handler
/// determines how to respond (e.g. send an apology message,
/// log and swallow, rethrow, etc.)
abstract interface class ErrorHandler {
  /// Handle an error that occurred during event processing.
  ///
  /// [error] - The error that was thrown
  /// [stackTrace] - Stack trace of the error
  /// [event] - The event that was being processed
  /// [session] - The session associated with the event
  ///
  /// Returns a [ChannelResponse] to send as a fallback, or `null`
  /// to swallow the error silently.
  Future<ChannelResponse?> handleError(
    Object error,
    StackTrace stackTrace,
    ChannelEvent event,
    Session session,
  );
}

/// Error handler that sends a configurable fallback message.
class FallbackErrorHandler implements ErrorHandler {
  const FallbackErrorHandler({
    this.fallbackMessage = 'Sorry, something went wrong. Please try again.',
    this.onError,
  });

  /// The fallback message to send on error
  final String fallbackMessage;

  /// Optional callback invoked with the error details
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  Future<ChannelResponse?> handleError(
    Object error,
    StackTrace stackTrace,
    ChannelEvent event,
    Session session,
  ) async {
    onError?.call(error, stackTrace);
    return ChannelResponse.text(
      conversation: event.conversation,
      text: fallbackMessage,
    );
  }
}

/// Error handler that swallows errors silently.
///
/// Uses an optional callback for logging (no direct print/debugPrint).
class SilentErrorHandler implements ErrorHandler {
  const SilentErrorHandler({this.onError});

  /// Optional callback invoked with the error details
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  Future<ChannelResponse?> handleError(
    Object error,
    StackTrace stackTrace,
    ChannelEvent event,
    Session session,
  ) async {
    onError?.call(error, stackTrace);
    return null;
  }
}
