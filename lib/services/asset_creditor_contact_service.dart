import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/contact_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef CreditorContactSubmitter = Future<void> Function(
  CreditorContactLog log,
);

/// 債権者連絡テンプレート生成・タスク集約・期日前リマインドを提供する (#3292 / #3288)。
class AssetCreditorContactService {
  static const double highInterestRateThreshold = 0.15;

  const AssetCreditorContactService._();

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 負債行の基準月における支払期日を解決する。
  static DateTime? debtRowDueDate(
    AssetLiabilityDebtRow row,
    DateTime baseDate,
  ) {
    final day = row.paymentDay;
    if (day == null) {
      return null;
    }
    final maxDay = DateUtils.getDaysInMonth(baseDate.year, baseDate.month);
    return DateTime(
      baseDate.year,
      baseDate.month,
      day.clamp(1, maxDay).toInt(),
    );
  }

  /// テンプレート種別に応じた連絡文面を生成する。
  static String buildTemplateText({
    required AssetLiabilityDebtRow row,
    required DateTime? dueDate,
    required CreditorContactTemplateKind kind,
  }) {
    final yen = NumberFormat('#,##0', 'ja_JP');
    final dueLabel =
        dueDate == null ? '未設定' : DateFormat('yyyy/MM/dd').format(dueDate);
    final ratePercent = (row.annualRate * 100).toStringAsFixed(1);
    final scheduledLabel = '¥${yen.format(row.scheduledPaymentAmount.round())}';
    final minLabel = '¥${yen.format(row.minimumPaymentEstimate.round())}';
    final balanceLabel = '¥${yen.format(row.balance.round().abs())}';

    final requestDetail = switch (kind) {
      CreditorContactTemplateKind.changeDueDate =>
        '今月の入金日（給料日）との兼ね合いのため、支払予定日を次回入金後に変更できないかご相談したいです。',
      CreditorContactTemplateKind.reduceMinimum =>
        '生活費と必須支出を確保した上で継続返済を続けるため、今月の最低返済額を減額・調整できないかご相談したいです。',
      CreditorContactTemplateKind.installmentOrGrace =>
        '一時的な資金繰り調整のため、当月の支払猶予または分割での返済計画へ変更できないかご相談したいです。',
    };

    return [
      '${row.name} ご担当者様',
      '',
      'いつもお世話になっております。今月の返済について事前にご相談いたします。',
      '【口座情報】残高: $balanceLabel / 年利: $ratePercent% / 支払予定日: $dueLabel',
      '【予定金額】予定額: $scheduledLabel（推定最低額: $minLabel）',
      '',
      requestDetail,
      'ご連絡可能な候補日時・お手続き方法をご案内いただけますと幸いです。',
    ].join('\n');
  }

  /// 連絡日時と次回支払期日から推奨フォロー日を算出する。
  static DateTime suggestNextFollowUpDate({
    required DateTime contactedAt,
    DateTime? dueDate,
  }) {
    final contactedDay = _dateOnly(contactedAt);
    if (dueDate != null) {
      final normalizedDue = _dateOnly(dueDate);
      if (normalizedDue.difference(contactedDay).inDays > 2) {
        return normalizedDue.subtract(const Duration(days: 2));
      }
    }
    return contactedDay.add(const Duration(days: 3));
  }

  /// 期限超過・期日接近・高金利の未払負債から連絡タスクを生成する (#3288)。
  static List<CreditorContactTask> buildContactTasks({
    required List<AssetLiabilityDebtRow> rows,
    required DateTime baseDate,
    required List<CreditorContactLog> logs,
  }) {
    final today = _dateOnly(baseDate);
    final latestByAccount = _latestLogsByAccount(logs);
    final tasks = <CreditorContactTask>[];

    for (final row in rows) {
      if (row.paid ||
          row.balance >= 0 ||
          row.scheduledPaymentAmount <= 0 ||
          row.includedInBillingAccount) {
        continue;
      }
      final dueDate = debtRowDueDate(row, today);
      final isOverdue = dueDate != null && !dueDate.isAfter(today);
      final isUrgent = dueDate != null && dueDate.difference(today).inDays <= 7;
      final isHighInterest = row.annualRate >= highInterestRateThreshold;
      if (!isOverdue && !isUrgent && !isHighInterest) {
        continue;
      }

      final latestLog = latestByAccount[row.id];
      final contactedInCycle = latestLog != null &&
          today.difference(_dateOnly(latestLog.contactedAt)).inDays <= 31;

      tasks.add(
        CreditorContactTask(
          accountId: row.id,
          accountName: row.name,
          dueDate: dueDate,
          annualRate: row.annualRate,
          scheduledPaymentAmount: row.scheduledPaymentAmount,
          isOverdue: isOverdue,
          isHighInterest: isHighInterest,
          status: contactedInCycle
              ? CreditorContactTaskStatus.contacted
              : CreditorContactTaskStatus.pending,
          contactedAt: contactedInCycle ? latestLog.contactedAt : null,
          nextFollowUpDate:
              contactedInCycle ? latestLog.nextFollowUpDate : null,
          note: contactedInCycle
              ? (latestLog.agreedSummary.trim().isNotEmpty
                  ? latestLog.agreedSummary
                  : latestLog.note)
              : '',
          latestLog: contactedInCycle ? latestLog : null,
        ),
      );
    }

    tasks.sort((a, b) {
      if (a.isContacted != b.isContacted) {
        return a.isContacted ? 1 : -1;
      }
      if (a.isOverdue != b.isOverdue) {
        return a.isOverdue ? -1 : 1;
      }
      final rateCmp = b.annualRate.compareTo(a.annualRate);
      if (rateCmp != 0) {
        return rateCmp;
      }
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      return b.scheduledPaymentAmount.compareTo(a.scheduledPaymentAmount);
    });

    return tasks;
  }

