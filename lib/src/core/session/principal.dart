import 'package:mcp_bundle/ports.dart';
import 'package:meta/meta.dart';

/// Authenticated identity with roles and permissions.
@immutable
class Principal {
  const Principal({
    required this.identity,
    required this.tenantId,
    required this.roles,
    required this.permissions,
    required this.authenticatedAt,
    this.expiresAt,
  });

  /// Creates a principal with basic role.
  factory Principal.basic({
    required ChannelIdentity identity,
    required String tenantId,
    Set<String>? permissions,
    DateTime? expiresAt,
  }) {
    return Principal(
      identity: identity,
      tenantId: tenantId,
      roles: const {'user'},
      permissions: permissions ?? const {},
      authenticatedAt: DateTime.now(),
      expiresAt: expiresAt,
    );
  }

  /// Creates an admin principal.
  factory Principal.admin({
    required ChannelIdentity identity,
    required String tenantId,
    Set<String>? permissions,
    DateTime? expiresAt,
  }) {
    return Principal(
      identity: identity,
      tenantId: tenantId,
      roles: const {'user', 'admin'},
      permissions: permissions ?? const {'*'},
      authenticatedAt: DateTime.now(),
      expiresAt: expiresAt,
    );
  }

  factory Principal.fromJson(Map<String, dynamic> json) {
    return Principal(
      identity:
          ChannelIdentity.fromJson(json['identity'] as Map<String, dynamic>),
      tenantId: json['tenantId'] as String,
      roles: Set<String>.from(json['roles'] as List),
      permissions: Set<String>.from(json['permissions'] as List),
      authenticatedAt: DateTime.parse(json['authenticatedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  /// Channel identity
  final ChannelIdentity identity;

  /// Tenant/workspace ID
  final String tenantId;

  /// Assigned roles
  final Set<String> roles;

  /// Granted permissions
  final Set<String> permissions;

  /// Authentication timestamp
  final DateTime authenticatedAt;

  /// Session expiration
  final DateTime? expiresAt;

  /// Check if principal has role
  bool hasRole(String role) => roles.contains(role);

  /// Check if principal has any of the specified roles
  bool hasAnyRole(Set<String> checkRoles) =>
      roles.intersection(checkRoles).isNotEmpty;

  /// Check if principal has permission
  bool hasPermission(String permission) =>
      permissions.contains('*') || permissions.contains(permission);

  /// Check if principal is expired
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Check if principal is an admin
  bool get isAdmin => hasRole('admin');

  Principal copyWith({
    ChannelIdentity? identity,
    String? tenantId,
    Set<String>? roles,
    Set<String>? permissions,
    DateTime? authenticatedAt,
    DateTime? expiresAt,
  }) {
    return Principal(
      identity: identity ?? this.identity,
      tenantId: tenantId ?? this.tenantId,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      authenticatedAt: authenticatedAt ?? this.authenticatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'identity': identity.toJson(),
        'tenantId': tenantId,
        'roles': roles.toList(),
        'permissions': permissions.toList(),
        'authenticatedAt': authenticatedAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Principal &&
          runtimeType == other.runtimeType &&
          identity == other.identity &&
          tenantId == other.tenantId;

  @override
  int get hashCode => Object.hash(identity, tenantId);

  @override
  String toString() =>
      'Principal(identity: ${identity.channelId}, tenantId: $tenantId, roles: $roles)';
}
