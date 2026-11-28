import 'dart:async';

typedef LlmIntentEdgeInvoker = Future<Map<String, Object?>> Function(
  String functionName,
  Map<String, Object?> body,
);

enum LlmRouterIntent {
  deepReasoning('deep_reasoning', 'reasoning_specialist', 'claude-sonnet-5'),
  memoryRecall('memory_recall', 'memory_retriever', 'memory-hub'),
  financeLedger('finance_ledger', 'finance_analyst', 'core-hub'),
  codingDebug('coding_debug', 'code_architect', 'claude-sonnet-5'),
  taskPlanning('task_planning', 'planner_agent', 'app-hub'),
  quickQa('quick_qa', 'fast_responder', 'groq-llama-3.3-70b'),
  generalChat('general_chat', 'fast_responder', 'groq-llama-3.3-70b');

  final String wireKey;
  final String defaultTargetAgent;
  final String defaultTargetHandler;

  const LlmRouterIntent(
    this.wireKey,
    this.defaultTargetAgent,
    this.defaultTargetHandler,
  );

  static LlmRouterIntent fromWireKey(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    for (final intent in LlmRouterIntent.values) {
      if (intent.wireKey == normalized) {
        return intent;
      }
    }
    return LlmRouterIntent.generalChat;
  }
}

class LlmIntentRouteResult {
  final LlmRouterIntent intent;
  final String targetAgent;
  final String targetHandler;
  final double confidence;
  final int latencyMs;
  final bool withinSla500ms;
  final String provider;
  final String model;
  final bool fallbackUsed;
  final String? fallbackReason;
  final String rationale;

  const LlmIntentRouteResult({
    required this.intent,
    required this.targetAgent,
    required this.targetHandler,
    required this.confidence,
    required this.latencyMs,
    required this.withinSla500ms,
    required this.provider,
    required this.model,
    required this.fallbackUsed,
    required this.fallbackReason,
    required this.rationale,
  });

  factory LlmIntentRouteResult.fromJson(Map<String, Object?> json) {
    final intent = LlmRouterIntent.fromWireKey(json['intent']?.toString());
    final rawTargetAgent = json['targetAgent']?.toString().trim() ?? '';
    final rawTargetHandler = json['targetHandler']?.toString().trim() ?? '';
    final rawConfidence = json['confidence'];
    final confidence =
        rawConfidence is num ? rawConfidence.toDouble().clamp(0.0, 1.0) : 0.7;
    final rawLatency = json['latencyMs'];
    final latencyMs =
        rawLatency is num ? rawLatency.round().clamp(0, 60000) : 0;
    final withinSla = json['withinSla500ms'] is bool
        ? json['withinSla500ms'] as bool
        : latencyMs <= LlmIntentRouterService.defaultBudgetMs;
    final provider = json['provider']?.toString().trim().isNotEmpty == true
        ? json['provider'].toString().trim()
        : 'deterministic_fallback';
    final model = json['model']?.toString().trim().isNotEmpty == true
        ? json['model'].toString().trim()
        : LlmIntentRouterService.fallbackModel;
    final fallbackUsed = json['fallbackUsed'] is bool
        ? json['fallbackUsed'] as bool
        : provider != 'groq';
    final fallbackReason = json['fallbackReason']?.toString().trim();
    final rationale = json['rationale']?.toString().trim() ?? '';

    return LlmIntentRouteResult(
      intent: intent,
      targetAgent: rawTargetAgent.isNotEmpty
          ? rawTargetAgent
          : intent.defaultTargetAgent,
      targetHandler: rawTargetHandler.isNotEmpty
          ? rawTargetHandler
          : intent.defaultTargetHandler,
      confidence: confidence,
      latencyMs: latencyMs,
      withinSla500ms: withinSla,
      provider: provider,
      model: model,
      fallbackUsed: fallbackUsed,
      fallbackReason: fallbackReason != null && fallbackReason.isNotEmpty
          ? fallbackReason
          : null,
      rationale: rationale,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'intent': intent.wireKey,
      'targetAgent': targetAgent,
      'targetHandler': targetHandler,
      'confidence': confidence,
      'latencyMs': latencyMs,
      'withinSla500ms': withinSla500ms,
      'provider': provider,
      'model': model,
      'fallbackUsed': fallbackUsed,
      'fallbackReason': fallbackReason,
      'rationale': rationale,
    };
  }
}

