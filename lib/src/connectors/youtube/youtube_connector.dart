import 'dart:async' show unawaited;
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
import '../base_connector.dart';
import 'youtube_config.dart';

final _log = Logger('YouTubeConnector');

/// YouTube channel connector.
///
/// Provides integration with YouTube via the Data API v3 and Live Streaming
/// API. Supports polling for live chat messages and video comment threads.
///
/// Write operations (send, delete, edit) require OAuth2 credentials to be
/// configured in [YouTubeConfig.credentials].
///
/// Example usage:
/// ```dart
/// final connector = YouTubeConnector(
///   config: YouTubeConfig(
///     apiKey: 'AIza...',
///     channelId: 'UC...',
///     mode: YouTubeMode.comments,
///     videoIds: ['VIDEO_ID_1'],
///     commandPrefix: '!bot',
///     credentials: {
///       'clientId': '...',
///       'clientSecret': '...',
///       'refreshToken': '...',
///     },
///   ),
/// );
///
/// await connector.start();
///
/// await for (final event in connector.events) {
///   // Handle live chat messages or comments
/// }
/// ```
class YouTubeConnector extends BaseConnector {
  YouTubeConnector({
    required this.config,
    ChannelPolicy? policy,
    http.Client? httpClient,
  })  : policy = policy ?? const ChannelPolicy(),
        _httpClient = httpClient ?? http.Client();

  @override
  final YouTubeConfig config;

  @override
  final ChannelPolicy policy;

  final http.Client _httpClient;

  final ExtendedChannelCapabilities _extendedCapabilities =
      ExtendedChannelCapabilities.youtube();

  static const String _apiBase = 'https://www.googleapis.com/youtube/v3';
  static const String _oauthTokenUrl =
      'https://oauth2.googleapis.com/token';

  // Quota cost constants (YouTube Data API v3)
  static const int _quotaCostList = 1;
  static const int _quotaCostInsert = 50;
  static const int _quotaCostUpdate = 50;
  static const int _quotaCostDelete = 50;
  static const int _quotaCostLiveChatList = 5;
  static const int _quotaCostLiveChatInsert = 200;

  /// Maximum character length for live chat messages.
  static const int liveChatMaxLength = 200;

  bool _polling = false;
  String? _liveChatPageToken;
  String? _commentPageToken;
  String? _accessToken;
  DateTime? _tokenExpiry;
  int _quotaUsed = 0;
  DateTime _quotaResetTime = _nextMidnightPT();

  @override
  String get channelType => 'youtube';

  @override
  ChannelIdentity get identity => ChannelIdentity(
        platform: 'youtube',
        channelId: config.channelId ?? config.liveChatId ?? 'default',
        displayName: 'YouTube Connector',
      );

  @override
  ChannelCapabilities get capabilities => _extendedCapabilities;

  @override
  ExtendedChannelCapabilities get extendedCapabilities => _extendedCapabilities;

  /// Current daily quota usage.
  int get quotaUsed => _quotaUsed;

  /// Remaining daily quota.
  int get quotaRemaining => config.quotaBudget - _quotaUsed;

  /// Check if a quota cost can be afforded, applying midnight PT reset.
  bool canUseQuota(int cost) {
    _checkQuotaReset();
    return _quotaUsed + cost <= config.quotaBudget;
  }

  /// Reset the quota counter (typically called at day boundary).
  void resetQuota() {
    _quotaUsed = 0;
  }

