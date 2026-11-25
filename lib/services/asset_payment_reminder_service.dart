import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset_liability_workbook.dart';
import 'asset_late_fee_service.dart';

/// 返済期日リマインダーの状態区分 (#2749)。
enum PaymentReminderStage {
  upcoming,
  dueToday,
  overdue,
}

/// 返済期日リマインダーおよび遅延損害金計算の設定。
class AssetPaymentReminderSettings {
  const AssetPaymentReminderSettings({
    this.enabled = true,
    this.daysBefore = const <int>[3, 1, 0],
    this.pushEnabled = true,
    this.emailDigestEnabled = true,
    this.customLateFeeAnnualRates = const <String, double>{},
  });

  final bool enabled;
  final List<int> daysBefore;
  final bool pushEnabled;
  final bool emailDigestEnabled;
  final Map<String, double> customLateFeeAnnualRates;

  int get maxDaysBefore => daysBefore.isEmpty ? 0 : daysBefore.reduce(max);

  double? customRateFor(String accountId) =>
      customLateFeeAnnualRates[accountId];

  AssetPaymentReminderSettings copyWith({
    bool? enabled,
    List<int>? daysBefore,
    bool? pushEnabled,
    bool? emailDigestEnabled,
    Map<String, double>? customLateFeeAnnualRates,
  }) {
    return AssetPaymentReminderSettings(
      enabled: enabled ?? this.enabled,
      daysBefore: daysBefore ?? this.daysBefore,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailDigestEnabled: emailDigestEnabled ?? this.emailDigestEnabled,
      customLateFeeAnnualRates:
          customLateFeeAnnualRates ?? this.customLateFeeAnnualRates,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'daysBefore': daysBefore,
      'pushEnabled': pushEnabled,
      'emailDigestEnabled': emailDigestEnabled,
      'customLateFeeAnnualRates': customLateFeeAnnualRates,
    };
  }

  static AssetPaymentReminderSettings fromJson(Map<String, dynamic> json) {
    final rawDays = json['daysBefore'];
    final days = <int>[];
    if (rawDays is List) {
      for (final d in rawDays) {
        final parsed = d is num ? d.toInt() : int.tryParse(d.toString());
        if (parsed != null && parsed >= 0 && parsed <= 14) {
          days.add(parsed);
        }
      }
    }
    final rawRates = json['customLateFeeAnnualRates'];
    final rates = <String, double>{};
    if (rawRates is Map) {
      for (final entry in rawRates.entries) {
        final val = entry.value is num
            ? (entry.value as num).toDouble()
            : double.tryParse(entry.value?.toString() ?? '');
        if (val != null && val >= 0) {
          rates[entry.key.toString()] =
              min(val, AssetLateFeeService.maxAnnualRateCeiling);
        }
      }
    }
    return AssetPaymentReminderSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      daysBefore: days.isEmpty ? const <int>[3, 1, 0] : days,
      pushEnabled:
          json['pushEnabled'] is bool ? json['pushEnabled'] as bool : true,
      emailDigestEnabled: json['emailDigestEnabled'] is bool
          ? json['emailDigestEnabled'] as bool
          : true,
      customLateFeeAnnualRates: Map<String, double>.unmodifiable(rates),
    );
  }
}

/// 返済期日リマインダー・遅延損害金詳細1件分。
class AssetPaymentReminderItem {
  const AssetPaymentReminderItem({
    required this.accountId,
    required this.accountName,
    required this.dueDate,
    required this.daysUntilDue,
    required this.stage,
    required this.scheduledPaymentAmount,
    required this.principalBalanceAbs,
    required this.effectiveLateFeeAnnualRate,
    required this.dailyLateFeeAmount,
    required this.overdueDays,
    required this.estimatedLateFeeAmount,
    required this.projectedBalanceWithLateFee,
    required this.deliveryKey,
  });

  final String accountId;
  final String accountName;
  final DateTime dueDate;
  final int daysUntilDue;
  final PaymentReminderStage stage;
  final double scheduledPaymentAmount;
  final double principalBalanceAbs;
  final double effectiveLateFeeAnnualRate;
  final double dailyLateFeeAmount;
  final int overdueDays;
  final double estimatedLateFeeAmount;
  final double projectedBalanceWithLateFee;
  final String deliveryKey;

  String get stageLabel {
    switch (stage) {
      case PaymentReminderStage.upcoming:
        return '期日あと$daysUntilDue日';
      case PaymentReminderStage.dueToday:
        return '本日返済期日';
      case PaymentReminderStage.overdue:
        return '期限超過 $overdueDays日';
    }
  }
}

