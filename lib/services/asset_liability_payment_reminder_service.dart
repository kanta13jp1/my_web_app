import '../models/asset_liability_workbook.dart';

enum AssetLiabilityPaymentReminderStatus { overdue, dueToday, dueTomorrow }

class AssetLiabilityPaymentReminderCandidate {
  final AssetLiabilityCashflowRow cashflowRow;
  final AssetLiabilityPaymentReminderStatus status;
  final int daysUntilDue;
  final bool hasShortageRisk;
  final String title;
  final String detail;

  const AssetLiabilityPaymentReminderCandidate({
    required this.cashflowRow,
    required this.status,
    required this.daysUntilDue,
    required this.hasShortageRisk,
    required this.title,
    required this.detail,
  });
}

class AssetLiabilityPaymentReminderService {
  const AssetLiabilityPaymentReminderService();

  List<AssetLiabilityPaymentReminderCandidate> buildCandidates({
    required AssetLiabilityWorkbook workbook,
    required DateTime now,
    int lookAheadDays = 1,
  }) {
    final today = _dateOnly(now);
    final candidates = <AssetLiabilityPaymentReminderCandidate>[];

    for (final row in workbook.cashflowRows) {
      if (!row.isPayment ||
          !row.isDirectCashflowTarget ||
          row.paid ||
          row.paymentAmount <= 0) {
        continue;
      }

      final paymentDate = _dateOnly(row.paymentDate);
      final daysUntilDue = paymentDate.difference(today).inDays;
      if (daysUntilDue > lookAheadDays) {
        continue;
      }

      final status = _statusFor(daysUntilDue);
      final hasShortageRisk = row.cashAfterPayment < 0 ||
          row.riskLevel == AssetLiabilityCashRiskLevel.short;
      candidates.add(
        AssetLiabilityPaymentReminderCandidate(
          cashflowRow: row,
          status: status,
          daysUntilDue: daysUntilDue,
          hasShortageRisk: hasShortageRisk,
          title: _titleFor(row, status),
          detail: _detailFor(row, status, hasShortageRisk),
        ),
      );
    }

    candidates.sort((a, b) {
      final date = a.cashflowRow.paymentDate.compareTo(
        b.cashflowRow.paymentDate,
      );
      if (date != 0) {
        return date;
      }
      final amount = b.cashflowRow.paymentAmount.compareTo(
        a.cashflowRow.paymentAmount,
      );
      if (amount != 0) {
        return amount;
      }
      return a.cashflowRow.accountName.compareTo(b.cashflowRow.accountName);
    });
    return candidates;
  }

  AssetLiabilityPaymentReminderStatus _statusFor(int daysUntilDue) {
    if (daysUntilDue < 0) {
      return AssetLiabilityPaymentReminderStatus.overdue;
    }
    if (daysUntilDue == 0) {
      return AssetLiabilityPaymentReminderStatus.dueToday;
    }
    return AssetLiabilityPaymentReminderStatus.dueTomorrow;
  }

  String _titleFor(
    AssetLiabilityCashflowRow row,
    AssetLiabilityPaymentReminderStatus status,
  ) {
    final prefix = switch (status) {
      AssetLiabilityPaymentReminderStatus.overdue => '期限超過',
      AssetLiabilityPaymentReminderStatus.dueToday => '本日支払日',
      AssetLiabilityPaymentReminderStatus.dueTomorrow => '明日支払日',
    };
    return '$prefix: ${row.accountName}';
  }

  String _detailFor(
    AssetLiabilityCashflowRow row,
    AssetLiabilityPaymentReminderStatus status,
    bool hasShortageRisk,
  ) {
    final statusDetail = switch (status) {
      AssetLiabilityPaymentReminderStatus.overdue => '支払日を過ぎた未払いです。',
      AssetLiabilityPaymentReminderStatus.dueToday => '今日中に支払い確認が必要です。',
      AssetLiabilityPaymentReminderStatus.dueTomorrow => '明日の支払い準備を確認してください。',
    };
    final source = row.paymentSourceAccountName == null
        ? '支払元口座未設定'
        : '支払元: ${row.paymentSourceAccountName}';
    final shortage = hasShortageRisk ? ' 支払後の手元資金が不足する見込みです。' : '';
    return '$statusDetail $source。$shortage'.trim();
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
