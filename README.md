# MCP Channel

A unified channel abstraction layer for messaging platforms with MCP integration. Provides a single bidirectional event/response API across Slack, Discord, Telegram, Kakao, Email, Microsoft Teams, and more.

## Features

- **Platform-agnostic messaging** via `ChannelPort` adapters.
- **Connectors** — Slack (Socket Mode + Events API), Discord, Email, Kakao. Telegram and Teams scaffolded.
- **Rich content** — `ContentBlock` system, attachments, action elements, threading, reactions, typing indicators.
- **Session management** — `Session`, `Principal`, `SessionManager`, `SessionStore` with conversation history and context.
- **Idempotency** — duplicate-event suppression with configurable TTL.
- **Policy enforcement** — rate limiting, retry-with-backoff, circuit breaker.
- **MCP integration** — `ChannelRuntime` orchestrates inbound events into MCP/LLM processing.
- **Crypto** — signature verification helpers and AES message handling (e.g. WeCom encryption).

## Quick Start

```dart
import 'package:mcp_channel/mcp_channel.dart';

final runtime = ChannelRuntime.inbound(
  mcpClients: {'default': mcpClient},
  defaultMode: InboundProcessingMode.llm,
);

runtime.registerChannel('slack', SlackConnector(
  SlackConfig(botToken: 'xoxb-...', appToken: 'xapp-...', useSocketMode: true),
));

await runtime.start();
await for (final event in runtime.events) {
  final response = await runtime.processEvent(event);
  if (response != null) {
    await runtime.sendResponse(response);
  }
}
```

## Core Components

- `ChannelEvent` / `ChannelResponse` — typed inbound events and outbound responses with rich content blocks.
- `ChannelPort` — abstract platform adapter interface (start, stop, send, edit, delete, react, sendTyping).
- `ChannelCapabilities` — feature-flag descriptor per connector.
- `Session` / `SessionManager` / `Principal` — conversation identity and history.
- `IdempotencyGuard` — duplicate-event guard.
- `ChannelPolicy` + `PolicyExecutor` — rate-limit / retry / circuit-breaker pipeline.

## Support

- [Issue Tracker](https://github.com/app-appplayer/mcp_channel/issues)
- [Discussions](https://github.com/app-appplayer/mcp_channel/discussions)

## License

MIT — see [LICENSE](LICENSE).