/// ワークブック全体の返済期日リマインダー計画。
class AssetPaymentReminderSchedule {
  const AssetPaymentReminderSchedule({
    required this.baseDate,
    required this.upcomingItems,
    required this.dueTodayItems,
    required this.overdueItems,
    required this.totalDailyLateFee,
    required this.totalEstimatedLateFee,
    required this.emailDigestSubject,
    required this.emailDigestBody,
  });

  final DateTime baseDate;
  final List<AssetPaymentReminderItem> upcomingItems;
  final List<AssetPaymentReminderItem> dueTodayItems;
  final List<AssetPaymentReminderItem> overdueItems;
  final double totalDailyLateFee;
  final double totalEstimatedLateFee;
  final String emailDigestSubject;
  final String emailDigestBody;

  List<AssetPaymentReminderItem> get actionableItems =>
      <AssetPaymentReminderItem>[
        ...overdueItems,
        ...dueTodayItems,
        ...upcomingItems,
      ];

  bool get hasAny => actionableItems.isNotEmpty;
}

typedef AssetPaymentReminderNotifier = Future<bool> Function(
  AssetPaymentReminderItem item,
);

/// 返済期日リマインダーおよび遅延損害金日割り計算・ガイダンスサービス (#2749)。
class AssetPaymentReminderService {
  const AssetPaymentReminderService._();

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 給料日サイクルに沿った支払期日を解決する。
  static DateTime resolveCycleDueDate({
    required DateTime baseDate,
    required int? salaryDay,
    required int dayOfMonth,
  }) {
    if (salaryDay == null) {
      final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
      return DateTime(
        baseDate.year,
        baseDate.month,
        dayOfMonth.clamp(1, lastDay).toInt(),
      );
    }
    final anchor = salaryDay.clamp(1, 28).toInt();
    final firstMonth = baseDate.day >= anchor
        ? DateTime(baseDate.year, baseDate.month)
        : DateTime(baseDate.year, baseDate.month - 1);
    final monthOffset = dayOfMonth >= anchor ? 0 : 1;
    final targetMonth = DateTime(
      firstMonth.year,
      firstMonth.month + monthOffset,
    );
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    return DateTime(
      targetMonth.year,
      targetMonth.month,
      dayOfMonth.clamp(1, lastDay).toInt(),
    );
  }

  /// 一意なリマインド送信済みキーを生成する。
  static String buildDeliveryKey({
    required String accountId,
    required DateTime dueDate,
    required PaymentReminderStage stage,
    required int daysUntilDue,
  }) {
    final datePart = DateFormat('yyyy-MM-dd').format(dueDate);
    return '$accountId|$datePart|${stage.name}|$daysUntilDue';
  }

