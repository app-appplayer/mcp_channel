import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Attachment type for responses.
enum AttachmentType {
  /// Generic file
  file,

  /// Image
  image,

  /// Video
  video,

  /// Audio
  audio,

  /// Document (PDF, etc.)
  document,
}

/// File attachment for responses.
@immutable
class Attachment {
  /// Attachment type
  final AttachmentType type;

  /// Display name
  final String name;

  /// URL for remote file
  final String? url;

  /// Binary data for upload
  final Uint8List? data;

  /// MIME type
  final String? mimeType;

  const Attachment({
    required this.type,
    required this.name,
    this.url,
    this.data,
    this.mimeType,
  });

  /// Creates a file attachment from URL.
  factory Attachment.fromUrl({
    required String name,
    required String url,
    AttachmentType type = AttachmentType.file,
    String? mimeType,
  }) {
    return Attachment(
      type: type,
      name: name,
      url: url,
      mimeType: mimeType,
    );
  }

  /// Creates a file attachment from binary data.
  factory Attachment.fromData({
    required String name,
    required Uint8List data,
    AttachmentType type = AttachmentType.file,
    String? mimeType,
  }) {
    return Attachment(
      type: type,
      name: name,
      data: data,
      mimeType: mimeType,
    );
  }

  /// Creates an image attachment.
  factory Attachment.image({
    required String name,
    String? url,
    Uint8List? data,
    String? mimeType,
  }) {
    return Attachment(
      type: AttachmentType.image,
      name: name,
      url: url,
      data: data,
      mimeType: mimeType ?? 'image/png',
    );
  }

  /// Creates a document attachment.
  factory Attachment.document({
    required String name,
    String? url,
    Uint8List? data,
    String? mimeType,
  }) {
    return Attachment(
      type: AttachmentType.document,
      name: name,
      url: url,
      data: data,
      mimeType: mimeType,
    );
  }

  Attachment copyWith({
    AttachmentType? type,
    String? name,
    String? url,
    Uint8List? data,
    String? mimeType,
  }) {
    return Attachment(
      type: type ?? this.type,
      name: name ?? this.name,
      url: url ?? this.url,
      data: data ?? this.data,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        if (url != null) 'url': url,
        if (mimeType != null) 'mimeType': mimeType,
        // Note: data is not serialized to JSON
      };

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      type: AttachmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttachmentType.file,
      ),
      name: json['name'] as String,
      url: json['url'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Attachment &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name &&
          url == other.url;

  @override
  int get hashCode => Object.hash(type, name, url);

  @override
  String toString() => 'Attachment(type: ${type.name}, name: $name)';
}
