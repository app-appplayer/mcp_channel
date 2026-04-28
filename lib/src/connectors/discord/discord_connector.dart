import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mcp_bundle/ports.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/policy/channel_policy.dart';
import '../../core/port/channel_error.dart';
import '../../core/port/connection_state.dart';
import '../../core/port/conversation_info.dart';
import '../../core/port/extended_channel_capabilities.dart';
import '../../core/port/send_result.dart';
import '../../core/types/channel_identity_info.dart';
import '../../core/types/file_info.dart';
import '../base_connector.dart';
import 'discord_config.dart';

final _log = Logger('DiscordConnector');

/// Discord Gateway opcodes.
class _GatewayOp {
  static const int dispatch = 0;
  static const int heartbeat = 1;
  static const int identify = 2;
  static const int resume = 6;
  static const int reconnect = 7;
  static const int invalidSession = 9;
  static const int hello = 10;
  static const int heartbeatAck = 11;
}

/// Discord channel connector via Gateway WebSocket + REST API.
class DiscordConnector extends BaseConnector {
  DiscordConnector({
    required this.config,
    ChannelPolicy? policy,
    http.Client? httpClient,
  })  : policy = policy ?? ChannelPolicy.discord(),
        _httpClient = httpClient ?? http.Client();

  @override
  final DiscordConfig config;

  @override
  final ChannelPolicy policy;

  final http.Client _httpClient;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.discord();

  /// REST API base URL using configured API version.
  String get _apiBase => 'https://discord.com/api/v${config.apiVersion}';

  /// Gateway WebSocket URL using configured API version.
  String get _gatewayUrl =>
      'wss://gateway.discord.gg/?v=${config.apiVersion}&encoding=json';

  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;
  Timer? _heartbeatTimer;
  int? _lastSequence;
  String? _sessionId;
  String? _resumeGatewayUrl;

  /// Per-route rate limit tracking: route -> reset time
  final Map<String, DateTime> _rateLimitBuckets = {};

