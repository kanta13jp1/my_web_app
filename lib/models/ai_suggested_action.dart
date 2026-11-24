enum AiSuggestedActionType {
  invite(
    wireValue: 'invite',
    displayName: '招待・共有',
    expectedSemanticSummary: 'メンバー招待や空間共有の操作',
  ),
  renameSpace(
    wireValue: 'rename_space',
    displayName: '空間名変更',
    expectedSemanticSummary: '空間・ノート・チャット名称の変更',
  ),
  openTool(
    wireValue: 'open_tool',
    displayName: '画面遷移',
    expectedSemanticSummary: '許可されたアプリ内ルートへの遷移',
  ),
  narrativeChoice(
    wireValue: 'narrative_choice',
    displayName: '会話分岐の選択',
    expectedSemanticSummary: '会話の選択肢や代替案を応答として送信',
  ),
  sceneTransition(
    wireValue: 'scene_transition',
    displayName: 'シーン移行',
    expectedSemanticSummary: '会話の場面転換・フェーズ切替と視覚トランジション',
  ),
  genericNarrativeChoice(
    wireValue: 'generic_narrative_choice',
    displayName: '汎用コンテキスト選択',
    expectedSemanticSummary: '固定ツールに当てはまらない汎用的な分岐意図の安全吸収',
  ),
  unknownFallback(
    wireValue: 'unknown_fallback',
    displayName: '未定義フォールバック',
    expectedSemanticSummary: '未定義または不整合なアクションを安全表示へ退避',
  );

  const AiSuggestedActionType({
    required this.wireValue,
    required this.displayName,
    required this.expectedSemanticSummary,
  });

  final String wireValue;
  final String displayName;
  final String expectedSemanticSummary;

  bool get isGenericOrFallback =>
      this == AiSuggestedActionType.narrativeChoice ||
      this == AiSuggestedActionType.sceneTransition ||
      this == AiSuggestedActionType.genericNarrativeChoice ||
      this == AiSuggestedActionType.unknownFallback;

  static AiSuggestedActionType parseWireValue(Object? raw) {
    final normalized =
        (raw?.toString() ?? '').trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'invite':
        return AiSuggestedActionType.invite;
      case 'rename_space':
      case 'renamespace':
        return AiSuggestedActionType.renameSpace;
      case 'open_tool':
      case 'opentool':
        return AiSuggestedActionType.openTool;
      case 'narrative_choice':
      case 'narrativechoice':
        return AiSuggestedActionType.narrativeChoice;
      case 'scene_transition':
      case 'scenetransition':
        return AiSuggestedActionType.sceneTransition;
      case 'generic_narrative_choice':
      case 'genericnarrativechoice':
        return AiSuggestedActionType.genericNarrativeChoice;
      case 'unknown_fallback':
      case 'unknownfallback':
      default:
        return AiSuggestedActionType.unknownFallback;
    }
  }
}

