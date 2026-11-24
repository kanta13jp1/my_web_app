import 'dart:convert';
import 'dart:math';

import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/payment_funding_rule.dart';
import 'package:my_web_app/services/asset_safety_transfer_suggestion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 原資不足検知時の自動口座間移動の実行モード (#3443)。
enum AutoTransferExecutionMode { promptConfirmation, autoCreateTask }

/// 支払原資不足時の自動口座間移動に関するユーザー設定 (#3443)。
class AutoTransferSettings {
  final bool enabled;
  final AutoTransferExecutionMode executionMode;
  final bool notifyOnExecution;
  final double extraSafetyBuffer;

  const AutoTransferSettings({
    this.enabled = false,
    this.executionMode = AutoTransferExecutionMode.promptConfirmation,
    this.notifyOnExecution = true,
    this.extraSafetyBuffer = 5000,
  });

  AutoTransferSettings copyWith({
    bool? enabled,
    AutoTransferExecutionMode? executionMode,
    bool? notifyOnExecution,
    double? extraSafetyBuffer,
  }) {
    return AutoTransferSettings(
      enabled: enabled ?? this.enabled,
      executionMode: executionMode ?? this.executionMode,
      notifyOnExecution: notifyOnExecution ?? this.notifyOnExecution,
      extraSafetyBuffer: extraSafetyBuffer ?? this.extraSafetyBuffer,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'execution_mode': executionMode.name,
      'notify_on_execution': notifyOnExecution,
      'extra_safety_buffer': extraSafetyBuffer,
    };
  }

  factory AutoTransferSettings.fromJson(Map<String, dynamic> json) {
    final modeName = json['execution_mode']?.toString();
    final mode = AutoTransferExecutionMode.values.firstWhere(
      (value) => value.name == modeName,
      orElse: () => AutoTransferExecutionMode.promptConfirmation,
    );
    final rawBuffer = json['extra_safety_buffer'];
    final buffer = rawBuffer is num
        ? rawBuffer.toDouble().clamp(0.0, 200000.0).toDouble()
        : 5000.0;
    return AutoTransferSettings(
      enabled: json['enabled'] == true,
      executionMode: mode,
      notifyOnExecution: json['notify_on_execution'] != false,
      extraSafetyBuffer: buffer,
    );
  }
}

/// 自動起票または確認実行された口座間移動タスクの監査ログ (#3443)。
class AutoTransferAuditEntry {
  final String id;
  final DateTime executedAt;
  final String fromAccountId;
  final String fromAccountName;
  final String toAccountId;
  final String toAccountName;
  final double amount;
  final double projectedBalanceBefore;
  final double donorRemainingBalanceAfter;
  final AutoTransferExecutionMode executionMode;
  final String status;
  final String dedupeKey;
  final String reason;

  const AutoTransferAuditEntry({
    required this.id,
    required this.executedAt,
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amount,
    required this.projectedBalanceBefore,
    required this.donorRemainingBalanceAfter,
    required this.executionMode,
    required this.status,
    required this.dedupeKey,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'executed_at': executedAt.toIso8601String(),
      'from_account_id': fromAccountId,
      'from_account_name': fromAccountName,
      'to_account_id': toAccountId,
      'to_account_name': toAccountName,
      'amount': amount,
      'projected_balance_before': projectedBalanceBefore,
      'donor_remaining_balance_after': donorRemainingBalanceAfter,
      'execution_mode': executionMode.name,
      'status': status,
      'dedupe_key': dedupeKey,
      'reason': reason,
    };
  }

