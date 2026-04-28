import 'package:mcp_bundle/ports.dart';

/// Types of PII that can be detected.
enum PiiType {
  email,
  phone,
  ssn,
  creditCard,
  ipAddress,
  name,
  address,
  dateOfBirth,
  custom,
}

/// Strategy for masking detected PII.
enum PiiMaskingStrategy {
  /// Replace entirely with asterisks: "john@example.com" -> "****************"
  full,

  /// Partial mask preserving structure: "john@example.com" -> "j***@e******.com"
  partial,

  /// Replace with consistent hash: "john@example.com" -> "[PII:a1b2c3d4]"
  hash,

  /// Replace with reversible token: "john@example.com" -> "[TOKEN:ref_123]"
  /// Requires a token store to reverse.
  tokenize,
}

/// A detected PII instance.
class PiiDetection {
  const PiiDetection({
    required this.type,
    required this.start,
    required this.end,
    required this.match,
    this.confidence = 1.0,
  });

  /// The type of PII detected.
  final PiiType type;

  /// Start index in the original text.
  final int start;

  /// End index in the original text.
  final int end;

  /// The original matched text.
  final String match;

  /// Confidence of the detection (0.0 - 1.0).
  final double confidence;
}

/// Protects Personally Identifiable Information (PII) in channel data.
///
/// Detects and masks PII in events and responses before they are
/// written to logs, metrics, or external storage. Does NOT modify
/// the actual event/response passed through the processing pipeline.
abstract interface class PiiProtector {
  /// Create a logging-safe copy of an event with PII masked.
  ChannelEvent protectEvent(ChannelEvent event);

  /// Create a logging-safe copy of a response with PII masked.
  ChannelResponse protectResponse(ChannelResponse response);

  /// Detect PII in text content.
  List<PiiDetection> detectPii(String text);
}

/// Built-in PII detection using regex patterns.
class RegexPiiDetector {
  static final Map<PiiType, RegExp> patterns = {
    PiiType.email:
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
    PiiType.phone: RegExp(
        r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}'),
    PiiType.ssn: RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
    PiiType.creditCard:
        RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'),
    PiiType.ipAddress:
        RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),
  };

  /// Detect PII in text using regex patterns.
  List<PiiDetection> detect(String text) {
    final detections = <PiiDetection>[];
    for (final entry in patterns.entries) {
      for (final match in entry.value.allMatches(text)) {
        detections.add(PiiDetection(
          type: entry.key,
          start: match.start,
          end: match.end,
          match: match.group(0)!,
        ));
      }
    }
    return detections;
  }
}
