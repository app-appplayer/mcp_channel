import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as aes_lib;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mcp_bundle/ports.dart';

import '../../core/policy/channel_policy.dart';
import '../../core/policy/circuit_breaker.dart';
import '../../core/policy/rate_limit.dart';
import '../../core/policy/retry.dart';
import '../../core/policy/timeout.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/conversation_info.dart';
import '../../core/port/extended_channel_capabilities.dart';
import '../../core/port/send_result.dart';
import '../../core/types/channel_identity_info.dart';
import '../base_connector.dart';
import 'wecom_config.dart';

final _log = Logger('WeComConnector');

/// WeCom (WeChat Work) channel connector.
///
/// Provides integration with the WeCom messaging platform via its
/// Server API for sending messages and callback URL for receiving events.
///
/// Example usage:
/// ```dart
/// final connector = WeComConnector(
///   config: WeComConfig(
///     corpId: 'ww1234567890',
///     agentId: 1000002,
///     agentSecret: 'your-agent-secret',
///     callbackToken: 'your-callback-token',
///     encodingAesKey: 'your-43-char-aes-key',
///     callbackPath: '/wecom/callback',
///   ),
/// );
///
/// await connector.start();
///
/// await for (final event in connector.events) {
///   // Handle events
/// }
/// ```
class WeComConnector extends BaseConnector {
  WeComConnector({
    required this.config,
    ChannelPolicy? policy,
    http.Client? httpClient,
  })  : policy = policy ?? const ChannelPolicy(
          rateLimit: RateLimitPolicy(
            maxRequests: 20,
            window: Duration(seconds: 1),
          ),
          retry: RetryPolicy(maxAttempts: 3),
          circuitBreaker: CircuitBreakerPolicy(),
          timeout: TimeoutPolicy(),
        ),
        _httpClient = httpClient ?? http.Client();

  @override
  final WeComConfig config;

  @override
  final ChannelPolicy policy;

  final http.Client _httpClient;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.wecom();

  /// Cached access token
  String? _accessToken;

  /// Access token expiration time
  DateTime? _tokenExpiresAt;

