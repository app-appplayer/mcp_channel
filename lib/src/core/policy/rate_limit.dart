import 'package:mcp_bundle/ports.dart' show ChannelResponse;
import 'package:meta/meta.dart';

import 'platform_rate_limit_feedback.dart';
import 'priority_queue.dart';

/// Action to take when rate limit is exceeded.
enum RateLimitAction {
  /// Delay request until rate limit allows
  delay,

  /// Reject request immediately
  reject,

  /// Queue request for later processing
  queue,
}

/// Rate limiting policy configuration.
@immutable
class RateLimitPolicy {
  const RateLimitPolicy({
    required this.maxRequests,
    required this.window,
    this.burstAllowance = 0,
    this.perConversation,
    this.perUser,
    this.action = RateLimitAction.delay,
    this.burstMultiplier = 1.0,
  });

  /// Slack platform defaults.
  factory RateLimitPolicy.slack() => const RateLimitPolicy(
        maxRequests: 1,
        window: Duration(seconds: 1),
        burstAllowance: 3,
        burstMultiplier: 1.5,
        action: RateLimitAction.delay,
        perConversation: RateLimitPolicy(
          maxRequests: 1,
          window: Duration(seconds: 1),
        ),
      );

  /// Telegram platform defaults.
  factory RateLimitPolicy.telegram() => const RateLimitPolicy(
        maxRequests: 30,
        window: Duration(seconds: 1),
        burstMultiplier: 1.0,
        action: RateLimitAction.delay,
        perConversation: RateLimitPolicy(
          maxRequests: 1,
          window: Duration(seconds: 3),
        ),
      );

  /// Discord platform defaults.
  factory RateLimitPolicy.discord() => const RateLimitPolicy(
        maxRequests: 50,
        window: Duration(seconds: 1),
        burstAllowance: 10,
        burstMultiplier: 1.5,
        action: RateLimitAction.delay,
      );

  /// Maximum requests per window
  final int maxRequests;

  /// Time window duration
  final Duration window;

  /// Burst allowance (temporary overage)
  final int burstAllowance;

  /// Per-conversation rate limit (optional)
  final RateLimitPolicy? perConversation;

  /// Per-user rate limit (optional)
  final RateLimitPolicy? perUser;

  /// Action when limit exceeded
  final RateLimitAction action;

  /// Multiplier applied to burst allowance for capacity calculation
  final double burstMultiplier;

  RateLimitPolicy copyWith({
    int? maxRequests,
    Duration? window,
    int? burstAllowance,
    RateLimitPolicy? perConversation,
    RateLimitPolicy? perUser,
    RateLimitAction? action,
    double? burstMultiplier,
  }) {
    return RateLimitPolicy(
      maxRequests: maxRequests ?? this.maxRequests,
      window: window ?? this.window,
      burstAllowance: burstAllowance ?? this.burstAllowance,
      perConversation: perConversation ?? this.perConversation,
      perUser: perUser ?? this.perUser,
      action: action ?? this.action,
      burstMultiplier: burstMultiplier ?? this.burstMultiplier,
    );
  }
}

/// Result of a rate limit check.
@immutable
class RateLimitResult {
  const RateLimitResult({
    required this.allowed,
    this.retryAfter,
    this.remainingTokens,
  });

  /// Creates an allowed result.
  factory RateLimitResult.allowed(int remainingTokens) =>
      RateLimitResult(allowed: true, remainingTokens: remainingTokens);

  /// Creates a limited result.
  factory RateLimitResult.limited({required Duration retryAfter}) =>
      RateLimitResult(allowed: false, retryAfter: retryAfter);

  /// Whether the request is allowed
  final bool allowed;

  /// How long to wait before retrying
  final Duration? retryAfter;

  /// Remaining tokens in the bucket
  final int? remainingTokens;
}

/// Exception thrown when rate limit is exceeded.
class RateLimitExceeded implements Exception {
  const RateLimitExceeded([this.retryAfter]);

  final Duration? retryAfter;

  @override
  String toString() => retryAfter != null
      ? 'RateLimitExceeded: retry after ${retryAfter!.inMilliseconds}ms'
      : 'RateLimitExceeded';
}

