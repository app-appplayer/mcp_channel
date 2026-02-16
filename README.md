# mcp_channel

A unified channel abstraction layer for messaging platforms with MCP (Model Context Protocol) integration.

## Features

- **Platform-agnostic messaging**: Support for Slack, Telegram, Discord, Teams, and more
- **MCP Integration**: Bidirectional integration with MCP ecosystem
- **Session Management**: Conversation state with history and context
- **Idempotency**: Duplicate event handling with configurable TTL
- **Policy Enforcement**: Rate limiting, retry with backoff, circuit breaker
- **Type-safe API**: Immutable data classes with factory constructors

## Installation

```yaml
dependencies:
  mcp_channel: ^0.1.0
```

## Quick Start

```dart
import 'package:mcp_channel/mcp_channel.dart';

void main() async {
  // Create a channel runtime with inbound processing
  final runtime = ChannelRuntime.inbound(
    mcpClients: {'default': mcpClient},
    defaultMode: InboundProcessingMode.llm,
  );

  // Register a Slack channel
  final slackConfig = SlackConfig(
    botToken: 'xoxb-...',
    appToken: 'xapp-...',
    useSocketMode: true,
  );
  runtime.registerChannel('slack', SlackConnector(slackConfig));

  // Start the runtime
  await runtime.start();

  // Process events
  await for (final event in runtime.events) {
    final response = await runtime.processEvent(event);
    if (response != null) {
      await runtime.sendResponse(response);
    }
  }
}
```

## Core Components

### ChannelEvent

Represents incoming events from messaging platforms:

```dart
final event = ChannelEvent.message(
  eventId: 'evt_123',
  channelType: 'slack',
  identity: ChannelIdentity.user(id: 'U123'),
  conversation: ConversationKey(
    channelType: 'slack',
    tenantId: 'T123',
    roomId: 'C456',
  ),
  text: 'Hello!',
);
```

### ChannelResponse

Represents outgoing responses to platforms:

```dart
final response = ChannelResponse.text(
  conversation: event.conversation,
  text: 'Hi there!',
);

// Rich content
final richResponse = ChannelResponse.rich(
  conversation: event.conversation,
  blocks: [
    ContentBlock.section(text: 'Welcome!'),
    ContentBlock.actions(elements: [
      ActionElement.primaryButton(
        actionId: 'btn_start',
        text: 'Get Started',
      ),
    ]),
  ],
);
```

### Session Management

```dart
final store = InMemorySessionStore();
final manager = SessionManager(store);

final session = await manager.getOrCreateSession(event);
final updated = session
    .addMessage(SessionMessage.user(content: 'Hello', eventId: event.eventId))
    .updateContext('topic', 'greeting');
```

### Idempotency Guard

```dart
final guard = IdempotencyGuard(InMemoryIdempotencyStore());

final result = await guard.process(event, () async {
  // Process event...
  return IdempotencyResult.success(response: response);
});
```

### Policy Execution

```dart
final policy = ChannelPolicy(
  rateLimit: RateLimitConfig(
    maxRequests: 100,
    window: Duration(minutes: 1),
  ),
  retry: RetryConfig(
    maxAttempts: 3,
    backoffMultiplier: 2.0,
  ),
  circuitBreaker: CircuitBreakerConfig(
    failureThreshold: 5,
    resetTimeout: Duration(minutes: 1),
  ),
);

final executor = PolicyExecutor(policy, 'slack');
final result = await executor.execute(() => sendMessage());
```

## Architecture

```
mcp_channel/
├── lib/
│   ├── mcp_channel.dart              # Main export
│   └── src/
│       ├── core/
│       │   ├── types/                # ChannelEvent, ChannelResponse, etc.
│       │   ├── port/                 # ChannelPort interface
│       │   ├── session/              # Session management
│       │   ├── idempotency/          # Duplicate handling
│       │   └── policy/               # Rate limit, retry, circuit breaker
│       ├── integration/              # MCP integration
│       └── connectors/               # Platform connectors
│           └── slack/
└── test/
```

## Supported Platforms

- Slack (Socket Mode, Events API)
- Telegram (planned)
- Discord (planned)
- Microsoft Teams (planned)

## License

MIT License - see [LICENSE](LICENSE) for details.
