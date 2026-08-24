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
        : '支出のたびに「能力を伸ばす支出か」を確認し、浪費ゼロ日の精度を上げてください。';
    return AssetWasteTrainingAiReview(
      summary:
          'AIレビュー待機中$reasonText。浪費抑制スコアは${snapshot.disciplineScore}点、浪費比率は${(snapshot.wasteRatio * 100).round()}%、日課達成は${snapshot.ruleCompletedCount}/${snapshot.ruleTargetCount}件です。$focus',
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
    try {
      final response = await _chatService.sendProviderChat(
        message: _buildPrompt(snapshot),
      );
      return AssetWasteTrainingAiReview(
        summary: _normalize(response.text),
        source: response.source,
        generatedAt: _now(),
      );
    } catch (_) {
      return AssetWasteTrainingAiReview.fallback(
        snapshot: snapshot,
        generatedAt: _now(),
        reason: 'AI連携に失敗しました。',
      );
    }
  }

  String _buildPrompt(AssetWasteTrainingSnapshot snapshot) {
    return '''
あなたは浪費抑制を「判断力を鍛える訓練」として支援するAI資産コーチです。
以下の数値から、現状分析、KGI、KGI達成のためのCSF、CSFに基づくKPI改善、次回モニタリング観点を日本語で3行以内にまとめてください。
対象月: ${snapshot.month.year}/${snapshot.month.month}
浪費抑制スコア: ${snapshot.disciplineScore}/100
支出総額: ${snapshot.totalExpense}円
浪費額: ${snapshot.wasteExpense}円
浪費比率: ${(snapshot.wasteRatio * 100).round()}%
支出件数: ${snapshot.expenseEntryCount}
浪費件数: ${snapshot.wasteEntryCount}
浪費ゼロ日: ${snapshot.noWasteDays}/${snapshot.elapsedDays}日
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