  /// ワークブックからリマインド対象と遅延損害金内訳を集計する。
  static AssetPaymentReminderSchedule buildSchedule({
    required AssetLiabilityWorkbook workbook,
    int? salaryDay,
    AssetPaymentReminderSettings settings =
        const AssetPaymentReminderSettings(),
  }) {
    final baseDay = _dateOnly(workbook.baseDate);
    if (!settings.enabled) {
      return AssetPaymentReminderSchedule(
        baseDate: baseDay,
        upcomingItems: const <AssetPaymentReminderItem>[],
        dueTodayItems: const <AssetPaymentReminderItem>[],
        overdueItems: const <AssetPaymentReminderItem>[],
        totalDailyLateFee: 0,
        totalEstimatedLateFee: 0,
        emailDigestSubject: '',
        emailDigestBody: '',
      );
    }

    final upcoming = <AssetPaymentReminderItem>[];
    final dueToday = <AssetPaymentReminderItem>[];
    final overdue = <AssetPaymentReminderItem>[];
    var totalDaily = 0.0;
    var totalAccumulated = 0.0;

    final maxAhead = settings.maxDaysBefore;
    final dayTriggers = settings.daysBefore.toSet();

    for (final row in workbook.debtMasterRows) {
      if (row.paid ||
          !row.requiresAction ||
          !row.isDirectCashflowTarget ||
          row.scheduledPaymentAmount <= 0) {
        continue;
      }
      final pDay = row.paymentDay;
      if (pDay == null) {
        continue;
      }
      DateTime? riskDueDate;
      if (salaryDay == null) {
        for (final risk in workbook.paymentDayRisks) {
          if (risk.paymentDay == pDay &&
              risk.requiresAction == row.requiresAction) {
            riskDueDate = _dateOnly(risk.paymentDate);
            break;
          }
        }
      }
      final dueDate = riskDueDate ??
          resolveCycleDueDate(
            baseDate: workbook.baseDate,
            salaryDay: salaryDay,
            dayOfMonth: pDay,
          );
      final daysUntilDue = dueDate.difference(baseDay).inDays;

      final configuredRate = settings.customRateFor(row.id) ??
          row.lateFeeAnnualRate ??
          AssetLateFeeService.defaultLateFeeAnnualRate(
            kind: row.kind,
            annualRate: row.annualRate,
          );
      final cappedRate = min(
        max(0.0, configuredRate),
        AssetLateFeeService.maxAnnualRateCeiling,
      );
      final dailyFee = row.scheduledPaymentAmount * cappedRate / 365.0;

      if (daysUntilDue < 0) {
        final calc = AssetLateFeeService.estimate(
          kind: row.kind,
          annualRate: row.annualRate,
          balance: row.balance,
          scheduledPaymentAmount: row.scheduledPaymentAmount,
          paid: row.paid,
          requiresAction: row.requiresAction,
          isDirectCashflowTarget: row.isDirectCashflowTarget,
          baseDate: workbook.baseDate,
          paymentDate: dueDate,
          customLateFeeAnnualRate: cappedRate,
        );
        totalDaily += dailyFee;
        totalAccumulated += calc.estimatedLateFeeAmount;
        overdue.add(
          AssetPaymentReminderItem(
            accountId: row.id,
            accountName: row.name,
            dueDate: dueDate,
            daysUntilDue: daysUntilDue,
            stage: PaymentReminderStage.overdue,
            scheduledPaymentAmount: row.scheduledPaymentAmount,
            principalBalanceAbs: row.balance.abs(),
            effectiveLateFeeAnnualRate: cappedRate,
            dailyLateFeeAmount: dailyFee,
            overdueDays: calc.overdueDays,
            estimatedLateFeeAmount: calc.estimatedLateFeeAmount,
            projectedBalanceWithLateFee: calc.projectedBalanceWithLateFee,
            deliveryKey: buildDeliveryKey(
              accountId: row.id,
              dueDate: dueDate,
              stage: PaymentReminderStage.overdue,
              daysUntilDue: daysUntilDue,
            ),
          ),
        );
      } else if (daysUntilDue == 0 &&
          (dayTriggers.isEmpty || dayTriggers.contains(0))) {
        dueToday.add(
          AssetPaymentReminderItem(
            accountId: row.id,
            accountName: row.name,
            dueDate: dueDate,
            daysUntilDue: 0,
            stage: PaymentReminderStage.dueToday,
            scheduledPaymentAmount: row.scheduledPaymentAmount,
            principalBalanceAbs: row.balance.abs(),
            effectiveLateFeeAnnualRate: cappedRate,
            dailyLateFeeAmount: dailyFee,
            overdueDays: 0,
            estimatedLateFeeAmount: 0,
            projectedBalanceWithLateFee: row.balance.abs(),
            deliveryKey: buildDeliveryKey(
              accountId: row.id,
              dueDate: dueDate,
              stage: PaymentReminderStage.dueToday,
              daysUntilDue: 0,
            ),
          ),
        );
      } else if (daysUntilDue > 0 && daysUntilDue <= maxAhead) {
        upcoming.add(
          AssetPaymentReminderItem(
            accountId: row.id,
            accountName: row.name,
            dueDate: dueDate,
            daysUntilDue: daysUntilDue,
            stage: PaymentReminderStage.upcoming,
            scheduledPaymentAmount: row.scheduledPaymentAmount,
            principalBalanceAbs: row.balance.abs(),
            effectiveLateFeeAnnualRate: cappedRate,
            dailyLateFeeAmount: dailyFee,
            overdueDays: 0,
            estimatedLateFeeAmount: 0,
            projectedBalanceWithLateFee: row.balance.abs(),
            deliveryKey: buildDeliveryKey(
              accountId: row.id,
              dueDate: dueDate,
              stage: PaymentReminderStage.upcoming,
              daysUntilDue: daysUntilDue,
            ),
          ),
        );
      }
    }

    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    dueToday.sort((a, b) => a.accountName.compareTo(b.accountName));
    overdue.sort(
      (a, b) => b.estimatedLateFeeAmount.compareTo(a.estimatedLateFeeAmount),
    );

    final digest = _buildEmailDigest(
      baseDay: baseDay,
      upcoming: upcoming,
      dueToday: dueToday,
      overdue: overdue,
      totalEstimatedLateFee: totalAccumulated,
    );

    return AssetPaymentReminderSchedule(
      baseDate: baseDay,
      upcomingItems: List<AssetPaymentReminderItem>.unmodifiable(upcoming),
      dueTodayItems: List<AssetPaymentReminderItem>.unmodifiable(dueToday),
      overdueItems: List<AssetPaymentReminderItem>.unmodifiable(overdue),
      totalDailyLateFee: totalDaily,
      totalEstimatedLateFee: totalAccumulated,
      emailDigestSubject: digest.subject,
      emailDigestBody: digest.body,
    );
  }

