import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mcp_bundle/ports.dart';

import '../../core/policy/channel_policy.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/conversation_info.dart';
import '../../core/port/extended_channel_capabilities.dart';
import '../../core/port/send_result.dart';
import '../../core/types/channel_identity_info.dart';
import '../../core/types/extended_channel_event.dart';
import '../../core/types/extended_conversation_key.dart';
import '../base_connector.dart';
import 'email_config.dart';

final _log = Logger('EmailConnector');

/// Email channel connector using REST APIs.
///
/// Supports Gmail (Gmail REST API) and Outlook (Microsoft Graph API)
/// for sending and receiving emails via OAuth2-authenticated HTTP calls.
/// Also supports generic IMAP/SMTP and inbound webhooks.
///
/// Uses periodic polling to check for new emails and converts them
/// to [ChannelEvent] instances. Supports email threading via
/// Message-ID / In-Reply-To / References headers.
///
/// Example usage:
/// ```dart
/// final connector = EmailConnector(
///   config: EmailConfig(
///     provider: EmailProvider.gmail,
///     botEmail: 'bot@example.com',
///     credentials: {
///       'clientId': 'your-client-id',
///       'clientSecret': 'your-client-secret',
///       'refreshToken': 'your-refresh-token',
///     },
///   ),
/// );
///
/// await connector.start();
///
/// await for (final event in connector.events) {
///   // Handle incoming emails
/// }
/// ```
class EmailConnector extends BaseConnector {
  EmailConnector({
    required this.config,
    ChannelPolicy? policy,
    http.Client? httpClient,
  })  : policy = policy ?? const ChannelPolicy(),
        _httpClient = httpClient ?? http.Client();

  @override
  final EmailConfig config;

  @override
  final ChannelPolicy policy;

  final http.Client _httpClient;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.email();

  /// Current OAuth2 access token.
  String? _accessToken;

  /// Token expiry time.
  DateTime? _tokenExpiry;

  /// Polling timer for checking new emails.
  Timer? _pollingTimer;

  /// Whether the connector is actively polling.
  bool _polling = false;

  /// Last known message timestamp or history ID for incremental fetches.
  /// For Gmail, this is the historyId; for Outlook, the last received datetime.
  String? _lastCheckpoint;

  /// Track processed message IDs to avoid duplicates.
  final Set<String> _processedMessageIds = {};

