import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ToolDefinition
  // ---------------------------------------------------------------------------
  group('ToolDefinition', () {
    test('constructor with required fields only', () {
      const def = ToolDefinition(
        name: 'my-tool',
        description: 'A test tool',
      );
      expect(def.name, 'my-tool');
      expect(def.description, 'A test tool');
      expect(def.parameters, isNull);
    });

    test('constructor with parameters', () {
      const def = ToolDefinition(
        name: 'search',
        description: 'Search tool',
        parameters: {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
          },
        },
      );
      expect(def.name, 'search');
      expect(def.description, 'Search tool');
      expect(def.parameters, isNotNull);
      expect(def.parameters!['type'], 'object');
    });

    group('fromJson', () {
      test('without parameters', () {
        final json = {
          'name': 'echo',
          'description': 'Echo tool',
        };
        final def = ToolDefinition.fromJson(json);
        expect(def.name, 'echo');
        expect(def.description, 'Echo tool');
        expect(def.parameters, isNull);
      });

      test('with parameters', () {
        final json = {
          'name': 'calc',
          'description': 'Calculator',
          'parameters': {
            'type': 'object',
            'properties': {
              'expression': {'type': 'string'},
            },
          },
        };
        final def = ToolDefinition.fromJson(json);
        expect(def.name, 'calc');
        expect(def.description, 'Calculator');
        expect(def.parameters, isNotNull);
        expect(
          (def.parameters!['properties'] as Map)['expression'],
          {'type': 'string'},
        );
      });
    });

    group('toJson', () {
      test('without parameters', () {
        const def = ToolDefinition(
          name: 'simple',
          description: 'Simple tool',
        );
        final json = def.toJson();
        expect(json['name'], 'simple');
        expect(json['description'], 'Simple tool');
        expect(json.containsKey('parameters'), isFalse);
      });

      test('with parameters', () {
        const def = ToolDefinition(
          name: 'complex',
          description: 'Complex tool',
          parameters: {'type': 'object'},
        );
        final json = def.toJson();
        expect(json['name'], 'complex');
        expect(json['description'], 'Complex tool');
        expect(json['parameters'], {'type': 'object'});
      });
    });
  });

  // ---------------------------------------------------------------------------
  // ToolExecutionResult
  // ---------------------------------------------------------------------------
  group('ToolExecutionResult', () {
    test('constructor with default success=true', () {
      const result = ToolExecutionResult();
      expect(result.success, isTrue);
      expect(result.content, isNull);
      expect(result.error, isNull);
    });

    test('constructor with custom fields', () {
      const result = ToolExecutionResult(
        success: false,
        content: 'data',
        error: 'err',
      );
      expect(result.success, isFalse);
      expect(result.content, 'data');
      expect(result.error, 'err');
    });

    test('success factory', () {
      const result = ToolExecutionResult.success('Hello world');
      expect(result.success, isTrue);
      expect(result.content, 'Hello world');
      expect(result.error, isNull);
    });

    test('failure factory', () {
      const result = ToolExecutionResult.failure('Something broke');
      expect(result.success, isFalse);
      expect(result.content, isNull);
      expect(result.error, 'Something broke');
    });

    group('toJson', () {
      test('success with content', () {
        const result = ToolExecutionResult.success('result data');
        final json = result.toJson();
        expect(json['success'], isTrue);
        expect(json['content'], 'result data');
        expect(json.containsKey('error'), isFalse);
      });

      test('failure with error', () {
        const result = ToolExecutionResult.failure('bad input');
        final json = result.toJson();
        expect(json['success'], isFalse);
        expect(json.containsKey('content'), isFalse);
        expect(json['error'], 'bad input');
      });

      test('without content or error', () {
        const result = ToolExecutionResult();
        final json = result.toJson();
        expect(json['success'], isTrue);
        expect(json.containsKey('content'), isFalse);
        expect(json.containsKey('error'), isFalse);
      });

      test('with both content and error', () {
        const result = ToolExecutionResult(
          success: false,
          content: 'partial',
          error: 'warning',
        );
        final json = result.toJson();
        expect(json['success'], isFalse);
        expect(json['content'], 'partial');
        expect(json['error'], 'warning');
      });
    });
  });
}
