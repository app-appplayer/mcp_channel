import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  const channelIdentity = ChannelIdentity(
    platform: 'test',
    channelId: 'C1',
  );

  const conversation = ConversationKey(
    channel: channelIdentity,
    conversationId: 'conv-1',
    userId: 'U1',
  );

  // ---------------------------------------------------------------------------
  // TC-055: ToolExecutionMode enum
  // ---------------------------------------------------------------------------
  group('TC-055: ToolExecutionMode', () {
    test('TC-055.1: has exactly two values', () {
      expect(ToolExecutionMode.values, hasLength(2));
    });

    test('TC-055.2: contains sequential and parallel', () {
      expect(
        ToolExecutionMode.values,
        containsAll([ToolExecutionMode.sequential, ToolExecutionMode.parallel]),
      );
    });

    test('TC-055.3: sequential has index 0', () {
      expect(ToolExecutionMode.sequential.index, 0);
    });

    test('TC-055.4: parallel has index 1', () {
      expect(ToolExecutionMode.parallel.index, 1);
    });

    test('TC-055.5: values have correct names', () {
      expect(ToolExecutionMode.sequential.name, 'sequential');
      expect(ToolExecutionMode.parallel.name, 'parallel');
    });
  });

  // ---------------------------------------------------------------------------
  // TC-056: ToolRequest
  // ---------------------------------------------------------------------------
  group('TC-056: ToolRequest', () {
    test('TC-056.1: constructor sets toolName', () {
      const request = ToolRequest(
        id: 'tr',
        toolName: 'search',
        arguments: {'query': 'dart'},
      );
      expect(request.toolName, 'search');
    });

    test('TC-056.2: constructor sets arguments', () {
      const request = ToolRequest(
        id: 'tr',
        toolName: 'calculate',
        arguments: {'expression': '2+2'},
      );
      expect(request.arguments, {'expression': '2+2'});
    });

    test('TC-056.3: arguments can be empty map', () {
      const request = ToolRequest(
        id: 'tr',
        toolName: 'ping',
        arguments: <String, dynamic>{},
      );
      expect(request.arguments, isEmpty);
    });

    test('TC-056.4: arguments can contain nested values', () {
      const request = ToolRequest(
        id: 'tr',
        toolName: 'complex-tool',
        arguments: {
          'name': 'test',
          'options': {'verbose': true, 'limit': 10},
        },
      );
      expect(request.toolName, 'complex-tool');
      expect(request.arguments['name'], 'test');
      expect(
        (request.arguments['options'] as Map)['verbose'],
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TC-057: NeedsToolsResult and NeedsAgenticLoopResult
  // ---------------------------------------------------------------------------
  group('TC-057: NeedsToolsResult', () {
    test('TC-057.1: ProcessResult.needsTools factory creates NeedsToolsResult',
        () {
      final result = ProcessResult.needsTools(
        tools: const [
          ToolRequest(id: 'tr', toolName: 'search', arguments: {'q': 'test'}),
        ],
      );
      expect(result, isA<NeedsToolsResult>());
    });

    test('TC-057.2: default mode is sequential', () {
      final result = ProcessResult.needsTools(
        tools: const [
          ToolRequest(id: 'tr', toolName: 'search', arguments: {'q': 'test'}),
        ],
      );
      final needsTools = result as NeedsToolsResult;
      expect(needsTools.mode, ToolExecutionMode.sequential);
    });

    test('TC-057.3: explicit parallel mode', () {
      final result = ProcessResult.needsTools(
        tools: const [
          ToolRequest(id: 'tr', toolName: 'a', arguments: {}),
          ToolRequest(id: 'tr', toolName: 'b', arguments: {}),
        ],
        mode: ToolExecutionMode.parallel,
      );
      final needsTools = result as NeedsToolsResult;
      expect(needsTools.mode, ToolExecutionMode.parallel);
    });

    test('TC-057.4: tools list is accessible', () {
      final result = ProcessResult.needsTools(
        tools: const [
          ToolRequest(id: 'tr', toolName: 'search', arguments: {'q': 'dart'}),
          ToolRequest(id: 'tr', toolName: 'fetch', arguments: {'url': 'https://x.com'}),
        ],
      );
      final needsTools = result as NeedsToolsResult;
      expect(needsTools.tools, hasLength(2));
      expect(needsTools.tools[0].toolName, 'search');
      expect(needsTools.tools[0].arguments, {'q': 'dart'});
      expect(needsTools.tools[1].toolName, 'fetch');
      expect(needsTools.tools[1].arguments, {'url': 'https://x.com'});
    });

    test('TC-057.5: multiple ToolRequests in a single NeedsToolsResult', () {
      final result = ProcessResult.needsTools(
        tools: const [
          ToolRequest(id: 'tr', toolName: 'tool-a', arguments: {'key': 'val-a'}),
          ToolRequest(id: 'tr', toolName: 'tool-b', arguments: {'key': 'val-b'}),
          ToolRequest(id: 'tr', toolName: 'tool-c', arguments: {'key': 'val-c'}),
        ],
        mode: ToolExecutionMode.parallel,
      );
      final needsTools = result as NeedsToolsResult;
      expect(needsTools.tools, hasLength(3));
      expect(
        needsTools.tools.map((t) => t.toolName).toList(),
        ['tool-a', 'tool-b', 'tool-c'],
      );
    });

    test('TC-057.6: empty tools list in NeedsToolsResult', () {
      final result = ProcessResult.needsTools(
        tools: const <ToolRequest>[],
      );
      final needsTools = result as NeedsToolsResult;
      expect(needsTools.tools, isEmpty);
      expect(needsTools.mode, ToolExecutionMode.sequential);
    });

    test('TC-057.7: pattern matching on NeedsToolsResult', () {
      final result = ProcessResult.needsTools(
        tools: const [
          ToolRequest(id: 'tr', toolName: 'search', arguments: {'q': 'hello'}),
        ],
        mode: ToolExecutionMode.parallel,
      );

      List<ToolRequest>? matchedTools;
      ToolExecutionMode? matchedMode;
      switch (result) {
        case NeedsToolsResult(:final tools, :final mode):
          matchedTools = tools;
          matchedMode = mode;
        default:
          break;
      }
      expect(matchedTools, isNotNull);
      expect(matchedTools, hasLength(1));
      expect(matchedTools![0].toolName, 'search');
      expect(matchedMode, ToolExecutionMode.parallel);
    });
  });

  group('TC-057: NeedsAgenticLoopResult', () {
    test(
        'TC-057.8: ProcessResult.needsAgenticLoop factory creates NeedsAgenticLoopResult',
        () {
      final result = ProcessResult.needsAgenticLoop(initialTools: const [ToolRequest(id: 'tr', toolName: 'init', arguments: {})]);
      expect(result, isA<NeedsAgenticLoopResult>());
    });

    test('TC-057.9: pattern matching on NeedsAgenticLoopResult', () {
      final result = ProcessResult.needsAgenticLoop(initialTools: const [ToolRequest(id: 'tr', toolName: 'init', arguments: {})]);

      var matched = false;
      switch (result) {
        case NeedsAgenticLoopResult():
          matched = true;
        default:
          matched = false;
      }
      expect(matched, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-057: Exhaustive pattern matching with all ProcessResult subtypes
  // ---------------------------------------------------------------------------
  group('TC-057: exhaustive pattern matching with all subtypes', () {
    test('TC-057.10: all six subtypes handled in switch', () {
      final results = <ProcessResult>[
        ProcessResult.respond(
          ChannelResponse.text(
            conversation: conversation,
            text: 'hello',
          ),
        ),
        ProcessResult.defer(),
        ProcessResult.ignore(),
        ProcessResult.needsTool(
          toolName: 'single-tool',
          arguments: {'key': 'value'},
        ),
        ProcessResult.needsTools(
          tools: const [
            ToolRequest(id: 'tr', toolName: 'multi-a', arguments: {}),
            ToolRequest(id: 'tr', toolName: 'multi-b', arguments: {}),
          ],
          mode: ToolExecutionMode.parallel,
        ),
        ProcessResult.needsAgenticLoop(initialTools: const [ToolRequest(id: 'tr', toolName: 'init', arguments: {})]),
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

    test('TC-057.11: existing ProcessResult.respond still works', () {
      final response = ChannelResponse.text(
        conversation: conversation,
        text: 'existing',
      );
      final result = ProcessResult.respond(response);
      expect(result, isA<RespondResult>());
      expect((result as RespondResult).response.text, 'existing');
    });

    test('TC-057.12: existing ProcessResult.defer still works', () {
      final result = ProcessResult.defer();
      expect(result, isA<DeferResult>());
    });

    test('TC-057.13: existing ProcessResult.ignore still works', () {
      final result = ProcessResult.ignore();
      expect(result, isA<IgnoreResult>());
    });

    test('TC-057.14: existing ProcessResult.needsTool still works', () {
      final result = ProcessResult.needsTool(
        toolName: 'legacy-tool',
        arguments: {'arg': 'val'},
      );
      expect(result, isA<NeedsToolResult>());
      final tool = result as NeedsToolResult;
      expect(tool.toolName, 'legacy-tool');
      expect(tool.arguments, {'arg': 'val'});
    });
  });
}
