import 'package:mcp_channel/mcp_channel.dart';
import 'package:test/test.dart';

void main() {
  group('ContentBlockType', () {
    test('has all 7 values', () {
      expect(ContentBlockType.values, hasLength(7));
      expect(ContentBlockType.values, contains(ContentBlockType.section));
      expect(ContentBlockType.values, contains(ContentBlockType.divider));
      expect(ContentBlockType.values, contains(ContentBlockType.image));
      expect(ContentBlockType.values, contains(ContentBlockType.actions));
      expect(ContentBlockType.values, contains(ContentBlockType.context));
      expect(ContentBlockType.values, contains(ContentBlockType.header));
      expect(ContentBlockType.values, contains(ContentBlockType.input));
    });
  });

  group('ContentBlock', () {
    group('section', () {
      test('creates section with text only', () {
        final block = ContentBlock.section(text: 'Hello world');

        expect(block.type, ContentBlockType.section);
        expect(block.content['text'], 'Hello world');
        expect(block.content.containsKey('accessoryType'), isFalse);
        expect(block.content.containsKey('accessory'), isFalse);
      });

      test('creates section with accessory', () {
        final block = ContentBlock.section(
          text: 'With image',
          accessoryType: 'image',
          accessory: {'url': 'https://example.com/img.png', 'alt': 'photo'},
        );

        expect(block.type, ContentBlockType.section);
        expect(block.content['text'], 'With image');
        expect(block.content['accessoryType'], 'image');
        expect(
          (block.content['accessory'] as Map)['url'],
          'https://example.com/img.png',
        );
      });
    });

    group('divider', () {
      test('creates divider with empty content', () {
        final block = ContentBlock.divider();

        expect(block.type, ContentBlockType.divider);
        expect(block.content, isEmpty);
      });
    });

    group('image', () {
      test('creates image without title', () {
        final block = ContentBlock.image(
          url: 'https://example.com/photo.png',
          altText: 'A photo',
        );

        expect(block.type, ContentBlockType.image);
        expect(block.content['url'], 'https://example.com/photo.png');
        expect(block.content['altText'], 'A photo');
        expect(block.content.containsKey('title'), isFalse);
      });

      test('creates image with title', () {
        final block = ContentBlock.image(
          url: 'https://example.com/chart.png',
          altText: 'Sales chart',
          title: 'Q4 Sales',
        );

        expect(block.content['title'], 'Q4 Sales');
      });
    });

    group('actions', () {
      test('creates actions block with elements', () {
        final elements = [
          ActionElement.button(
            actionId: 'btn-1',
            text: 'Click me',
          ),
        ];

        final block = ContentBlock.actions(elements: elements);

        expect(block.type, ContentBlockType.actions);
        final blockElements = block.content['elements'] as List;
        expect(blockElements, hasLength(1));
        expect((blockElements[0] as Map)['actionId'], 'btn-1');
      });
    });

    group('context', () {
      test('creates context block with elements', () {
        final block = ContentBlock.context(
          elements: ['Posted by Bot', 'Last updated: today'],
        );

        expect(block.type, ContentBlockType.context);
        expect(block.content['elements'], hasLength(2));
        expect(
          (block.content['elements'] as List)[0],
          'Posted by Bot',
        );
      });
    });

    group('header', () {
      test('creates header block with text', () {
        final block = ContentBlock.header(text: 'Welcome');

        expect(block.type, ContentBlockType.header);
        expect(block.content['text'], 'Welcome');
      });
    });

    group('input', () {
      test('creates input without placeholder and with default multiline', () {
        final block = ContentBlock.input(
          label: 'Name',
          actionId: 'input-name',
        );

        expect(block.type, ContentBlockType.input);
        expect(block.content['label'], 'Name');
        expect(block.content['actionId'], 'input-name');
        expect(block.content.containsKey('placeholder'), isFalse);
        expect(block.content['multiline'], isFalse);
      });

      test('creates input with placeholder and multiline', () {
        final block = ContentBlock.input(
          label: 'Description',
          actionId: 'input-desc',
          placeholder: 'Enter description...',
          multiline: true,
        );

        expect(block.content['placeholder'], 'Enter description...');
        expect(block.content['multiline'], isTrue);
      });
    });

    group('fromJson', () {
      test('deserializes known type', () {
        final json = {
          'type': 'header',
          'content': {'text': 'Hello'},
        };

        final block = ContentBlock.fromJson(json);

        expect(block.type, ContentBlockType.header);
        expect(block.content['text'], 'Hello');
      });

      test('deserializes unknown type falls back to section', () {
        final json = {
          'type': 'custom_widget',
          'content': {'data': 'some data'},
        };

        final block = ContentBlock.fromJson(json);

        expect(block.type, ContentBlockType.section);
        expect(block.content['data'], 'some data');
      });
    });

    group('copyWith', () {
      test('copies with type changed', () {
        final original = ContentBlock.header(text: 'Title');
        final copy = original.copyWith(type: ContentBlockType.section);

        expect(copy.type, ContentBlockType.section);
        expect(copy.content['text'], 'Title');
      });

      test('copies with content changed', () {
        final original = ContentBlock.header(text: 'Old');
        final copy = original.copyWith(content: {'text': 'New'});

        expect(copy.type, ContentBlockType.header);
        expect(copy.content['text'], 'New');
      });

      test('copies with no changes preserves values', () {
        final original = ContentBlock.divider();
        final copy = original.copyWith();

        expect(copy.type, original.type);
        expect(copy.content, original.content);
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        final block = ContentBlock.header(text: 'Title');
        final json = block.toJson();

        expect(json['type'], 'header');
        expect((json['content'] as Map)['text'], 'Title');
      });
    });

    group('equality', () {
      test('equal when same type', () {
        final a = ContentBlock.header(text: 'A');
        final b = ContentBlock.header(text: 'B');

        // Equality is based on type only
        expect(a == b, isTrue);
      });

      test('not equal when different type', () {
        final a = ContentBlock.header(text: 'Title');
        final b = ContentBlock.divider();

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        final a = ContentBlock.header(text: 'Title');
        expect(a == a, isTrue);
      });

      test('not equal to different type object', () {
        final a = ContentBlock.header(text: 'Title');
        expect(a == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        final a = ContentBlock.header(text: 'A');
        final b = ContentBlock.header(text: 'B');

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains type name', () {
        final block = ContentBlock.header(text: 'Title');
        expect(block.toString(), contains('header'));
      });
    });
  });

  group('ActionElementType', () {
    test('has all 6 values', () {
      expect(ActionElementType.values, hasLength(6));
      expect(ActionElementType.values, contains(ActionElementType.button));
      expect(ActionElementType.values, contains(ActionElementType.select));
      expect(
          ActionElementType.values, contains(ActionElementType.multiSelect));
      expect(ActionElementType.values, contains(ActionElementType.datePicker));
      expect(ActionElementType.values, contains(ActionElementType.timePicker));
      expect(ActionElementType.values, contains(ActionElementType.overflow));
    });
  });

  group('ActionElement', () {
    group('button', () {
      test('creates button with required fields', () {
        final elem = ActionElement.button(
          actionId: 'btn-1',
          text: 'Click',
        );

        expect(elem.type, ActionElementType.button);
        expect(elem.actionId, 'btn-1');
        expect(elem.text, 'Click');
        expect(elem.style, isNull);
        expect(elem.value, isNull);
        expect(elem.url, isNull);
        expect(elem.confirm, isNull);
      });

      test('creates button with all optional fields', () {
        final confirm = ConfirmDialog(title: 'Sure?', text: 'Really?');
        final elem = ActionElement.button(
          actionId: 'btn-2',
          text: 'Delete',
          value: 'item-99',
          url: 'https://example.com',
          style: 'danger',
          confirm: confirm,
        );

        expect(elem.value, 'item-99');
        expect(elem.url, 'https://example.com');
        expect(elem.style, 'danger');
        expect(elem.confirm, confirm);
      });
    });

    group('primaryButton', () {
      test('creates button with primary style', () {
        final elem = ActionElement.primaryButton(
          actionId: 'submit',
          text: 'Submit',
        );

        expect(elem.type, ActionElementType.button);
        expect(elem.style, 'primary');
        expect(elem.text, 'Submit');
      });

      test('creates primary button with value and confirm', () {
        final confirm = ConfirmDialog(title: 'Confirm', text: 'Proceed?');
        final elem = ActionElement.primaryButton(
          actionId: 'approve',
          text: 'Approve',
          value: 'yes',
          confirm: confirm,
        );

        expect(elem.value, 'yes');
        expect(elem.confirm, confirm);
        expect(elem.style, 'primary');
      });
    });

    group('dangerButton', () {
      test('creates button with danger style', () {
        final elem = ActionElement.dangerButton(
          actionId: 'delete',
          text: 'Delete',
        );

        expect(elem.type, ActionElementType.button);
        expect(elem.style, 'danger');
        expect(elem.text, 'Delete');
      });

      test('creates danger button with value and confirm', () {
        final confirm = ConfirmDialog(title: 'Warning', text: 'Delete?');
        final elem = ActionElement.dangerButton(
          actionId: 'remove',
          text: 'Remove',
          value: 'item-1',
          confirm: confirm,
        );

        expect(elem.value, 'item-1');
        expect(elem.confirm, confirm);
        expect(elem.style, 'danger');
      });
    });

    group('select', () {
      test('creates select with options', () {
        final options = [
          const SelectOption(text: 'Option A', value: 'a'),
          const SelectOption(text: 'Option B', value: 'b'),
        ];

        final elem = ActionElement.select(
          actionId: 'sel-1',
          placeholder: 'Choose one',
          options: options,
        );

        expect(elem.type, ActionElementType.select);
        expect(elem.actionId, 'sel-1');
        expect(elem.text, 'Choose one');
        expect(elem.options, hasLength(2));
      });
    });

    group('datePicker', () {
      test('creates date picker with placeholder and initial date', () {
        final elem = ActionElement.datePicker(
          actionId: 'date-1',
          placeholder: 'Select date',
          initialDate: '2024-01-15',
        );

        expect(elem.type, ActionElementType.datePicker);
        expect(elem.actionId, 'date-1');
        expect(elem.text, 'Select date');
        expect(elem.value, '2024-01-15');
      });

      test('creates date picker without optional fields', () {
        final elem = ActionElement.datePicker(actionId: 'date-2');

        expect(elem.text, isNull);
        expect(elem.value, isNull);
      });
    });

    group('fromJson', () {
      test('deserializes with all fields including options and confirm', () {
        final json = {
          'type': 'button',
          'actionId': 'btn-1',
          'text': 'Click',
          'style': 'primary',
          'value': 'v1',
          'url': 'https://example.com',
          'options': [
            {'text': 'A', 'value': 'a'},
            {'text': 'B', 'value': 'b'},
          ],
          'confirm': {
            'title': 'Sure?',
            'text': 'Really?',
            'confirm': 'Yes',
            'deny': 'No',
          },
        };

        final elem = ActionElement.fromJson(json);

        expect(elem.type, ActionElementType.button);
        expect(elem.actionId, 'btn-1');
        expect(elem.text, 'Click');
        expect(elem.style, 'primary');
        expect(elem.value, 'v1');
        expect(elem.url, 'https://example.com');
        expect(elem.options, hasLength(2));
        expect(elem.options![0].text, 'A');
        expect(elem.confirm, isNotNull);
        expect(elem.confirm!.title, 'Sure?');
      });

      test('deserializes with required fields only', () {
        final json = {
          'type': 'select',
          'actionId': 'sel-1',
        };

        final elem = ActionElement.fromJson(json);

        expect(elem.type, ActionElementType.select);
        expect(elem.actionId, 'sel-1');
        expect(elem.text, isNull);
        expect(elem.style, isNull);
        expect(elem.value, isNull);
        expect(elem.url, isNull);
        expect(elem.options, isNull);
        expect(elem.confirm, isNull);
      });

      test('deserializes with unknown type falls back to button', () {
        final json = {
          'type': 'custom_widget',
          'actionId': 'act-1',
        };

        final elem = ActionElement.fromJson(json);

        expect(elem.type, ActionElementType.button);
      });
    });

    group('copyWith', () {
      test('copies with all fields changed', () {
        final original = ActionElement.button(
          actionId: 'btn-1',
          text: 'Old',
        );

        final options = [
          const SelectOption(text: 'X', value: 'x'),
        ];
        final confirm = ConfirmDialog(title: 'T', text: 'Body');

        final copy = original.copyWith(
          type: ActionElementType.select,
          actionId: 'sel-1',
          text: 'New',
          style: 'primary',
          value: 'val',
          url: 'https://example.com',
          options: options,
          confirm: confirm,
        );

        expect(copy.type, ActionElementType.select);
        expect(copy.actionId, 'sel-1');
        expect(copy.text, 'New');
        expect(copy.style, 'primary');
        expect(copy.value, 'val');
        expect(copy.url, 'https://example.com');
        expect(copy.options, hasLength(1));
        expect(copy.confirm, confirm);
      });

      test('copies with no fields changed preserves values', () {
        final original = ActionElement.button(
          actionId: 'btn-1',
          text: 'Click',
          style: 'primary',
        );

        final copy = original.copyWith();

        expect(copy.type, original.type);
        expect(copy.actionId, original.actionId);
        expect(copy.text, original.text);
        expect(copy.style, original.style);
      });
    });

    group('toJson', () {
      test('serializes with all optional fields', () {
        final options = [
          const SelectOption(text: 'A', value: 'a'),
        ];
        final confirm = ConfirmDialog(title: 'T', text: 'Body');

        final elem = ActionElement(
          type: ActionElementType.button,
          actionId: 'btn-1',
          text: 'Click',
          style: 'primary',
          value: 'v1',
          url: 'https://example.com',
          options: options,
          confirm: confirm,
        );

        final json = elem.toJson();

        expect(json['type'], 'button');
        expect(json['actionId'], 'btn-1');
        expect(json['text'], 'Click');
        expect(json['style'], 'primary');
        expect(json['value'], 'v1');
        expect(json['url'], 'https://example.com');
        expect(json['options'], hasLength(1));
        expect(json['confirm'], isNotNull);
      });

      test('omits null optional fields', () {
        final elem = ActionElement.button(
          actionId: 'btn-1',
          text: 'Click',
        );

        final json = elem.toJson();

        expect(json.containsKey('style'), isFalse);
        expect(json.containsKey('value'), isFalse);
        expect(json.containsKey('url'), isFalse);
        expect(json.containsKey('options'), isFalse);
        expect(json.containsKey('confirm'), isFalse);
      });
    });

    group('equality', () {
      test('equal when same actionId', () {
        final a = ActionElement.button(actionId: 'btn-1', text: 'A');
        final b = ActionElement.button(actionId: 'btn-1', text: 'B');

        expect(a == b, isTrue);
      });

      test('not equal when different actionId', () {
        final a = ActionElement.button(actionId: 'btn-1', text: 'Click');
        final b = ActionElement.button(actionId: 'btn-2', text: 'Click');

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        final a = ActionElement.button(actionId: 'btn-1', text: 'Click');
        expect(a == a, isTrue);
      });

      test('not equal to different type object', () {
        final a = ActionElement.button(actionId: 'btn-1', text: 'Click');
        expect(a == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        final a = ActionElement.button(actionId: 'btn-1', text: 'A');
        final b = ActionElement.button(actionId: 'btn-1', text: 'B');

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains type, actionId, and text', () {
        final elem = ActionElement.button(
          actionId: 'btn-1',
          text: 'Click',
        );

        final str = elem.toString();

        expect(str, contains('button'));
        expect(str, contains('btn-1'));
        expect(str, contains('Click'));
      });
    });
  });

  group('SelectOption', () {
    group('constructor', () {
      test('creates with required fields', () {
        const opt = SelectOption(text: 'Red', value: 'red');

        expect(opt.text, 'Red');
        expect(opt.value, 'red');
        expect(opt.description, isNull);
      });

      test('creates with description', () {
        const opt = SelectOption(
          text: 'Blue',
          value: 'blue',
          description: 'A calming color',
        );

        expect(opt.description, 'A calming color');
      });
    });

    group('fromJson', () {
      test('deserializes with all fields', () {
        final json = {
          'text': 'Green',
          'value': 'green',
          'description': 'Nature color',
        };

        final opt = SelectOption.fromJson(json);

        expect(opt.text, 'Green');
        expect(opt.value, 'green');
        expect(opt.description, 'Nature color');
      });

      test('deserializes without description', () {
        final json = {'text': 'Yellow', 'value': 'yellow'};

        final opt = SelectOption.fromJson(json);

        expect(opt.text, 'Yellow');
        expect(opt.value, 'yellow');
        expect(opt.description, isNull);
      });
    });

    group('toJson', () {
      test('serializes with description', () {
        const opt = SelectOption(
          text: 'Red',
          value: 'red',
          description: 'Warm color',
        );

        final json = opt.toJson();

        expect(json['text'], 'Red');
        expect(json['value'], 'red');
        expect(json['description'], 'Warm color');
      });

      test('serializes without description', () {
        const opt = SelectOption(text: 'Blue', value: 'blue');

        final json = opt.toJson();

        expect(json['text'], 'Blue');
        expect(json['value'], 'blue');
        expect(json.containsKey('description'), isFalse);
      });
    });

    group('equality', () {
      test('equal when same value', () {
        const a = SelectOption(text: 'Red Label', value: 'red');
        const b = SelectOption(text: 'Different Label', value: 'red');

        expect(a == b, isTrue);
      });

      test('not equal when different value', () {
        const a = SelectOption(text: 'Same', value: 'red');
        const b = SelectOption(text: 'Same', value: 'blue');

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        const a = SelectOption(text: 'Red', value: 'red');
        expect(a == a, isTrue);
      });

      test('not equal to different type object', () {
        const a = SelectOption(text: 'Red', value: 'red');
        expect(a == 'red', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        const a = SelectOption(text: 'A', value: 'val');
        const b = SelectOption(text: 'B', value: 'val');

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains text and value', () {
        const opt = SelectOption(text: 'Red', value: 'red');

        final str = opt.toString();

        expect(str, contains('Red'));
        expect(str, contains('red'));
      });
    });
  });

  group('ConfirmDialog', () {
    group('constructor', () {
      test('creates with default confirm and deny', () {
        const dialog = ConfirmDialog(
          title: 'Delete Item',
          text: 'Are you sure?',
        );

        expect(dialog.title, 'Delete Item');
        expect(dialog.text, 'Are you sure?');
        expect(dialog.confirm, 'Confirm');
        expect(dialog.deny, 'Cancel');
      });

      test('creates with custom confirm and deny', () {
        const dialog = ConfirmDialog(
          title: 'Remove',
          text: 'This cannot be undone.',
          confirm: 'Yes, remove',
          deny: 'Keep',
        );

        expect(dialog.confirm, 'Yes, remove');
        expect(dialog.deny, 'Keep');
      });
    });

    group('fromJson', () {
      test('deserializes with all fields', () {
        final json = {
          'title': 'Warning',
          'text': 'Proceed?',
          'confirm': 'Go',
          'deny': 'Stop',
        };

        final dialog = ConfirmDialog.fromJson(json);

        expect(dialog.title, 'Warning');
        expect(dialog.text, 'Proceed?');
        expect(dialog.confirm, 'Go');
        expect(dialog.deny, 'Stop');
      });

      test('deserializes without confirm/deny uses defaults', () {
        final json = {
          'title': 'Notice',
          'text': 'Continue?',
        };

        final dialog = ConfirmDialog.fromJson(json);

        expect(dialog.title, 'Notice');
        expect(dialog.text, 'Continue?');
        expect(dialog.confirm, 'Confirm');
        expect(dialog.deny, 'Cancel');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const dialog = ConfirmDialog(
          title: 'Delete',
          text: 'Sure?',
          confirm: 'Yes',
          deny: 'No',
        );

        final json = dialog.toJson();

        expect(json['title'], 'Delete');
        expect(json['text'], 'Sure?');
        expect(json['confirm'], 'Yes');
        expect(json['deny'], 'No');
      });

      test('serializes default confirm and deny', () {
        const dialog = ConfirmDialog(
          title: 'Title',
          text: 'Body',
        );

        final json = dialog.toJson();

        expect(json['confirm'], 'Confirm');
        expect(json['deny'], 'Cancel');
      });
    });

    group('equality', () {
      test('equal when same title and text', () {
        const a = ConfirmDialog(title: 'T', text: 'B');
        const b = ConfirmDialog(title: 'T', text: 'B', confirm: 'OK');

        expect(a == b, isTrue);
      });

      test('not equal when title differs', () {
        const a = ConfirmDialog(title: 'A', text: 'Body');
        const b = ConfirmDialog(title: 'B', text: 'Body');

        expect(a == b, isFalse);
      });

      test('not equal when text differs', () {
        const a = ConfirmDialog(title: 'Title', text: 'A');
        const b = ConfirmDialog(title: 'Title', text: 'B');

        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        const a = ConfirmDialog(title: 'T', text: 'B');
        expect(a == a, isTrue);
      });

      test('not equal to different type object', () {
        const a = ConfirmDialog(title: 'T', text: 'B');
        expect(a == 'string', isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have same hashCode', () {
        const a = ConfirmDialog(title: 'T', text: 'B');
        const b = ConfirmDialog(title: 'T', text: 'B');

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains title', () {
        const dialog = ConfirmDialog(title: 'My Dialog', text: 'Content');

        expect(dialog.toString(), contains('My Dialog'));
      });
    });
  });
}