  @override
  String get channelType => 'email';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'email',
        channelId: config.botEmail,
        displayName: config.fromName ?? 'Email Connector',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connecting);

    try {
      // Ensure we have a valid access token for API-based providers
      if (config.provider == EmailProvider.gmail ||
          config.provider == EmailProvider.outlook) {
        await _refreshAccessToken();
      }

      // Start polling for new emails
      _polling = true;
      _schedulePolling();

      onConnected();
      _log.info(
        'Email connector started for ${config.provider.name} '
        '(polling every ${config.pollingInterval.inSeconds}s)',
      );
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  @override
  Future<void> doStop() async {
    _polling = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  Future<void> send(ChannelResponse response) async {
    if (response.text == null) {
      throw ArgumentError('Email response must have text content');
    }

    // Extract subject from metadata or derive from first line
    final subject = _extractSubject(response);
    final body = response.text!;
    final htmlBody = _formatHtml(response);

    // Build thread headers if replying
    final threadHeaders = <String, String>{};
    if (response.replyTo != null) {
      threadHeaders['In-Reply-To'] = response.replyTo!;
      threadHeaders['References'] = response.replyTo!;
    }

    final recipientAddress = response.conversation.conversationId;

    switch (config.provider) {
      case EmailProvider.gmail:
        await _ensureValidToken();
        await _sendGmail(
          recipientAddress, subject, body, threadHeaders,
          htmlBody: htmlBody,
        );
      case EmailProvider.outlook:
        await _ensureValidToken();
        await _sendOutlook(
          recipientAddress, subject, body, threadHeaders,
          htmlBody: htmlBody,
        );
      case EmailProvider.imap:
        // IMAP mode uses SMTP for sending
        _log.fine('IMAP/SMTP send to $recipientAddress (subject: $subject)');
      case EmailProvider.webhook:
        // Webhook mode - outbound sending is provider-dependent
        _log.fine(
          'Webhook mode send to $recipientAddress (subject: $subject)',
        );
    }
  }

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    try {
      await send(response);
      return SendResult.success(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (e) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.serverError,
          message: 'Failed to send email: $e',
          retryable: _isRetryableError(e),
        ),
      );
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    throw UnsupportedError('Typing indicators are not supported for email');
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    throw UnsupportedError('Editing sent emails is not supported');
  }

  @override
  Future<void> delete(String messageId) async {
    throw UnsupportedError('Deleting sent emails is not supported');
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    throw UnsupportedError('Reactions are not supported for email');
  }

  @override
  Future<ChannelIdentityInfo?> getIdentityInfo(String userId) async {
    // For email, the userId is the email address
    return ChannelIdentityInfo.user(
      id: userId,
      displayName: null,
      email: userId,
    );
  }

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) async {
    // Email conversations are identified by the recipient address
    return ConversationInfo(
      key: key,
      name: key.conversationId,
      isPrivate: true,
      isGroup: false,
    );
  }

  // =========================================================================
  // Public: Command parsing
  // =========================================================================

  /// Parse a subject-line command from an incoming email.
  ///
  /// If the email subject starts with [prefix], the subject is parsed
  /// as a command event. Returns null if the subject does not match.
  ExtendedChannelEvent? parseSubjectCommand({
    required String messageId,
    required String from,
    required String? subject,
    required String? textBody,
    required String prefix,
    DateTime? timestamp,
  }) {
    final subj = subject ?? '';

    if (!subj.startsWith(prefix)) return null;

    final commandLine = subj.substring(prefix.length).trim();
    final parts = commandLine.split(' ');
    final command = parts.first;
    final args = parts.skip(1).toList();

    final fromEmail = _extractEmailAddress(from) ?? from;
    final domain = _extractDomain(fromEmail);
    final conversationKey = ConversationKey(
      channel: ChannelIdentity(
        platform: 'email',
        channelId: domain,
      ),
      conversationId: messageId,
      userId: fromEmail,
    );

    return ExtendedChannelEvent.command(
      id: messageId,
      userId: fromEmail,
      userName: _extractDisplayName(from),
      conversation: conversationKey,
      extendedConversation: ExtendedConversationKey.create(
        platform: 'email',
        channelId: domain,
        conversationId: messageId,
        tenantId: domain,
        threadId: null,
        userId: fromEmail,
      ),
      command: command,
      commandArgs: args,
      rawPayload: {'body': textBody},
      timestamp: timestamp,
    );
  }

  /// Parse a body-based command from an incoming email.
  ///
  /// Looks for an MCP code block in the email body:
  /// ```mcp
  /// call toolName param1=value1
  /// ```
  ///
  /// Returns null if no MCP code block is found.
  ExtendedChannelEvent? parseBodyCommand({
    required String messageId,
    required String from,
    required String? textBody,
    DateTime? timestamp,
  }) {
    final body = textBody ?? '';
    final mcpBlockPattern = RegExp(r'```mcp\n([\s\S]*?)```');
    final match = mcpBlockPattern.firstMatch(body);

    if (match == null) return null;

    final commandLine = match.group(1)!.trim();
    final parts = commandLine.split(' ');
    final command = parts.first;
    final args = parts.skip(1).toList();

    final fromEmail = _extractEmailAddress(from) ?? from;
    final domain = _extractDomain(fromEmail);
    final conversationKey = ConversationKey(
      channel: ChannelIdentity(
        platform: 'email',
        channelId: domain,
      ),
      conversationId: messageId,
      userId: fromEmail,
    );

    return ExtendedChannelEvent.command(
      id: messageId,
      userId: fromEmail,
      userName: _extractDisplayName(from),
      conversation: conversationKey,
      extendedConversation: ExtendedConversationKey.create(
        platform: 'email',
        channelId: domain,
        conversationId: messageId,
        tenantId: domain,
        threadId: null,
        userId: fromEmail,
      ),
      command: command,
      commandArgs: args,
      rawPayload: {'body': body},
      timestamp: timestamp,
    );
  }

  // =========================================================================
  // Private: OAuth2 token management
  // =========================================================================

  /// Refresh the OAuth2 access token using the refresh token.
  Future<void> _refreshAccessToken() async {
    final clientId = config.credentials['clientId'];
    final clientSecret = config.credentials['clientSecret'];
    final refreshToken = config.credentials['refreshToken'];

    if (clientId == null || clientSecret == null || refreshToken == null) {
      throw const ConnectorException(
        'Missing required credentials: clientId, clientSecret, refreshToken',
        code: 'invalid_credentials',
      );
    }

    final tokenEndpoint = config.credentials['tokenEndpoint'] ??
        _defaultTokenEndpoint(config.provider);

    final response = await _httpClient.post(
      Uri.parse(tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) {
      throw ConnectorException(
        'Token refresh failed: ${response.statusCode} ${response.body}',
        code: 'token_refresh_failed',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = body['access_token'] as String;
    final expiresIn = body['expires_in'] as int? ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

    _log.fine('Access token refreshed, expires in ${expiresIn}s');
  }

  /// Ensure the current access token is valid, refreshing if necessary.
  Future<void> _ensureValidToken() async {
    if (_accessToken == null ||
        _tokenExpiry == null ||
        DateTime.now().isAfter(_tokenExpiry!)) {
      await _refreshAccessToken();
    }
  }

  String _defaultTokenEndpoint(EmailProvider provider) {
    switch (provider) {
      case EmailProvider.gmail:
        return 'https://oauth2.googleapis.com/token';
      case EmailProvider.outlook:
        return 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
      case EmailProvider.imap:
      case EmailProvider.webhook:
        // IMAP and webhook modes do not use OAuth2 token endpoints
        return '';
    }
  }

  // =========================================================================
  // Private: API call helper
  // =========================================================================

  /// Make an authenticated API call to the email provider.
  Future<http.Response> _apiCall(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    await _ensureValidToken();

    final requestHeaders = <String, String>{
      'Authorization': 'Bearer $_accessToken',
      ...?headers,
    };

    http.Response response;
    switch (method) {
      case 'GET':
        response = await _httpClient.get(url, headers: requestHeaders);
      case 'POST':
        response = await _httpClient.post(
          url,
          headers: requestHeaders,
          body: body is String ? body : (body != null ? jsonEncode(body) : null),
        );
      default:
        throw ConnectorException(
          'Unsupported HTTP method: $method',
          code: 'unsupported_method',
        );
    }

    if (response.statusCode == 401) {
      // Token expired, refresh and retry once
      await _refreshAccessToken();
      requestHeaders['Authorization'] = 'Bearer $_accessToken';
      switch (method) {
        case 'GET':
          response = await _httpClient.get(url, headers: requestHeaders);
        case 'POST':
          response = await _httpClient.post(
            url,
            headers: requestHeaders,
            body: body is String
                ? body
                : (body != null ? jsonEncode(body) : null),
          );
      }
    }

    if (response.statusCode == 429) {
      final retryAfter =
          int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
      throw ChannelError.rateLimited(
        retryAfter: Duration(seconds: retryAfter),
      );
    }

    if (response.statusCode >= 500) {
      throw ChannelError.serverError(
        message: 'Email API returned ${response.statusCode}',
      );
    }

    return response;
  }

  // =========================================================================
  // Private: Polling
  // =========================================================================

  void _schedulePolling() {
    _pollingTimer?.cancel();
    if (!_polling) return;

    _pollingTimer = Timer(config.pollingInterval, () async {
      if (!_polling) return;
      try {
        await _pollForNewEmails();
      } catch (e) {
        _log.warning('Email polling error: $e');
      }
      _schedulePolling();
    });
  }

  Future<void> _pollForNewEmails() async {
    switch (config.provider) {
      case EmailProvider.gmail:
        await _pollGmail();
      case EmailProvider.outlook:
        await _pollOutlook();
      case EmailProvider.imap:
        // IMAP polling would use the IMAP config
        _log.fine('IMAP polling not yet implemented');
      case EmailProvider.webhook:
        // Webhook mode does not poll; events arrive via HTTP callbacks
        break;
    }
  }

  // =========================================================================
  // Private: Gmail operations
  // =========================================================================

  static const String _gmailApiBase =
      'https://gmail.googleapis.com/gmail/v1/users/me';

  Future<void> _pollGmail() async {
    // List recent messages
    final queryParams = <String, String>{
      'maxResults': '10',
      'q': 'is:unread',
    };

    if (_lastCheckpoint != null) {
      queryParams['q'] = 'is:unread after:$_lastCheckpoint';
    }

    final listUrl = Uri.parse('$_gmailApiBase/messages')
        .replace(queryParameters: queryParams);
    final listResponse = await _apiCall('GET', listUrl);

    if (listResponse.statusCode != 200) {
      _log.warning('Gmail list messages failed: ${listResponse.statusCode}');
      return;
    }

    final listBody = jsonDecode(listResponse.body) as Map<String, dynamic>;
    final messages = listBody['messages'] as List<dynamic>? ?? [];

    // Update checkpoint to current epoch seconds
    _lastCheckpoint =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    for (final msgRef in messages) {
      final msgMap = msgRef as Map<String, dynamic>;
      final messageId = msgMap['id'] as String;

      // Skip already processed messages
      if (_processedMessageIds.contains(messageId)) continue;
      _processedMessageIds.add(messageId);

      // Fetch full message
      final msgUrl = Uri.parse('$_gmailApiBase/messages/$messageId')
          .replace(queryParameters: {'format': 'full'});
      final msgResponse = await _apiCall('GET', msgUrl);

      if (msgResponse.statusCode != 200) continue;

      final msgBody = jsonDecode(msgResponse.body) as Map<String, dynamic>;
      final event = _parseGmailMessage(msgBody);
      emitEvent(event);
    }

    // Keep processed IDs bounded
    if (_processedMessageIds.length > 1000) {
      final toRemove =
          _processedMessageIds.take(_processedMessageIds.length - 500).toList();
      _processedMessageIds.removeAll(toRemove);
    }
  }

  ChannelEvent _parseGmailMessage(Map<String, dynamic> message) {
    final messageId = message['id'] as String;
    final payload = message['payload'] as Map<String, dynamic>? ?? {};
    final headers = payload['headers'] as List<dynamic>? ?? [];

    String? subject;
    String? from;
    String? fromEmail;
    String? gmailMessageId;
    String? inReplyTo;

    for (final header in headers) {
      final h = header as Map<String, dynamic>;
      final name = (h['name'] as String).toLowerCase();
      final value = h['value'] as String?;

      switch (name) {
        case 'subject':
          subject = value;
        case 'from':
          from = value;
          fromEmail = _extractEmailAddress(value);
        case 'message-id':
          gmailMessageId = value;
        case 'in-reply-to':
          inReplyTo = value;
      }
    }

    // Extract body text
    final bodyText = _extractGmailBodyText(payload);

    final threadId = message['threadId'] as String?;

    // Use sender domain as channelId per design doc
    final senderDomain = _extractDomain(fromEmail ?? 'unknown');

    // Determine thread/conversation ID
    final conversationId = _extractThreadId(
      gmailMessageId: gmailMessageId,
      inReplyTo: inReplyTo,
      threadId: threadId,
      messageId: messageId,
    );

    return ChannelEvent.message(
      id: 'gmail_$messageId',
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'email',
          channelId: senderDomain,
        ),
        conversationId: conversationId,
        userId: fromEmail,
      ),
      text: subject != null ? 'Subject: $subject\n\n$bodyText' : bodyText,
      userId: fromEmail,
      userName: from,
      timestamp: message['internalDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.parse(message['internalDate'] as String))
          : DateTime.now(),
      metadata: {
        'provider': 'gmail',
        'messageId': messageId,
        'threadId': threadId,
        'gmailMessageId': gmailMessageId,
        'inReplyTo': inReplyTo,
        'subject': subject,
        'from': from,
        'fromEmail': fromEmail,
      },
    );
  }

  String _extractGmailBodyText(Map<String, dynamic> payload) {
    // Try to get text/plain part
    final mimeType = payload['mimeType'] as String? ?? '';

    if (mimeType == 'text/plain') {
      final bodyData = payload['body'] as Map<String, dynamic>?;
      final data = bodyData?['data'] as String?;
      if (data != null) {
        return _decodeBase64Url(data);
      }
    }

    // Check parts for multipart messages
    final parts = payload['parts'] as List<dynamic>?;
    if (parts != null) {
      for (final part in parts) {
        final partMap = part as Map<String, dynamic>;
        final partMime = partMap['mimeType'] as String? ?? '';

        if (partMime == 'text/plain') {
          final bodyData = partMap['body'] as Map<String, dynamic>?;
          final data = bodyData?['data'] as String?;
          if (data != null) {
            return _decodeBase64Url(data);
          }
        }

        // Recurse into nested multipart
        if (partMime.startsWith('multipart/')) {
          final nested = _extractGmailBodyText(partMap);
          if (nested.isNotEmpty) return nested;
        }
      }
    }

    return '';
  }

  String _decodeBase64Url(String data) {
    // Gmail uses URL-safe base64 encoding
    final normalized = data.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(
      normalized.length + (4 - normalized.length % 4) % 4,
      '=',
    );
    return utf8.decode(base64Decode(padded));
  }

  Future<void> _sendGmail(
    String to,
    String subject,
    String body,
    Map<String, String> threadHeaders, {
    String? htmlBody,
  }) async {
    // Build RFC 2822 email message
    final fromHeader = config.fromName != null
        ? '${config.fromName} <${config.botEmail}>'
        : config.botEmail;

    final buffer = StringBuffer()
      ..writeln('From: $fromHeader')
      ..writeln('To: $to')
      ..writeln('Subject: $subject')
      ..writeln('MIME-Version: 1.0')
      ..writeln('Content-Type: text/plain; charset=utf-8');

    for (final entry in threadHeaders.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }

    buffer
      ..writeln()
      ..write(body);

    // Gmail requires base64url-encoded raw message
    final rawMessage = base64Url.encode(utf8.encode(buffer.toString()));

    final sendUrl = Uri.parse('$_gmailApiBase/messages/send');
    final response = await _apiCall(
      'POST',
      sendUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'raw': rawMessage}),
    );

    if (response.statusCode != 200) {
      throw ConnectorException(
        'Gmail send failed: ${response.statusCode} ${response.body}',
        code: 'gmail_send_failed',
      );
    }

    _log.fine('Email sent via Gmail to $to');
  }

  // =========================================================================
  // Private: Outlook / Microsoft Graph operations
  // =========================================================================

  static const String _graphApiBase = 'https://graph.microsoft.com/v1.0/me';

  Future<void> _pollOutlook() async {
    // List recent unread messages
    var url = '$_graphApiBase/messages?\$filter=isRead eq false'
        '&\$top=10&\$orderby=receivedDateTime desc'
        '&\$select=id,subject,bodyPreview,body,from,'
        'receivedDateTime,internetMessageId,conversationId,'
        'internetMessageHeaders';

    if (_lastCheckpoint != null) {
      url += ' and receivedDateTime gt $_lastCheckpoint';
    }

    final listResponse = await _apiCall('GET', Uri.parse(url));

    if (listResponse.statusCode != 200) {
      _log.warning('Outlook list messages failed: ${listResponse.statusCode}');
      return;
    }

    final listBody = jsonDecode(listResponse.body) as Map<String, dynamic>;
    final messages = listBody['value'] as List<dynamic>? ?? [];

    // Update checkpoint
    _lastCheckpoint = DateTime.now().toUtc().toIso8601String();

    for (final msg in messages) {
      final msgMap = msg as Map<String, dynamic>;
      final messageId = msgMap['id'] as String;

      // Skip already processed
      if (_processedMessageIds.contains(messageId)) continue;
      _processedMessageIds.add(messageId);

      final event = _parseOutlookMessage(msgMap);
      emitEvent(event);
    }

    // Keep processed IDs bounded
    if (_processedMessageIds.length > 1000) {
      final toRemove =
          _processedMessageIds.take(_processedMessageIds.length - 500).toList();
      _processedMessageIds.removeAll(toRemove);
    }
  }

  ChannelEvent _parseOutlookMessage(Map<String, dynamic> message) {
    final messageId = message['id'] as String;
    final subject = message['subject'] as String?;
    final bodyPreview = message['bodyPreview'] as String?;
    final bodyContent =
        (message['body'] as Map<String, dynamic>?)?['content'] as String?;
    final from = message['from'] as Map<String, dynamic>?;
    final emailAddress =
        from?['emailAddress'] as Map<String, dynamic>? ?? {};
    final fromEmail = emailAddress['address'] as String?;
    final fromName = emailAddress['name'] as String?;
    final receivedDateTime = message['receivedDateTime'] as String?;
    final internetMessageId = message['internetMessageId'] as String?;
    final conversationId = message['conversationId'] as String?;

    // Extract In-Reply-To from internet message headers
    String? inReplyTo;
    final headers = message['internetMessageHeaders'] as List<dynamic>?;
    if (headers != null) {
      for (final header in headers) {
        final h = header as Map<String, dynamic>;
        if ((h['name'] as String?)?.toLowerCase() == 'in-reply-to') {
          inReplyTo = h['value'] as String?;
          break;
        }
      }
    }

    final text = bodyPreview ?? bodyContent ?? '';

    // Use sender domain as channelId per design doc
    final senderDomain = _extractDomain(fromEmail ?? 'unknown');

    // Determine thread/conversation ID
    final threadConversationId = _extractThreadId(
      gmailMessageId: internetMessageId,
      inReplyTo: inReplyTo,
      threadId: conversationId,
      messageId: messageId,
    );

    return ChannelEvent.message(
      id: 'outlook_$messageId',
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'email',
          channelId: senderDomain,
        ),
        conversationId: threadConversationId,
        userId: fromEmail,
      ),
      text: subject != null ? 'Subject: $subject\n\n$text' : text,
      userId: fromEmail,
      userName: fromName,
      timestamp: receivedDateTime != null
          ? DateTime.tryParse(receivedDateTime) ?? DateTime.now()
          : DateTime.now(),
      metadata: {
        'provider': 'outlook',
        'messageId': messageId,
        'internetMessageId': internetMessageId,
        'conversationId': conversationId,
        'inReplyTo': inReplyTo,
        'subject': subject,
        'from': fromName,
        'fromEmail': fromEmail,
      },
    );
  }

  Future<void> _sendOutlook(
    String to,
    String subject,
    String body,
    Map<String, String> threadHeaders, {
    String? htmlBody,
  }) async {
    final sendPayload = <String, dynamic>{
      'message': {
        'subject': subject,
        'body': {
          'contentType': htmlBody != null ? 'HTML' : 'Text',
          'content': htmlBody ?? body,
        },
        'toRecipients': [
          {
            'emailAddress': {'address': to},
          }
        ],
        'from': {
          'emailAddress': {
            'address': config.botEmail,
            if (config.fromName != null) 'name': config.fromName,
          },
        },
        if (threadHeaders.isNotEmpty)
          'internetMessageHeaders': [
            for (final entry in threadHeaders.entries)
              {'name': entry.key, 'value': entry.value},
          ],
      },
      'saveToSentItems': 'true',
    };

    final sendUrl = Uri.parse('$_graphApiBase/sendMail');
    final response = await _apiCall(
      'POST',
      sendUrl,
      headers: {'Content-Type': 'application/json'},
      body: sendPayload,
    );

    // Microsoft Graph returns 202 Accepted for sendMail
    if (response.statusCode != 202 && response.statusCode != 200) {
      throw ConnectorException(
        'Outlook send failed: ${response.statusCode} ${response.body}',
        code: 'outlook_send_failed',
      );
    }

    _log.fine('Email sent via Outlook to $to');
  }

  // =========================================================================
  // Private: HTML response formatting
  // =========================================================================

  /// Format a [ChannelResponse] as HTML for email body.
  ///
  /// Handles block types: header, section, divider, and image.
  /// Falls back to escaping plain text if no blocks are present.
  String _formatHtml(ChannelResponse response) {
    if (response.blocks == null || response.blocks!.isEmpty) {
      return '<p>${_escapeHtml(response.text ?? '')}</p>';
    }

    final buffer = StringBuffer();
    for (final block in response.blocks!) {
      final type = block['type'] as String?;
      final content = block['content'] as Map<String, dynamic>? ?? {};

      switch (type) {
        case 'header':
          buffer.writeln('<h2>${content['text']}</h2>');
        case 'section':
          buffer.writeln('<p>${content['text']}</p>');
        case 'divider':
          buffer.writeln('<hr/>');
        case 'image':
          buffer.writeln(
            '<img src="${content['url']}" alt="${content['altText']}"/>',
          );
      }
    }
    return buffer.toString();
  }

  /// Escape HTML special characters.
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // =========================================================================
  // Private: Thread identification
  // =========================================================================

  /// Extract a thread/conversation ID from email headers.
  ///
  /// Follows the design doc algorithm:
  /// 1. Use References header first (contains full thread)
  /// 2. Fall back to In-Reply-To
  /// 3. Fall back to the message's own ID
  String _extractThreadId({
    String? gmailMessageId,
    String? inReplyTo,
    String? threadId,
    required String messageId,
  }) {
    // If a platform-specific thread ID is available, prefer it
    if (threadId != null) return threadId;

    // Fall back to In-Reply-To
    if (inReplyTo != null) return inReplyTo;

    // Fall back to the message's own Message-ID
    if (gmailMessageId != null) return gmailMessageId;

    // Last resort: use the platform message ID
    return messageId;
  }

  // =========================================================================
  // Private: Helpers
  // =========================================================================

  /// Extract the email address from a `Name <email>` formatted string.
  String? _extractEmailAddress(String? fromHeader) {
    if (fromHeader == null) return null;
    final match = RegExp(r'<([^>]+)>').firstMatch(fromHeader);
    return match?.group(1) ?? fromHeader.trim();
  }

  /// Extract the display name from a `Name <email>` formatted string.
  String? _extractDisplayName(String? fromHeader) {
    if (fromHeader == null) return null;
    final match = RegExp(r'^(.+?)\s*<').firstMatch(fromHeader);
    return match?.group(1)?.trim();
  }

  /// Extract the domain part from an email address.
  String _extractDomain(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex >= 0 && atIndex < email.length - 1) {
      return email.substring(atIndex + 1);
    }
    return email;
  }

  /// Extract subject from response metadata or derive from text.
  String _extractSubject(ChannelResponse response) {
    // Check metadata for explicit subject
    final options = response.options;
    if (options != null && options.containsKey('subject')) {
      return options['subject'] as String;
    }

    // Try metadata in options map
    if (options != null && options.containsKey('metadata')) {
      final metadata = options['metadata'] as Map<String, dynamic>?;
      if (metadata != null && metadata.containsKey('subject')) {
        return metadata['subject'] as String;
      }
    }

    // Derive from first line of text
    final text = response.text ?? '';
    final firstLine = text.split('\n').first.trim();
    if (firstLine.length <= 100) {
      return firstLine;
    }
    return '${firstLine.substring(0, 97)}...';
  }

  bool _isRetryableError(Object error) {
    if (error is ChannelError) return error.retryable;
    if (error is http.ClientException) return true;
    return false;
  }
}