class LlmIntentRouterSlaStats {
  final int totalRequests;
  final int withinSla500msCount;
  final int fallbackCount;
  final double averageLatencyMs;

  const LlmIntentRouterSlaStats({
    required this.totalRequests,
    required this.withinSla500msCount,
    required this.fallbackCount,
    required this.averageLatencyMs,
  });

  double get slaComplianceRate =>
      totalRequests == 0 ? 1.0 : withinSla500msCount / totalRequests;
}

/// Ultra-low-latency LLM orchestrator intent router client with <=500ms SLA
/// and deterministic fail-open fallback.
class LlmIntentRouterService {
  static const int defaultBudgetMs = 500;
  static const String defaultEdgeFunction = 'app-hub';
  static const String defaultRouterAction = 'ai.intent.route';
  static const String fallbackModel = 'deterministic-rules-v1';

  final LlmIntentEdgeInvoker? _invoker;
  final String edgeFunctionName;

  int _totalRequests = 0;
  int _withinSla500msCount = 0;
  int _fallbackCount = 0;
  int _cumulativeLatencyMs = 0;

  LlmIntentRouterService({
    LlmIntentEdgeInvoker? invoker,
    this.edgeFunctionName = defaultEdgeFunction,
  }) : _invoker = invoker;

  LlmIntentRouterSlaStats get slaStats => LlmIntentRouterSlaStats(
        totalRequests: _totalRequests,
        withinSla500msCount: _withinSla500msCount,
        fallbackCount: _fallbackCount,
        averageLatencyMs:
            _totalRequests == 0 ? 0.0 : _cumulativeLatencyMs / _totalRequests,
      );

