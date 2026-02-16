import 'package:meta/meta.dart';

/// Block type for rich content.
enum ContentBlockType {
  /// Text section with optional accessory
  section,

  /// Visual divider line
  divider,

  /// Image with alt text
  image,

  /// Interactive buttons/menus
  actions,

  /// Contextual information
  context,

  /// Header text
  header,

  /// Input field (for modals)
  input,
}

/// Building block for rich content.
@immutable
class ContentBlock {
  /// Block type
  final ContentBlockType type;

  /// Type-specific content
  final Map<String, dynamic> content;

  const ContentBlock({
    required this.type,
    required this.content,
  });

  /// Creates a section block with text.
  factory ContentBlock.section({
    required String text,
    String? accessoryType,
    Map<String, dynamic>? accessory,
  }) {
    return ContentBlock(
      type: ContentBlockType.section,
      content: {
        'text': text,
        if (accessoryType != null) 'accessoryType': accessoryType,
        if (accessory != null) 'accessory': accessory,
      },
    );
  }

  /// Creates a divider block.
  factory ContentBlock.divider() {
    return const ContentBlock(
      type: ContentBlockType.divider,
      content: {},
    );
  }

  /// Creates an image block.
  factory ContentBlock.image({
    required String url,
    required String altText,
    String? title,
  }) {
    return ContentBlock(
      type: ContentBlockType.image,
      content: {
        'url': url,
        'altText': altText,
        if (title != null) 'title': title,
      },
    );
  }

  /// Creates an actions block with interactive elements.
  factory ContentBlock.actions({
    required List<ActionElement> elements,
  }) {
    return ContentBlock(
      type: ContentBlockType.actions,
      content: {
        'elements': elements.map((e) => e.toJson()).toList(),
      },
    );
  }

  /// Creates a context block.
  factory ContentBlock.context({
    required List<String> elements,
  }) {
    return ContentBlock(
      type: ContentBlockType.context,
      content: {
        'elements': elements,
      },
    );
  }

  /// Creates a header block.
  factory ContentBlock.header({
    required String text,
  }) {
    return ContentBlock(
      type: ContentBlockType.header,
      content: {
        'text': text,
      },
    );
  }

  /// Creates an input block.
  factory ContentBlock.input({
    required String label,
    required String actionId,
    String? placeholder,
    bool multiline = false,
  }) {
    return ContentBlock(
      type: ContentBlockType.input,
      content: {
        'label': label,
        'actionId': actionId,
        if (placeholder != null) 'placeholder': placeholder,
        'multiline': multiline,
      },
    );
  }

  ContentBlock copyWith({
    ContentBlockType? type,
    Map<String, dynamic>? content,
  }) {
    return ContentBlock(
      type: type ?? this.type,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'content': content,
      };

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: ContentBlockType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ContentBlockType.section,
      ),
      content: Map<String, dynamic>.from(json['content'] as Map),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentBlock &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'ContentBlock(type: ${type.name})';
}

/// Element type for interactive actions.
enum ActionElementType {
  /// Clickable button
  button,

  /// Dropdown select menu
  select,

  /// Multi-select menu
  multiSelect,

  /// Date picker
  datePicker,

  /// Time picker
  timePicker,

  /// Overflow menu
  overflow,
}

/// Interactive element for buttons and menus.
@immutable
class ActionElement {
  /// Element type
  final ActionElementType type;

  /// Unique action identifier
  final String actionId;

  /// Button/label text
  final String? text;

  /// Style (primary, danger)
  final String? style;

  /// Action value
  final String? value;

  /// Options for select
  final List<SelectOption>? options;

  /// Confirmation dialog
  final ConfirmDialog? confirm;

  const ActionElement({
    required this.type,
    required this.actionId,
    this.text,
    this.style,
    this.value,
    this.options,
    this.confirm,
  });

  /// Creates a button element.
  factory ActionElement.button({
    required String actionId,
    required String text,
    String? value,
    String? style,
    ConfirmDialog? confirm,
  }) {
    return ActionElement(
      type: ActionElementType.button,
      actionId: actionId,
      text: text,
      value: value,
      style: style,
      confirm: confirm,
    );
  }