  factory AutoTransferAuditEntry.fromJson(Map<String, dynamic> json) {
    final modeName = json['execution_mode']?.toString();
    final mode = AutoTransferExecutionMode.values.firstWhere(
      (value) => value.name == modeName,
      orElse: () => AutoTransferExecutionMode.promptConfirmation,
    );
    return AutoTransferAuditEntry(
      id: json['id']?.toString() ?? '',
      executedAt: DateTime.tryParse(json['executed_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fromAccountId: json['from_account_id']?.toString() ?? '',
      fromAccountName: json['from_account_name']?.toString() ?? '',
      toAccountId: json['to_account_id']?.toString() ?? '',
      toAccountName: json['to_account_name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      projectedBalanceBefore:
          (json['projected_balance_before'] as num?)?.toDouble() ?? 0,
      donorRemainingBalanceAfter:
          (json['donor_remaining_balance_after'] as num?)?.toDouble() ?? 0,
      executionMode: mode,
      status: json['status']?.toString() ?? 'confirmed',
      dedupeKey: json['dedupe_key']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

/// 自動口座間移動の設定と監査ログの端末永続化ストア (#3443)。
class AssetAutoTransferStore {
  const AssetAutoTransferStore._();

  static const String settingsPrefsKey = 'asset_auto_transfer_settings_v1';
  static const String auditLogsPrefsKey = 'asset_auto_transfer_audit_log_v1';
  static const int maxAuditLogs = 50;

  static Future<AutoTransferSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(settingsPrefsKey);
      if (raw == null || raw.trim().isEmpty) {
        return const AutoTransferSettings();
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AutoTransferSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return AutoTransferSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // 読込失敗時は安全なデフォルト (自動実行OFF) を使う。
    }
    return const AutoTransferSettings();
  }

  static Future<void> saveSettings(AutoTransferSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(settingsPrefsKey, jsonEncode(settings.toJson()));
    } catch (_) {
      // 保存失敗時も画面操作自体はブロックしない。
    }
  }

  static Future<List<AutoTransferAuditEntry>> loadAuditLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(auditLogsPrefsKey);
      if (raw == null || raw.trim().isEmpty) {
        return const <AutoTransferAuditEntry>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AutoTransferAuditEntry>[];
      }
      final logs = <AutoTransferAuditEntry>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          logs.add(AutoTransferAuditEntry.fromJson(item));
        } else if (item is Map) {
          logs.add(
            AutoTransferAuditEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
      logs.sort((a, b) => b.executedAt.compareTo(a.executedAt));
      return List<AutoTransferAuditEntry>.unmodifiable(logs);
    } catch (_) {
      return const <AutoTransferAuditEntry>[];
    }
  }

  static Future<List<AutoTransferAuditEntry>> appendAuditLog(
    AutoTransferAuditEntry entry,
  ) async {
    final existing = await loadAuditLogs();
    final merged = <AutoTransferAuditEntry>[
      entry,
      ...existing.where((item) => item.id != entry.id),
    ];
    final capped = merged.take(maxAuditLogs).toList(growable: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        auditLogsPrefsKey,
        jsonEncode(capped.map((e) => e.toJson()).toList(growable: false)),
      );
    } catch (_) {
      // 保存失敗時も呼び出し元はメモリ上の履歴を保持する。
    }
    return List<AutoTransferAuditEntry>.unmodifiable(capped);
  }
}

/// 余裕残高保護・重複チェック済みの自動口座間移動候補 (#3443)。
class AutoTransferPlanCandidate {
  final AssetSafetyTransferSuggestion suggestion;
  final double donorRemainingProjectedBalance;
  final double projectedBalanceAfterTransfer;
  final bool alreadyTracked;

  const AutoTransferPlanCandidate({
    required this.suggestion,
    required this.donorRemainingProjectedBalance,
    required this.projectedBalanceAfterTransfer,
    required this.alreadyTracked,
  });
}

/// 自動/確認実行で生成されたタスクと監査レコードのペア。
class AutoTransferExecutionBundle {
  final AssetLiabilityTransferTask task;
  final AutoTransferAuditEntry audit;

  const AutoTransferExecutionBundle({
    required this.task,
    required this.audit,
  });
}

/// 支払原資不足時の安全な自動口座間移動プラン生成・監査記録ビルダー (#3443)。
class AssetAutoTransferService {
  const AssetAutoTransferService._();

  static List<AutoTransferPlanCandidate> buildCandidates({
    required AssetLiabilityWorkbook workbook,
    required double minimumSafetyBalance,
    required AutoTransferSettings settings,
    PaymentFundingRule? fundingRule,
  }) {
    final effectiveFloor = minimumSafetyBalance > 0
        ? minimumSafetyBalance
        : max(5000.0, settings.extraSafetyBuffer);
    final rawSuggestions =
        AssetSafetyTransferSuggestionService.buildSuggestions(
      workbook: workbook,
      minimumSafetyBalance: effectiveFloor,
      bufferAmount: settings.extraSafetyBuffer,
      fundingRule: fundingRule,
    );
    if (rawSuggestions.isEmpty) {
      return const <AutoTransferPlanCandidate>[];
    }

    final summariesById = <String, AssetLiabilityAccountCashflowSummary>{
      for (final summary in workbook.accountCashflowSummaries)
        summary.accountId: summary,
    };

    final candidates = <AutoTransferPlanCandidate>[];
    for (final suggestion in rawSuggestions) {
      final donor = summariesById[suggestion.fromAccountId];
      if (donor == null) {
        continue;
      }
      final donorAfterProjected = donor.projectedBalance - suggestion.amount;
      final donorAfterCurrent =
          donor.currentBalance - donor.pendingTransferOut - suggestion.amount;
      if (donorAfterProjected < effectiveFloor || donorAfterCurrent < 0) {
        continue;
      }

      final alreadyTracked = workbook.transferTasks.any((task) {
        if (task.canceled) return false;
        if (task.dedupeKey != null && task.dedupeKey == suggestion.dedupeKey) {
          return true;
        }
        return !task.completed &&
            task.fromAccountId == suggestion.fromAccountId &&
            task.toAccountId == suggestion.toAccountId &&
            (task.amount - suggestion.amount).abs() < 1;
      });

      candidates.add(
        AutoTransferPlanCandidate(
          suggestion: suggestion,
          donorRemainingProjectedBalance: donorAfterProjected,
          projectedBalanceAfterTransfer:
              suggestion.projectedBalanceBefore + suggestion.amount,
          alreadyTracked: alreadyTracked,
        ),
      );
    }
    return List<AutoTransferPlanCandidate>.unmodifiable(candidates);
  }

  static AutoTransferExecutionBundle buildTransferTaskAndAudit({
    required AutoTransferPlanCandidate candidate,
    required AutoTransferExecutionMode mode,
    required DateTime now,
  }) {
    final s = candidate.suggestion;
    final dueDate = s.neededBy == null
        ? null
        : DateTime(s.neededBy!.year, s.neededBy!.month, s.neededBy!.day);
    final micros = now.microsecondsSinceEpoch;
    final task = AssetLiabilityTransferTask(
      id: 'auto_transfer_${s.toAccountId}_$micros',
      fromAccountId: s.fromAccountId,
      fromAccountName: s.fromAccountName,
      toAccountId: s.toAccountId,
      toAccountName: s.toAccountName,
      amount: s.amount,
      dueDate: dueDate,
      dedupeKey: s.dedupeKey,
    );
    final status = mode == AutoTransferExecutionMode.autoCreateTask
        ? 'auto_created'
        : 'confirmed';
    final audit = AutoTransferAuditEntry(
      id: 'auto_audit_${s.toAccountId}_$micros',
      executedAt: now,
      fromAccountId: s.fromAccountId,
      fromAccountName: s.fromAccountName,
      toAccountId: s.toAccountId,
      toAccountName: s.toAccountName,
      amount: s.amount,
      projectedBalanceBefore: s.projectedBalanceBefore,
      donorRemainingBalanceAfter: candidate.donorRemainingProjectedBalance,
      executionMode: mode,
      status: status,
      dedupeKey: s.dedupeKey,
      reason: s.reason,
    );
    return AutoTransferExecutionBundle(task: task, audit: audit);
  }
}
