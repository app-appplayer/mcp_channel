import 'package:meta/meta.dart';

/// File attachment information.
@immutable
class FileInfo {
  /// File identifier
  final String id;

  /// File name
  final String name;

  /// MIME type
  final String? mimeType;

  /// File size in bytes
  final int? size;

  /// Download URL
  final String? url;

  /// Thumbnail URL
  final String? thumbnailUrl;

  const FileInfo({
    required this.id,
    required this.name,
    this.mimeType,
    this.size,
    this.url,
    this.thumbnailUrl,
  });

  FileInfo copyWith({
    String? id,
    String? name,
    String? mimeType,
    int? size,
    String? url,
    String? thumbnailUrl,
  }) {
    return FileInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (mimeType != null) 'mimeType': mimeType,
        if (size != null) 'size': size,
        if (url != null) 'url': url,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      };

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      mimeType: json['mimeType'] as String?,
      size: json['size'] as int?,
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'FileInfo(id: $id, name: $name, mimeType: $mimeType)';
}
