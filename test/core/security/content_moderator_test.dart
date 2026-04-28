import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

/// Test helper: a keyword-based content moderator.
///
/// Blocks content containing any blocked keyword, flags content containing
/// any flagged keyword, redacts content containing any redacted keyword,
/// and allows everything else.
class _KeywordModerator implements ContentModerator {
  const _KeywordModerator({
    this.blockedKeywords = const {},
    this.flaggedKeywords = const {},
    this.redactedKeywords = const {},
  });

  final Set<String> blockedKeywords;
  final Set<String> flaggedKeywords;
  final Set<String> redactedKeywords;

  @override
  Future<ModerationResult> moderateInbound(ChannelEvent event) async {
    return _moderate(event.text ?? '');
  }

  @override
  Future<ModerationResult> moderateOutbound(ChannelResponse response) async {
    return _moderate(response.text ?? '');
  }

  ModerationResult _moderate(String content) {
    final lowerContent = content.toLowerCase();

    // Check blocked keywords first
    for (final keyword in blockedKeywords) {
      if (lowerContent.contains(keyword.toLowerCase())) {
        return ModerationResult(
          action: ModerationAction.block,
          reason: 'contains blocked keyword: $keyword',
          flaggedCategories: const ['blocked_keyword'],
          confidence: 1.0,
        );
      }
    }

    // Check redacted keywords
    for (final keyword in redactedKeywords) {
      if (lowerContent.contains(keyword.toLowerCase())) {
        return ModerationResult(
          action: ModerationAction.redact,
          reason: 'contains redacted keyword: $keyword',
          flaggedCategories: const ['redacted_keyword'],
          replacementContent: content.replaceAll(
            RegExp(keyword, caseSensitive: false),
            '[REDACTED]',
          ),
          confidence: 0.9,
        );
      }
    }

    // Check flagged keywords
    for (final keyword in flaggedKeywords) {
      if (lowerContent.contains(keyword.toLowerCase())) {
        return ModerationResult(
          action: ModerationAction.flag,
          reason: 'contains flagged keyword: $keyword',
          flaggedCategories: const ['flagged_keyword'],
          confidence: 0.8,
        );
      }
    }

    return const ModerationResult(action: ModerationAction.allow);
  }
}

/// Helper to create a test ConversationKey.
ConversationKey _testConversation() => const ConversationKey(
      channel: ChannelIdentity(platform: 'test', channelId: 'ch1'),
      conversationId: 'conv1',
      userId: 'u1',
    );

/// Helper to create a test ChannelEvent with given text.
ChannelEvent _testEvent(String text) => ChannelEvent.message(
      id: 'evt-1',
      conversation: _testConversation(),
      text: text,
    );

/// Helper to create a test ChannelResponse with given text.
ChannelResponse _testResponse(String text) => ChannelResponse.text(
      conversation: _testConversation(),
      text: text,
    );