  @override
  String get channelType => 'discord';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'discord',
        channelId: config.applicationId,
        displayName: 'Discord Bot',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connecting);

    try {
      await _connectGateway();
      onConnected();
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  @override
  Future<void> doStop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close(1000);
    _wsChannel = null;
  }

  @override
  Future<void> send(ChannelResponse response) async {
    final channelId = response.conversation.conversationId;
    final payload = _buildMessagePayload(response);
    await _restCall('POST', '/channels/$channelId/messages', payload);
  }

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    try {
      final channelId = response.conversation.conversationId;
      final payload = _buildMessagePayload(response);
      final result =
          await _restCall('POST', '/channels/$channelId/messages', payload);

      return SendResult.success(
        messageId: result['id'] as String? ?? '',
        platformData: result,
      );
    } catch (e) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.serverError,
          message: 'Failed to send Discord message: $e',
          retryable: _isRetryableError(e),
        ),
      );
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    await _restCall(
        'POST', '/channels/${conversation.conversationId}/typing', {});
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    final channelId = response.conversation.conversationId;
    final payload = _buildMessagePayload(response);
    await _restCall(
        'PATCH', '/channels/$channelId/messages/$messageId', payload);
  }

  @override
  Future<void> delete(String messageId) async {
    // messageId format: "channelId:messageId"
    final parts = messageId.split(':');
    if (parts.length == 2) {
      await _restCall('DELETE', '/channels/${parts[0]}/messages/${parts[1]}', null);
    }
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    final parts = messageId.split(':');
    if (parts.length == 2) {
      final encoded = Uri.encodeComponent(reaction);
      await _restCall(
        'PUT',
        '/channels/${parts[0]}/messages/${parts[1]}/reactions/$encoded/@me',
        null,
      );
    }
  }

  @override
  Future<FileInfo?> uploadFile({
    required ConversationKey conversation,
    required String name,
    required Uint8List data,
    String? mimeType,
  }) async {
    try {
      final channelId = conversation.conversationId;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiBase/channels/$channelId/messages'),
      );
      request.headers['Authorization'] = 'Bot ${config.botToken}';
      request.files.add(http.MultipartFile.fromBytes(
        'files[0]',
        data,
        filename: name,
      ));

      final response = await _httpClient.send(request);
      final body =
          jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;
      final attachments = body['attachments'] as List<dynamic>? ?? [];

      if (attachments.isNotEmpty) {
        final attachment = attachments.first as Map<String, dynamic>;
        return FileInfo(
          id: attachment['id'] as String? ?? '',
          name: name,
          mimeType: mimeType ?? attachment['content_type'] as String? ?? 'application/octet-stream',
          size: data.length,
          url: attachment['url'] as String?,
        );
      }
      return null;
    } catch (e) {
      _log.warning('File upload failed: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> downloadFile(String fileId) async {
    // fileId is expected to be a direct URL for Discord
    try {
      final response = await _httpClient.get(Uri.parse(fileId));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (e) {
      _log.warning('File download failed: $e');
      return null;
    }
  }

  @override
  Future<ChannelIdentityInfo?> getIdentityInfo(String userId) async {
    try {
      final result = await _restCall('GET', '/users/$userId', null);
      return ChannelIdentityInfo.user(
        id: userId,
        displayName: result['global_name'] as String? ??
            result['username'] as String?,
        username: result['username'] as String?,
        avatarUrl: result['avatar'] != null
            ? 'https://cdn.discordapp.com/avatars/$userId/${result['avatar']}.png'
            : null,
        platformData: result,
      );
    } catch (e) {
      _log.warning('Failed to get identity for $userId: $e');
      return null;
    }
  }

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) async {
    try {
      final result =
          await _restCall('GET', '/channels/${key.conversationId}', null);
      final type = result['type'] as int? ?? 0;

      return ConversationInfo(
        key: key,
        name: result['name'] as String?,
        topic: result['topic'] as String?,
        isPrivate: type == 1, // DM
        isGroup: type == 3, // GROUP_DM
        platformData: result,
      );
    } catch (e) {
      _log.warning('Failed to get conversation: $e');
      return null;
    }
  }

  /// Acknowledge an interaction (must respond within 3 seconds).
  ///
  /// Sends a deferred response so the bot can process the interaction
  /// and follow up later via [followUpInteraction].
  Future<void> acknowledgeInteraction(
    String interactionId,
    String interactionToken, {
    bool ephemeral = false,
  }) async {
    await _restCall(
      'POST',
      '/interactions/$interactionId/$interactionToken/callback',
      {
        'type': 5, // DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE
        'data': {
          if (ephemeral) 'flags': 64, // EPHEMERAL
        },
      },
    );
  }

  /// Follow up an acknowledged interaction with the actual response.
  Future<void> followUpInteraction(
    String interactionToken,
    ChannelResponse response,
  ) async {
    final payload = _buildMessagePayload(response);
    await _restCall(
      'POST',
      '/webhooks/${config.applicationId}/$interactionToken',
      payload,
    );
  }

  /// Show a modal dialog in response to an interaction.
  ///
  /// The [components] list should contain action row maps with text input
  /// components conforming to the Discord modal component structure.
  Future<void> showModal(
    String interactionId,
    String interactionToken, {
    required String customId,
    required String title,
    required List<Map<String, dynamic>> components,
  }) async {
    await _restCall(
      'POST',
      '/interactions/$interactionId/$interactionToken/callback',
      {
        'type': 9, // MODAL
        'data': {
          'custom_id': customId,
          'title': title,
          'components': components,
        },
      },
    );
  }

  // =========================================================================
  // Private: Gateway
  // =========================================================================

  Future<void> _connectGateway() async {
    final url = _resumeGatewayUrl ?? _gatewayUrl;
    _wsChannel = WebSocketChannel.connect(Uri.parse(url));
    await _wsChannel!.ready;

    _wsSubscription = _wsChannel!.stream.listen(
      _handleGatewayMessage,
      onError: (Object error) {
        _log.severe('Gateway error: $error');
        onDisconnected();
      },
      onDone: () {
        _log.info('Gateway connection closed');
        onDisconnected();
      },
    );
  }

  void _handleGatewayMessage(dynamic data) {
    final payload = jsonDecode(data as String) as Map<String, dynamic>;
    final op = payload['op'] as int;
    final d = payload['d'];
    final s = payload['s'] as int?;
    final t = payload['t'] as String?;

    if (s != null) _lastSequence = s;

    switch (op) {
      case _GatewayOp.hello:
        final heartbeatInterval =
            (d as Map<String, dynamic>)['heartbeat_interval'] as int;
        _startHeartbeat(Duration(milliseconds: heartbeatInterval));
        if (_sessionId != null) {
          _sendResume();
        } else {
          _sendIdentify();
        }
        break;

      case _GatewayOp.heartbeatAck:
        // Heartbeat acknowledged
        break;

      case _GatewayOp.dispatch:
        _handleDispatch(t!, d as Map<String, dynamic>);
        break;

      case _GatewayOp.reconnect:
        _log.info('Gateway requested reconnect');
        onDisconnected();
        break;

      case _GatewayOp.invalidSession:
        final resumable = d as bool? ?? false;
        if (!resumable) {
          _sessionId = null;
          _lastSequence = null;
        }
        // Wait then re-identify
        Future<void>.delayed(const Duration(seconds: 2)).then((_) {
          _sendIdentify();
        });
        break;
    }
  }

  void _startHeartbeat(Duration interval) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(interval, (_) {
      _wsChannel?.sink.add(jsonEncode({
        'op': _GatewayOp.heartbeat,
        'd': _lastSequence,
      }));
    });
  }

  void _sendIdentify() {
    _wsChannel?.sink.add(jsonEncode({
      'op': _GatewayOp.identify,
      'd': {
        'token': config.botToken,
        'intents': config.intents,
        'properties': {
          'os': Platform.operatingSystem,
          'browser': 'mcp_channel',
          'device': 'mcp_channel',
        },
        if (config.compress) 'compress': true,
        if (config.shardId != null && config.totalShards != null)
          'shard': [config.shardId, config.totalShards],
      },
    }));
  }

  void _sendResume() {
    _wsChannel?.sink.add(jsonEncode({
      'op': _GatewayOp.resume,
      'd': {
        'token': config.botToken,
        'session_id': _sessionId,
        'seq': _lastSequence,
      },
    }));
  }

  void _handleDispatch(String eventName, Map<String, dynamic> data) {
    switch (eventName) {
      case 'READY':
        _sessionId = data['session_id'] as String?;
        _resumeGatewayUrl = data['resume_gateway_url'] as String?;
        _log.info('Discord Gateway ready, session: $_sessionId');
        break;

      case 'MESSAGE_CREATE':
        emitEvent(_parseMessageCreate(data));
        break;

      case 'MESSAGE_UPDATE':
        emitEvent(_parseMessageUpdate(data));
        break;

      case 'MESSAGE_REACTION_ADD':
        emitEvent(_parseReactionAdd(data));
        break;

      case 'INTERACTION_CREATE':
        emitEvent(_parseInteraction(data));
        break;

      default:
        _log.fine('Unhandled dispatch: $eventName');
    }
  }

  // =========================================================================
  // Private: REST API
  // =========================================================================

  Future<Map<String, dynamic>> _restCall(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    // Check per-route rate limit
    final now = DateTime.now();
    final resetTime = _rateLimitBuckets[path];
    if (resetTime != null && now.isBefore(resetTime)) {
      await Future<void>.delayed(resetTime.difference(now));
    }

    final uri = Uri.parse('$_apiBase$path');
    final headers = <String, String>{
      'Authorization': 'Bot ${config.botToken}',
      if (body != null) 'Content-Type': 'application/json',
    };

    http.Response response;
    switch (method) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
        break;
      case 'POST':
        response =
            await _httpClient.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        response =
            await _httpClient.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PUT':
        response =
            await _httpClient.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    // Parse rate limit headers
    final remaining =
        int.tryParse(response.headers['x-ratelimit-remaining'] ?? '');
    final resetAfter =
        double.tryParse(response.headers['x-ratelimit-reset-after'] ?? '');
    if (remaining != null && remaining == 0 && resetAfter != null) {
      _rateLimitBuckets[path] = DateTime.now()
          .add(Duration(milliseconds: (resetAfter * 1000).toInt()));
    }

    if (response.statusCode == 429) {
      final retryBody = jsonDecode(response.body) as Map<String, dynamic>;
      final retryAfter = retryBody['retry_after'] as double? ?? 1.0;
      throw ChannelError.rateLimited(
        retryAfter: Duration(milliseconds: (retryAfter * 1000).toInt()),
      );
    }

    if (response.statusCode >= 500) {
      throw ChannelError.serverError(
        message: 'Discord API $method $path returned ${response.statusCode}',
      );
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      return {};
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw ConnectorException(
        'Discord API error: ${responseBody['message'] ?? response.statusCode}',
        code: responseBody['code']?.toString(),
      );
    }

    return responseBody;
  }

  Map<String, dynamic> _buildMessagePayload(ChannelResponse response) {
    final payload = <String, dynamic>{};

    if (response.text != null) {
      payload['content'] = response.text;
    }

    if (response.blocks != null) {
      payload['embeds'] = _blocksToEmbeds(response.blocks!);
    }

    if (response.replyTo != null) {
      payload['message_reference'] = {
        'message_id': response.replyTo,
      };
    }

    return payload;
  }

  List<Map<String, dynamic>> _blocksToEmbeds(
      List<Map<String, dynamic>> blocks) {
    // Convert generic blocks to Discord embeds
    final embeds = <Map<String, dynamic>>[];
    for (final block in blocks) {
      final type = block['type'] as String?;
      switch (type) {
        case 'section':
          embeds.add({
            'description': block['text'] ?? '',
          });
          break;
        case 'header':
          embeds.add({
            'title': block['text'] ?? '',
          });
          break;
        case 'image':
          embeds.add({
            'image': {'url': block['url'] ?? ''},
          });
          break;
      }
    }
    return embeds;
  }

  // =========================================================================
  // Event parsing
  // =========================================================================

  ChannelEvent _parseMessageCreate(Map<String, dynamic> data) {
    final author = data['author'] as Map<String, dynamic>? ?? {};
    final channelId = data['channel_id'] as String? ?? 'unknown';
    final guildId = data['guild_id'] as String? ?? 'dm';
    final messageId = data['id'] as String? ?? '';

    return ChannelEvent.message(
      id: 'dc_$messageId',
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'discord',
          channelId: guildId,
        ),
        conversationId: channelId,
        userId: author['id'] as String?,
      ),
      text: data['content'] as String? ?? '',
      userId: author['id'] as String?,
      userName: author['global_name'] as String? ??
          author['username'] as String?,
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      metadata: data,
    );
  }

  ChannelEvent _parseMessageUpdate(Map<String, dynamic> data) {
    final author = data['author'] as Map<String, dynamic>? ?? {};
    final channelId = data['channel_id'] as String? ?? 'unknown';
    final guildId = data['guild_id'] as String? ?? 'dm';
    final messageId = data['id'] as String? ?? '';

    return ChannelEvent.message(
      id: 'dc_upd_$messageId',
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'discord',
          channelId: guildId,
        ),
        conversationId: channelId,
        userId: author['id'] as String?,
      ),
      text: data['content'] as String? ?? '',
      userId: author['id'] as String?,
      userName: author['global_name'] as String? ??
          author['username'] as String?,
      timestamp: data['edited_timestamp'] != null
          ? DateTime.tryParse(data['edited_timestamp'] as String) ??
              DateTime.now()
          : DateTime.now(),
      metadata: {
        ...data,
        'is_edit': true,
      },
    );
  }

  ChannelEvent _parseReactionAdd(Map<String, dynamic> data) {
    final emoji = data['emoji'] as Map<String, dynamic>? ?? {};
    return ChannelEvent(
      id: 'dc_react_${data['message_id']}_${data['user_id']}',
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'discord',
          channelId: data['guild_id'] as String? ?? 'dm',
        ),
        conversationId: data['channel_id'] as String? ?? 'unknown',
        userId: data['user_id'] as String?,
      ),
      type: 'reaction',
      text: emoji['name'] as String?,
      userId: data['user_id'] as String?,
      timestamp: DateTime.now(),
      metadata: {
        ...data,
        'target_message_id': data['message_id'],
      },
    );
  }

  ChannelEvent _parseInteraction(Map<String, dynamic> data) {
    final interactionData = data['data'] as Map<String, dynamic>? ?? {};
    final user = data['user'] as Map<String, dynamic>? ??
        (data['member'] as Map<String, dynamic>?)?['user'] as Map<String, dynamic>? ??
        {};

    return ChannelEvent(
      id: 'dc_int_${data['id']}',
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'discord',
          channelId: data['guild_id'] as String? ?? 'dm',
        ),
        conversationId: data['channel_id'] as String? ?? 'unknown',
        userId: user['id'] as String?,
      ),
      type: 'command',
      text: '/${interactionData['name'] ?? ''}',
      userId: user['id'] as String?,
      userName: user['global_name'] as String? ?? user['username'] as String?,
      timestamp: DateTime.now(),
      metadata: {
        ...data,
        'command': interactionData['name'],
        'interaction_id': data['id'],
        'interaction_token': data['token'],
      },
    );
  }

  bool _isRetryableError(Object error) {
    if (error is ChannelError) return error.retryable;
    if (error is http.ClientException) return true;
    return false;
  }
}