  @override
  Future<void> start() async {
    updateConnectionState(ConnectionState.connecting);

    try {
      // Refresh OAuth2 token if credentials are configured
      if (config.hasOAuth2Credentials) {
        await _refreshAccessToken();
      }

      _polling = true;

      final shouldPollComments = config.mode == YouTubeMode.comments ||
          config.mode == YouTubeMode.both;
      final shouldPollLiveChat = config.mode == YouTubeMode.liveChat ||
          config.mode == YouTubeMode.both;

      if (shouldPollLiveChat && config.liveChatId != null) {
        unawaited(_pollLiveChat());
      }

      if (shouldPollComments && config.channelId != null) {
        unawaited(_pollComments());
      }

      onConnected();
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  @override
  Future<void> doStop() async {
    _polling = false;
  }

  @override
  Future<void> send(ChannelResponse response) async {
    _ensureOAuth2();

    if (response.text == null) {
      throw ArgumentError('Response must have text content');
    }

    if (config.liveChatId != null) {
      await _sendLiveChatMessage(
        config.liveChatId!,
        response.text!,
      );
    } else if (response.replyTo != null) {
      // Reply to a comment thread
      await _sendCommentReply(
        response.replyTo!,
        response.text!,
      );
    } else {
      throw const ConnectorException(
        'YouTube send requires either a liveChatId or a replyTo comment ID',
        code: 'missing_target',
      );
    }
  }

  @override
  Future<SendResult> sendWithResult(ChannelResponse response) async {
    try {
      _ensureOAuth2();

      if (response.text == null) {
        return SendResult.failure(
          error: const ChannelError(
            code: ChannelErrorCode.invalidRequest,
            message: 'Response must have text content',
          ),
        );
      }

      Map<String, dynamic> result;

      if (config.liveChatId != null) {
        result = await _sendLiveChatMessage(
          config.liveChatId!,
          response.text!,
        );
      } else if (response.replyTo != null) {
        result = await _sendCommentReply(
          response.replyTo!,
          response.text!,
        );
      } else {
        return SendResult.failure(
          error: const ChannelError(
            code: ChannelErrorCode.invalidRequest,
            message:
                'YouTube send requires either a liveChatId or a replyTo comment ID',
          ),
        );
      }

      final messageId = result['id'] as String? ?? '';
      return SendResult.success(
        messageId: messageId,
        platformData: result,
      );
    } catch (e) {
      return SendResult.failure(
        error: ChannelError(
          code: ChannelErrorCode.serverError,
          message: 'Failed to send YouTube message: $e',
          retryable: _isRetryableError(e),
        ),
      );
    }
  }

  @override
  Future<void> sendTyping(ConversationKey conversation) async {
    throw UnsupportedError(
      'YouTube does not support typing indicators',
    );
  }

  @override
  Future<void> edit(String messageId, ChannelResponse response) async {
    _ensureOAuth2();

    if (response.text == null) {
      throw ArgumentError('Response must have text content');
    }

    // Live chat messages cannot be edited
    if (config.liveChatId != null && messageId.contains('.')) {
      throw UnsupportedError(
        'YouTube live chat messages cannot be edited',
      );
    }

    // Edit a comment via PUT to comments endpoint
    await _editComment(messageId, response.text!);
  }

  @override
  Future<void> delete(String messageId) async {
    _ensureOAuth2();

    // Determine if this is a live chat message or comment by format.
    // Live chat message IDs typically contain dots, while comment IDs
    // use alphanumeric patterns like "Ugx..." or "UgyB...".
    if (config.liveChatId != null && messageId.contains('.')) {
      await _deleteLiveChatMessage(messageId);
    } else {
      await _deleteComment(messageId);
    }
  }

  @override
  Future<void> react(String messageId, String reaction) async {
    throw UnsupportedError(
      'YouTube does not support reactions',
    );
  }

  // =========================================================================
  // Public: Moderation actions (live chat)
  // =========================================================================

  /// Ban a user from live chat permanently.
  Future<void> banUser(String liveChatId, String userId) async {
    _ensureOAuth2();

    await _apiCall(
      'POST',
      'liveChat/bans',
      queryParams: {'part': 'snippet'},
      body: {
        'snippet': {
          'liveChatId': liveChatId,
          'type': 'permanent',
          'bannedUserDetails': {
            'channelId': userId,
          },
        },
      },
      quotaCost: _quotaCostInsert,
      requiresAuth: true,
    );
  }

  /// Timeout a user from live chat for a specified duration.
  Future<void> timeoutUser(
    String liveChatId,
    String userId,
    Duration duration,
  ) async {
    _ensureOAuth2();

    await _apiCall(
      'POST',
      'liveChat/bans',
      queryParams: {'part': 'snippet'},
      body: {
        'snippet': {
          'liveChatId': liveChatId,
          'type': 'temporary',
          'banDurationSeconds': duration.inSeconds.toString(),
          'bannedUserDetails': {
            'channelId': userId,
          },
        },
      },
      quotaCost: _quotaCostInsert,
      requiresAuth: true,
    );
  }

  // =========================================================================
  // Public: Command parsing
  // =========================================================================

  /// Parse a prefix-based command from message text.
  ///
  /// Returns an [ExtendedChannelEvent] with type [ChannelEventType.command]
  /// if the text starts with the configured command prefix. Returns `null`
  /// if no prefix is configured or the text does not match.
  ///
  /// Example: with prefix "!bot", text "!bot search flutter" produces
  /// command="search", args=["flutter"].
  ExtendedChannelEvent? parseCommand(
    String text,
    ConversationKey conversation, {
    String? userId,
    String? userName,
    DateTime? timestamp,
  }) {
    final prefix = config.commandPrefix;
    if (prefix == null) return null;

    if (!text.startsWith(prefix)) return null;

    final commandLine = text.substring(prefix.length).trim();
    if (commandLine.isEmpty) return null;

    final parts = commandLine.split(' ');
    final command = parts.first;
    final args = parts.skip(1).toList();

    return ExtendedChannelEvent.command(
      id: 'yt_cmd_${DateTime.now().millisecondsSinceEpoch}',
      conversation: conversation,
      command: command,
      commandArgs: args,
      userId: userId,
      userName: userName,
      timestamp: timestamp,
    );
  }

  @override
  Future<ChannelIdentityInfo?> getIdentityInfo(String userId) async {
    try {
      final result = await _apiCall(
        'GET',
        'channels',
        queryParams: {
          'part': 'snippet',
          'id': userId,
        },
        quotaCost: _quotaCostList,
      );

      final items = result['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final channel = items.first as Map<String, dynamic>;
      final snippet = channel['snippet'] as Map<String, dynamic>? ?? {};
      final thumbnails =
          snippet['thumbnails'] as Map<String, dynamic>? ?? {};
      final defaultThumb =
          thumbnails['default'] as Map<String, dynamic>? ?? {};

      return ChannelIdentityInfo.user(
        id: userId,
        displayName: snippet['title'] as String?,
        username: snippet['customUrl'] as String?,
        avatarUrl: defaultThumb['url'] as String?,
        platformData: channel,
      );
    } catch (e) {
      _log.warning('Failed to get identity info for $userId: $e');
      return null;
    }
  }

  @override
  Future<ConversationInfo?> getConversation(ConversationKey key) async {
    try {
      // For live chat, the conversation is the live chat itself
      if (config.liveChatId != null) {
        return ConversationInfo(
          key: key,
          name: 'YouTube Live Chat',
          isPrivate: false,
          isGroup: true,
          platformData: {'liveChatId': config.liveChatId},
        );
      }

      // For comments, look up the video info
      final result = await _apiCall(
        'GET',
        'videos',
        queryParams: {
          'part': 'snippet',
          'id': key.conversationId,
        },
        quotaCost: _quotaCostList,
      );

      final items = result['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final video = items.first as Map<String, dynamic>;
      final snippet = video['snippet'] as Map<String, dynamic>? ?? {};

      return ConversationInfo(
        key: key,
        name: snippet['title'] as String?,
        topic: snippet['description'] as String?,
        isPrivate: false,
        isGroup: true,
        platformData: video,
      );
    } catch (e) {
      _log.warning('Failed to get conversation info: $e');
      return null;
    }
  }

  // =========================================================================
  // Private: Polling
  // =========================================================================

  Future<void> _pollLiveChat() async {
    while (_polling) {
      try {
        final params = <String, String>{
          'part': 'snippet,authorDetails',
          'liveChatId': config.liveChatId!,
          'maxResults': '200',
        };
        if (_liveChatPageToken != null) {
          params['pageToken'] = _liveChatPageToken!;
        }

        final result = await _apiCall(
          'GET',
          'liveChat/messages',
          queryParams: params,
          quotaCost: _quotaCostLiveChatList,
        );

        _liveChatPageToken = result['nextPageToken'] as String?;
        final pollingIntervalMs =
            result['pollingIntervalMillis'] as int?;

        final items = result['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final message = item as Map<String, dynamic>;
          final event = _parseLiveChatMessage(message);
          emitEvent(event);
        }

        // Use server-suggested polling interval if available,
        // otherwise fall back to configured interval.
        final delay = pollingIntervalMs != null
            ? Duration(milliseconds: pollingIntervalMs)
            : config.pollingInterval;
        await Future<void>.delayed(delay);
      } catch (e) {
        _log.warning('Live chat polling error: $e');
        if (_polling) {
          await Future<void>.delayed(config.pollingInterval);
        }
      }
    }
  }

  Future<void> _pollComments() async {
    while (_polling) {
      try {
        final params = <String, String>{
          'part': 'snippet',
          'allThreadsRelatedToChannelId': config.channelId!,
          'order': 'time',
          'maxResults': '100',
        };
        if (_commentPageToken != null) {
          params['pageToken'] = _commentPageToken!;
        }

        final result = await _apiCall(
          'GET',
          'commentThreads',
          queryParams: params,
          quotaCost: _quotaCostList,
        );

        _commentPageToken = result['nextPageToken'] as String?;

        final items = result['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final thread = item as Map<String, dynamic>;
          final event = _parseCommentThread(thread);
          emitEvent(event);
        }

        await Future<void>.delayed(config.pollingInterval);
      } catch (e) {
        _log.warning('Comment polling error: $e');
        if (_polling) {
          await Future<void>.delayed(config.pollingInterval);
        }
      }
    }
  }

  // =========================================================================
  // Private: Send operations
  // =========================================================================

  Future<Map<String, dynamic>> _sendLiveChatMessage(
    String liveChatId,
    String text,
  ) async {
    // Live chat messages are limited to 200 characters
    final truncated = text.length > liveChatMaxLength
        ? '${text.substring(0, liveChatMaxLength - 3)}...'
        : text;

    return _apiCall(
      'POST',
      'liveChat/messages',
      queryParams: {'part': 'snippet'},
      body: {
        'snippet': {
          'liveChatId': liveChatId,
          'type': 'textMessageEvent',
          'textMessageDetails': {
            'messageText': truncated,
          },
        },
      },
      quotaCost: _quotaCostLiveChatInsert,
      requiresAuth: true,
    );
  }

  Future<Map<String, dynamic>> _sendCommentReply(
    String parentId,
    String text,
  ) async {
    return _apiCall(
      'POST',
      'comments',
      queryParams: {'part': 'snippet'},
      body: {
        'snippet': {
          'parentId': parentId,
          'textOriginal': text,
        },
      },
      quotaCost: _quotaCostInsert,
      requiresAuth: true,
    );
  }

  // =========================================================================
  // Private: Edit operations
  // =========================================================================

  Future<Map<String, dynamic>> _editComment(
    String commentId,
    String text,
  ) async {
    return _apiCall(
      'PUT',
      'comments',
      queryParams: {'part': 'snippet'},
      body: {
        'id': commentId,
        'snippet': {
          'textOriginal': text,
        },
      },
      quotaCost: _quotaCostUpdate,
      requiresAuth: true,
    );
  }

  // =========================================================================
  // Private: Delete operations
  // =========================================================================

  Future<void> _deleteLiveChatMessage(String messageId) async {
    await _apiCall(
      'DELETE',
      'liveChat/messages',
      queryParams: {'id': messageId},
      quotaCost: _quotaCostDelete,
      requiresAuth: true,
    );
  }

  Future<void> _deleteComment(String commentId) async {
    await _apiCall(
      'DELETE',
      'comments',
      queryParams: {'id': commentId},
      quotaCost: _quotaCostDelete,
      requiresAuth: true,
    );
  }

  // =========================================================================
  // Private: Quota management
  // =========================================================================

  /// Check if the quota should be reset (midnight Pacific Time).
  void _checkQuotaReset() {
    if (DateTime.now().toUtc().isAfter(_quotaResetTime)) {
      _quotaUsed = 0;
      _quotaResetTime = _nextMidnightPT();
    }
  }

  /// Calculate the next midnight Pacific Time in UTC.
  ///
  /// YouTube API quota resets at midnight Pacific Time (PT).
  /// PT is UTC-8 (PST) or UTC-7 (PDT). This uses UTC-8 as a
  /// conservative estimate.
  static DateTime _nextMidnightPT() {
    final now = DateTime.now().toUtc();
    // Pacific Time is UTC-8 (PST). Convert UTC to PT.
    final ptNow = now.subtract(const Duration(hours: 8));
    // Next midnight in PT
    final nextMidnightPT = DateTime(ptNow.year, ptNow.month, ptNow.day + 1);
    // Convert back to UTC
    return nextMidnightPT.add(const Duration(hours: 8));
  }

  // =========================================================================
  // Private: OAuth2 token management
  // =========================================================================

  void _ensureOAuth2() {
    if (!config.hasOAuth2Credentials) {
      throw const ConnectorException(
        'OAuth2 credentials are required for write operations',
        code: 'oauth2_required',
      );
    }
  }

  Future<void> _refreshAccessToken() async {
    final creds = config.credentials!;

    final response = await _httpClient.post(
      Uri.parse(_oauthTokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': creds['clientId']!,
        'client_secret': creds['clientSecret']!,
        'refresh_token': creds['refreshToken']!,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) {
      throw ConnectorException(
        'Failed to refresh OAuth2 token: ${response.statusCode}',
        code: 'oauth2_refresh_failed',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = body['access_token'] as String;
    final expiresIn = body['expires_in'] as int? ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
  }

  Future<String> _getAccessToken() async {
    if (_accessToken == null ||
        _tokenExpiry == null ||
        DateTime.now().isAfter(_tokenExpiry!)) {
      await _refreshAccessToken();
    }
    return _accessToken!;
  }

  // =========================================================================
  // Private: API call helper
  // =========================================================================

  /// Generic YouTube API call helper.
  ///
  /// Handles API key or OAuth2 authentication, quota tracking,
  /// and error responses.
  Future<Map<String, dynamic>> _apiCall(
    String method,
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    int quotaCost = 0,
    bool requiresAuth = false,
  }) async {
    // Check quota budget with midnight PT reset
    _checkQuotaReset();

    if (_quotaUsed + quotaCost > config.quotaBudget) {
      throw const ConnectorException(
        'YouTube API daily quota budget exceeded',
        code: 'quota_exceeded',
      );
    }

    final params = Map<String, String>.from(queryParams ?? {});

    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (requiresAuth && config.hasOAuth2Credentials) {
      final token = await _getAccessToken();
      headers['Authorization'] = 'Bearer $token';
    } else {
      // Use API key for read-only requests
      params['key'] = config.apiKey;
    }

    final uri = Uri.parse('$_apiBase/$endpoint')
        .replace(queryParameters: params);

    http.Response response;

    switch (method) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
        break;
      case 'POST':
        headers['Content-Type'] = 'application/json';
        response = await _httpClient.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        headers['Content-Type'] = 'application/json';
        response = await _httpClient.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
        break;
      default:
        throw ConnectorException(
          'Unsupported HTTP method: $method',
          code: 'unsupported_method',
        );
    }

    // Track quota usage on successful call
    _quotaUsed += quotaCost;

    if (response.statusCode == 429) {
      throw ChannelError.rateLimited(
        message: 'YouTube API rate limit exceeded',
        retryAfter: const Duration(seconds: 60),
      );
    }

    if (response.statusCode == 403) {
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      final error = errorBody['error'] as Map<String, dynamic>? ?? {};
      final errors = error['errors'] as List<dynamic>? ?? [];
      final firstError =
          errors.isNotEmpty ? errors.first as Map<String, dynamic> : <String, dynamic>{};
      final reason = firstError['reason'] as String? ?? '';

      if (reason == 'quotaExceeded' || reason == 'dailyLimitExceeded') {
        throw ConnectorException(
          'YouTube API quota exceeded: $reason',
          code: 'quota_exceeded',
        );
      }

      throw ConnectorException(
        'YouTube API forbidden: ${error['message'] ?? response.body}',
        code: 'forbidden',
      );
    }

    if (response.statusCode >= 500) {
      throw ChannelError.serverError(
        message:
            'YouTube API $endpoint returned ${response.statusCode}',
      );
    }

    // DELETE returns 204 No Content
    if (response.statusCode == 204 || response.body.isEmpty) {
      return <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ConnectorException(
        'YouTube API $endpoint failed: '
        '${response.statusCode} ${response.body}',
        code: 'api_error',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // =========================================================================
  // Private: Event parsing
  // =========================================================================

  ChannelEvent _parseLiveChatMessage(Map<String, dynamic> message) {
    final id = message['id'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final snippet = message['snippet'] as Map<String, dynamic>? ?? {};
    final authorDetails =
        message['authorDetails'] as Map<String, dynamic>? ?? {};

    final textDetails =
        snippet['textMessageDetails'] as Map<String, dynamic>?;
    final superChatDetails =
        snippet['superChatDetails'] as Map<String, dynamic>?;

    final text = textDetails?['messageText'] as String? ??
        superChatDetails?['userComment'] as String? ??
        '';

    final publishedAt = snippet['publishedAt'] as String?;
    final timestamp = publishedAt != null
        ? DateTime.tryParse(publishedAt) ?? DateTime.now()
        : DateTime.now();

    final authorChannelId = authorDetails['channelId'] as String?;

    return ChannelEvent.message(
      id: 'yt_lc_$id',
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'youtube',
          channelId: config.channelId ?? config.liveChatId ?? 'default',
        ),
        conversationId: config.liveChatId ?? 'livechat',
        userId: authorChannelId,
      ),
      text: text,
      userId: authorChannelId,
      userName: authorDetails['displayName'] as String?,
      timestamp: timestamp,
      metadata: {
        ...message,
        'source': 'livechat',
        'liveChatId': config.liveChatId,
        'authorChannelUrl': authorDetails['channelUrl'] as String?,
        'authorProfileImageUrl':
            authorDetails['profileImageUrl'] as String?,
        'isChatOwner': authorDetails['isChatOwner'] as bool? ?? false,
        'isChatModerator':
            authorDetails['isChatModerator'] as bool? ?? false,
        if (superChatDetails != null) 'superChat': superChatDetails,
      },
    );
  }

  ChannelEvent _parseCommentThread(Map<String, dynamic> thread) {
    final id = thread['id'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final snippet = thread['snippet'] as Map<String, dynamic>? ?? {};
    final topLevelComment =
        snippet['topLevelComment'] as Map<String, dynamic>? ?? {};
    final commentSnippet =
        topLevelComment['snippet'] as Map<String, dynamic>? ?? {};

    final text = commentSnippet['textOriginal'] as String? ??
        commentSnippet['textDisplay'] as String? ??
        '';

    final publishedAt = commentSnippet['publishedAt'] as String?;
    final timestamp = publishedAt != null
        ? DateTime.tryParse(publishedAt) ?? DateTime.now()
        : DateTime.now();

    final authorChannelId =
        commentSnippet['authorChannelId'] as Map<String, dynamic>?;
    final userId = authorChannelId?['value'] as String?;

    final videoId = snippet['videoId'] as String? ?? '';

    return ChannelEvent.message(
      id: 'yt_ct_$id',
      conversation: ConversationKey(
        channel: ChannelIdentity(
          platform: 'youtube',
          channelId: config.channelId ?? 'default',
        ),
        conversationId: videoId,
        userId: userId,
      ),
      text: text,
      userId: userId,
      userName: commentSnippet['authorDisplayName'] as String?,
      timestamp: timestamp,
      metadata: {
        ...thread,
        'source': 'comment',
        'videoId': videoId,
        'threadId': id,
        'totalReplyCount': snippet['totalReplyCount'] as int? ?? 0,
        'isPublic': snippet['isPublic'] as bool? ?? true,
        'authorProfileImageUrl':
            commentSnippet['authorProfileImageUrl'] as String?,
        'likeCount': commentSnippet['likeCount'] as int? ?? 0,
      },
    );
  }

  bool _isRetryableError(Object error) {
    if (error is ChannelError) return error.retryable;
    if (error is http.ClientException) return true;
    return false;
  }
}
