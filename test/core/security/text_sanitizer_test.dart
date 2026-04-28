import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('TextSanitizer', () {
    // TC-068: Default configuration strips HTML tags
    group('HTML stripping', () {
      test('default config strips HTML tags', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize('Hello <b>world</b>!');

        expect(result, equals('Hello world!'));
      });

      // TC-172: Strip nested HTML tags
      test('strips nested HTML tags', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize(
          '<div><p>Hello <span>nested</span> world</p></div>',
        );

        expect(result, equals('Hello nested world'));
      });

      test('preserves text without HTML', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize('Plain text with no tags');

        expect(result, equals('Plain text with no tags'));
      });

      test('stripHtml disabled preserves tags', () {
        const sanitizer = TextSanitizer(stripHtml: false);

        final result = sanitizer.sanitize('Hello <b>world</b>!');

        expect(result, equals('Hello <b>world</b>!'));
      });
    });

    // TC-173: Control character handling
    group('control character removal', () {
      test('removes control characters', () {
        const sanitizer = TextSanitizer();

        // \x00 (null), \x07 (bell), \x1F (unit separator)
        final result = sanitizer.sanitize('Hello\x00\x07\x1Fworld');

        expect(result, equals('Helloworld'));
      });

      test('preserves newline and tab', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize('Hello\n\tworld');

        expect(result, equals('Hello\n\tworld'));
      });

      test('preserves carriage return', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize('Hello\rworld');

        expect(result, equals('Hello\rworld'));
      });

      test('removeControlChars disabled preserves control chars', () {
        const sanitizer = TextSanitizer(removeControlChars: false);

        final result = sanitizer.sanitize('Hello\x07world');

        expect(result, equals('Hello\x07world'));
      });
    });

    // TC-174: maxLength truncation
    group('maxLength truncation', () {
      test('truncates text exceeding maxLength', () {
        const sanitizer = TextSanitizer(maxLength: 5);

        final result = sanitizer.sanitize('Hello world');

        expect(result, equals('Hello'));
      });

      test('default maxLength is 4000', () {
        const sanitizer = TextSanitizer();

        expect(sanitizer.maxLength, equals(4000));
      });

      test('text at default maxLength is not truncated', () {
        const sanitizer = TextSanitizer();

        final text = 'A' * 4000;
        final result = sanitizer.sanitize(text);

        expect(result.length, equals(4000));
        expect(result, equals(text));
      });

      test('text exceeding default maxLength is truncated', () {
        const sanitizer = TextSanitizer();

        final text = 'A' * 5000;
        final result = sanitizer.sanitize(text);

        expect(result.length, equals(4000));
      });

      test('does not truncate text shorter than maxLength', () {
        const sanitizer = TextSanitizer(maxLength: 100);

        final result = sanitizer.sanitize('Short text');

        expect(result, equals('Short text'));
      });
    });

    group('markdown escaping', () {
      test('escapeMarkdown disabled by default', () {
        const sanitizer = TextSanitizer();

        expect(sanitizer.escapeMarkdown, isFalse);
      });

      test('does not escape markdown characters when disabled', () {
        const sanitizer = TextSanitizer(escapeMarkdown: false);

        final result = sanitizer.sanitize('**bold** and _italic_');

        expect(result, equals('**bold** and _italic_'));
      });

      test('escapes asterisks when enabled', () {
        const sanitizer = TextSanitizer(escapeMarkdown: true);

        final result = sanitizer.sanitize('**bold**');

        expect(result, equals('\\*\\*bold\\*\\*'));
      });

      test('escapes underscores when enabled', () {
        const sanitizer = TextSanitizer(escapeMarkdown: true);

        final result = sanitizer.sanitize('_italic_');

        expect(result, equals('\\_italic\\_'));
      });

      test('escapes backticks when enabled', () {
        const sanitizer = TextSanitizer(escapeMarkdown: true);

        final result = sanitizer.sanitize('`code`');

        expect(result, equals('\\`code\\`'));
      });

      test('escapes square brackets and parentheses when enabled', () {
        const sanitizer = TextSanitizer(escapeMarkdown: true);

        final result = sanitizer.sanitize('[link](url)');

        expect(result, equals('\\[link\\]\\(url\\)'));
      });

      test('escapes hash symbols when enabled', () {
        const sanitizer = TextSanitizer(escapeMarkdown: true);

        final result = sanitizer.sanitize('# Heading');

        expect(result, equals('\\# Heading'));
      });

      test('escapes multiple markdown characters in mixed text', () {
        const sanitizer = TextSanitizer(escapeMarkdown: true);

        final result = sanitizer.sanitize('Use **bold** and `code`');

        expect(result, equals('Use \\*\\*bold\\*\\* and \\`code\\`'));
      });
    });

    group('all options disabled', () {
      test('returns text as-is when all options are disabled', () {
        const sanitizer = TextSanitizer(
          stripHtml: false,
          removeControlChars: false,
          escapeMarkdown: false,
        );

        const input = '<b>Hello\x07</b>  \n  world';
        final result = sanitizer.sanitize(input);

        // maxLength still applies (default 4000), but input is short
        expect(result, equals(input));
      });
    });

    group('combined sanitization', () {
      test('applies control char removal and HTML stripping', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize(
          '  <p>Hello\x00 world</p>  ',
        );

        // Control chars removed, HTML stripped, no trimming
        expect(result, equals('  Hello world  '));
      });

      test('applies HTML stripping then markdown escaping', () {
        const sanitizer = TextSanitizer(escapeMarkdown: true);

        final result = sanitizer.sanitize('<b>**bold**</b>');

        // HTML stripped first, then markdown escaped
        expect(result, equals('\\*\\*bold\\*\\*'));
      });

      test('applies all steps in order: control chars, HTML, markdown, maxLength', () {
        const sanitizer = TextSanitizer(
          maxLength: 10,
          escapeMarkdown: true,
        );

        final result = sanitizer.sanitize('<p>\x07**hi**</p>');

        // 1. Remove control chars: '<p>**hi**</p>'
        // 2. Strip HTML: '**hi**'
        // 3. Escape markdown: '\*\*hi\*\*'
        // 4. Truncate to 10: '\*\*hi\*\*' (length 10, fits exactly)
        expect(result, equals('\\*\\*hi\\*\\*'));
      });
    });

    group('edge cases', () {
      test('handles empty string', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize('');

        expect(result, equals(''));
      });

      test('handles string that becomes empty after sanitization', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize('<br>');

        expect(result, equals(''));
      });

      test('preserves leading and trailing whitespace', () {
        const sanitizer = TextSanitizer();

        final result = sanitizer.sanitize('  Hello world  ');

        // No trimming in new implementation
        expect(result, equals('  Hello world  '));
      });
    });
  });
}
