import 'package:meta/meta.dart';

import 'channel_error.dart';

/// Result of sending a response to a channel.
@immutable
class SendResult {
  const SendResult({
    required this.success,
    this.messageId,
    this.error,
    this.timestamp,
    this.platformData,
  });

  /// Creates a successful send result.
  factory SendResult.success({
    required String messageId,
    DateTime? timestamp,
    Map<String, dynamic>? platformData,
  }) {
    return SendResult(
      success: true,
      messageId: messageId,
      timestamp: timestamp ?? DateTime.now(),
      platformData: platformData,
    );
  }

  /// Creates a failed send result.
  factory SendResult.failure({
    required ChannelError error,
    Map<String, dynamic>? platformData,
  }) {
    return SendResult(
      success: false,
      error: error,
      platformData: platformData,
    );
  }

  factory SendResult.fromJson(Map<String, dynamic> json) {
    return SendResult(
      success: json['success'] as bool,
      messageId: json['messageId'] as String?,
      error: json['error'] != null
          ? ChannelError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      platformData: json['platformData'] as Map<String, dynamic>?,
    );
  }

  /// Whether the send was successful
  final bool success;

  /// Platform message ID (if successful)
  final String? messageId;

  /// Error information (if failed)
  final ChannelError? error;

  /// Timestamp when message was sent
  final DateTime? timestamp;

  /// Platform-specific response data
  final Map<String, dynamic>? platformData;

  Map<String, dynamic> toJson() => {
        'success': success,
        if (messageId != null) 'messageId': messageId,
        if (error != null) 'error': error!.toJson(),
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
        if (platformData != null) 'platformData': platformData,
      };

  @override
  String toString() => success
      ? 'SendResult.success(messageId: $messageId)'
      : 'SendResult.failure(error: ${error?.code})';
}
