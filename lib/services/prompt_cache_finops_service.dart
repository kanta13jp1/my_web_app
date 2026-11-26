/// Prompt block classification for Anthropic prompt caching (#2788).
enum CacheBlockRole {
  systemPrompt('system_prompt', 'System Prompt', 0),
  dbSchema('db_schema', 'DB Schema', 1),
  fewShot('few_shot', 'Few-Shot Examples', 2),
  userInput('user_input', 'User Input', 3);

  const CacheBlockRole(this.wireName, this.label, this.priority);

  final String wireName;
  final String label;
  final int priority;

  bool get isStatic => this != CacheBlockRole.userInput;
}

/// Urgency classification for real-time vs Message Batches API dispatch.
enum ExecutionUrgency {
  realtime,
  batchEligible,
}

/// Dispatch endpoint mode for Claude API requests.
enum DispatchMode {
  messagesApi('messages_api'),
  messageBatchesApi('message_batches_api');

  const DispatchMode(this.wireName);

  final String wireName;
}

/// Input block used to construct an ordered prompt cache prefix.
class PromptBlockInput {
  const PromptBlockInput({
    required this.role,
    required this.content,
    required this.estimatedInputCount,
  });

  final CacheBlockRole role;
  final String content;
  final int estimatedInputCount;
}

/// Ordered block with optional ephemeral cache breakpoint.
class OrderedPromptBlock {
  const OrderedPromptBlock({
    required this.role,
    required this.content,
    required this.estimatedInputCount,
    this.cacheEphemeral = false,
  });

  final CacheBlockRole role;
  final String content;
  final int estimatedInputCount;
  final bool cacheEphemeral;
}

/// Result of ordering blocks for maximum prompt cache hit efficiency.
class PromptPrefixPlan {
  const PromptPrefixPlan({
    required this.blocks,
    required this.cacheEnabled,
    required this.staticPrefixCount,
    required this.dynamicCount,
  });

  final List<OrderedPromptBlock> blocks;
  final bool cacheEnabled;
  final int staticPrefixCount;
  final int dynamicCount;
}

/// Single LLM invocation usage record for FinOps monitoring.
class LlmUsageSample {
  const LlmUsageSample({
    required this.feature,
    required this.dispatchMode,
    required this.baseInputCount,
    required this.cacheReadCount,
    required this.cacheCreationCount,
    required this.outputCount,
  });

  final String feature;
  final DispatchMode dispatchMode;
  final int baseInputCount;
  final int cacheReadCount;
  final int cacheCreationCount;
  final int outputCount;
}

/// Aggregated FinOps summary of batch offload and prompt cache hit rate.
class PromptCacheFinopsSummary {
  const PromptCacheFinopsSummary({
    required this.totalRequests,
    required this.batchRequests,
    required this.batchOffloadRate,
    required this.totalBaseInputCount,
    required this.totalCacheReadCount,
    required this.totalCacheCreationCount,
    required this.totalOutputCount,
    required this.cacheHitRate,
  });

  final int totalRequests;
  final int batchRequests;
  final double batchOffloadRate;
  final int totalBaseInputCount;
  final int totalCacheReadCount;
  final int totalCacheCreationCount;
  final int totalOutputCount;
  final double cacheHitRate;
}

/// Service for prompt cache prefix ordering, batch routing, and FinOps metrics.
class PromptCacheFinopsService {
  int _totalRequests = 0;
  int _batchRequests = 0;
  int _totalBaseInputCount = 0;
  int _totalCacheReadCount = 0;
  int _totalCacheCreationCount = 0;
  int _totalOutputCount = 0;

  /// Selects real-time Messages API or async Message Batches API.
  DispatchMode selectDispatchMode(ExecutionUrgency urgency) {
    return urgency == ExecutionUrgency.batchEligible
        ? DispatchMode.messageBatchesApi
        : DispatchMode.messagesApi;
  }

  /// Places static blocks before user input and marks the prefix breakpoint.
  PromptPrefixPlan buildPromptCachePrefix(
    List<PromptBlockInput> inputs, {
    int minCacheableCount = 1024,
  }) {
    final sorted = List<PromptBlockInput>.from(inputs)
      ..sort((a, b) => a.role.priority.compareTo(b.role.priority));

    var staticPrefixCount = 0;
    var dynamicCount = 0;
    var lastStaticIdx = -1;

    for (var i = 0; i < sorted.length; i++) {
      final count =
          sorted[i].estimatedInputCount < 0 ? 0 : sorted[i].estimatedInputCount;
      if (sorted[i].role.isStatic) {
        staticPrefixCount += count;
        lastStaticIdx = i;
      } else {
        dynamicCount += count;
      }
    }

    final cacheEnabled =
        lastStaticIdx >= 0 && staticPrefixCount >= minCacheableCount;

    final blocks = <OrderedPromptBlock>[];
    for (var i = 0; i < sorted.length; i++) {
      final count =
          sorted[i].estimatedInputCount < 0 ? 0 : sorted[i].estimatedInputCount;
      blocks.add(
        OrderedPromptBlock(
          role: sorted[i].role,
          content: sorted[i].content,
          estimatedInputCount: count,
          cacheEphemeral: cacheEnabled && i == lastStaticIdx,
        ),
      );
    }

    return PromptPrefixPlan(
      blocks: List<OrderedPromptBlock>.unmodifiable(blocks),
      cacheEnabled: cacheEnabled,
      staticPrefixCount: staticPrefixCount,
      dynamicCount: dynamicCount,
    );
  }

  /// Records usage from a single LLM response for FinOps aggregation.
  void recordUsage(LlmUsageSample sample) {
    _totalRequests += 1;
    if (sample.dispatchMode == DispatchMode.messageBatchesApi) {
      _batchRequests += 1;
    }
    _totalBaseInputCount +=
        sample.baseInputCount < 0 ? 0 : sample.baseInputCount;
    _totalCacheReadCount +=
        sample.cacheReadCount < 0 ? 0 : sample.cacheReadCount;
    _totalCacheCreationCount +=
        sample.cacheCreationCount < 0 ? 0 : sample.cacheCreationCount;
    _totalOutputCount += sample.outputCount < 0 ? 0 : sample.outputCount;
  }

  /// Returns an immutable FinOps snapshot of cache-hit and batch rates.
  PromptCacheFinopsSummary getSummary() {
    final inputDenom =
        _totalBaseInputCount + _totalCacheReadCount + _totalCacheCreationCount;
    final hitRate = inputDenom == 0 ? 0.0 : _totalCacheReadCount / inputDenom;
    final batchRate =
        _totalRequests == 0 ? 0.0 : _batchRequests / _totalRequests;

    return PromptCacheFinopsSummary(
      totalRequests: _totalRequests,
      batchRequests: _batchRequests,
      batchOffloadRate: batchRate,
      totalBaseInputCount: _totalBaseInputCount,
      totalCacheReadCount: _totalCacheReadCount,
      totalCacheCreationCount: _totalCacheCreationCount,
      totalOutputCount: _totalOutputCount,
      cacheHitRate: hitRate,
    );
  }
}
