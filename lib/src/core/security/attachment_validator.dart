import '../types/attachment.dart';

/// Result of attachment validation.
sealed class AttachmentValidationResult {
  const AttachmentValidationResult._();

  /// Attachment is allowed.
  factory AttachmentValidationResult.allowed() = AttachmentAllowed;

  /// Attachment is rejected.
  factory AttachmentValidationResult.rejected(String reason) =
      AttachmentRejected;
}

/// Attachment is valid and allowed.
final class AttachmentAllowed extends AttachmentValidationResult {
  const AttachmentAllowed() : super._();
}

/// Attachment is rejected.
final class AttachmentRejected extends AttachmentValidationResult {
  const AttachmentRejected(this.reason) : super._();

  /// Reason for rejection
  final String reason;
}

/// Validates file attachments in channel events.
class AttachmentValidator {
  const AttachmentValidator({
    this.maxFileSize = 10 * 1024 * 1024,
    this.allowedMimeTypes = const {},
    this.blockedMimeTypes = const {
      'application/x-executable',
      'application/x-msdownload',
      'application/x-sh',
    },
  });

  /// Maximum file size in bytes.
  final int maxFileSize;

  /// Allowed MIME types. Empty means all types allowed.
  final Set<String> allowedMimeTypes;

  /// Blocked MIME types (takes precedence over allowed).
  final Set<String> blockedMimeTypes;

  /// Validate an attachment.
  AttachmentValidationResult validate(Attachment attachment) {
    // Check file size if data is available
    if (attachment.data != null && attachment.data!.length > maxFileSize) {
      return AttachmentValidationResult.rejected(
        'File exceeds maximum size of $maxFileSize bytes',
      );
    }

    if (attachment.mimeType != null) {
      if (blockedMimeTypes.contains(attachment.mimeType)) {
        return AttachmentValidationResult.rejected(
          'File type ${attachment.mimeType} is not allowed',
        );
      }

      if (allowedMimeTypes.isNotEmpty &&
          !allowedMimeTypes.contains(attachment.mimeType)) {
        return AttachmentValidationResult.rejected(
          'File type ${attachment.mimeType} is not in allowed list',
        );
      }
    }

    return AttachmentValidationResult.allowed();
  }
}
