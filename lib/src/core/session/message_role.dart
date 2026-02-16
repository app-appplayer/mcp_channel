/// Role of a message in session history.
enum MessageRole {
  /// User message
  user,

  /// Assistant/bot response
  assistant,

  /// System message
  system,

  /// Tool result message
  tool,
}
