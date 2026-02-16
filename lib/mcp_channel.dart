/// Unified channel abstraction layer for messaging platforms.
///
/// This library provides a platform-agnostic interface for building
/// messaging applications that can work across multiple platforms
/// like Slack, Discord, Telegram, Teams, and more.
///
/// ## Core Components
///
/// - [ChannelPort] - Primary interface for channel adapters
/// - [ChannelEvent] - Incoming events from messaging platforms
/// - [ChannelResponse] - Outgoing responses to platforms
/// - [Session] - Conversation state management
/// - [IdempotencyGuard] - Duplicate event handling
/// - [PolicyExecutor] - Rate limiting, retry, and circuit breaker
///
/// ## Usage Example
///
/// ```dart
/// import 'package:mcp_channel/mcp_channel.dart';
///
/// class MyBot {
///   final ChannelPort channel;
///   final SessionManager sessions;
///   final IdempotencyGuard idempotency;
///
///   MyBot(this.channel, this.sessions, this.idempotency);
///
///   Future<void> run() async {
///     await channel.start();
///
///     await for (final event in channel.events) {
///       await handleEvent(event);
///     }
///   }
///
///   Future<void> handleEvent(ChannelEvent event) async {
///     // Process with idempotency guarantee
///     await idempotency.process(event, () async {
///       // Get or create session
///       final session = await sessions.getOrCreateSession(event);
///
///       // Generate response
///       final text = 'Hello! You said: ${event.text}';
///
///       // Send response
///       final response = ChannelResponse.text(
///         conversation: event.conversation,
///         text: text,
///       );
///
///       await channel.send(response);
///
///       return IdempotencyResult.success(response: response);
///     });
///   }
/// }
/// ```
library;

// Core types
export 'src/core/types/types.dart';

// Port interface
export 'src/core/port/port.dart';

// Session management
export 'src/core/session/sessions.dart';

// Idempotency
export 'src/core/idempotency/idempotency.dart';

// Policy
export 'src/core/policy/policy.dart';

// Integration interfaces (for connecting with mcp_llm, mcp_server, etc.)
export 'src/core/integration/integration.dart';

// Connectors
export 'src/connectors/connectors.dart';