class AiSuggestedAction {
  const AiSuggestedAction({
    required this.id,
    required this.type,
    required this.rawActionType,
    required this.label,
    this.promptText,
    this.sceneTitle,
    this.sceneDescription,
    this.targetRoute,
    this.contextExcerpt = '',
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final AiSuggestedActionType type;
  final String rawActionType;
  final String label;
  final String? promptText;
  final String? sceneTitle;
  final String? sceneDescription;
  final String? targetRoute;
  final String contextExcerpt;
  final Map<String, dynamic> metadata;

  static final RegExp _financialOrStoryMismatchPattern = RegExp(
    r'(決済|支払|請求|送金|課金|お金|呼び込|物語|ストーリー|エンディング|次の場面|シーン移行|倒す|戦う|魔法|chap(?:ter)?\s*\d+|checkout|money)',
    caseSensitive: false,
  );

  static final RegExp _safeInternalRoutePattern =
      RegExp(r'^\/[a-zA-Z0-9\-_/]+$');

  static bool isSafeAppRoute(String route) {
    final trimmed = route.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.startsWith('//')) {
      return false;
    }
    return _safeInternalRoutePattern.hasMatch(trimmed);
  }

  factory AiSuggestedAction.fromJson(Map<String, dynamic> json) {
    final rawTypeObj = json['action_type'] ?? json['type'] ?? '';
    final rawType = rawTypeObj.toString().trim();
    final parsedType = AiSuggestedActionType.parseWireValue(rawType);

    final rawLabel = (json['label'] ?? json['title'] ?? '').toString().trim();
    final safeLabel = rawLabel.isEmpty ? '提案を確認する' : rawLabel;

    final rawPrompt = (json['prompt'] ?? json['promptText'] ?? '').toString();
    final promptText = rawPrompt.trim().isEmpty ? null : rawPrompt.trim();

    final rawSceneTitle =
        (json['scene_title'] ?? json['sceneTitle'] ?? '').toString();
    final sceneTitle =
        rawSceneTitle.trim().isEmpty ? null : rawSceneTitle.trim();

    final rawSceneDescription =
        (json['scene_description'] ?? json['sceneDescription'] ?? '')
            .toString();
    final sceneDescription =
        rawSceneDescription.trim().isEmpty ? null : rawSceneDescription.trim();

    final rawRoute =
        (json['target_route'] ?? json['targetRoute'] ?? '').toString();
    final targetRoute = rawRoute.trim().isEmpty ? null : rawRoute.trim();

    final rawContext =
        (json['context_excerpt'] ?? json['contextExcerpt'] ?? '').toString();

    final rawMetadata = json['metadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : const <String, dynamic>{};

    final rawId = (json['id'] ?? '').toString().trim();
    final resolvedId = rawId.isEmpty
        ? '${parsedType.wireValue}_${safeLabel.hashCode.abs()}'
        : rawId;

    return AiSuggestedAction(
      id: resolvedId,
      type: parsedType,
      rawActionType: rawType.isEmpty ? parsedType.wireValue : rawType,
      label: safeLabel,
      promptText: promptText,
      sceneTitle: sceneTitle,
      sceneDescription: sceneDescription,
      targetRoute: targetRoute,
      contextExcerpt: rawContext.trim(),
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'action_type': type.wireValue,
      'raw_action_type': rawActionType,
      'label': label,
      if (promptText != null) 'prompt_text': promptText,
      if (sceneTitle != null) 'scene_title': sceneTitle,
      if (sceneDescription != null) 'scene_description': sceneDescription,
      if (targetRoute != null) 'target_route': targetRoute,
      'context_excerpt': contextExcerpt,
      'metadata': metadata,
    };
  }

  bool get isUnknownWireType => type == AiSuggestedActionType.unknownFallback;

  String? get deceptionReason {
    if (isUnknownWireType) {
      return '未定義のアクション種別 "$rawActionType" を検知したため安全フォールバックへ退避しました';
    }
    final combined = '$label ${promptText ?? ''}'.trim();
    if (type == AiSuggestedActionType.invite &&
        _financialOrStoryMismatchPattern.hasMatch(combined)) {
      return 'invite 種別に対して金銭・物語系のラベル "$label" が割り当てられており、意図外使用（Creator Deception）の疑いがあります';
    }
    if (type == AiSuggestedActionType.renameSpace &&
        _financialOrStoryMismatchPattern.hasMatch(combined)) {
      return 'rename_space 種別に対して空間名変更と無関係なラベル "$label" が割り当てられています';
    }
    final route = targetRoute;
    if (type == AiSuggestedActionType.openTool &&
        route != null &&
        !isSafeAppRoute(route)) {
      return 'open_tool 種別の遷移先 "$route" が安全なアプリ内ルート形式に一致しません';
    }
    return null;
  }

  bool get isPotentialCreatorDeception => deceptionReason != null;

  String get effectiveNarrativeReply {
    final prompt = promptText;
    return (prompt != null && prompt.isNotEmpty) ? prompt : label;
  }
}

class AiSuggestedActionEvent {
  const AiSuggestedActionEvent({
    required this.id,
    required this.actionId,
    required this.label,
    required this.actionType,
    required this.rawActionType,
    required this.eventKind,
    required this.contextExcerpt,
    required this.flaggedDeception,
    required this.recordedAt,
    this.deceptionReason,
  });

  final String id;
  final String actionId;
  final String label;
  final AiSuggestedActionType actionType;
  final String rawActionType;
  final String eventKind; // 'impression' | 'click'
  final String contextExcerpt;
  final bool flaggedDeception;
  final String? deceptionReason;
  final DateTime recordedAt;

  factory AiSuggestedActionEvent.fromJson(Map<String, dynamic> json) {
    final parsedType = AiSuggestedActionType.parseWireValue(
      json['action_type'] ?? json['raw_action_type'],
    );
    final rawType =
        (json['raw_action_type'] ?? json['action_type'] ?? parsedType.wireValue)
            .toString();
    final kindRaw = (json['event_kind'] ?? 'impression').toString().trim();
    final eventKind = kindRaw == 'click' ? 'click' : 'impression';
    final recordedRaw = json['recorded_at']?.toString() ?? '';
    final parsedDate = DateTime.tryParse(recordedRaw) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final reasonRaw = json['deception_reason']?.toString().trim() ?? '';

    return AiSuggestedActionEvent(
      id: (json['id'] ?? '').toString(),
      actionId: (json['action_id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      actionType: parsedType,
      rawActionType: rawType,
      eventKind: eventKind,
      contextExcerpt: (json['context_excerpt'] ?? '').toString(),
      flaggedDeception: json['flagged_deception'] == true,
      deceptionReason: reasonRaw.isEmpty ? null : reasonRaw,
      recordedAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'action_id': actionId,
      'label': label,
      'action_type': actionType.wireValue,
      'raw_action_type': rawActionType,
      'event_kind': eventKind,
      'context_excerpt': contextExcerpt,
      'flagged_deception': flaggedDeception,
      if (deceptionReason != null) 'deception_reason': deceptionReason,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    };
  }
}

class AiActionTypeAuditSummary {
  const AiActionTypeAuditSummary({
    required this.actionType,
    required this.impressionCount,
    required this.clickCount,
    required this.deceptionCount,
  });

  final AiSuggestedActionType actionType;
  final int impressionCount;
  final int clickCount;
  final int deceptionCount;

  int get totalEvents => impressionCount + clickCount;

  double get ctr => impressionCount == 0 ? 0.0 : clickCount / impressionCount;

  double get unexpectedUseRate =>
      totalEvents == 0 ? 0.0 : deceptionCount / totalEvents;
}