  /// 未送信のリマインダーのみを通知コールバックへ配送する（重複送信防止）。
  static Future<Set<String>> dispatchUndelivered({
    required AssetPaymentReminderSchedule schedule,
    required Set<String> alreadyDeliveredKeys,
    required AssetPaymentReminderNotifier notifier,
  }) async {
    final newlyDelivered = <String>{};
    for (final item in schedule.actionableItems) {
      if (alreadyDeliveredKeys.contains(item.deliveryKey)) {
        continue;
      }
      final ok = await notifier(item);
      if (ok) {
        newlyDelivered.add(item.deliveryKey);
      }
    }
    return Set<String>.unmodifiable(newlyDelivered);
  }

  static _EmailDigest _buildEmailDigest({
    required DateTime baseDay,
    required List<AssetPaymentReminderItem> upcoming,
    required List<AssetPaymentReminderItem> dueToday,
    required List<AssetPaymentReminderItem> overdue,
    required double totalEstimatedLateFee,
  }) {
    final dateLabel = DateFormat('yyyy/MM/dd').format(baseDay);
    final yen = NumberFormat('#,##0', 'ja_JP');
    final subject = overdue.isNotEmpty
        ? '[$dateLabel] 返済期日超過アラート (${overdue.length}件) / 予定リマインダー'
        : '[$dateLabel] 返済期日リマインダー (${dueToday.length + upcoming.length}件)';

    final buf = StringBuffer()
      ..writeln('【返済期日・遅延損害金レポート ($dateLabel)】')
      ..writeln();

    if (overdue.isNotEmpty) {
      buf.writeln(
        '■ 期限超過 (${overdue.length}件 / 延滞損害金概算合計: +¥${yen.format(totalEstimatedLateFee.round())})',
      );
      for (final item in overdue) {
        final ratePct =
            (item.effectiveLateFeeAnnualRate * 100).toStringAsFixed(1);
        buf.writeln(
          '- ${item.accountName}: 期日 ${DateFormat('M/d').format(item.dueDate)} '
          '(${item.overdueDays}日超過 / 年利$ratePct%) '
          '予定額 ¥${yen.format(item.scheduledPaymentAmount.round())} / '
          '増加額 +¥${yen.format(item.estimatedLateFeeAmount.round())} '
          '(1日あたり約+¥${yen.format(item.dailyLateFeeAmount.round())})',
        );
      }
      buf
        ..writeln('  ※ 遅延発生時は債権者窓口への早期連絡または公的相談窓口の確認をご検討ください。')
        ..writeln();
    }

    if (dueToday.isNotEmpty) {
      buf.writeln('■ 本日返済期日 (${dueToday.length}件)');
      for (final item in dueToday) {
        buf.writeln(
          '- ${item.accountName}: 本日 ${DateFormat('M/d').format(item.dueDate)} / '
          '予定額 ¥${yen.format(item.scheduledPaymentAmount.round())}',
        );
      }
      buf.writeln();
    }

    if (upcoming.isNotEmpty) {
      buf.writeln('■ 数日以内の返済予定 (${upcoming.length}件)');
      for (final item in upcoming) {
        buf.writeln(
          '- ${item.accountName}: あと${item.daysUntilDue}日 '
          '(${DateFormat('M/d').format(item.dueDate)}) / '
          '予定額 ¥${yen.format(item.scheduledPaymentAmount.round())}',
        );
      }
      buf.writeln();
    }

    return _EmailDigest(
      subject: subject,
      body: buf.toString().trim(),
    );
  }
}

class _EmailDigest {
  const _EmailDigest({
    required this.subject,
    required this.body,
  });

  final String subject;
  final String body;
}

/// リマインダー設定および送信済みキーの端末永続化ストア (#2749)。
class AssetPaymentReminderStore {
  const AssetPaymentReminderStore._();

  static const String _settingsPrefsKey = 'asset_payment_reminder_settings_v1';
  static const String _deliveredPrefsKey =
      'asset_payment_reminder_delivered_v1';
  static const int maxDeliveredKeys = 200;

  static Future<AssetPaymentReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsPrefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AssetPaymentReminderSettings();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const AssetPaymentReminderSettings();
      }
      return AssetPaymentReminderSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return const AssetPaymentReminderSettings();
    }
  }

  static Future<void> saveSettings(
    AssetPaymentReminderSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsPrefsKey, jsonEncode(settings.toJson()));
  }

  static Future<Set<String>> loadDeliveredKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deliveredPrefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>{};
      }
      return Set<String>.unmodifiable(decoded.map((e) => e.toString()));
    } catch (_) {
      return const <String>{};
    }
  }

  static Future<void> saveDeliveredKeys(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = keys.length > maxDeliveredKeys
        ? keys.skip(keys.length - maxDeliveredKeys).toList()
        : keys.toList();
    await prefs.setString(_deliveredPrefsKey, jsonEncode(trimmed));
  }
}
