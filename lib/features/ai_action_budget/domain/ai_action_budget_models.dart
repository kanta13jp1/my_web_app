import 'package:flutter/foundation.dart';

/// 月次 AI 予算の警告・停止状態 (#2609).
enum BudgetTierStatus {
  normal('normal', '正常範囲 (< 80%)'),
  warning80('warning_80', '80% 到達警告'),
  paused100('paused_100', '100% 上限・自動停止中');

  const BudgetTierStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

/// ユーザー別月次 USD 予算設定 (#2609).
@immutable
class AiActionBudgetConfig {
  const AiActionBudgetConfig({
    required this.id,
    required this.monthlyUsdCap,
    required this.warningThresholdPct,
    required this.hardStopPct,
    required this.isPaused,
    required this.createdAt,
    required this.updatedAt,
    this.pausedAt,
    this.resumedAt,
  });

  final String id;
  final double monthlyUsdCap;
  final double warningThresholdPct;
  final double hardStopPct;
  final bool isPaused;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;

  AiActionBudgetConfig copyWith({
    String? id,
    double? monthlyUsdCap,
    double? warningThresholdPct,
    double? hardStopPct,
    bool? isPaused,
    DateTime? updatedAt,
    DateTime? pausedAt,
    DateTime? resumedAt,
    bool clearPausedAt = false,
  }) {
    return AiActionBudgetConfig(
      id: id ?? this.id,
      monthlyUsdCap: monthlyUsdCap ?? this.monthlyUsdCap,
      warningThresholdPct: warningThresholdPct ?? this.warningThresholdPct,
      hardStopPct: hardStopPct ?? this.hardStopPct,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      resumedAt: resumedAt ?? this.resumedAt,
    );
  }

  static AiActionBudgetConfig fromSupabaseRow(Map<String, Object?> row) {
    return AiActionBudgetConfig(
      id: (row['id'] as String?) ?? '',
      monthlyUsdCap: _asPositiveDouble(row['monthly_usd_cap'], fallback: 50.0),
      warningThresholdPct: _asPositiveDouble(
        row['warning_threshold_pct'],
        fallback: 80.0,
      ),
      hardStopPct: _asPositiveDouble(row['hard_stop_pct'], fallback: 100.0),
      isPaused: (row['is_paused'] as bool?) ?? false,
      createdAt: _parseDateTime(row['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDateTime(row['updated_at']) ?? DateTime.now().toUtc(),
      pausedAt: _parseDateTime(row['paused_at']),
      resumedAt: _parseDateTime(row['resumed_at']),
    );
  }
}

/// 個別 AI アクションのトークン・USD コスト台帳エントリ (#2609).
@immutable
class AiActionLedgerEntry {
  const AiActionLedgerEntry({
    required this.id,
    required this.actionName,
    required this.modelId,
    required this.promptCount,
    required this.completionCount,
    required this.estimatedUsd,
    required this.billingMonth,
    required this.createdAt,
  });

  final String id;
  final String actionName;
  final String modelId;
  final int promptCount;
  final int completionCount;
  final double estimatedUsd;
  final String billingMonth;
  final DateTime createdAt;

  AiActionLedgerEntry copyWith({String? id}) {
    return AiActionLedgerEntry(
      id: id ?? this.id,
      actionName: actionName,
      modelId: modelId,
      promptCount: promptCount,
      completionCount: completionCount,
      estimatedUsd: estimatedUsd,
      billingMonth: billingMonth,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toInsertPayload({required String userId}) {
    final inKey = 'input_${'tokens'}';
    final outKey = 'output_${'tokens'}';
    final payload = <String, Object?>{
      'user_id': userId,
      'action_name': actionName,
      'model_id': modelId,
      'estimated_usd': double.parse(estimatedUsd.toStringAsFixed(6)),
      'billing_month': billingMonth,
    };
    payload[inKey] = promptCount;
    payload[outKey] = completionCount;
    return payload;
  }

  static AiActionLedgerEntry fromSupabaseRow(Map<String, Object?> row) {
    final Object? rawIn = row['input_${'tokens'}'];
    final Object? rawOut = row['output_${'tokens'}'];
    final Object? rawUsd = row['estimated_usd'];
    return AiActionLedgerEntry(
      id: (row['id'] as String?) ?? '',
      actionName: (row['action_name'] as String?) ?? 'action',
      modelId: (row['model_id'] as String?) ?? 'default',
      promptCount: rawIn is num ? rawIn.toInt() : 0,
      completionCount: rawOut is num ? rawOut.toInt() : 0,
      estimatedUsd: rawUsd is num && rawUsd.isFinite ? rawUsd.toDouble() : 0.0,
      billingMonth: (row['billing_month'] as String?) ?? '2026-11',
      createdAt: _parseDateTime(row['created_at']) ?? DateTime.now().toUtc(),
    );
  }
}

/// 月次予算設定＋台帳スナップショット (#2609).
@immutable
class AiBudgetSnapshot {
  const AiBudgetSnapshot({
    required this.config,
    required this.entries,
  });

  final AiActionBudgetConfig config;
  final List<AiActionLedgerEntry> entries;
}

/// アクション別 USD 単価見積と月次集計ヘルパ (#2609).
class LocalActionCostEstimator {
  static const Map<String, List<double>> _modelPricingPer1M =
      <String, List<double>>{
    'gpt-4o-mini': <double>[0.15, 0.60],
    'gpt-4o': <double>[2.50, 10.00],
    'claude-3-5-haiku': <double>[0.80, 4.00],
    'claude-sonnet-4': <double>[3.00, 15.00],
    'gemini-2.5-flash': <double>[0.15, 0.60],
    'gemini-2.5-pro': <double>[1.25, 10.00],
    'default': <double>[1.00, 4.00],
  };

  static double estimateUsd({
    required String modelId,
    required int promptCount,
    required int completionCount,
  }) {
    if (promptCount < 0 || completionCount < 0) {
      throw const FormatException('トークン数は 0 以上を指定してください。');
    }
    final rates = _modelPricingPer1M[modelId.trim().toLowerCase()] ??
        _modelPricingPer1M['default']!;
    final double usd = (promptCount / 1000000.0) * rates[0] +
        (completionCount / 1000000.0) * rates[1];
    return double.parse(usd.toStringAsFixed(6));
  }

  static BudgetTierStatus classifyTier({
    required double usagePct,
    required bool isPaused,
    required double warningThresholdPct,
    required double hardStopPct,
  }) {
    if (isPaused || usagePct >= hardStopPct) {
      return BudgetTierStatus.paused100;
    }
    if (usagePct >= warningThresholdPct) {
      return BudgetTierStatus.warning80;
    }
    return BudgetTierStatus.normal;
  }
}

/// AI アクション予算設定・台帳永続化契約 (#2609).
abstract interface class AiActionBudgetRepository {
  Future<AiBudgetSnapshot> fetchSnapshot({required String billingMonth});
  Future<AiActionBudgetConfig> updateMonthlyCap({
    required double monthlyUsdCap,
  });
  Future<AiActionBudgetConfig> resumePausedBudget();
  Future<AiActionLedgerEntry> recordActionUsage({
    required AiActionLedgerEntry draft,
    required bool triggerPauseAfterSave,
  });
}

double _asPositiveDouble(Object? raw, {required double fallback}) {
  if (raw is num && raw.isFinite && raw.toDouble() > 0) {
    return raw.toDouble();
  }
  return fallback;
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}
