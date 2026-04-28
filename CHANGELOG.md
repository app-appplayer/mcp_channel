# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-04-28 - Multi-Platform Connectors

### Added
- Connectors — Discord, Email, Kakao (in addition to existing Slack).
- Extended channel types — rich `ContentBlock` system, action elements, attachments, extended capabilities and events.
- `Principal` entity for typed session identity.
- AES message handling (e.g. WeCom encryption) and signature verification helpers.

### Changed
- Slack connector and base connector hardened for production usage (Socket Mode + Events API).
- Session subsystem (Session / SessionManager / SessionStore / SessionMessage) refactored around `Principal`.
- Channel policy / rate limit / circuit breaker tightened.
- MCP integration (`ChannelHandler`, `MessageProcessor`) refactored.
- New dependency: `mcp_bundle ^0.3.0`.

---

## [0.1.0] - 2024-02-16

### Added
- Initial release
- Core types: `ChannelEvent`, `ChannelResponse`, `ChannelIdentity`, `ConversationKey`
- `ChannelPort` interface for platform adapters
- Session management with `Session`, `SessionManager`, `SessionStore`
- Idempotency handling with `IdempotencyGuard`
- Policy enforcement: rate limiting, retry with backoff, circuit breaker
- MCP integration: `ChannelRuntime`, `McpInvoker`, `LlmBridge`
- Slack connector (skeleton implementation)
- Basic test coverage
