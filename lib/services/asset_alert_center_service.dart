import 'package:intl/intl.dart';

import '../models/asset_alert.dart';
import '../models/asset_liability_workbook.dart';
import 'asset_liability_payment_reminder_service.dart';

/// 統合アラートパネル (Issue #2475) の集約結果。
class AssetAlertCenter {
  /// 重要度降順 → 発生日昇順 で並んだ、未 dismiss のアラート。
  final List<AssetAlert> alerts;

  /// dismiss 済みで非表示にした件数。
  final int dismissedCount;

  const AssetAlertCenter({
    required this.alerts,
    required this.dismissedCount,
  });

  static const AssetAlertCenter empty = AssetAlertCenter(
    alerts: <AssetAlert>[],
    dismissedCount: 0,
  );

  bool get hasAlerts => alerts.isNotEmpty;

  int get criticalCount =>
      alerts.where((a) => a.severity == AssetAlertSeverity.critical).length;

  int get warningCount =>
      alerts.where((a) => a.severity == AssetAlertSeverity.warning).length;
}

/// 複数の発生源から資産アラートを集約する純サービス。
///
/// - 延滞 / 支払リマインダーは [AssetLiabilityPaymentReminderService] の候補を
///   単一の真実として使い、延滞行の二重計上を避ける。
/// - 口座ショート・支払原資未設定は workbook から直接導出する。
/// - 異常検知 (第2弾D / #2476-#2477) は [anomalyAlerts] として外部注入できる
///   (D 未実装の現時点では空のまま統合設計だけ用意する)。
/// - 判定・金額整形はすべて deterministic。AI は関与しない (issue 注意事項準拠)。
class AssetAlertCenterService {
  const AssetAlertCenterService({
    this.reminderService = const AssetLiabilityPaymentReminderService(),
  });

  final AssetLiabilityPaymentReminderService reminderService;

  static final NumberFormat _yen = NumberFormat.decimalPattern();

  /// アラートを集約する。
  ///
  /// [dismissedIds] に含まれる id のアラートは除外し [AssetAlertCenter.dismissedCount]
  /// に数える。[anomalyAlerts] は将来の異常検知結果を注入するための口。
  AssetAlertCenter build({
    required AssetLiabilityWorkbook workbook,
    required DateTime now,
    Set<String> dismissedIds = const <String>{},
    List<AssetAlert> anomalyAlerts = const <AssetAlert>[],
    int reminderLookAheadDays = 1,
  }) {
    final collected = <AssetAlert>[];

    // 1. 延滞 + 支払日前リマインダー (#2453) — reminder 候補を単一ソースに。
    final reminders = reminderService.buildCandidates(
      workbook: workbook,
      now: now,
      lookAheadDays: reminderLookAheadDays,
    );
    for (final reminder in reminders) {
      collected.add(_fromReminder(reminder));
    }

    // 2. 口座残高ショート見込み。
    for (final summary in workbook.shortAccountSummaries) {
      collected.add(
        AssetAlert(
          id: 'account_shortfall:${summary.accountId}',
          severity: AssetAlertSeverity.critical,
          category: AssetAlertCategory.accountShortfall,
          title: '${summary.accountName} が残高不足の見込み',
          detail: '見込み残高が ¥${_formatYen(summary.projectedBalance)} '
              '(不足 ¥${_formatYen(summary.shortfall)})。入金または資金移動を検討してください。',
          accountId: summary.accountId,
        ),
      );
    }

    // 3. 支払原資未設定。
    for (final row in workbook.paymentSourceMissingRows) {
      collected.add(
        AssetAlert(
          id: 'payment_source_missing:${row.id}',
          severity: AssetAlertSeverity.warning,
          category: AssetAlertCategory.paymentSourceMissing,
          title: '${row.name} の支払原資が未設定',
          detail:
              '予定支払 ¥${_formatYen(row.scheduledPaymentAmount)} の引落口座が未設定です。',
          accountId: row.id,
        ),
      );
    }

    // 4. 異常検知 (外部注入 / 第2弾D)。
    collected.addAll(anomalyAlerts);

    // id 重複排除 (同一 id は最初の 1 件を優先)。
    final seen = <String>{};
    final deduped = <AssetAlert>[];
    for (final alert in collected) {
      if (seen.add(alert.id)) {
        deduped.add(alert);
      }
    }

    // dismiss 済みを除外。
    final visible = <AssetAlert>[];
    var dismissed = 0;
    for (final alert in deduped) {
      if (dismissedIds.contains(alert.id)) {
        dismissed += 1;
      } else {
        visible.add(alert);
      }
    }

    // 重要度降順 → occurredAt 昇順 (null は末尾) → id 昇順 で安定ソート。
    visible.sort((a, b) {
      final bySeverity = b.severity.weight.compareTo(a.severity.weight);
      if (bySeverity != 0) {
        return bySeverity;
      }
      final byDate = _compareNullableDate(a.occurredAt, b.occurredAt);
      if (byDate != 0) {
        return byDate;
      }
      return a.id.compareTo(b.id);
    });

    return AssetAlertCenter(alerts: visible, dismissedCount: dismissed);
  }

  AssetAlert _fromReminder(AssetLiabilityPaymentReminderCandidate reminder) {
    final row = reminder.cashflowRow;
    final dateKey = DateFormat('yyyy-MM-dd').format(row.paymentDate);
    final isOverdue =
        reminder.status == AssetLiabilityPaymentReminderStatus.overdue;
    final category = isOverdue
        ? AssetAlertCategory.overduePayment
        : AssetAlertCategory.paymentDue;
    // 延滞は critical、期日前でもショートリスクがあれば critical、そうでなければ warning。
    final severity = (isOverdue || reminder.hasShortageRisk)
        ? AssetAlertSeverity.critical
        : AssetAlertSeverity.warning;
    return AssetAlert(
      id: '${category.storageId}:${row.accountId}:$dateKey',
      severity: severity,
      category: category,
      title: reminder.title,
      detail: reminder.detail,
      occurredAt: row.paymentDate,
      accountId: row.accountId,
    );
  }

  static int _compareNullableDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1; // null は末尾。
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }

  static String _formatYen(double value) => _yen.format(value.round());
}
