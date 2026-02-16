import 'package:meta/meta.dart';

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

  const RateLimitPolicy({
    required this.maxRequests,
    required this.window,
    this.burstAllowance = 0,
    this.perConversation,
    this.perUser,
    this.action = RateLimitAction.delay,
  });

  /// Slack platform defaults.
  factory RateLimitPolicy.slack() => const RateLimitPolicy(
        maxRequests: 1,
        window: Duration(seconds: 1),
        burstAllowance: 3,
        perConversation: RateLimitPolicy(
          maxRequests: 1,
          window: Duration(seconds: 1),
        ),
      );

  /// Telegram platform defaults.
  factory RateLimitPolicy.telegram() => const RateLimitPolicy(
        maxRequests: 30,
        window: Duration(seconds: 1),
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
      );

  RateLimitPolicy copyWith({
    int? maxRequests,
    Duration? window,
    int? burstAllowance,
    RateLimitPolicy? perConversation,
    RateLimitPolicy? perUser,
    RateLimitAction? action,
  }) {
    return RateLimitPolicy(
      maxRequests: maxRequests ?? this.maxRequests,
      window: window ?? this.window,
      burstAllowance: burstAllowance ?? this.burstAllowance,
      perConversation: perConversation ?? this.perConversation,
      perUser: perUser ?? this.perUser,
      action: action ?? this.action,
    );
  }
}

/// Result of a rate limit check.
@immutable
class RateLimitResult {
  /// Whether the request is allowed
  final bool allowed;

  /// How long to wait before retrying
  final Duration? retryAfter;

  /// Remaining tokens in the bucket
  final int? remainingTokens;

  const RateLimitResult({
    required this.allowed,
    this.retryAfter,
    this.remainingTokens,
  });

  /// Creates an allowed result.
  factory RateLimitResult.allowed({int? remainingTokens}) =>
      RateLimitResult(allowed: true, remainingTokens: remainingTokens);

  /// Creates a limited result.
  factory RateLimitResult.limited({required Duration retryAfter}) =>
      RateLimitResult(allowed: false, retryAfter: retryAfter);
}

/// Exception thrown when rate limit is exceeded.
class RateLimitExceeded implements Exception {
  final Duration? retryAfter;

  const RateLimitExceeded([this.retryAfter]);

  @override
  String toString() => retryAfter != null
      ? 'RateLimitExceeded: retry after ${retryAfter!.inMilliseconds}ms'
      : 'RateLimitExceeded';
}

/// Exception thrown when request is queued due to rate limit.
class RateLimitQueued implements Exception {
  final Duration? retryAfter;

  const RateLimitQueued([this.retryAfter]);

  @override
  String toString() => 'RateLimitQueued';
}

/// Token bucket for rate limiting.
class _TokenBucket {
  final int maxTokens;
  final Duration refillPeriod;
  final int burstAllowance;

  int _tokens;
  DateTime _lastRefill;

  _TokenBucket({
    required this.maxTokens,
    required this.refillPeriod,
    this.burstAllowance = 0,
  })  : _tokens = maxTokens + burstAllowance,
        _lastRefill = DateTime.now();

  RateLimitResult tryConsume() {
    _refill();

    if (_tokens > 0) {
      _tokens--;
      return RateLimitResult.allowed(remainingTokens: _tokens);
    }

    // Calculate when next token will be available
    final tokensPerMs = maxTokens / refillPeriod.inMilliseconds;
    final msUntilToken = (1 / tokensPerMs).ceil();
    return RateLimitResult.limited(
      retryAfter: Duration(milliseconds: msUntilToken),
    );
  }

  void _refill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill);

    if (elapsed >= refillPeriod) {
      final periods = elapsed.inMilliseconds ~/ refillPeriod.inMilliseconds;
      final tokensToAdd = periods * maxTokens;
      _tokens = (_tokens + tokensToAdd).clamp(0, maxTokens + burstAllowance);
      _lastRefill = now;
    }
  }
}

/// Rate limiter using token bucket algorithm.
class RateLimiter {
  final RateLimitPolicy _policy;
  final Map<String, _TokenBucket> _buckets = {};

  RateLimiter(this._policy);

  /// Check if request is allowed.
  Future<RateLimitResult> checkLimit({
    String? conversationKey,
    String? userId,
  }) async {
    // Check global limit
    final globalResult = _checkBucket('global', _policy);
    if (!globalResult.allowed) return globalResult;

    // Check per-conversation limit
    if (conversationKey != null && _policy.perConversation != null) {
      final convResult = _checkBucket(
        'conv:$conversationKey',
        _policy.perConversation!,
      );
      if (!convResult.allowed) return convResult;
    }

    // Check per-user limit
    if (userId != null && _policy.perUser != null) {
      final userResult = _checkBucket('user:$userId', _policy.perUser!);
      if (!userResult.allowed) return userResult;
    }

    return RateLimitResult.allowed();
  }

  RateLimitResult _checkBucket(String key, RateLimitPolicy policy) {
    final bucket = _buckets.putIfAbsent(
      key,
      () => _TokenBucket(
        maxTokens: policy.maxRequests,
        refillPeriod: policy.window,
        burstAllowance: policy.burstAllowance,
      ),
    );

    return bucket.tryConsume();
  }

  /// Acquire a token (blocks if delay action, throws if reject).
  Future<void> acquire({
    String? conversationKey,
    String? userId,
  }) async {
    final result = await checkLimit(
      conversationKey: conversationKey,
      userId: userId,
    );

    if (!result.allowed) {
      switch (_policy.action) {
        case RateLimitAction.delay:
          if (result.retryAfter != null) {
            await Future.delayed(result.retryAfter!);
          }
          return acquire(conversationKey: conversationKey, userId: userId);

        case RateLimitAction.reject:
          throw RateLimitExceeded(result.retryAfter);

        case RateLimitAction.queue:
          throw RateLimitQueued(result.retryAfter);
      }
    }
  }

  /// Reset all buckets.
  void reset() {
    _buckets.clear();
  }
}
