import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2025, 1, 15, 10, 0, 0);

  group('SessionToolCall', () {
    test('creates with required fields', () {
      const call = SessionToolCall(
        name: 'search',
        arguments: {'query': 'test'},
      );
      expect(call.name, 'search');
      expect(call.arguments, {'query': 'test'});
      expect(call.id, isNull);
    });

    test('creates with optional ID', () {
      const call = SessionToolCall(
        name: 'search',
        arguments: {'query': 'test'},
        id: 'call_1',
      );
      expect(call.id, 'call_1');
    });

    test('serializes to JSON', () {
      const call = SessionToolCall(
        name: 'search',
        arguments: {'query': 'test'},
        id: 'call_1',
      );
      final json = call.toJson();
      expect(json['name'], 'search');
      expect(json['arguments'], {'query': 'test'});
      expect(json['id'], 'call_1');
    });

    test('serializes without optional fields', () {
      const call = SessionToolCall(
        name: 'search',
        arguments: {},
      );
      final json = call.toJson();
      expect(json.containsKey('id'), isFalse);
    });

    test('deserializes from JSON', () {
      final call = SessionToolCall.fromJson({
        'name': 'search',
        'arguments': {'query': 'test'},
        'id': 'call_1',
      });
      expect(call.name, 'search');
      expect(call.arguments['query'], 'test');
      expect(call.id, 'call_1');
    });

    test('round-trip serialization', () {
      const original = SessionToolCall(
        name: 'calc',
        arguments: {'x': 1, 'y': 2},
        id: 'c1',
      );
      final restored = SessionToolCall.fromJson(original.toJson());
      expect(restored.name, original.name);
      expect(restored.arguments, original.arguments);
      expect(restored.id, original.id);
    });

    test('toString contains name', () {
      const call = SessionToolCall(name: 'test', arguments: {});
      expect(call.toString(), contains('test'));
    });
  });

  group('SessionToolResult', () {
    test('creates with required fields', () {
      const result = SessionToolResult(
        toolName: 'search',
        content: 'found 3 results',
      );
      expect(result.toolName, 'search');
      expect(result.content, 'found 3 results');
      expect(result.success, true);
      expect(result.error, isNull);
    });

    test('creates with failure', () {
      const result = SessionToolResult(
        toolName: 'search',
        content: '',
        success: false,
        error: 'timeout',
      );
      expect(result.success, false);
      expect(result.error, 'timeout');
    });

    test('serializes to JSON', () {
      const result = SessionToolResult(
        toolName: 'search',
        content: 'ok',
        success: true,
      );
      final json = result.toJson();
      expect(json['toolName'], 'search');
      expect(json['content'], 'ok');
      expect(json['success'], true);
      expect(json.containsKey('error'), isFalse);
    });

    test('serializes error to JSON', () {
      const result = SessionToolResult(
        toolName: 'search',
        content: '',
        success: false,
        error: 'fail',
      );
      final json = result.toJson();
      expect(json['error'], 'fail');
    });

    test('deserializes from JSON', () {
      final result = SessionToolResult.fromJson({
        'toolName': 'search',
        'content': 'ok',
        'success': true,
      });
      expect(result.toolName, 'search');
      expect(result.success, true);
    });

    test('deserializes with missing success defaults to true', () {
      final result = SessionToolResult.fromJson({
        'toolName': 'search',
        'content': 'ok',
      });
      expect(result.success, true);
    });

    test('round-trip serialization', () {
      const original = SessionToolResult(
        toolName: 'calc',
        content: '42',
        success: true,
      );
      final restored = SessionToolResult.fromJson(original.toJson());
      expect(restored.toolName, original.toolName);
      expect(restored.content, original.content);
      expect(restored.success, original.success);
    });

    test('toString contains tool name', () {
      const result = SessionToolResult(toolName: 'x', content: 'y');
      expect(result.toString(), contains('x'));
    });
  });

  group('SessionMessage', () {
    test('creates user message', () {
      final msg = SessionMessage.user(
        content: 'hello',
        eventId: 'evt_1',
        timestamp: now,
      );
      expect(msg.role, MessageRole.user);
      expect(msg.content, 'hello');
      expect(msg.eventId, 'evt_1');
      expect(msg.timestamp, now);
    });

    test('creates assistant message', () {
      final toolCalls = [
        const SessionToolCall(name: 'search', arguments: {}),
      ];
      final msg = SessionMessage.assistant(
        content: 'response',
        toolCalls: toolCalls,
        timestamp: now,
      );
      expect(msg.role, MessageRole.assistant);
      expect(msg.toolCalls?.length, 1);
    });

    test('creates system message', () {
      final msg = SessionMessage.system(
        content: 'system prompt',
        timestamp: now,
      );
      expect(msg.role, MessageRole.system);
    });

    test('creates tool message', () {
      const result = SessionToolResult(
        toolName: 'search',
        content: 'found',
      );
      final msg = SessionMessage.tool(
        content: 'tool output',
        result: result,
        timestamp: now,
      );
      expect(msg.role, MessageRole.tool);
      expect(msg.toolResult?.toolName, 'search');
    });

    test('user message auto-generates timestamp', () {
      final msg = SessionMessage.user(content: 'hi', eventId: 'e1');
      expect(msg.timestamp, isNotNull);
    });

    test('assistant message auto-generates timestamp', () {
      final msg = SessionMessage.assistant(content: 'hi');
      expect(msg.timestamp, isNotNull);
    });

    test('system message auto-generates timestamp', () {
      final msg = SessionMessage.system(content: 'hi');
      expect(msg.timestamp, isNotNull);
    });

    test('tool message auto-generates timestamp', () {
      const result = SessionToolResult(toolName: 't', content: 'c');
      final msg = SessionMessage.tool(content: 'hi', result: result);
      expect(msg.timestamp, isNotNull);
    });

    test('copyWith creates modified copy', () {
      final original = SessionMessage.user(
        content: 'original',
        eventId: 'e1',
        timestamp: now,
      );
      final copy = original.copyWith(content: 'modified');
      expect(copy.content, 'modified');
      expect(copy.role, MessageRole.user);
      expect(copy.eventId, 'e1');
    });

    test('serializes to JSON', () {
      final msg = SessionMessage.user(
        content: 'hello',
        eventId: 'evt_1',
        timestamp: now,
        metadata: {'source': 'test'},
      );
      final json = msg.toJson();
      expect(json['role'], 'user');
      expect(json['content'], 'hello');
      expect(json['eventId'], 'evt_1');
      expect(json['metadata'], {'source': 'test'});
    });

    test('serializes without optional fields', () {
      final msg = SessionMessage.system(content: 'hi', timestamp: now);
      final json = msg.toJson();
      expect(json.containsKey('eventId'), isFalse);
      expect(json.containsKey('toolCalls'), isFalse);
      expect(json.containsKey('toolResult'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('serializes with toolCalls', () {
      final msg = SessionMessage.assistant(
        content: 'ok',
        toolCalls: [
          const SessionToolCall(name: 'search', arguments: {'q': 'a'}),
        ],
        timestamp: now,
      );
      final json = msg.toJson();
      expect(json['toolCalls'], isList);
      expect((json['toolCalls'] as List).length, 1);
    });

    test('deserializes from JSON', () {
      final msg = SessionMessage.fromJson({
        'role': 'user',
        'content': 'hello',
        'timestamp': now.toIso8601String(),
        'eventId': 'evt_1',
      });
      expect(msg.role, MessageRole.user);
      expect(msg.content, 'hello');
      expect(msg.eventId, 'evt_1');
    });

    test('deserializes with toolCalls', () {
      final msg = SessionMessage.fromJson({
        'role': 'assistant',
        'content': 'ok',
        'timestamp': now.toIso8601String(),
        'toolCalls': [
          {'name': 'search', 'arguments': {'q': 'test'}},
        ],
      });
      expect(msg.toolCalls?.length, 1);
      expect(msg.toolCalls?.first.name, 'search');
    });

    test('deserializes with toolResult', () {
      final msg = SessionMessage.fromJson({
        'role': 'tool',
        'content': 'result',
        'timestamp': now.toIso8601String(),
        'toolResult': {
          'toolName': 'search',
          'content': 'found',
          'success': true,
        },
      });
      expect(msg.toolResult?.toolName, 'search');
    });

    test('deserializes unknown role defaults to user', () {
      final msg = SessionMessage.fromJson({
        'role': 'invalid_role',
        'content': 'test',
        'timestamp': now.toIso8601String(),
      });
      expect(msg.role, MessageRole.user);
    });

    test('round-trip serialization with all fields', () {
      final original = SessionMessage(
        role: MessageRole.assistant,
        content: 'response',
        timestamp: now,
        toolCalls: [
          const SessionToolCall(
            name: 'search',
            arguments: {'q': 'test'},
            id: 'c1',
          ),
        ],
        metadata: {'key': 'value'},
      );
      final restored = SessionMessage.fromJson(original.toJson());
      expect(restored.role, original.role);
      expect(restored.content, original.content);
      expect(restored.toolCalls?.length, 1);
      expect(restored.metadata?['key'], 'value');
    });

    test('toString truncates long content', () {
      final msg = SessionMessage.user(
        content: 'A' * 100,
        eventId: 'e1',
      );
      final str = msg.toString();
      expect(str, contains('...'));
    });

    test('toString shows short content fully', () {
      final msg = SessionMessage.user(content: 'hi', eventId: 'e1');
      final str = msg.toString();
      expect(str, contains('hi'));
    });
  });

  group('MessageRole', () {
    test('has all expected values', () {
      expect(MessageRole.values, hasLength(4));
      expect(MessageRole.values, contains(MessageRole.user));
      expect(MessageRole.values, contains(MessageRole.assistant));
      expect(MessageRole.values, contains(MessageRole.system));
      expect(MessageRole.values, contains(MessageRole.tool));
    });
  });

  group('SessionState', () {
    test('has all expected values', () {
      expect(SessionState.values, hasLength(4));
      expect(SessionState.values, contains(SessionState.active));
      expect(SessionState.values, contains(SessionState.paused));
      expect(SessionState.values, contains(SessionState.expired));
      expect(SessionState.values, contains(SessionState.closed));
    });
  });

  group('ConcurrentModificationException', () {
    test('stores fields correctly', () {
      const ex = ConcurrentModificationException(
        sessionId: 'sess_1',
        expectedVersion: 2,
        actualVersion: 5,
      );
      expect(ex.sessionId, 'sess_1');
      expect(ex.expectedVersion, 2);
      expect(ex.actualVersion, 5);
    });

    test('toString contains relevant info', () {
      const ex = ConcurrentModificationException(
        sessionId: 'sess_1',
        expectedVersion: 2,
        actualVersion: 5,
      );
      final str = ex.toString();
      expect(str, contains('sess_1'));
      expect(str, contains('2'));
      expect(str, contains('5'));
    });
  });
}
