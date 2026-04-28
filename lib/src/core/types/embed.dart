import 'package:meta/meta.dart';

/// Embedded content for rich messages (primarily used by Discord-like platforms).
@immutable
class Embed {
  const Embed({
    this.title,
    this.description,
    this.url,
    this.color,
    this.imageUrl,
    this.thumbnailUrl,
    this.author,
    this.footer,
    this.timestamp,
    this.fields,
  });

  factory Embed.fromJson(Map<String, dynamic> json) {
    return Embed(
      title: json['title'] as String?,
      description: json['description'] as String?,
      url: json['url'] as String?,
      color: json['color'] as String?,
      imageUrl: json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      author: json['author'] as String?,
      footer: json['footer'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      fields: json['fields'] != null
          ? (json['fields'] as List)
              .map((f) => EmbedField.fromJson(f as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  /// Title
  final String? title;

  /// Description
  final String? description;

  /// URL
  final String? url;

  /// Color (hex string)
  final String? color;

  /// Image URL
  final String? imageUrl;

  /// Thumbnail URL
  final String? thumbnailUrl;

  /// Author name
  final String? author;

  /// Footer text
  final String? footer;

  /// Timestamp
  final DateTime? timestamp;

  /// Additional fields
  final List<EmbedField>? fields;

  Embed copyWith({
    String? title,
    String? description,
    String? url,
    String? color,
    String? imageUrl,
    String? thumbnailUrl,
    String? author,
    String? footer,
    DateTime? timestamp,
    List<EmbedField>? fields,
  }) {
    return Embed(
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      color: color ?? this.color,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      author: author ?? this.author,
      footer: footer ?? this.footer,
      timestamp: timestamp ?? this.timestamp,
      fields: fields ?? this.fields,
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (url != null) 'url': url,
        if (color != null) 'color': color,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (author != null) 'author': author,
        if (footer != null) 'footer': footer,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
        if (fields != null) 'fields': fields!.map((f) => f.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Embed &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          description == other.description;

  @override
  int get hashCode => Object.hash(title, description);

  @override
  String toString() => 'Embed(title: $title, description: $description)';
}

/// Field for embed content.
@immutable
class EmbedField {
  const EmbedField({
    required this.name,
    required this.value,
    this.inline = false,
  });

  factory EmbedField.fromJson(Map<String, dynamic> json) {
    return EmbedField(
      name: json['name'] as String,
      value: json['value'] as String,
      inline: json['inline'] as bool? ?? false,
    );
  }

  /// Field name/title
  final String name;

  /// Field value
  final String value;

  /// Display inline
  final bool inline;

  EmbedField copyWith({
    String? name,
    String? value,
    bool? inline,
  }) {
    return EmbedField(
      name: name ?? this.name,
      value: value ?? this.value,
      inline: inline ?? this.inline,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'inline': inline,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbedField &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value;

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() =>
      'EmbedField(name: $name, value: $value, inline: $inline)';
}
