import 'jev_client.dart';

class AssetManagementAiProviderRoutingFeatureFlag {
  static const String dartDefineName =
      'ASSET_MANAGEMENT_AI_PROVIDER_ROUTING_ENABLED';

  static const bool enabled = bool.fromEnvironment(
    dartDefineName,
    defaultValue: false,
  );

  const AssetManagementAiProviderRoutingFeatureFlag._();
}

class JevRoutingFeatureFlag {
  static const String dartDefineName = 'JEV_ROUTING_ENABLED';

  static const bool enabled = bool.fromEnvironment(
    dartDefineName,
    defaultValue: false,
  );

  const JevRoutingFeatureFlag._();
}

class JevApiKeyConfig {
  static const String dartDefineName = 'TYPESAFE_API_KEY';

  static const String value = String.fromEnvironment(
    dartDefineName,
    defaultValue: '',
  );

  const JevApiKeyConfig._();
}

enum AssetManagementAiProviderUseCase {
  summary,
  riskExplanation,
  developerSuggestion,
  reconciliationHelp,
}

extension AssetManagementAiProviderUseCaseId
    on AssetManagementAiProviderUseCase {
  String get id {
    switch (this) {
      case AssetManagementAiProviderUseCase.summary:
        return 'summary';
      case AssetManagementAiProviderUseCase.riskExplanation:
        return 'risk_explanation';
      case AssetManagementAiProviderUseCase.developerSuggestion:
        return 'developer_suggestion';
      case AssetManagementAiProviderUseCase.reconciliationHelp:
        return 'reconciliation_help';
    }
  }
}

class AssetManagementAiProviderCandidate {
  final String providerId;
  final String modelId;
  final String displayName;
  final String tier;

  const AssetManagementAiProviderCandidate({
    required this.providerId,
    required this.modelId,
    required this.displayName,
    required this.tier,
  });

  Map<String, String> toJson() {
    return <String, String>{
      'provider_id': providerId,
      'model_id': modelId,
      'display_name': displayName,
      'tier': tier,
    };
  }
}

class AssetManagementAiProviderRouteDecision {
  final AssetManagementAiProviderUseCase useCase;
  final bool routingEnabled;
  final List<AssetManagementAiProviderCandidate> candidates;
  final String reason;
  final String localFallbackReason;
  final JevClassificationResult? jevClassification;

  const AssetManagementAiProviderRouteDecision({
    required this.useCase,
    required this.routingEnabled,
    required this.candidates,
    required this.reason,
    required this.localFallbackReason,
    this.jevClassification,
  });

  AssetManagementAiProviderCandidate? get primaryExternalCandidate {
    return candidates.isEmpty ? null : candidates.first;
  }

  String get providerChoiceReason {
    final chain = candidates
        .map((candidate) => '${candidate.modelId}@${candidate.providerId}')
        .join(' > ');
    final suffix = chain.isEmpty
        ? 'fallback=local-deterministic'
        : 'chain=$chain > local-deterministic';
    final jevInfo = jevClassification != null
        ? '; jev=${jevClassification!.bestChoiceId}(${(jevClassification!.confidence * 100).toStringAsFixed(0)}%)'
        : '';
    return 'asset:${useCase.id}; routing=$routingEnabled$jevInfo; $reason; $suffix';
  }

