import 'package:meta/meta.dart';
import 'package:mcp_client/mcp_client.dart';

import '../core/idempotency/idempotency_config.dart';
import '../core/policy/channel_policy.dart';
import '../core/session/session_store.dart';
import 'llm_bridge.dart';

/// Inbound processing mode.
enum InboundProcessingMode {
  /// Process with LLM (may include tool calls).
  llm,

  /// Direct tool call (command-based).
  directTool,

  /// Custom handler.
  custom,
}

/// MCP server transport type.
enum ServerTransportType {
  stdio,
  sse,
  streamableHttp,
}

/// MCP server configuration.
@immutable
class McpServerConfig {
  final String name;
  final String version;
  final ServerTransportType transportType;
  final String? host;
  final int? port;
  final String? command;
  final List<String>? arguments;

  const McpServerConfig({
    required this.name,
    this.version = '1.0.0',
    this.transportType = ServerTransportType.stdio,
    this.host,
    this.port,
    this.command,
    this.arguments,
  });
}

/// Inbound mode configuration.
@immutable
class InboundConfig {
  /// MCP clients map (clientId -> Client instance).
  final Map<String, Client> mcpClients;

  /// LlmBridge instance for LLM integration.
  final LlmBridge? llmBridge;

  /// Default processing mode.
  final InboundProcessingMode defaultMode;

  /// Enable batch tool execution optimization.
  final bool enableBatchExecution;

  /// Enable deferred tool loading for token optimization.
  final bool enableDeferredLoading;

  /// Health check interval.
  final Duration healthCheckInterval;

  const InboundConfig({
    this.mcpClients = const {},
    this.llmBridge,
    this.defaultMode = InboundProcessingMode.llm,
    this.enableBatchExecution = true,
    this.enableDeferredLoading = false,
    this.healthCheckInterval = const Duration(minutes: 5),
  });
}

/// Outbound mode configuration.
@immutable
class OutboundConfig {
  /// MCP server configuration.
  final McpServerConfig serverConfig;

  /// Which channels to expose as tools.
  final Set<String> exposedChannels;

  /// Which channels to expose as resources.
  final Set<String> exposedResources;

  /// Tool naming prefix.
  final String toolPrefix;

  /// Resource URI prefix.
  final String resourcePrefix;

  const OutboundConfig({
    required this.serverConfig,
    this.exposedChannels = const {},
    this.exposedResources = const {},
    this.toolPrefix = '',
    this.resourcePrefix = '',
  });
}

/// Security configuration.
@immutable
class SecurityConfig {
  /// Enable permission checking.
  final bool enablePermissionCheck;

  /// Enable audit logging.
  final bool enableAuditLog;

  /// Allowed roles for channel operations.
  final Set<String> allowedRoles;

  const SecurityConfig({
    this.enablePermissionCheck = true,
    this.enableAuditLog = true,
    this.allowedRoles = const {'user', 'admin'},
  });
}

/// Audit configuration.
@immutable
class AuditConfig {
  /// Audit log level.
  final AuditLogLevel level;

  /// Log sensitive data.
  final bool logSensitiveData;

  /// Retention period.
  final Duration retentionPeriod;

  const AuditConfig({
    this.level = AuditLogLevel.standard,
    this.logSensitiveData = false,
    this.retentionPeriod = const Duration(days: 90),
  });
}

/// Audit log level.
enum AuditLogLevel {
  /// Errors only.
  minimal,

  /// Events, tools, errors.
  standard,

  /// All including LLM interactions.
  detailed,

  /// Everything including raw payloads.
  debug,
}

/// Token vault configuration.
@immutable
class TokenVaultConfig {
  /// Storage type for tokens.
  final TokenStorageType storageType;

  /// Token refresh threshold.
  final Duration tokenRefreshThreshold;

  /// Enable automatic token rotation.
  final bool enableAutoRotation;

  /// Auto rotation interval.
  final Duration autoRotationInterval;

  const TokenVaultConfig({
    this.storageType = TokenStorageType.memory,
    this.tokenRefreshThreshold = const Duration(minutes: 5),
    this.enableAutoRotation = false,
    this.autoRotationInterval = const Duration(hours: 24),
  });
}

/// Token storage type.
enum TokenStorageType {
  memory,
  encrypted,
  keychain,
  vault,
}

/// Channel runtime configuration.
@immutable
class ChannelRuntimeConfig {
  /// Inbound mode configuration.
  final InboundConfig? inbound;

  /// Outbound mode configuration.
  final OutboundConfig? outbound;

  /// Session configuration.
  final SessionStoreConfig session;

  /// Security configuration.
  final SecurityConfig security;

  /// Idempotency configuration.
  final IdempotencyConfig idempotency;

  /// Policy configuration.
  final ChannelPolicy policy;

  /// Audit configuration.
  final AuditConfig audit;

  /// Token vault configuration.
  final TokenVaultConfig tokens;

  const ChannelRuntimeConfig({
    this.inbound,
    this.outbound,
    this.session = const SessionStoreConfig(),
    this.security = const SecurityConfig(),
    this.idempotency = const IdempotencyConfig(),
    this.policy = const ChannelPolicy(),
    this.audit = const AuditConfig(),
    this.tokens = const TokenVaultConfig(),
  });

  /// Inbound only mode.
  factory ChannelRuntimeConfig.inboundOnly({
    required InboundConfig inbound,
    SessionStoreConfig? session,
    SecurityConfig? security,
    IdempotencyConfig? idempotency,
    ChannelPolicy? policy,
  }) =>
      ChannelRuntimeConfig(
        inbound: inbound,
        session: session ?? const SessionStoreConfig(),
        security: security ?? const SecurityConfig(),
        idempotency: idempotency ?? const IdempotencyConfig(),
        policy: policy ?? const ChannelPolicy(),
      );

  /// Outbound only mode.
  factory ChannelRuntimeConfig.outboundOnly({
    required OutboundConfig outbound,
    SecurityConfig? security,
  }) =>
      ChannelRuntimeConfig(
        outbound: outbound,
        security: security ?? const SecurityConfig(),
      );

  /// Full bidirectional mode.
  factory ChannelRuntimeConfig.bidirectional({
    required InboundConfig inbound,
    required OutboundConfig outbound,
    SessionStoreConfig? session,
    SecurityConfig? security,
    IdempotencyConfig? idempotency,
    ChannelPolicy? policy,
  }) =>
      ChannelRuntimeConfig(
        inbound: inbound,
        outbound: outbound,
        session: session ?? const SessionStoreConfig(),
        security: security ?? const SecurityConfig(),
        idempotency: idempotency ?? const IdempotencyConfig(),
        policy: policy ?? const ChannelPolicy(),
      );

  /// Check if inbound mode is enabled.
  bool get isInboundEnabled => inbound != null;

  /// Check if outbound mode is enabled.
  bool get isOutboundEnabled => outbound != null;

  /// Check if bidirectional mode is enabled.
  bool get isBidirectional => isInboundEnabled && isOutboundEnabled;
}
