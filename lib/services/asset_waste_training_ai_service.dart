import 'ai_hub_chat_service.dart';

typedef AssetWasteTrainingAiInvoker = AiHubChatInvoker;

class AssetWasteTrainingSnapshot {
  final DateTime month;
  final DateTime monitoredAt;
  final int totalExpense;
  final int wasteExpense;
  final int expenseEntryCount;
  final int wasteEntryCount;
  final int noWasteDays;
  final int recordedExpenseDays;
  final int elapsedDays;
  final int ruleCompletedCount;
  final int ruleTargetCount;
  final int todayViolationCount;
  final int compliantStreakDays;
  final bool lockdownActive;

  const AssetWasteTrainingSnapshot({
    required this.month,
    required this.monitoredAt,
    required this.totalExpense,
    required this.wasteExpense,
    required this.expenseEntryCount,
    required this.wasteEntryCount,
    required this.noWasteDays,
    this.recordedExpenseDays = 0,
    required this.elapsedDays,
    required this.ruleCompletedCount,
    required this.ruleTargetCount,
    required this.todayViolationCount,
    required this.compliantStreakDays,
    required this.lockdownActive,
  });

  double get wasteRatio {
    if (totalExpense <= 0) return 0;
    return (wasteExpense / totalExpense).clamp(0, 1).toDouble();
  }

  double get noWasteProgress {
    if (elapsedDays <= 0) return 0;
    return (noWasteDays / elapsedDays).clamp(0, 1).toDouble();
  }

  double get wasteControlProgress {
    if (totalExpense <= 0) return 1;
    return (1 - wasteRatio).clamp(0, 1).toDouble();
  }

  double get ruleProgress {
    if (ruleTargetCount <= 0) return 0;
    return (ruleCompletedCount / ruleTargetCount).clamp(0, 1).toDouble();
  }

  double get violationProgress => todayViolationCount == 0 ? 1 : 0;

  double get trainingProgress {
    if (recordedExpenseDays == 0) return 0;
    return (noWasteProgress * 0.35 +
            wasteControlProgress * 0.35 +
            ruleProgress * 0.20 +
            violationProgress * 0.10)
        .clamp(0, 1)
        .toDouble();
  }

  int get disciplineScore => (trainingProgress * 100).round();

  int get wasteControlScore => (wasteControlProgress * 100).round();

  String get cacheKey => [
        month.year,
        month.month,
        totalExpense,
        wasteExpense,
        expenseEntryCount,
        wasteEntryCount,
        noWasteDays,
        recordedExpenseDays,
        elapsedDays,
        ruleCompletedCount,
        ruleTargetCount,
        todayViolationCount,
        compliantStreakDays,
        lockdownActive,
      ].join('|');
}

class AssetWasteTrainingAiReview {
  final String summary;
  final String source;
  final DateTime generatedAt;
  final bool isFallback;

  const AssetWasteTrainingAiReview({
    required this.summary,
    required this.source,
    required this.generatedAt,
    this.isFallback = false,
  });

  factory AssetWasteTrainingAiReview.fallback({
    required AssetWasteTrainingSnapshot snapshot,
    required DateTime generatedAt,
    String? reason,
  }) {
    final normalizedReason =
        reason?.trim().replaceFirst(RegExp(r'[。．.!！?？]+$'), '') ?? '';
    final reasonText = normalizedReason.isEmpty ? '' : ' $normalizedReason';
    final focus = snapshot.wasteExpense > 0
        ? '今月の浪費額を次の1件から止め、浪費カテゴリを記録ログとして見直してください。'
        : '支出のたびに「能力を伸ばす支出か」を確認し、未記録日の確認と分類の見直しをしてください。';
    return AssetWasteTrainingAiReview(
      summary:
          'AIレビューを利用できないため、記録から参考値を表示しています$reasonText。浪費抑制スコアは記録ベースの参考値${snapshot.disciplineScore}点、浪費比率は${(snapshot.wasteRatio * 100).round()}%、日課達成は${snapshot.ruleCompletedCount}/${snapshot.ruleTargetCount}件です。$focus',
      source: 'local-kpi-engine',
      generatedAt: generatedAt,
      isFallback: true,
    );
  }
}