/// Exception thrown when request is queued due to rate limit.
class RateLimitQueued implements Exception {
  const RateLimitQueued([this.retryAfter]);

  final Duration? retryAfter;

  @override
  String toString() => 'RateLimitQueued';
}

/// Token bucket for rate limiting.
class _TokenBucket {
  _TokenBucket({
    required this.maxTokens,
    required this.refillPeriod,
    this.burstAllowance = 0,
    this.burstMultiplier = 1.0,
  })  : _tokens = maxTokens + (burstAllowance * burstMultiplier).round(),
        _lastRefill = DateTime.now();

  int maxTokens;
  final Duration refillPeriod;
  final int burstAllowance;
  final double burstMultiplier;

  int _tokens;
  DateTime _lastRefill;

  /// Effective burst capacity after applying multiplier.
  int get _effectiveBurst => (burstAllowance * burstMultiplier).round();

  /// Check current state without consuming a token.
  RateLimitResult peek() {
    _refill();

    if (_tokens > 0) {
      return RateLimitResult.allowed(_tokens);
    }

    // Calculate when next token will be available
    final tokensPerMs = maxTokens / refillPeriod.inMilliseconds;
    final msUntilToken = (1 / tokensPerMs).ceil();
    return RateLimitResult.limited(
      retryAfter: Duration(milliseconds: msUntilToken),
    );
  }

  /// Consume a token and return the result.
  RateLimitResult tryConsume() {
    _refill();

    if (_tokens > 0) {
      _tokens--;
      return RateLimitResult.allowed(_tokens);
    }

    // Calculate when next token will be available
    final tokensPerMs = maxTokens / refillPeriod.inMilliseconds;
    final msUntilToken = (1 / tokensPerMs).ceil();
    return RateLimitResult.limited(
      retryAfter: Duration(milliseconds: msUntilToken),
    );
  }

  /// Synchronize token count from platform feedback.
  void syncTokens(int remaining) {
    _tokens = remaining.clamp(0, maxTokens + _effectiveBurst);
  }

  /// Adjust max token limit from platform feedback.
  void adjustLimit(int newLimit) {
    maxTokens = newLimit;
    if (_tokens > maxTokens + _effectiveBurst) {
      _tokens = maxTokens + _effectiveBurst;
    }
  }

  void _refill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill);

    if (elapsed >= refillPeriod) {
      final periods = elapsed.inMilliseconds ~/ refillPeriod.inMilliseconds;
      final tokensToAdd = periods * maxTokens;
      _tokens = (_tokens + tokensToAdd).clamp(0, maxTokens + _effectiveBurst);
      _lastRefill = now;
    }
  }
}

/// Rate limiter using token bucket algorithm.
class RateLimiter {
  RateLimiter(this._policy);

  final RateLimitPolicy _policy;
  final Map<String, _TokenBucket> _buckets = {};
  final Map<String, DateTime> _pausedUntil = {};
  final PriorityMessageQueue _priorityQueue = PriorityMessageQueue();

  /// Check if request would be allowed without consuming a token.
  Future<RateLimitResult> checkLimit({
    String? conversationKey,
    String? userId,
  }) async {
    // Check if globally paused by platform feedback
    final pauseEnd = _pausedUntil['global'];
    if (pauseEnd != null) {
      final now = DateTime.now();
      if (now.isBefore(pauseEnd)) {
        return RateLimitResult.limited(
          retryAfter: pauseEnd.difference(now),
        );
      }
      _pausedUntil.remove('global');
    }

    // Peek global limit without consuming
    final globalResult = _peekBucket('global', _policy);
    if (!globalResult.allowed) return globalResult;

    // Peek per-conversation limit without consuming
    if (conversationKey != null && _policy.perConversation != null) {
      final convResult = _peekBucket(
        'conv:$conversationKey',
        _policy.perConversation!,
      );
      if (!convResult.allowed) return convResult;
    }

    // Peek per-user limit without consuming
    if (userId != null && _policy.perUser != null) {
      final userResult = _peekBucket('user:$userId', _policy.perUser!);
      if (!userResult.allowed) return userResult;
    }

    return RateLimitResult.allowed(globalResult.remainingTokens ?? 0);
  }

