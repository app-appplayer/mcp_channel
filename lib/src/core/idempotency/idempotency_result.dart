import 'package:meta/meta.dart';

import '../types/channel_response.dart';

/// Result of idempotent event processing.
@immutable
class IdempotencyResult {
  /// Whether processing was successful
  final bool success;

  /// Response that was sent (if any)
  final ChannelResponse? response;

  /// Error information (if failed)
  final String? error;

  /// Custom result data
  final Map<String, dynamic>? data;

  const IdempotencyResult({
    required this.success,
    this.response,
    this.error,
    this.data,
  });

  /// Creates a successful result.
  factory IdempotencyResult.success({
    ChannelResponse? response,
    Map<String, dynamic>? data,
  }) {
    return IdempotencyResult(
      success: true,
      response: response,
      data: data,
    );
  }

  /// Creates a failed result.
  factory IdempotencyResult.failure({
    required String error,
    Map<String, dynamic>? data,
  }) {
    return IdempotencyResult(
      success: false,
      error: error,
      data: data,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (response != null) 'response': response!.toJson(),
        if (error != null) 'error': error,
        if (data != null) 'data': data,
      };

  factory IdempotencyResult.fromJson(Map<String, dynamic> json) {
    return IdempotencyResult(
      success: json['success'] as bool,
      response: json['response'] != null
          ? ChannelResponse.fromJson(json['response'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => success
      ? 'IdempotencyResult.success()'
      : 'IdempotencyResult.failure(error: $error)';
}