  @override
  String get channelType => 'wecom';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'wecom',
        channelId: config.corpId,
        displayName: 'WeCom Connector',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connecting);

    try {
      // Validate credentials by obtaining an access token
      await _ensureAccessToken();
      _log.info('WeCom connector started for corp ${config.corpId}');
      onConnected();
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  @override
  Future<void> doStop() async {
    _accessToken = null;
    _tokenExpiresAt = null;
  }

  @override
  Future<void> send(ChannelResponse response) async {
    if (response.text == null && response.blocks == null) {
      throw ArgumentError('Response must have text or blocks');
    }

    final payload = _buildMessagePayload(response);
    await _sendMessage(payload);
  }

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    if (response.text == null && response.blocks == null) {
      return SendResult.failure(
        error: const ChannelError(
          code: ChannelErrorCode.invalidRequest,
          message: 'Response must have text or blocks',
        ),
      );
    }

    try {
      final payload = _buildMessagePayload(response);
      final result = await _sendMessage(payload);

      final msgId = result['msgid'] as String? ?? '';
      return SendResult.success(
        messageId: msgId,
        platformData: result,
      );
    } catch (e) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.serverError,
          message: 'Failed to send WeCom message: $e',
          retryable: _isRetryableError(e),
        ),
      );
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    // WeCom does not support typing indicators
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) {
    throw UnsupportedError('WeCom does not support message editing');
  }

  @override
  Future<void> delete(String messageId) {
    throw UnsupportedError('WeCom does not support message deletion');
  }

  @override
  Future<void> react(String messageId, String reaction) {
    throw UnsupportedError('WeCom does not support reactions');
  }

  @override
  Future<ChannelIdentityInfo?> getIdentityInfo(String userId) async {
    try {
      final token = await _ensureAccessToken();
      final apiBase = '${config.apiBaseUrl}/cgi-bin';
      final response = await _httpClient.get(
        Uri.parse('$apiBase/user/get?access_token=$token&userid=$userId'),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final errCode = body['errcode'] as int? ?? 0;
      if (errCode != 0) {
        _log.warning(
          'Failed to get user info for $userId: ${body['errmsg']}',
        );
        return null;
      }

      return ChannelIdentityInfo.user(
        id: userId,
        displayName: body['name'] as String?,
        email: body['email'] as String?,
        avatarUrl: body['avatar'] as String?,
        platformData: body,
      );
    } catch (e) {
      _log.warning('Failed to get identity info for $userId: $e');
      return null;
    }
  }

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) async {
    // WeCom does not have a direct "get conversation" API equivalent;
    // conversations are implicitly user-to-agent interactions.
    return null;
  }

  // ===========================================================================
  // Callback handling
  // ===========================================================================

  /// Verify a callback URL request from WeCom.
  ///
  /// WeCom sends a GET request with [msgSignature], [timestamp], [nonce],
  /// and [echoStr] to verify the callback URL. Returns the decrypted
  /// echoStr if verification succeeds, or null on failure.
  String? verifyCallback({
    required String msgSignature,
    required String timestamp,
    required String nonce,
    required String echoStr,
  }) {
    final computedSignature = _computeSignature(
      timestamp: timestamp,
      nonce: nonce,
      encrypt: echoStr,
    );

    if (computedSignature != msgSignature) {
      _log.warning('Callback verification failed: signature mismatch');
      return null;
    }

    return _decryptMessage(echoStr);
  }

  /// Handle an incoming callback event from WeCom.
  ///
  /// WeCom sends a POST request with XML body containing the encrypted
  /// message. The [msgSignature], [timestamp], and [nonce] are passed as
  /// query parameters for signature verification.
  ///
  /// Returns the parsed [ChannelEvent] if successful, or null on failure.
  ChannelEvent? handleCallback({
    required String msgSignature,
    required String timestamp,
    required String nonce,
    required String xmlBody,
  }) {
    // Extract encrypted content from XML
    final encryptMatch =
        RegExp(r'<Encrypt><!\[CDATA\[(.*?)\]\]></Encrypt>').firstMatch(xmlBody);
    if (encryptMatch == null) {
      _log.warning('Failed to extract encrypted content from callback XML');
      return null;
    }

    final encrypt = encryptMatch.group(1)!;

    // Verify signature
    final computedSignature = _computeSignature(
      timestamp: timestamp,
      nonce: nonce,
      encrypt: encrypt,
    );

    if (computedSignature != msgSignature) {
      _log.warning('Callback signature verification failed');
      return null;
    }

    // Decrypt message
    final decrypted = _decryptMessage(encrypt);
    if (decrypted == null) {
      _log.warning('Failed to decrypt callback message');
      return null;
    }

    // Parse decrypted XML to ChannelEvent
    final event = _parseCallbackXml(decrypted);
    if (event != null) {
      emitEvent(event);
    }
    return event;
  }

  // ===========================================================================
  // Private: Access token management
  // ===========================================================================

  /// Ensure a valid access token is available, refreshing if needed.
  ///
  /// WeCom access tokens have a 2-hour TTL. We refresh 5 minutes early
  /// to avoid edge-case expiration during requests.
  Future<String> _ensureAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiresAt != null &&
        DateTime.now().isBefore(_tokenExpiresAt!)) {
      return _accessToken!;
    }

    final apiBase = '${config.apiBaseUrl}/cgi-bin';
    final response = await _httpClient.get(
      Uri.parse(
        '$apiBase/gettoken?corpid=${config.corpId}&corpsecret=${config.agentSecret}',
      ),
    );

    if (response.statusCode != 200) {
      throw ConnectorException(
        'Failed to obtain WeCom access token: HTTP ${response.statusCode}',
        code: 'token_request_failed',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final errCode = body['errcode'] as int? ?? 0;
    if (errCode != 0) {
      throw ConnectorException(
        'Failed to obtain WeCom access token: ${body['errmsg']}',
        code: 'token_error_$errCode',
      );
    }

    _accessToken = body['access_token'] as String;
    final expiresIn = body['expires_in'] as int? ?? 7200;
    // Refresh 5 minutes before actual expiry to prevent edge-case failures
    _tokenExpiresAt = DateTime.now().add(
      Duration(seconds: expiresIn - 300),
    );

    _log.fine('WeCom access token refreshed, expires in ${expiresIn}s');
    return _accessToken!;
  }

  // ===========================================================================
  // Private: Signature verification
  // ===========================================================================

  /// Compute SHA1 signature for callback verification.
  ///
  /// WeCom signature algorithm: sort(callbackToken, timestamp, nonce, encrypt)
  /// then SHA1 hash the concatenated result.
  String _computeSignature({
    required String timestamp,
    required String nonce,
    required String encrypt,
  }) {
    final params = [config.callbackToken, timestamp, nonce, encrypt]..sort();
    final plainText = params.join();
    final digest = sha1.convert(utf8.encode(plainText));
    return digest.toString();
  }

  // ===========================================================================
  // Private: Message encryption/decryption
  // ===========================================================================

  /// Decrypt an AES-encrypted message from WeCom.
  ///
  /// The encodingAesKey is a Base64-encoded 43-character string that
  /// decodes to a 32-byte AES key. WeCom uses AES-256-CBC with the
  /// first 16 bytes of the key as IV.
  ///
  /// Decrypted content format:
  /// random(16 bytes) + msgLen(4 bytes, big-endian) + msg + corpId
  String? _decryptMessage(String encrypted) {
    try {
      // Decode the AES key from encodingAesKey (43 chars Base64 + '=' padding)
      final aesKey = base64Decode('${config.encodingAesKey}=');
      final iv = aes_lib.IV(Uint8List.fromList(aesKey.sublist(0, 16)));

      // Decode the encrypted message
      final encryptedBytes = base64Decode(encrypted);

      // AES-256-CBC decryption with no padding (manual PKCS#7 removal)
      final encrypter = aes_lib.Encrypter(
        aes_lib.AES(
          aes_lib.Key(Uint8List.fromList(aesKey)),
          mode: aes_lib.AESMode.cbc,
          padding: null,
        ),
      );

      final decrypted = encrypter.decryptBytes(
        aes_lib.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: iv,
      );

      // Remove PKCS#7 padding
      final padLen = decrypted.last;
      final content = decrypted.sublist(0, decrypted.length - padLen);

      // Parse: random(16) + msgLen(4) + msg + corpId
      final msgLen = ByteData.sublistView(
        Uint8List.fromList(content),
        16,
        20,
      ).getInt32(0, Endian.big);
      final msg = utf8.decode(content.sublist(20, 20 + msgLen));

      // Verify trailing corpId matches config
      final trailingCorpId = utf8.decode(content.sublist(20 + msgLen));
      if (trailingCorpId != config.corpId) {
        _log.warning(
          'Decrypted corpId mismatch: '
          'expected ${config.corpId}, got $trailingCorpId',
        );
        return null;
      }

      return msg;
    } catch (e) {
      _log.warning('Message decryption failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // Private: API calls
  // ===========================================================================

  /// Send a message via the WeCom message/send API.
  Future<Map<String, dynamic>> _sendMessage(
    Map<String, dynamic> payload,
  ) async {
    final token = await _ensureAccessToken();
    final apiBase = '${config.apiBaseUrl}/cgi-bin';

    final response = await _httpClient.post(
      Uri.parse('$apiBase/message/send?access_token=$token'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 429) {
      throw ChannelError.rateLimited(
        retryAfter: const Duration(seconds: 5),
        platformData: const {'api': 'message/send'},
      );
    }

    if (response.statusCode >= 500) {
      throw ChannelError.serverError(
        message: 'WeCom API message/send returned ${response.statusCode}',
        platformData: {'statusCode': response.statusCode},
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final errCode = body['errcode'] as int? ?? 0;

    if (errCode != 0) {
      final errMsg = body['errmsg'] as String? ?? 'unknown_error';

      // Handle specific error codes
      if (errCode == 45009) {
        // API call frequency limit exceeded
        throw ChannelError.rateLimited(
          message: 'WeCom API rate limit exceeded: $errMsg',
          retryAfter: const Duration(seconds: 30),
        );
      }

      if (errCode == 40001 || errCode == 40014 || errCode == 42001) {
        // Invalid or expired access token; force refresh on next call
        _accessToken = null;
        _tokenExpiresAt = null;
      }

      throw ConnectorException(
        'WeCom API message/send failed: $errMsg (errcode: $errCode)',
        code: 'wecom_$errCode',
      );
    }

    return body;
  }

  /// Build a WeCom message payload from a ChannelResponse.
  Map<String, dynamic> _buildMessagePayload(ChannelResponse response) {
    final payload = <String, dynamic>{
      'agentid': config.agentId,
    };

    // Determine recipient: use userId from conversation or broadcast to all
    final userId = response.conversation.userId;
    if (userId != null && userId.isNotEmpty) {
      payload['touser'] = userId;
    } else {
      // Send to the conversation target or fallback to all users
      final conversationId = response.conversation.conversationId;
      if (conversationId.isNotEmpty && conversationId != 'unknown') {
        payload['touser'] = conversationId;
      } else {
        payload['touser'] = '@all';
      }
    }

    // Determine message type from response type and content
    final msgType =
        response.options?['msgtype'] as String? ?? _inferMessageType(response);

    payload['msgtype'] = msgType;

    switch (msgType) {
      case 'text':
        payload['text'] = {
          'content': response.text ?? '',
        };
        break;

      case 'markdown':
        payload['markdown'] = {
          'content': response.text ?? '',
        };
        break;

      case 'textcard':
        payload['textcard'] = {
          'title': response.options?['title'] ?? '',
          'description': response.text ?? '',
          'url': response.options?['url'] ?? '',
          if (response.options?['btntxt'] != null)
            'btntxt': response.options!['btntxt'],
        };
        break;

      default:
        // Default to text message
        payload['msgtype'] = 'text';
        payload['text'] = {
          'content': response.text ?? '',
        };
        break;
    }

    // Merge any additional platform-specific options
    if (response.options != null) {
      if (response.options!.containsKey('safe')) {
        payload['safe'] = response.options!['safe'];
      }
      if (response.options!.containsKey('enable_id_trans')) {
        payload['enable_id_trans'] = response.options!['enable_id_trans'];
      }
      if (response.options!.containsKey('enable_duplicate_check')) {
        payload['enable_duplicate_check'] =
            response.options!['enable_duplicate_check'];
      }
      if (response.options!.containsKey('duplicate_check_interval')) {
        payload['duplicate_check_interval'] =
            response.options!['duplicate_check_interval'];
      }
    }

    return payload;
  }

  /// Infer the WeCom message type from the response content.
  String _inferMessageType(ChannelResponse response) {
    if (response.type == 'rich' && response.blocks != null) {
      return 'markdown';
    }
    return 'text';
  }

  // ===========================================================================
  // Private: Event parsing
  // ===========================================================================

  /// Parse a decrypted WeCom callback XML into a ChannelEvent.
  ChannelEvent? _parseCallbackXml(String xml) {
    try {
      final msgType = _extractXmlValue(xml, 'MsgType');
      final fromUser = _extractXmlValue(xml, 'FromUserName');
      final createTime = _extractXmlValue(xml, 'CreateTime');
      final msgId = _extractXmlValue(xml, 'MsgId');
      final agentId = _extractXmlValue(xml, 'AgentID');

      final timestamp = createTime != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (int.tryParse(createTime) ?? 0) * 1000,
            )
          : DateTime.now();

      final conversation = ConversationKey(
        channel: ChannelIdentity(
          platform: 'wecom',
          channelId: config.corpId,
        ),
        conversationId: agentId ?? config.agentId.toString(),
        userId: fromUser,
      );

      final eventId = msgId ??
          'wecom_${fromUser}_${DateTime.now().millisecondsSinceEpoch}';

      switch (msgType) {
        case 'text':
          final content = _extractXmlValue(xml, 'Content');
          return ChannelEvent.message(
            id: eventId,
            conversation: conversation,
            text: content ?? '',
            userId: fromUser,
            timestamp: timestamp,
            metadata: {'raw_xml': xml, 'msg_type': msgType},
          );

        case 'image':
          final picUrl = _extractXmlValue(xml, 'PicUrl');
          final mediaId = _extractXmlValue(xml, 'MediaId');
          return ChannelEvent(
            id: eventId,
            conversation: conversation,
            type: 'file',
            userId: fromUser,
            timestamp: timestamp,
            attachments: [
              if (picUrl != null)
                ChannelAttachment(
                  type: 'image',
                  url: picUrl,
                  mimeType: 'image/jpeg',
                ),
            ],
            metadata: {
              'raw_xml': xml,
              'msg_type': msgType,
              'media_id': mediaId,
            },
          );

        case 'voice':
          final mediaId = _extractXmlValue(xml, 'MediaId');
          final format = _extractXmlValue(xml, 'Format');
          return ChannelEvent(
            id: eventId,
            conversation: conversation,
            type: 'file',
            userId: fromUser,
            timestamp: timestamp,
            attachments: [
              if (mediaId != null)
                ChannelAttachment(
                  type: 'audio',
                  url: mediaId,
                  mimeType: format == 'amr' ? 'audio/amr' : 'audio/$format',
                ),
            ],
            metadata: {
              'raw_xml': xml,
              'msg_type': msgType,
              'media_id': mediaId,
            },
          );

        case 'video':
          final mediaId = _extractXmlValue(xml, 'MediaId');
          final thumbMediaId = _extractXmlValue(xml, 'ThumbMediaId');
          return ChannelEvent(
            id: eventId,
            conversation: conversation,
            type: 'file',
            userId: fromUser,
            timestamp: timestamp,
            attachments: [
              if (mediaId != null)
                ChannelAttachment(
                  type: 'video',
                  url: mediaId,
                  mimeType: 'video/mp4',
                ),
            ],
            metadata: {
              'raw_xml': xml,
              'msg_type': msgType,
              'media_id': mediaId,
              'thumb_media_id': thumbMediaId,
            },
          );

        case 'location':
          final locationX = _extractXmlValue(xml, 'Location_X');
          final locationY = _extractXmlValue(xml, 'Location_Y');
          final scale = _extractXmlValue(xml, 'Scale');
          final label = _extractXmlValue(xml, 'Label');
          return ChannelEvent(
            id: eventId,
            conversation: conversation,
            type: 'location',
            text: label,
            userId: fromUser,
            timestamp: timestamp,
            metadata: {
              'raw_xml': xml,
              'msg_type': msgType,
              'latitude': locationX,
              'longitude': locationY,
              'scale': scale,
            },
          );

        case 'event':
          return _parseEventMessage(xml, conversation, fromUser, timestamp);

        default:
          return ChannelEvent(
            id: eventId,
            conversation: conversation,
            type: 'unknown',
            userId: fromUser,
            timestamp: timestamp,
            metadata: {'raw_xml': xml, 'msg_type': msgType},
          );
      }
    } catch (e) {
      _log.warning('Failed to parse callback XML: $e');
      return null;
    }
  }

  /// Parse a WeCom event-type message (e.g., subscribe, click, etc.).
  ChannelEvent _parseEventMessage(
    String xml,
    ConversationKey conversation,
    String? fromUser,
    DateTime timestamp,
  ) {
    final event = _extractXmlValue(xml, 'Event');
    final eventKey = _extractXmlValue(xml, 'EventKey');

    final eventId =
        'wecom_event_${fromUser}_${DateTime.now().millisecondsSinceEpoch}';

    switch (event) {
      case 'subscribe':
        return ChannelEvent(
          id: eventId,
          conversation: conversation,
          type: 'join',
          userId: fromUser,
          timestamp: timestamp,
          metadata: {'raw_xml': xml, 'event': event},
        );

      case 'unsubscribe':
        return ChannelEvent(
          id: eventId,
          conversation: conversation,
          type: 'leave',
          userId: fromUser,
          timestamp: timestamp,
          metadata: {'raw_xml': xml, 'event': event},
        );

      case 'click':
        return ChannelEvent(
          id: eventId,
          conversation: conversation,
          type: 'button',
          text: eventKey,
          userId: fromUser,
          timestamp: timestamp,
          metadata: {
            'raw_xml': xml,
            'event': event,
            'event_key': eventKey,
          },
        );

      case 'enter_agent':
        return ChannelEvent(
          id: eventId,
          conversation: conversation,
          type: 'join',
          userId: fromUser,
          timestamp: timestamp,
          metadata: {
            'raw_xml': xml,
            'event': event,
            'event_key': eventKey,
          },
        );

      default:
        return ChannelEvent(
          id: eventId,
          conversation: conversation,
          type: 'unknown',
          userId: fromUser,
          timestamp: timestamp,
          metadata: {
            'raw_xml': xml,
            'event': event,
            'event_key': eventKey,
          },
        );
    }
  }

  /// Extract a value from a simple XML element.
  ///
  /// Handles both `<Tag>value</Tag>` and `<Tag><![CDATA[value]]></Tag>`.
  String? _extractXmlValue(String xml, String tag) {
    // Try CDATA format first
    final cdataPattern = RegExp('<$tag><!\\[CDATA\\[(.*?)\\]\\]></$tag>');
    final cdataMatch = cdataPattern.firstMatch(xml);
    if (cdataMatch != null) return cdataMatch.group(1);

    // Try plain text format
    final plainPattern = RegExp('<$tag>(.*?)</$tag>');
    final plainMatch = plainPattern.firstMatch(xml);
    if (plainMatch != null) return plainMatch.group(1);

    return null;
  }

  bool _isRetryableError(Object error) {
    if (error is ChannelError) return error.retryable;
    if (error is http.ClientException) return true;
    return false;
  }
}