  Map<String, dynamic> toLogPayload() {
    return <String, dynamic>{
      'use_case': useCase.id,
      'routing_enabled': routingEnabled,
      'reason': reason,
      'fallback': localFallbackReason,
      if (jevClassification != null)
        'jev_classification': jevClassification!.toJson(),
      'providers': candidates
          .map((candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }
}

class AssetManagementAiProviderRouter {
  final bool routingEnabled;
  final bool jevEnabled;
  final JevClient? jevClient;

  const AssetManagementAiProviderRouter({
    this.routingEnabled = AssetManagementAiProviderRoutingFeatureFlag.enabled,
    this.jevEnabled = JevRoutingFeatureFlag.enabled,
    this.jevClient,
  });

  AssetManagementAiProviderRouteDecision routeFor({
    required AssetManagementAiProviderUseCase useCase,
    String? explicitProvider,
  }) {
    final normalizedProvider = explicitProvider?.trim();
    if (normalizedProvider != null &&
        normalizedProvider.isNotEmpty &&
        normalizedProvider != 'auto') {
      final candidate = _candidateForExplicitProvider(normalizedProvider);
      return AssetManagementAiProviderRouteDecision(
        useCase: useCase,
        routingEnabled: routingEnabled,
        candidates: <AssetManagementAiProviderCandidate>[candidate],
        reason: 'explicit provider override from caller',
        localFallbackReason:
            'local deterministic summary after explicit provider failure',
      );
    }

    return AssetManagementAiProviderRouteDecision(
      useCase: useCase,
      routingEnabled: routingEnabled,
      candidates: _defaultRoutingTable[useCase] ?? _defaultFallbackChain,
      reason: _reasonFor(useCase),
      localFallbackReason:
          'local deterministic summary after all configured providers fail',
    );
  }

  /// TypeSafe AI (Jev) による一次判定を伴う非同期ルーティング。
  ///
  /// Jev によりプロンプトの計算複雑度（lightweight / performance / premium）
  /// を超低遅延（~500ms）・低コスト（$0.0001）でスコアリングし、
  /// 最適なモデルチェーンを選択する。
  ///
  /// Jev が無効、未設定、または確信度不足（<= 0.40）の場合は、
  /// 自動的に従来の決定論的チェーンへフォールバックする（Fail-Open）。
  Future<AssetManagementAiProviderRouteDecision> routeForWithJev({
    required AssetManagementAiProviderUseCase useCase,
    String? prompt,
    String? explicitProvider,
  }) async {
    final normalizedProvider = explicitProvider?.trim();
    if (normalizedProvider != null &&
        normalizedProvider.isNotEmpty &&
        normalizedProvider != 'auto') {
      return routeFor(useCase: useCase, explicitProvider: explicitProvider);
    }

    if (!jevEnabled ||
        jevClient == null ||
        prompt == null ||
        prompt.trim().isEmpty) {
      return routeFor(useCase: useCase, explicitProvider: explicitProvider);
    }

    const choices = <JevChoice>[
      JevChoice(
        id: 'lightweight',
        label: 'Lightweight / Fast',
        description: 'Simple summaries, greetings, deterministic formatting',
      ),
      JevChoice(
        id: 'performance',
        label: 'Performance / Standard',
        description:
            'Standard risk analysis, balance reconciliation, moderate reasoning',
      ),
      JevChoice(
        id: 'premium',
        label: 'Premium / Deep Reasoning',
        description:
            'Complex financial advisory, multi-step code generation, high ambiguity',
      ),
    ];

    final jevResult = await jevClient!.classify(
      input: prompt,
      choices: choices,
      context: 'Asset management AI routing: useCase=${useCase.id}',
    );

    if (jevResult == null || jevResult.shouldFallbackToHeavyLlm) {
      final baseDecision =
          routeFor(useCase: useCase, explicitProvider: explicitProvider);
      return AssetManagementAiProviderRouteDecision(
        useCase: baseDecision.useCase,
        routingEnabled: baseDecision.routingEnabled,
        candidates: baseDecision.candidates,
        reason:
            '${baseDecision.reason} (jev fallback: ${jevResult == null ? "offline or unconfigured" : "low confidence ${(jevResult.confidence * 100).toStringAsFixed(0)}%"})',
        localFallbackReason: baseDecision.localFallbackReason,
        jevClassification: jevResult,
      );
    }

    List<AssetManagementAiProviderCandidate> reorderedCandidates;
    if (jevResult.bestChoiceId == 'lightweight') {
      reorderedCandidates = <AssetManagementAiProviderCandidate>[
        _defaultFallbackChain[3], // google_flash_lite
        _defaultFallbackChain[2], // google (gemini-3.1-pro)
        _defaultFallbackChain[1], // openai (gpt-5)
        _defaultFallbackChain[0], // anthropic (claude-opus-4-7)
      ];
    } else if (jevResult.bestChoiceId == 'performance') {
      reorderedCandidates = <AssetManagementAiProviderCandidate>[
        _defaultFallbackChain[2], // google (gemini-3.1-pro)
        _defaultFallbackChain[1], // openai (gpt-5)
        _defaultFallbackChain[0], // anthropic (claude-opus-4-7)
        _defaultFallbackChain[3], // google_flash_lite
      ];
    } else {
      reorderedCandidates = _defaultFallbackChain;
    }

    return AssetManagementAiProviderRouteDecision(
      useCase: useCase,
      routingEnabled: routingEnabled,
      candidates: reorderedCandidates,
      reason:
          'jev classified as ${jevResult.bestChoiceId} (confidence: ${(jevResult.confidence * 100).toStringAsFixed(1)}%)',
      localFallbackReason:
          'local deterministic summary after all configured providers fail',
      jevClassification: jevResult,
    );
  }

  static const List<AssetManagementAiProviderCandidate> _defaultFallbackChain =
      <AssetManagementAiProviderCandidate>[
    AssetManagementAiProviderCandidate(
      providerId: 'anthropic',
      modelId: 'claude-opus-4-7',
      displayName: 'Claude Opus 4.7',
      tier: 'premium',
    ),
    AssetManagementAiProviderCandidate(
      providerId: 'openai',
      modelId: 'gpt-5',
      displayName: 'GPT-5',
      tier: 'performance',
    ),
    AssetManagementAiProviderCandidate(
      providerId: 'google',
      modelId: 'gemini-3.1-pro',
      displayName: 'Gemini 3.1 Pro',
      tier: 'performance',
    ),
    // 高レート上限・低コストの最終フォールバック。上位 google(flash) が
    // レート制限でクールダウン中でも、別プロバイダ扱い=独立クールダウンで応答できる。
    AssetManagementAiProviderCandidate(
      providerId: 'google_flash_lite',
      modelId: 'gemini-2.5-flash-lite',
      displayName: 'Gemini 2.5 Flash-Lite',
      tier: 'fallback',
    ),
  ];

  static const Map<AssetManagementAiProviderUseCase,
          List<AssetManagementAiProviderCandidate>>
      _defaultRoutingTable = <AssetManagementAiProviderUseCase,
          List<AssetManagementAiProviderCandidate>>{
    AssetManagementAiProviderUseCase.summary: _defaultFallbackChain,
    AssetManagementAiProviderUseCase.riskExplanation: _defaultFallbackChain,
    AssetManagementAiProviderUseCase.developerSuggestion: _defaultFallbackChain,
    AssetManagementAiProviderUseCase.reconciliationHelp: _defaultFallbackChain,
  };

  static String _reasonFor(AssetManagementAiProviderUseCase useCase) {
    switch (useCase) {
      case AssetManagementAiProviderUseCase.summary:
        return 'premium explanation quality for user-facing summaries';
      case AssetManagementAiProviderUseCase.riskExplanation:
        return 'high-recall reasoning for already calculated risk categories';
      case AssetManagementAiProviderUseCase.developerSuggestion:
        return 'implementation suggestion text only, no money calculation';
      case AssetManagementAiProviderUseCase.reconciliationHelp:
        return 'statement reconciliation explanation over redacted categories';
    }
  }

  static AssetManagementAiProviderCandidate _candidateForExplicitProvider(
    String provider,
  ) {
    switch (provider) {
      case 'anthropic':
        return _defaultFallbackChain[0];
      case 'openai':
        return _defaultFallbackChain[1];
      case 'google':
        return _defaultFallbackChain[2];
      default:
        return AssetManagementAiProviderCandidate(
          providerId: provider,
          modelId: provider,
          displayName: provider,
          tier: 'manual',
        );
    }
  }
}
