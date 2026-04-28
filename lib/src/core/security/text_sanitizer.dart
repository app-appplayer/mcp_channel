/// Sanitizes text content to prevent injection attacks.
///
/// Handles: HTML injection, script injection, markdown injection,
/// control characters, and excessively long messages.
class TextSanitizer {
  const TextSanitizer({
    this.maxLength = 4000,
    this.stripHtml = true,
    this.escapeMarkdown = false,
    this.removeControlChars = true,
  });

  /// Maximum allowed message length. Messages exceeding this are truncated.
  final int maxLength;

  /// Whether to strip HTML tags from text.
  final bool stripHtml;

  /// Whether to escape special markdown characters.
  final bool escapeMarkdown;

  /// Whether to remove control characters (except newline, tab).
  final bool removeControlChars;

  static final RegExp _htmlTagPattern = RegExp(r'<[^>]*>');
  static final RegExp _controlCharPattern =
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _markdownPattern =
      RegExp(r'([*_~`\[\]()#>+\-=|{}!])');

  /// Sanitize text content.
  String sanitize(String text) {
    var result = text;

    if (removeControlChars) {
      // Keep \n and \t, remove other control characters
      result = result.replaceAll(_controlCharPattern, '');
    }

    if (stripHtml) {
      result = result.replaceAll(_htmlTagPattern, '');
    }

    if (escapeMarkdown) {
      result = result.replaceAllMapped(
        _markdownPattern,
        (m) => '\\${m[0]}',
      );
    }

    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result;
  }
}