  /// 保存済み合意内容と次回期日/フォロー日からリマインダー一覧を生成する (#3292)。
  static List<CreditorContactReminder> buildDueReminders({
    required List<AssetLiabilityDebtRow> rows,
    required DateTime baseDate,
    required List<CreditorContactLog> logs,
    int windowDays = 5,
  }) {
    final today = _dateOnly(baseDate);
    final rowsById = <String, AssetLiabilityDebtRow>{
      for (final row in rows) row.id: row,
    };
    final latestByAccount = _latestLogsByAccount(logs);
    final reminders = <CreditorContactReminder>[];

    for (final entry in latestByAccount.entries) {
      final log = entry.value;
      final row = rowsById[log.accountId];
      if (row != null && row.paid) {
        continue;
      }
      final summary = log.agreedSummary.trim().isNotEmpty
          ? log.agreedSummary.trim()
          : log.note.trim();
      final nextDue = row == null ? null : debtRowDueDate(row, today);
      final targetDate = log.nextFollowUpDate ?? nextDue;
      final daysUntil = targetDate == null
          ? windowDays
          : _dateOnly(targetDate).difference(today).inDays;
      final isUrgent = targetDate != null && daysUntil <= windowDays;
      if (summary.isEmpty && !isUrgent) {
        continue;
      }

      reminders.add(
        CreditorContactReminder(
          accountId: log.accountId,
          accountName: row?.name ?? log.accountName,
          dueDate: nextDue,
          nextFollowUpDate: log.nextFollowUpDate,
          agreedSummary:
              summary.isEmpty ? '${log.templateKind.label} について連絡済み' : summary,
          daysUntilReminder: daysUntil,
          isUrgent: isUrgent,
        ),
      );
    }

    reminders.sort((a, b) {
      if (a.isUrgent != b.isUrgent) {
        return a.isUrgent ? -1 : 1;
      }
      return a.daysUntilReminder.compareTo(b.daysUntilReminder);
    });
    return reminders;
  }

  static Map<String, CreditorContactLog> _latestLogsByAccount(
    List<CreditorContactLog> logs,
  ) {
    final map = <String, CreditorContactLog>{};
    final sorted = List<CreditorContactLog>.from(logs)
      ..sort((a, b) => b.contactedAt.compareTo(a.contactedAt));
    for (final log in sorted) {
      map.putIfAbsent(log.accountId, () => log);
    }
    return map;
  }
}

/// 債権者連絡ログのローカル永続化と送信フックを調停する (#3292 / #3288)。
class AssetContactLogStore {
  static const String prefsKey = 'asset_creditor_contact_logs_v1';

  const AssetContactLogStore();

  Future<List<CreditorContactLog>> loadLogs({
    SharedPreferences? prefs,
  }) async {
    final resolved = prefs ?? await SharedPreferences.getInstance();
    final raw = resolved.getString(prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <CreditorContactLog>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <CreditorContactLog>[];
      }
      final logs = <CreditorContactLog>[];
      for (final item in decoded) {
        if (item is Map) {
          final parsed = CreditorContactLog.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (parsed != null) {
            logs.add(parsed);
          }
        }
      }
      logs.sort((a, b) => b.contactedAt.compareTo(a.contactedAt));
      return logs;
    } catch (_) {
      return const <CreditorContactLog>[];
    }
  }

  /// リモート送信（指定時）が成功した後にのみローカル履歴へ保存する。
  Future<List<CreditorContactLog>> saveLog(
    CreditorContactLog log, {
    SharedPreferences? prefs,
    CreditorContactSubmitter? remoteSubmitter,
  }) async {
    if (remoteSubmitter != null) {
      await remoteSubmitter(log);
    }
    final resolved = prefs ?? await SharedPreferences.getInstance();
    final current = await loadLogs(prefs: resolved);
    final updated = <CreditorContactLog>[
      log,
      for (final item in current)
        if (item.id != log.id) item,
    ]..sort((a, b) => b.contactedAt.compareTo(a.contactedAt));
    final encoded = jsonEncode(
      <Map<String, dynamic>>[
        for (final item in updated) item.toJson(),
      ],
    );
    await resolved.setString(prefsKey, encoded);
    return updated;
  }
}
