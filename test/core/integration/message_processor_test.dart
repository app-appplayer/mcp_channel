import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  final channelIdentity = ChannelIdentity(
    platform: 'test',
    channelId: 'C1',
  );

  final conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'conv-1',
    userId: 'U1',
  );

  // ---------------------------------------------------------------------------
  // ProcessResult sealed class and subtypes
  // ---------------------------------------------------------------------------
  group('ProcessResult', () {
    group('RespondResult', () {
      test('factory constructor creates RespondResult', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Hello',
        );
        final result = ProcessResult.respond(response);
        expect(result, isA<RespondResult>());
      });

      test('has response field', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'World',
        );
        final result = ProcessResult.respond(response);
        final respond = result as RespondResult;
        expect(respond.response, response);
        expect(respond.response.text, 'World');
      });

      test('pattern matching on RespondResult', () {
        final response = ChannelResponse.text(
          conversation: conversation,
          text: 'Match',
        );
        final result = ProcessResult.respond(response);

        String? matched;
        switch (result) {
          case RespondResult(:final response):
            matched = response.text;
          case DeferResult():
            matched = 'defer';
          case IgnoreResult():
            matched = 'ignore';
          case NeedsToolResult():
            matched = 'tool';
          case NeedsToolsResult():
            matched = 'tools';
          case NeedsAgenticLoopResult():
            matched = 'agentic';
        }
        expect(matched, 'Match');
      });
    });

    group('DeferResult', () {
      test('factory constructor creates DeferResult', () {
        final result = ProcessResult.defer();
        expect(result, isA<DeferResult>());
      });

      test('pattern matching on DeferResult', () {
        final result = ProcessResult.defer();

        var matched = false;
        switch (result) {
          case DeferResult():
            matched = true;
          default:
            matched = false;
        }
        expect(matched, isTrue);
      });
    });

    group('IgnoreResult', () {
      test('factory constructor creates IgnoreResult', () {
        final result = ProcessResult.ignore();
        expect(result, isA<IgnoreResult>());
      });

      test('pattern matching on IgnoreResult', () {
        final result = ProcessResult.ignore();

        var matched = false;
        switch (result) {
          case IgnoreResult():
            matched = true;
          default:
            matched = false;
        }
        expect(matched, isTrue);
      });
    });

    group('NeedsToolResult', () {
      test('factory constructor creates NeedsToolResult', () {
        final result = ProcessResult.needsTool(
          toolName: 'search',
          arguments: {'query': 'dart'},
        );
        expect(result, isA<NeedsToolResult>());
      });

      test('has toolName and arguments fields', () {
        final result = ProcessResult.needsTool(
          toolName: 'calculate',
          arguments: {'expression': '2+2'},
        );
        final tool = result as NeedsToolResult;
        expect(tool.toolName, 'calculate');
        expect(tool.arguments, {'expression': '2+2'});
      });

      test('pattern matching on NeedsToolResult', () {
        final result = ProcessResult.needsTool(
          toolName: 'lookup',
          arguments: {'id': '123'},
        );

        String? matchedToolName;
        Map<String, dynamic>? matchedArgs;
        switch (result) {
          case NeedsToolResult(:final toolName, :final arguments):
            matchedToolName = toolName;
            matchedArgs = arguments;
          default:
            break;
        }
        expect(matchedToolName, 'lookup');
        expect(matchedArgs, {'id': '123'});
      });
    });

    group('exhaustive pattern matching', () {
      test('all subtypes handled', () {
        final results = <ProcessResult>[
          ProcessResult.respond(
            ChannelResponse.text(
              conversation: conversation,
              text: 'text',
            ),
          ),
          ProcessResult.defer(),
          ProcessResult.ignore(),
          ProcessResult.needsTool(
            toolName: 'tool',
            arguments: {},
          ),
          ProcessResult.needsTools(
            tools: [const ToolRequest(id: 'tr-a', toolName: 'a', arguments: {})],
          ),
          ProcessResult.needsAgenticLoop(
            initialTools: const [ToolRequest(id: 'tr-init', toolName: 'init', arguments: {})],
          ),
        ];

        final types = <String>[];
        for (final result in results) {
          switch (result) {
            case RespondResult():
              types.add('respond');
            case DeferResult():
              types.add('defer');
            case IgnoreResult():
              types.add('ignore');
            case NeedsToolResult():
              types.add('needsTool');
            case NeedsToolsResult():
              types.add('needsTools');
            case NeedsAgenticLoopResult():
              types.add('needsAgenticLoop');
          }
        }

        expect(types, [
          'respond',
          'defer',
          'ignore',
          'needsTool',
          'needsTools',
          'needsAgenticLoop',
        ]);
      });
    });
  });
}