class AssetWasteTrainingAiService {
  final AiHubChatService _chatService;
  final DateTime Function() _now;

  AssetWasteTrainingAiService({
    AiHubChatService? chatService,
    AssetWasteTrainingAiInvoker? invoker,
    DateTime Function()? now,
  })  : _chatService = chatService ?? AiHubChatService(invoker: invoker),
        _now = now ?? DateTime.now;

  Future<AssetWasteTrainingAiReview> generateReview(
    AssetWasteTrainingSnapshot snapshot,
  ) async {
    if (snapshot.recordedExpenseDays == 0) {
      return AssetWasteTrainingAiReview(
        summary: '支出記録がないため採点・浪費の有無の判定はできません。未記録日は不明です。',
        source: 'local-observation-check',
        generatedAt: _now(),
        isFallback: true,
      );
    }
    try {
      final response = await _chatService.sendProviderChat(
        message: _buildPrompt(snapshot),
      );
      return AssetWasteTrainingAiReview(
        summary: _normalize(response.text),
        source: response.source,
        generatedAt: _now(),
      );
    } catch (error) {
      return AssetWasteTrainingAiReview.fallback(
        snapshot: snapshot,
        generatedAt: _now(),
        reason: _failureReason(error),
      );
    }
  }

  // Only fixed, user-facing descriptions leave this boundary. Provider error
  // payloads can contain private request text, URLs or credentials.
  String _failureReason(Object error) {
    final detail = error.toString().toLowerCase();
    if (RegExp(r'429|quota|rate.?limit|cooldown').hasMatch(detail)) {
      return 'AIの利用制限により取得できませんでした。時間を置いて確認してください';
    }
    if (RegExp(r'offline|local.only|external.*blocked').hasMatch(detail)) {
      return 'オフライン設定などにより外部AIを利用できません。接続設定を確認してください';
    }
    if (RegExp(r'secret_needed|missing.*key|not configured').hasMatch(detail)) {
      return 'AIの接続設定に確認が必要です';
    }
    if (RegExp(r'401|403|unauthorized|forbidden|login_required|jwt')
        .hasMatch(detail)) {
      return '認証またはアクセス権を確認できません。ログイン状態と接続設定を確認してください';
    }
    if (RegExp(r'timeout|timed out|socket|network|failed to fetch')
        .hasMatch(detail)) {
      return 'AIとの通信を完了できませんでした。接続状況を確認してください';
    }
    return 'AI応答を取得できませんでした。原因は未確認です';
  }

  String _buildPrompt(AssetWasteTrainingSnapshot snapshot) {
    return '''
あなたは浪費抑制を「判断力を鍛える訓練」として支援するAI資産コーチです。
以下の数値から、現状分析、KGI、KGI達成のためのCSF、CSFに基づくKPI改善、次回モニタリング観点を日本語で3行以内にまとめてください。
対象期間開始: ${snapshot.month.year}/${snapshot.month.month}/${snapshot.month.day}
浪費抑制スコア: ${snapshot.disciplineScore}/100
支出総額: ${snapshot.totalExpense}円
浪費額: ${snapshot.wasteExpense}円
浪費比率: ${(snapshot.wasteRatio * 100).round()}%
支出件数: ${snapshot.expenseEntryCount}
浪費件数: ${snapshot.wasteEntryCount}
浪費分類の記録がない支出記録日: ${snapshot.noWasteDays}日
支出記録日: ${snapshot.recordedExpenseDays}/${snapshot.elapsedDays}日
未記録日の支出・浪費の有無は不明です。点数は記録ベースの参考値で、能力・達成実績とは断定しないでください。
日課達成: ${snapshot.ruleCompletedCount}/${snapshot.ruleTargetCount}件
本日の違反: ${snapshot.todayViolationCount}件
連続遵守: ${snapshot.compliantStreakDays}日
ロックダウン稼働: ${snapshot.lockdownActive ? 'yes' : 'no'}
''';
  }

  String _normalize(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 280) {
      return collapsed;
    }
    return '${collapsed.substring(0, 280)}...';
  }
}