  Future<LlmIntentRouteResult> routeIntent(
    String userInput, {
    int budgetMs = defaultBudgetMs,
    Map<String, Object?>? context,
  }) async {
    final trimmed = userInput.trim();
    final effectiveBudgetMs = budgetMs.clamp(50, defaultBudgetMs);

    if (trimmed.isEmpty) {
      return _record(
        classifyLocally('', latencyMs: 0, fallbackReason: 'empty_input'),
      );
    }

    final invoker = _invoker;
    if (invoker == null) {
      return _record(
        classifyLocally(
          trimmed,
          latencyMs: 0,
          fallbackReason: 'missing_edge_invoker',
        ),
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await invoker(
        edgeFunctionName,
        {
          'action': defaultRouterAction,
          'input': trimmed,
          'budgetMs': effectiveBudgetMs,
          if (context != null && context.isNotEmpty) 'context': context,
        },
      ).timeout(Duration(milliseconds: effectiveBudgetMs));
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final rawIntent = response['intent']?.toString().trim() ?? '';
      if (rawIntent.isEmpty) {
        return _record(
          classifyLocally(
            trimmed,
            latencyMs: elapsedMs,
            fallbackReason: 'invalid_edge_payload',
          ),
        );
      }

      final normalizedMap = Map<String, Object?>.from(response);
      normalizedMap.putIfAbsent('latencyMs', () => elapsedMs);
      final result = LlmIntentRouteResult.fromJson(normalizedMap);
      return _record(result);
    } on TimeoutException {
      stopwatch.stop();
      return _record(
        classifyLocally(
          trimmed,
          latencyMs: stopwatch.elapsedMilliseconds,
          fallbackReason: 'timeout_budget_exceeded',
        ),
      );
    } catch (_) {
      stopwatch.stop();
      return _record(
        classifyLocally(
          trimmed,
          latencyMs: stopwatch.elapsedMilliseconds,
          fallbackReason: 'edge_invoker_error',
        ),
      );
    }
  }

  LlmIntentRouteResult classifyLocally(
    String userInput, {
    int latencyMs = 0,
    String? fallbackReason,
  }) {
    final normalized = userInput.trim().toLowerCase();
    final LlmRouterIntent intent;
    final double confidence;
    final String rationale;

    if (normalized.isEmpty) {
      intent = LlmRouterIntent.generalChat;
      confidence = 0.5;
      rationale = 'Empty input routed to general_chat.';
    } else if (_financeRegex.hasMatch(normalized)) {
      intent = LlmRouterIntent.financeLedger;
      confidence = 0.88;
      rationale = 'Matched finance/ledger domain keywords.';
    } else if (_memoryRegex.hasMatch(normalized)) {
      intent = LlmRouterIntent.memoryRecall;
      confidence = 0.86;
      rationale = 'Matched long-term memory recall keywords.';
    } else if (_codingRegex.hasMatch(normalized)) {
      intent = LlmRouterIntent.codingDebug;
      confidence = 0.87;
      rationale = 'Matched coding/debugging keywords.';
    } else if (_planningRegex.hasMatch(normalized)) {
      intent = LlmRouterIntent.taskPlanning;
      confidence = 0.84;
      rationale = 'Matched task planning keywords.';
    } else if (_reasoningRegex.hasMatch(normalized) ||
        normalized.length >= 160) {
      intent = LlmRouterIntent.deepReasoning;
      confidence = 0.82;
      rationale = 'Matched complex reasoning keywords or long prompt.';
    } else if (normalized.length <= 48 && _quickQaRegex.hasMatch(normalized)) {
      intent = LlmRouterIntent.quickQa;
      confidence = 0.8;
      rationale = 'Short question routed to fast Q&A.';
    } else {
      intent = LlmRouterIntent.generalChat;
      confidence = 0.7;
      rationale = 'Defaulted to general_chat.';
    }

    final safeLatency = latencyMs < 0 ? 0 : latencyMs;
    return LlmIntentRouteResult(
      intent: intent,
      targetAgent: intent.defaultTargetAgent,
      targetHandler: intent.defaultTargetHandler,
      confidence: confidence,
      latencyMs: safeLatency,
      withinSla500ms: safeLatency <= defaultBudgetMs,
      provider: 'deterministic_fallback',
      model: fallbackModel,
      fallbackUsed: true,
      fallbackReason: fallbackReason,
      rationale: rationale,
    );
  }

  LlmIntentRouteResult _record(LlmIntentRouteResult result) {
    _totalRequests += 1;
    if (result.withinSla500ms) {
      _withinSla500msCount += 1;
    }
    if (result.fallbackUsed) {
      _fallbackCount += 1;
    }
    _cumulativeLatencyMs += result.latencyMs;
    return result;
  }

  static final RegExp _financeRegex = RegExp(
    r'(receipt|expense|budget|balance|ledger|invoice|payment|家計|収支|資産|残高|レシート|支出|振込|予算)',
  );
  static final RegExp _memoryRegex = RegExp(
    r'(remember|recall|memory|previous|history|last time|ノート|記憶|思い出|履歴|前回|過去)',
  );
  static final RegExp _codingRegex = RegExp(
    r'(stacktrace|exception|typescript|flutter|dart|sql|bug|error|refactor|debug|コード|バグ|エラー|実装|テスト|修正)',
  );
  static final RegExp _planningRegex = RegExp(
    r'(schedule|roadmap|plan|wbs|milestone|task|todo|deadline|計画|予定|タスク|期限|ロードマップ|手順)',
  );
  static final RegExp _reasoningRegex = RegExp(
    r'(architecture|trade-?off|analyze|comparison|proof|deep dive|設計|比較|分析|推論|検証|戦略)',
  );
  static final RegExp _quickQaRegex = RegExp(
    r'(\?|what is|how to|define|意味|とは|教えて|何)',
  );
}
