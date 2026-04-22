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
    final sectionLines = _sectionCounts(report).entries.map((entry) {
      return '- ${entry.key}: ${entry.value}機能';
    }).join('\n');
    final consolidationLines =
        report.consolidationCandidates.take(5).map((candidate) {
      return '- ${candidate.canonicalFeatureName}: '
          '${candidate.featureNames.join(' / ')} '
          '(共通軸=${candidate.sharedAxis})';
    }).join('\n');

    return '''
あなたはプロダクト全体のAI戦略レビュー担当です。
以下の全機能KGI/CSF/KPIモニタリング結果を読み、現状分析、最重要CSF、次の改善アクション、類似機能の統合判断を日本語で3行以内にまとめてください。
総機能数: ${report.totalFeatures}
順調: ${report.onTrackCount}
要観察: ${report.watchCount}
改善優先: ${report.improveCount}
統合候補: ${report.consolidationCount}
全体KGI進捗: ${(report.portfolioPlan.displayProgress * 100).round()}%

セクション別:
$sectionLines

改善優先キュー:
$priorityLines

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
