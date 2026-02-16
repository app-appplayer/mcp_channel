import 'package:meta/meta.dart';

/// Standard error codes for channel operations.
class ChannelErrorCode {
  /// Rate limit exceeded
  static const String rateLimited = 'rate_limited';

  /// Channel/user/message not found
  static const String notFound = 'not_found';

  /// Insufficient permissions
  static const String permissionDenied = 'permission_denied';

  /// Malformed request
  static const String invalidRequest = 'invalid_request';

  /// Message exceeds max length
  static const String messageTooLong = 'message_too_long';

  /// File exceeds max size
  static const String fileTooLarge = 'file_too_large';

  /// Network connectivity issue
  static const String networkError = 'network_error';

  /// Operation timed out
  static const String timeout = 'timeout';

  /// Platform server error
  static const String serverError = 'server_error';

  /// Unknown error
  static const String unknown = 'unknown';

  ChannelErrorCode._();
}

/// Error information for failed channel operations.
@immutable
class ChannelError implements Exception {
  /// Error code
  final String code;

  /// Error message
  final String message;

  /// Whether the error is retryable
  final bool retryable;

  /// Suggested retry delay (if retryable)
  final Duration? retryAfter;

  /// Platform-specific error data
  final Map<String, dynamic>? platformData;

  const ChannelError({
    required this.code,
    required this.message,
    this.retryable = false,
    this.retryAfter,
    this.platformData,
  });

  /// Creates a rate limited error.
  factory ChannelError.rateLimited({
    String? message,
    Duration? retryAfter,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelError(
      code: ChannelErrorCode.rateLimited,
      message: message ?? 'Rate limit exceeded',
      retryable: true,
      retryAfter: retryAfter,
      platformData: platformData,
    );
  }

  /// Creates a not found error.
  factory ChannelError.notFound({
    String? message,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelError(
      code: ChannelErrorCode.notFound,
      message: message ?? 'Resource not found',
      retryable: false,
      platformData: platformData,
    );
  }

  /// Creates a permission denied error.
  factory ChannelError.permissionDenied({
    String? message,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelError(
      code: ChannelErrorCode.permissionDenied,
      message: message ?? 'Permission denied',
      retryable: false,
      platformData: platformData,
    );
  }

  /// Creates an invalid request error.
  factory ChannelError.invalidRequest({
    String? message,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelError(
      code: ChannelErrorCode.invalidRequest,
      message: message ?? 'Invalid request',
      retryable: false,
      platformData: platformData,
    );
  }

  /// Creates a network error.
  factory ChannelError.networkError({
    String? message,
    Duration? retryAfter,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelError(
      code: ChannelErrorCode.networkError,
      message: message ?? 'Network error',
      retryable: true,
      retryAfter: retryAfter,
      platformData: platformData,
    );
  }

  /// Creates a timeout error.
  factory ChannelError.timeout({
    String? message,
    Duration? retryAfter,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelError(
      code: ChannelErrorCode.timeout,
      message: message ?? 'Operation timed out',
      retryable: true,
      retryAfter: retryAfter,
      platformData: platformData,
    );
  }

  /// Creates a server error.
  factory ChannelError.serverError({
    String? message,
    Duration? retryAfter,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelError(
      code: ChannelErrorCode.serverError,
      message: message ?? 'Server error',
      retryable: true,
      retryAfter: retryAfter,
      platformData: platformData,
    );
  }

  /// Creates an unknown error.
  factory ChannelError.unknown({
    String? message,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelError(
      code: ChannelErrorCode.unknown,
      message: message ?? 'Unknown error',
      retryable: false,
      platformData: platformData,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'retryable': retryable,
        if (retryAfter != null) 'retryAfterMs': retryAfter!.inMilliseconds,
        if (platformData != null) 'platformData': platformData,
      };

  factory ChannelError.fromJson(Map<String, dynamic> json) {
    return ChannelError(
      code: json['code'] as String,
      message: json['message'] as String,
      retryable: json['retryable'] as bool? ?? false,
      retryAfter: json['retryAfterMs'] != null
          ? Duration(milliseconds: json['retryAfterMs'] as int)
          : null,
      platformData: json['platformData'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'ChannelError(code: $code, message: $message)';
}

/// Exception wrapper for ChannelError.
class ChannelException implements Exception {
  /// The underlying channel error.
  final ChannelError error;

  const ChannelException(this.error);

  @override
  String toString() => 'ChannelException: ${error.message} (${error.code})';
}
