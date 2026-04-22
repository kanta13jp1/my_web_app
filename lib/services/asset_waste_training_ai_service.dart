import 'package:supabase_flutter/supabase_flutter.dart';

typedef AssetWasteTrainingAiInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

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
    final reasonText =
        reason == null || reason.trim().isEmpty ? '' : '（$reason）';
    final focus = snapshot.wasteExpense > 0
        ? '今月の浪費額を次の1件から止め、記録した浪費カテゴリを「訓練ログ」として見直してください。'
        : '今月は浪費ログが少ないため、支出のたびに「能力を伸ばす支出か」を確認して精度を上げてください。';
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
  final SupabaseClient? _supabase;
  final AssetWasteTrainingAiInvoker? _invoker;
  final DateTime Function() _now;

  const AssetWasteTrainingAiService({
    SupabaseClient? supabase,
    AssetWasteTrainingAiInvoker? invoker,
    DateTime Function()? now,
  })  : _supabase = supabase,
        _invoker = invoker,
        _now = now ?? DateTime.now;

  Future<AssetWasteTrainingAiReview> generateReview(
    AssetWasteTrainingSnapshot snapshot,
  ) async {
    if (_AssetWasteTrainingAiQuotaGuard.isCoolingDown) {
      return AssetWasteTrainingAiReview.fallback(
        snapshot: snapshot,
        generatedAt: _now(),
        reason: 'AIクォータ保護中',
      );
    }

    try {
      final data = await _invokeProviderChat({
        'action': 'provider.chat',
        'provider': 'deepinfra',
        'message': _buildPrompt(snapshot),
      });
      final text = (data['text'] ?? data['result'] ?? data['message'])
          ?.toString()
          .trim();
      if (data['success'] == true && text != null && text.isNotEmpty) {
        return AssetWasteTrainingAiReview(
          summary: _normalize(text),
          source: 'ai-hub provider.chat / deepinfra',
          generatedAt: _now(),
        );
      }
      return AssetWasteTrainingAiReview.fallback(
        snapshot: snapshot,
        generatedAt: _now(),
        reason: 'AI応答が空でした',
      );
    } catch (error) {
      final message = error.toString();
      if (RegExp(r'429|quota|rate.?limit', caseSensitive: false)
          .hasMatch(message)) {
        _AssetWasteTrainingAiQuotaGuard.markQuotaExceeded();
      }
      return AssetWasteTrainingAiReview.fallback(
        snapshot: snapshot,
        generatedAt: _now(),
        reason: 'AI連携に失敗しました',
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

  String _buildPrompt(AssetWasteTrainingSnapshot snapshot) {
    return '''
あなたは浪費抑制を「判断力を鍛える訓練」として支援するAI資産コーチです。
以下の数値から、現状分析、KGI、KGI達成のためのCSF、CSFに基づくKPI改善、次回モニタリング観点を日本語で3行以内にまとめてください。説教ではなく、次の行動が明確になる言い方にしてください。

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
連続達成: ${snapshot.compliantStreakDays}日
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

class _AssetWasteTrainingAiQuotaGuard {
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