  /// Creates a primary button.
  factory ActionElement.primaryButton({
    required String actionId,
    required String text,
    String? value,
    ConfirmDialog? confirm,
  }) {
    return ActionElement.button(
      actionId: actionId,
      text: text,
      value: value,
      style: 'primary',
      confirm: confirm,
    );
  }

  /// Creates a danger button.
  factory ActionElement.dangerButton({
    required String actionId,
    required String text,
    String? value,
    ConfirmDialog? confirm,
  }) {
    return ActionElement.button(
      actionId: actionId,
      text: text,
      value: value,
      style: 'danger',
      confirm: confirm,
    );
  }

  /// Creates a select menu.
  factory ActionElement.select({
    required String actionId,
    required String placeholder,
    required List<SelectOption> options,
  }) {
    return ActionElement(
      type: ActionElementType.select,
      actionId: actionId,
      text: placeholder,
      options: options,
    );
  }

  /// Creates a date picker.
  factory ActionElement.datePicker({
    required String actionId,
    String? placeholder,
    String? initialDate,
  }) {
    return ActionElement(
      type: ActionElementType.datePicker,
      actionId: actionId,
      text: placeholder,
      value: initialDate,
    );
  }

  ActionElement copyWith({
    ActionElementType? type,
    String? actionId,
    String? text,
    String? style,
    String? value,
    List<SelectOption>? options,
    ConfirmDialog? confirm,
  }) {
    return ActionElement(
      type: type ?? this.type,
      actionId: actionId ?? this.actionId,
      text: text ?? this.text,
      style: style ?? this.style,
      value: value ?? this.value,
      options: options ?? this.options,
      confirm: confirm ?? this.confirm,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'actionId': actionId,
        if (text != null) 'text': text,
        if (style != null) 'style': style,
        if (value != null) 'value': value,
        if (options != null)
          'options': options!.map((o) => o.toJson()).toList(),
        if (confirm != null) 'confirm': confirm!.toJson(),
      };

  factory ActionElement.fromJson(Map<String, dynamic> json) {
    return ActionElement(
      type: ActionElementType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActionElementType.button,
      ),
      actionId: json['actionId'] as String,
      text: json['text'] as String?,
      style: json['style'] as String?,
      value: json['value'] as String?,
      options: json['options'] != null
          ? (json['options'] as List)
              .map((o) => SelectOption.fromJson(o as Map<String, dynamic>))
              .toList()
          : null,
      confirm: json['confirm'] != null
          ? ConfirmDialog.fromJson(json['confirm'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionElement &&
          runtimeType == other.runtimeType &&
          actionId == other.actionId;

  @override
  int get hashCode => actionId.hashCode;

  @override
  String toString() =>
      'ActionElement(type: ${type.name}, actionId: $actionId, text: $text)';
}

/// Option for select menus.
@immutable
class SelectOption {
  /// Display text
  final String text;

  /// Option value
  final String value;

  /// Optional description
  final String? description;

  const SelectOption({
    required this.text,
    required this.value,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'value': value,
        if (description != null) 'description': description,
      };

  factory SelectOption.fromJson(Map<String, dynamic> json) {
    return SelectOption(
      text: json['text'] as String,
      value: json['value'] as String,
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectOption &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SelectOption(text: $text, value: $value)';
}

/// Confirmation dialog for destructive actions.
@immutable
class ConfirmDialog {
  /// Dialog title
  final String title;

  /// Dialog text/body
  final String text;

  /// Confirm button text
  final String confirm;

  /// Deny/cancel button text
  final String deny;

  const ConfirmDialog({
    required this.title,
    required this.text,
    this.confirm = 'Confirm',
    this.deny = 'Cancel',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'text': text,
        'confirm': confirm,
        'deny': deny,
      };

  factory ConfirmDialog.fromJson(Map<String, dynamic> json) {
    return ConfirmDialog(
      title: json['title'] as String,
      text: json['text'] as String,
      confirm: json['confirm'] as String? ?? 'Confirm',
      deny: json['deny'] as String? ?? 'Cancel',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfirmDialog &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          text == other.text;

  @override
  int get hashCode => Object.hash(title, text);

  @override
  String toString() => 'ConfirmDialog(title: $title)';
}
