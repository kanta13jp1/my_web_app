import '../models/feature_strategy_monitor.dart';
import 'ai_hub_chat_service.dart';

typedef FeatureStrategyAiInvoker = AiHubChatInvoker;

class FeatureStrategyAiReviewService {
  final AiHubChatService _chatService;
  final DateTime Function() _now;

  FeatureStrategyAiReviewService({
    AiHubChatService? chatService,
    FeatureStrategyAiInvoker? invoker,
    DateTime Function()? now,
  })  : _chatService = chatService ?? AiHubChatService(invoker: invoker),
        _now = now ?? DateTime.now;

  Future<FeatureStrategyAiReview> generateReview(
    FeatureStrategyReport report,
  ) async {
    if (report.signals.isEmpty) {
      return FeatureStrategyAiReview.fallback(
        report: report,
        generatedAt: _now(),
        reason: '対象機能がありません。',
      );
    }

    try {
      final response = await _chatService.sendProviderChat(
        message: _buildPrompt(report),
      );
      return FeatureStrategyAiReview(
        summary: _normalize(response.text),
        source: response.source,
        generatedAt: _now(),
      );
    } catch (_) {
      return FeatureStrategyAiReview.fallback(
        report: report,
        generatedAt: _now(),
        reason: 'AI連携に失敗しました。',
      );
    }
  }

  String _buildPrompt(FeatureStrategyReport report) {
    final priorityLines = report.prioritySignals.take(8).map((signal) {
      return '- ${signal.featureName}: status=${signal.status.name}, '
          'progress=${(signal.progress * 100).round()}%, '
          'next=${signal.nextImprovement}';
    }).join('\n');
    final reviewDueLines = report.reviewDueSignals.take(8).map((signal) {
      return '- ${signal.featureName}: ${signal.reviewDueLabel}, '
          'cadence=${signal.monitoringCadence}, '
          'next=${signal.nextImprovement}';
    }).join('\n');
    final sectionLines = _sectionCounts(report).entries.map((entry) {
      return '- ${entry.key}: ${entry.value}機能';
    }).join('\n');
    final consolidationLines =
        report.consolidationCandidates.take(5).map((candidate) {
      return '- ${candidate.canonicalFeatureName}: '
          '${candidate.featureNames.join(' / ')} / '
          'sections=${candidate.sectionLabel} / '
          'saved=${candidate.estimatedWasteMinutesSaved}分 / '
          'action=${candidate.consolidationAction}';
    }).join('\n');
    final lifeCapitalLines = report.lifeCapitalSummaries.map((summary) {
      return '- ${summary.label}: ${summary.featureCount}機能, '
          '浪費削減高=${summary.highImpactFeatureCount}機能, '
          '進捗=${(summary.averageProgress * 100).round()}%, '
          '詰まり=${summary.bottleneckFeatureName}';
    }).join('\n');
    final lifeCapitalLaneLines =
        report.lifeCapitalConsolidationLanes.map((lane) {
      return '- ${lane.label}: 代表=${lane.canonicalFeatureName}, '
          '束ねる=${lane.featureCount}機能, '
          '統合候補=${lane.consolidationCandidateCount}, '
          '削減見込み=${lane.estimatedWasteMinutesSaved}分, '
          'next=${lane.nextAction}';
    }).join('\n');
    final focus = report.focusRecommendation;
    final focusLine = focus == null
        ? '未選定'
        : '${focus.label} / ${focus.featureName}: ${focus.action} '
            '(CSF=${focus.csf}, 7日完了=${focus.actionStats.completedDaysLast7}日, '
            '観察=${focus.actionStats.deferredDaysLast7}日, '
            '継続=${focus.actionStats.currentStreakDays}日, '
            '解放=${focus.actionStats.unlockStatusLabel}, '
            '保留=${focus.parkedResourceCount}資本/${focus.parkedFeatureCount}機能)';
    final queuedFocus = report.queuedFocusRecommendation;
    final queuedFocusLine = queuedFocus == null
        ? 'なし'
        : '${queuedFocus.label} / ${queuedFocus.featureName}: ${queuedFocus.action} '
            '(解放条件=${queuedFocus.unlockCondition})';
    final recoveryRoadmapLines = report.recoveryRoadmap.take(6).map((step) {
      return '- ${step.order}. ${step.label}: ${step.stageLabel} / '
          '${step.featureName} / gate=${step.gate}';
    }).join('\n');

    return '''
あなたはプロダクト全体のAI戦略レビュー担当です。
以下の全機能KGI/CSF/KPIモニタリング結果を読み、現状分析、最重要CSF、次の改善アクション、類似機能の統合判断を日本語で3行以内にまとめてください。
特にライフマネジメントでは、時間・お金・健康・体力・知能・集中力の浪費をなくすことを最重要課題として扱ってください。
継続系タスクは同時に広げず、今日の低ハードル1手を優先し、他は観察に回してください。
低ハードル1手は完了3日分または3日継続まで固定し、解放条件を満たすまで新しい継続タスクを増やさないでください。
総機能数: ${report.totalFeatures}
順調: ${report.onTrackCount}
要観察: ${report.watchCount}
改善優先: ${report.improveCount}
統合候補: ${report.consolidationCount}
統合による導線迷い削減見込み: ${report.consolidationWasteMinutesSaved}分
レビュー期限到来: ${report.reviewDueCount}
レビュー期限超過: ${report.reviewOverdueCount}
レビュー期限遵守率: ${(report.reviewCadenceComplianceRatio * 100).round()}%
全体KGI進捗: ${(report.portfolioPlan.displayProgress * 100).round()}%
  生命資本カバー: ${(report.lifeCapitalCoverageRatio * 100).round()}%
  生命資本別代表導線: ${report.lifeCapitalLaneCount}/${FeatureLifeCapitalResource.values.length}資本
  生命資本回復ロードマップ: ${report.recoveryRoadmapCount}資本
  代表導線による迷い削減見込み: ${report.lifeCapitalLaneWasteMinutesSaved}分
  浪費削減高スコア機能: ${report.highWasteReductionCount}
低ハードル完了(7日): ${report.focusActionsCompletedLast7}
低ハードル観察(7日): ${report.focusActionsDeferredLast7}
選定1手の継続日数: ${report.focusActionStreakDays}

セクション別:
$sectionLines

  生命資本別:
  $lifeCapitalLines
  
  生命資本別の代表導線レーン:
  $lifeCapitalLaneLines

 今日の低ハードル1手:
$focusLine

解放後の次候補:
$queuedFocusLine

生命資本回復ロードマップ:
${recoveryRoadmapLines.isEmpty ? '- まだ順番はありません' : recoveryRoadmapLines}

改善優先キュー:
$priorityLines

レビュー期限キュー:
${reviewDueLines.isEmpty ? '- 期限到来レビューなし' : reviewDueLines}

類似機能の統合候補:
${consolidationLines.isEmpty ? '- 現時点では明確な統合候補なし' : consolidationLines}
''';
  }

  Map<String, int> _sectionCounts(FeatureStrategyReport report) {
    final counts = <String, int>{};
    for (final signal in report.signals) {
      counts.update(
        signal.sectionName,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  String _normalize(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 240) {
      return collapsed;
    }
    return '${collapsed.substring(0, 240)}...';
  }
}
