import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/feature_strategy_monitor.dart';

typedef FeatureStrategyAiInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class FeatureStrategyAiReviewService {
  final SupabaseClient? _supabase;
  final FeatureStrategyAiInvoker? _invoker;
  final DateTime Function() _now;

  const FeatureStrategyAiReviewService({
    SupabaseClient? supabase,
    FeatureStrategyAiInvoker? invoker,
    DateTime Function()? now,
  })  : _supabase = supabase,
        _invoker = invoker,
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
    if (_FeatureStrategyAiQuotaGuard.isCoolingDown) {
      return FeatureStrategyAiReview.fallback(
        report: report,
        generatedAt: _now(),
        reason: 'AIクォータ保護中です。',
      );
    }

    try {
      final data = await _invokeProviderChat({
        'action': 'provider.chat',
        'provider': 'deepinfra',
        'message': _buildPrompt(report),
      });
      final text = (data['text'] ?? data['result'] ?? data['message'])
          ?.toString()
          .trim();
      if (data['success'] == true && text != null && text.isNotEmpty) {
        return FeatureStrategyAiReview(
          summary: _normalize(text),
          source: 'ai-hub provider.chat / deepinfra',
          generatedAt: _now(),
        );
      }
      return FeatureStrategyAiReview.fallback(
        report: report,
        generatedAt: _now(),
        reason: 'AI応答が空でした。',
      );
    } catch (error) {
      final message = error.toString();
      if (RegExp(r'429|quota|rate.?limit', caseSensitive: false)
          .hasMatch(message)) {
        _FeatureStrategyAiQuotaGuard.markQuotaExceeded();
      }
      return FeatureStrategyAiReview.fallback(
        report: report,
        generatedAt: _now(),
        reason: 'AI連携に失敗しました。',
      );
    }
  }

  Future<Map<String, dynamic>> _invokeProviderChat(
    Map<String, dynamic> body,
  ) async {
    final invoker = _invoker;
    if (invoker != null) {
      return invoker(body);
    }
    final client = _supabase ?? Supabase.instance.client;
    final response = await client.functions.invoke('ai-hub', body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{
      'success': false,
      'message': data?.toString() ?? 'empty response',
    };
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

    return '''
あなたはプロダクト全体のAI戦略レビュー担当です。
以下の全機能KGI/CSF/KPIモニタリング結果を読み、現状分析、最重要CSF、次の改善アクションを日本語で3行以内にまとめてください。
出力は短く、箇条書きではなく自然文で返してください。

総機能数: ${report.totalFeatures}
順調: ${report.onTrackCount}
要観察: ${report.watchCount}
改善優先: ${report.improveCount}
全体KGI進捗: ${(report.portfolioPlan.displayProgress * 100).round()}%

セクション別:
$sectionLines

改善優先キュー:
$priorityLines
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

class _FeatureStrategyAiQuotaGuard {
  static DateTime? _lastQuotaErrorAt;
  static const Duration _cooldown = Duration(seconds: 60);

  static void markQuotaExceeded() {
    _lastQuotaErrorAt = DateTime.now();
  }

  static bool get isCoolingDown {
    final ts = _lastQuotaErrorAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _cooldown;
  }
}
