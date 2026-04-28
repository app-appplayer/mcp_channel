import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

/// TC-072: PII Protector tests
void main() {
  group('PiiType', () {
    test('has all expected values', () {
      expect(PiiType.values, hasLength(9));
      expect(PiiType.email, isNotNull);
      expect(PiiType.phone, isNotNull);
      expect(PiiType.ssn, isNotNull);
      expect(PiiType.creditCard, isNotNull);
      expect(PiiType.ipAddress, isNotNull);
      expect(PiiType.name, isNotNull);
      expect(PiiType.address, isNotNull);
      expect(PiiType.dateOfBirth, isNotNull);
      expect(PiiType.custom, isNotNull);
    });
  });

  group('PiiMaskingStrategy', () {
    test('has all expected values', () {
      expect(PiiMaskingStrategy.values, hasLength(4));
      expect(PiiMaskingStrategy.full, isNotNull);
      expect(PiiMaskingStrategy.partial, isNotNull);
      expect(PiiMaskingStrategy.hash, isNotNull);
      expect(PiiMaskingStrategy.tokenize, isNotNull);
    });
  });

  group('PiiDetection', () {
    test('constructor sets all required fields', () {
      const detection = PiiDetection(
        type: PiiType.email,
        start: 5,
        end: 21,
        match: 'test@example.com',
      );

      expect(detection.type, PiiType.email);
      expect(detection.start, 5);
      expect(detection.end, 21);
      expect(detection.match, 'test@example.com');
    });

    test('confidence defaults to 1.0', () {
      const detection = PiiDetection(
        type: PiiType.phone,
        start: 0,
        end: 12,
        match: '555-123-4567',
      );

      expect(detection.confidence, 1.0);
    });

    test('custom confidence is stored', () {
      const detection = PiiDetection(
        type: PiiType.ssn,
        start: 4,
        end: 15,
        match: '123-45-6789',
        confidence: 0.85,
      );

      expect(detection.confidence, 0.85);
    });

    test('custom PiiType is supported', () {
      const detection = PiiDetection(
        type: PiiType.custom,
        start: 0,
        end: 10,
        match: 'custom-pii',
        confidence: 0.7,
      );

      expect(detection.type, PiiType.custom);
      expect(detection.match, 'custom-pii');
      expect(detection.confidence, 0.7);
    });
  });

  group('RegexPiiDetector', () {
    late RegexPiiDetector detector;

    setUp(() {
      detector = RegexPiiDetector();
    });

    group('detect email addresses', () {
      test('detects a single email address', () {
        final detections = detector.detect('Contact us at info@example.com');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.email);
        expect(detections[0].match, 'info@example.com');
      });

      test('detects email with subdomains and plus addressing', () {
        final detections =
            detector.detect('Send to user+tag@mail.sub.example.org please');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.email);
        expect(detections[0].match, 'user+tag@mail.sub.example.org');
      });
    });

    group('detect phone numbers', () {
      test('detects standard US phone number with dashes', () {
        final detections = detector.detect('Call 555-123-4567 for details');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.phone);
        expect(detections[0].match, '555-123-4567');
      });

      test('detects phone number with parentheses', () {
        final detections = detector.detect('Phone: (555) 123-4567');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.phone);
        expect(detections[0].match, '(555) 123-4567');
      });

      test('detects phone number with country code', () {
        final detections = detector.detect('Dial +1-555-123-4567 now');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.phone);
        expect(detections[0].match, '+1-555-123-4567');
      });

      test('detects phone number with dots', () {
        final detections = detector.detect('Fax: 555.123.4567');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.phone);
        expect(detections[0].match, '555.123.4567');
      });
    });

    group('detect credit card numbers', () {
      test('detects credit card with dashes', () {
        final detections = detector.detect('Card: 4111-1111-1111-1111');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.creditCard);
        expect(detections[0].match, '4111-1111-1111-1111');
      });

      test('detects credit card with spaces', () {
        final detections =
            detector.detect('CC 5500 0000 0000 0004 on file');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.creditCard);
        expect(detections[0].match, '5500 0000 0000 0004');
      });
    });

    group('detect IP addresses', () {
      test('detects standard IPv4 address', () {
        final detections = detector.detect('Server at 192.168.1.1 is down');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.ipAddress);
        expect(detections[0].match, '192.168.1.1');
      });

      test('detects loopback IP address', () {
        final detections = detector.detect('localhost is 127.0.0.1');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.ipAddress);
        expect(detections[0].match, '127.0.0.1');
      });
    });

    group('detect SSN', () {
      test('detects SSN with dashes', () {
        final detections = detector.detect('SSN: 123-45-6789');

        expect(detections, hasLength(1));
        expect(detections[0].type, PiiType.ssn);
        expect(detections[0].match, '123-45-6789');
      });
    });

    group('no detections in clean text', () {
      test('returns empty list for text without PII', () {
        final detections = detector.detect(
          'This is a perfectly normal sentence with no sensitive data.',
        );

        expect(detections, isEmpty);
      });
    });

    group('multiple detections', () {
      test('detects multiple PII types in a single text', () {
        const text =
            'Email: user@test.com, Phone: 555-123-4567, IP: 10.0.0.1';
        final detections = detector.detect(text);

        expect(detections.length, greaterThanOrEqualTo(3));

        final types = detections.map((d) => d.type).toSet();
        expect(types, contains(PiiType.email));
        expect(types, contains(PiiType.phone));
        expect(types, contains(PiiType.ipAddress));
      });
    });

    group('detection positions', () {
      test('start and end indices are correct', () {
        const text = 'Email: user@test.com here';
        final detections = detector.detect(text);

        expect(detections, hasLength(1));
        final detection = detections[0];
        expect(detection.start, text.indexOf('user@test.com'));
        expect(detection.end, detection.start + 'user@test.com'.length);
        expect(detection.match, 'user@test.com');
      });
    });

    group('static patterns map', () {
      test('contains patterns for known PII types', () {
        expect(RegexPiiDetector.patterns, containsPair(PiiType.email, isA<RegExp>()));
        expect(RegexPiiDetector.patterns, containsPair(PiiType.phone, isA<RegExp>()));
        expect(RegexPiiDetector.patterns, containsPair(PiiType.ssn, isA<RegExp>()));
        expect(RegexPiiDetector.patterns, containsPair(PiiType.creditCard, isA<RegExp>()));
        expect(RegexPiiDetector.patterns, containsPair(PiiType.ipAddress, isA<RegExp>()));
      });
    });
  });
}
