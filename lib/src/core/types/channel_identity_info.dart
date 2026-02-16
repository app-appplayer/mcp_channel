import 'package:meta/meta.dart';

/// Type of identity in a channel.
enum IdentityType {
  /// Human user
  user,

  /// Bot or application
  bot,

  /// System or platform
  system,

  /// Unknown type
  unknown,
}

/// Extended identity information for messaging platforms.
///
/// This provides detailed user information beyond the base ChannelIdentity
/// from mcp_bundle which only contains platform, channelId, and displayName.
@immutable
class ChannelIdentityInfo {
  const ChannelIdentityInfo({
    required this.id,
    required this.type,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.email,
    this.timezone,
    this.locale,
    this.isAdmin,
    this.platformData,
  });

  /// Creates a user identity info.
  factory ChannelIdentityInfo.user({
    required String id,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? email,
    String? timezone,
    String? locale,
    bool? isAdmin,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelIdentityInfo(
      id: id,
      type: IdentityType.user,
      displayName: displayName,
      username: username,
      avatarUrl: avatarUrl,
      email: email,
      timezone: timezone,
      locale: locale,
      isAdmin: isAdmin,
      platformData: platformData,
    );
  }

  /// Creates a bot identity info.
  factory ChannelIdentityInfo.bot({
    required String id,
    String? displayName,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelIdentityInfo(
      id: id,
      type: IdentityType.bot,
      displayName: displayName,
      platformData: platformData,
    );
  }

  /// Creates a system identity info.
  factory ChannelIdentityInfo.system({
    required String id,
    String? displayName,
  }) {
    return ChannelIdentityInfo(
      id: id,
      type: IdentityType.system,
      displayName: displayName,
    );
  }

  factory ChannelIdentityInfo.fromJson(Map<String, dynamic> json) {
    return ChannelIdentityInfo(
      id: json['id'] as String,
      type: IdentityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => IdentityType.unknown,
      ),
      displayName: json['displayName'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      email: json['email'] as String?,
      timezone: json['timezone'] as String?,
      locale: json['locale'] as String?,
      isAdmin: json['isAdmin'] as bool?,
      platformData: json['platformData'] as Map<String, dynamic>?,
    );
  }

  /// Platform-specific user ID
  final String id;

  /// Identity type
  final IdentityType type;

  /// Display name
  final String? displayName;

  /// Username/handle
  final String? username;

  /// Avatar image URL
  final String? avatarUrl;

  /// Email address
  final String? email;

  /// User timezone
  final String? timezone;

  /// User locale
  final String? locale;

  /// Admin/owner flag
  final bool? isAdmin;

  /// Platform-specific data
  final Map<String, dynamic>? platformData;

  ChannelIdentityInfo copyWith({
    String? id,
    IdentityType? type,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? email,
    String? timezone,
    String? locale,
    bool? isAdmin,
    Map<String, dynamic>? platformData,
  }) {
    return ChannelIdentityInfo(
      id: id ?? this.id,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      isAdmin: isAdmin ?? this.isAdmin,
      platformData: platformData ?? this.platformData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        if (displayName != null) 'displayName': displayName,
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (email != null) 'email': email,
        if (timezone != null) 'timezone': timezone,
        if (locale != null) 'locale': locale,
        if (isAdmin != null) 'isAdmin': isAdmin,
        if (platformData != null) 'platformData': platformData,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelIdentityInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, type);

  @override
  String toString() =>
      'ChannelIdentityInfo(id: $id, type: ${type.name}, displayName: $displayName)';
}
