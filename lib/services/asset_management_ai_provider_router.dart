class AssetManagementAiProviderRoutingFeatureFlag {
  static const String dartDefineName =
      'ASSET_MANAGEMENT_AI_PROVIDER_ROUTING_ENABLED';

  static const bool enabled = bool.fromEnvironment(
    dartDefineName,
    defaultValue: false,
  );

  const AssetManagementAiProviderRoutingFeatureFlag._();
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

  const AssetManagementAiProviderRouteDecision({
    required this.useCase,
    required this.routingEnabled,
    required this.candidates,
    required this.reason,
    required this.localFallbackReason,
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
    return 'asset:${useCase.id}; routing=$routingEnabled; $reason; $suffix';
  }

  Map<String, dynamic> toLogPayload() {
    return <String, dynamic>{
      'use_case': useCase.id,
      'routing_enabled': routingEnabled,
      'reason': reason,
      'fallback': localFallbackReason,
      'providers': candidates
          .map((candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }
}

class AssetManagementAiProviderRouter {
  final bool routingEnabled;

  const AssetManagementAiProviderRouter({
    this.routingEnabled = AssetManagementAiProviderRoutingFeatureFlag.enabled,
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
