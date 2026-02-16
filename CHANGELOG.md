# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