void main() {
  // TC-071: ModerationAction, ModerationResult, and ContentModerator tests
  group('ModerationAction', () {
    test('enum has exactly four values', () {
      expect(ModerationAction.values, hasLength(4));
    });

    test('enum values are allow, block, flag, and redact', () {
      expect(
        ModerationAction.values,
        containsAll([
          ModerationAction.allow,
          ModerationAction.block,
          ModerationAction.flag,
          ModerationAction.redact,
        ]),
      );
    });
  });

  group('ModerationResult', () {
    group('construction with allow action', () {
      test('creates result with allow action and null optionals', () {
        const result = ModerationResult(action: ModerationAction.allow);

        expect(result.action, equals(ModerationAction.allow));
        expect(result.reason, isNull);
        expect(result.flaggedCategories, isNull);
        expect(result.replacementContent, isNull);
        expect(result.confidence, isNull);
      });
    });

    group('construction with flag action', () {
      test('creates result with reason and flaggedCategories', () {
        const result = ModerationResult(
          action: ModerationAction.flag,
          reason: 'potentially harmful content',
          flaggedCategories: ['hate', 'violence'],
          confidence: 0.75,
        );

        expect(result.action, equals(ModerationAction.flag));
        expect(result.reason, equals('potentially harmful content'));
        expect(result.flaggedCategories, equals(['hate', 'violence']));
        expect(result.confidence, equals(0.75));
      });
    });

    group('construction with block action', () {
      test('creates result with confidence', () {
        const result = ModerationResult(
          action: ModerationAction.block,
          confidence: 0.99,
        );

        expect(result.action, equals(ModerationAction.block));
        expect(result.confidence, equals(0.99));
      });

      test('creates result with reason and flaggedCategories', () {
        const result = ModerationResult(
          action: ModerationAction.block,
          reason: 'explicit content detected',
          flaggedCategories: ['spam', 'explicit'],
        );

        expect(result.reason, equals('explicit content detected'));
        expect(result.flaggedCategories, equals(['spam', 'explicit']));
      });
    });

    group('construction with redact action', () {
      test('creates result with replacementContent', () {
        const result = ModerationResult(
          action: ModerationAction.redact,
          reason: 'profanity detected',
          replacementContent: 'This is a [REDACTED] message',
          confidence: 0.95,
        );

        expect(result.action, equals(ModerationAction.redact));
        expect(result.reason, equals('profanity detected'));
        expect(
          result.replacementContent,
          equals('This is a [REDACTED] message'),
        );
        expect(result.confidence, equals(0.95));
      });

      test('replacementContent can be set with flaggedCategories', () {
        const result = ModerationResult(
          action: ModerationAction.redact,
          flaggedCategories: ['profanity'],
          replacementContent: 'cleaned text',
        );

        expect(result.flaggedCategories, equals(['profanity']));
        expect(result.replacementContent, equals('cleaned text'));
      });
    });
  });

  group('ContentModerator', () {
    late _KeywordModerator moderator;

    setUp(() {
      moderator = const _KeywordModerator(
        blockedKeywords: {'forbidden', 'banned'},
        flaggedKeywords: {'suspicious', 'caution'},
        redactedKeywords: {'secret'},
      );
    });

    group('moderateInbound', () {
      test('allows event without any keywords', () async {
        final result = await moderator.moderateInbound(
          _testEvent('Hello, this is a normal message'),
        );

        expect(result.action, equals(ModerationAction.allow));
        expect(result.reason, isNull);
        expect(result.flaggedCategories, isNull);
      });

      test('blocks event containing a blocked keyword', () async {
        final result = await moderator.moderateInbound(
          _testEvent('This contains a forbidden word'),
        );

        expect(result.action, equals(ModerationAction.block));
        expect(result.reason, contains('forbidden'));
        expect(result.flaggedCategories, contains('blocked_keyword'));
        expect(result.confidence, equals(1.0));
      });

      test('flags event containing a flagged keyword', () async {
        final result = await moderator.moderateInbound(
          _testEvent('This message is suspicious'),
        );

        expect(result.action, equals(ModerationAction.flag));
        expect(result.reason, contains('suspicious'));
        expect(result.flaggedCategories, contains('flagged_keyword'));
        expect(result.confidence, equals(0.8));
      });

      test('redacts event containing a redacted keyword', () async {
        final result = await moderator.moderateInbound(
          _testEvent('This is a secret message'),
        );

        expect(result.action, equals(ModerationAction.redact));
        expect(result.reason, contains('secret'));
        expect(result.replacementContent, contains('[REDACTED]'));
        expect(result.confidence, equals(0.9));
      });

      test('blocked keyword takes priority over flagged keyword', () async {
        final result = await moderator.moderateInbound(
          _testEvent('This is both suspicious and forbidden'),
        );

        expect(result.action, equals(ModerationAction.block));
        expect(result.reason, contains('forbidden'));
      });

      test('keyword matching is case-insensitive', () async {
        final result = await moderator.moderateInbound(
          _testEvent('BANNED content here'),
        );

        expect(result.action, equals(ModerationAction.block));
        expect(result.reason, contains('banned'));
      });
    });

    group('moderateOutbound', () {
      test('allows response without any keywords', () async {
        final result = await moderator.moderateOutbound(
          _testResponse('Here is a safe reply'),
        );

        expect(result.action, equals(ModerationAction.allow));
      });

      test('blocks response containing a blocked keyword', () async {
        final result = await moderator.moderateOutbound(
          _testResponse('This response is forbidden'),
        );

        expect(result.action, equals(ModerationAction.block));
        expect(result.reason, contains('forbidden'));
      });

      test('flags response containing a flagged keyword', () async {
        final result = await moderator.moderateOutbound(
          _testResponse('This reply is suspicious'),
        );

        expect(result.action, equals(ModerationAction.flag));
        expect(result.reason, contains('suspicious'));
      });

      test('redacts response containing a redacted keyword', () async {
        final result = await moderator.moderateOutbound(
          _testResponse('The secret is here'),
        );

        expect(result.action, equals(ModerationAction.redact));
        expect(result.replacementContent, contains('[REDACTED]'));
      });
    });
  });
}