  _TokenBucket _getOrCreateBucket(String key, RateLimitPolicy policy) {
    return _buckets.putIfAbsent(
      key,
      () => _TokenBucket(
        maxTokens: policy.maxRequests,
        refillPeriod: policy.window,
        burstAllowance: policy.burstAllowance,
        burstMultiplier: policy.burstMultiplier,
      ),
    );
  }

  /// Peek at bucket state without consuming a token.
  RateLimitResult _peekBucket(String key, RateLimitPolicy policy) {
    final bucket = _getOrCreateBucket(key, policy);
    return bucket.peek();
  }

  /// Consume a token from the bucket.
  RateLimitResult _consumeBucket(String key, RateLimitPolicy policy) {
    final bucket = _getOrCreateBucket(key, policy);
    return bucket.tryConsume();
  }

  /// Acquire a token (blocks if delay action, throws if reject).
  ///
  /// Unlike [checkLimit], this method consumes a token when allowed.
  Future<void> acquire({
    String? conversationKey,
    String? userId,
  }) async {
    // First check without consuming
    final peekResult = await checkLimit(
      conversationKey: conversationKey,
      userId: userId,
    );

    if (!peekResult.allowed) {
      switch (_policy.action) {
        case RateLimitAction.delay:
          if (peekResult.retryAfter != null) {
            await Future<void>.delayed(peekResult.retryAfter!);
          }
          return acquire(conversationKey: conversationKey, userId: userId);

        case RateLimitAction.reject:
          throw RateLimitExceeded(peekResult.retryAfter);

        case RateLimitAction.queue:
          throw RateLimitQueued(peekResult.retryAfter);
      }
    }

    // All checks passed, now consume tokens from all applicable buckets
    _consumeBucket('global', _policy);

    if (conversationKey != null && _policy.perConversation != null) {
      _consumeBucket('conv:$conversationKey', _policy.perConversation!);
    }

    if (userId != null && _policy.perUser != null) {
      _consumeBucket('user:$userId', _policy.perUser!);
    }
  }

  /// Update rate limiter state based on platform response feedback.
  void updateFromResponse(
    PlatformRateLimitFeedback feedback, {
    String? conversationKey,
  }) {
    final bucketKey =
        conversationKey != null ? 'conv:$conversationKey' : 'global';

    if (feedback.retryAfter != null) {
      _pausedUntil[bucketKey] = DateTime.now().add(feedback.retryAfter!);
    } else if (feedback.isLimited && feedback.resetAt != null) {
      final now = DateTime.now();
      if (feedback.resetAt!.isAfter(now)) {
        _pausedUntil[bucketKey] = feedback.resetAt!;
      }
    }

    if (feedback.remainingRequests != null) {
      _syncBucketTokens(bucketKey, feedback.remainingRequests!);
    }

    if (feedback.limit != null) {
      _adjustBucketLimit(bucketKey, feedback.limit!);
    }
  }

  /// Queue a message when rate limited.
  void queueMessage(
    ChannelResponse response, {
    MessagePriority priority = MessagePriority.normal,
    String? conversationKey,
    Duration? ttl,
  }) {
    _priorityQueue.enqueue(QueuedMessage(
      response: response,
      priority: priority,
      enqueuedAt: DateTime.now(),
      conversationKey: conversationKey,
      deadline: ttl != null ? DateTime.now().add(ttl) : null,
    ));
  }

  /// Process queued messages when rate limit allows.
  Future<List<QueuedMessage>> drainQueue({int maxMessages = 10}) async {
    final ready = <QueuedMessage>[];

    while (ready.length < maxMessages && !_priorityQueue.isEmpty) {
      final result = await checkLimit();
      if (!result.allowed) break;

      final message = _priorityQueue.dequeue();
      if (message != null) ready.add(message);
    }

    return ready;
  }

  void _syncBucketTokens(String bucketKey, int remaining) {
    final bucket = _buckets[bucketKey];
    if (bucket != null) {
      bucket.syncTokens(remaining);
    }
  }

  void _adjustBucketLimit(String bucketKey, int newLimit) {
    final bucket = _buckets[bucketKey];
    if (bucket != null) {
      bucket.adjustLimit(newLimit);
    }
  }

  /// Reset all buckets.
  void reset() {
    _buckets.clear();
    _pausedUntil.clear();
  }
}
