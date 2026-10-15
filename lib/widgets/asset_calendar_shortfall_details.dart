import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';

/// Read-only evidence for an aggregate cash forecast. This does not confirm an
/// account debit or perform any transfer, borrowing, or paid-state operation.
class AssetCalendarShortfallDetails extends StatelessWidget {
  const AssetCalendarShortfallDetails({
    super.key,
    required this.calendar,
    required this.asOf,
    required this.startingCashBalance,
    this.balanceRecordedAt,
    this.balanceRecordedOn,
    this.onReviewPayments,
  });

  final AssetPaymentCalendarMonth calendar;
  final DateTime asOf;
  final double? startingCashBalance;

  /// Only an explicitly recorded timestamp, never the forecast's calculation
  /// time or midnight manufactured from a date-only balance observation.
  final DateTime? balanceRecordedAt;
  final DateTime? balanceRecordedOn;
  final VoidCallback? onReviewPayments;

  String yen(num value) => NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      ).format(value);

  @override
  Widget build(BuildContext context) {
    final firstDate = calendar.firstShortfallDate;
    if (firstDate == null) return const SizedBox.shrink();
    final firstBalance = calendar.dayFor(firstDate)?.projectedBalance;
    AssetCalendarDaySummary? worst;
    for (final day in calendar.days) {
      final currentWorst = worst?.projectedBalance;
      if (day.projectedBalance != null &&
          (currentWorst == null || day.projectedBalance! < currentWorst)) {
        worst = day;
      }
    }
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final lines = <(DateTime, AssetCalendarEvent)>[
      for (final day in calendar.days)
        if (!day.date.isBefore(today))
          for (final event in day.events)
            if (event.affectsCashProjection &&
                (event.kind == AssetCalendarEventKind.debtPayment ||
                    event.kind == AssetCalendarEventKind.subscription) &&
                (event.amount ?? 0) > 0)
              (day.date, event),
    ];
    final expectedIncome = calendar.days.fold<double>(
      0,
      (sum, day) =>
          sum +
          day.events
              .where((event) =>
                  event.kind == AssetCalendarEventKind.expectedInflow)
              .fold<double>(0, (amount, event) => amount + (event.amount ?? 0)),
    );
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Column(
      key: const Key('asset_calendar_shortfall_details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('現金・預金合計の資金繰り見込み'),
        Text(
          '${DateFormat('M/d').format(firstDate)}の不足見込み: '
          '${firstBalance == null ? '未確認' : yen(-firstBalance)}',
        ),
        if (worst != null)
          Text(
            '期間内の最大不足: ${DateFormat('M/d').format(worst.date)}に'
            '${yen(calendar.shortfallRecoveryAmount)}',
          ),
        Text(
          '試算基準日: ${DateFormat('yyyy/MM/dd').format(asOf)}',
          style: textStyle,
        ),
        Text(
          '起点残高: ${startingCashBalance == null ? '未確認' : yen(startingCashBalance!)}'
          '（現金・預金合計）',
          style: textStyle,
        ),
        Text(
          balanceRecordedAt != null
              ? '残高の記録日時: ${DateFormat('yyyy/MM/dd HH:mm').format(balanceRecordedAt!)}'
              : balanceRecordedOn != null
                  ? '残高記録日: ${DateFormat('yyyy/MM/dd').format(balanceRecordedOn!)}（時刻不明）'
                  : '残高の記録日時: 未確認',
          style: textStyle,
        ),
        Text(
          expectedIncome > 0
              ? 'この見込みには入金予定${yen(expectedIncome)}を含みます（着金未確認）。'
              : 'この見込みに含まれる入金予定はありません。',
          style: textStyle,
        ),
        const Text(
          '登録情報からの試算です。口座別の引落可否は、支払元と最新残高を照合してください。',
        ),
        ExpansionTile(
          key: const Key('asset_calendar_shortfall_payment_evidence'),
          tilePadding: EdgeInsets.zero,
          title: Text('対象の支払い ${lines.length}件と確認事項'),
          children: [
            for (final (date, event) in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${DateFormat('M/d').format(date)} ${event.label} ${yen(event.amount!)}\n'
                    '支払元: ${event.paymentSourceAccountName ?? '未設定・未確認'} / '
                    '${event.billingConfirmed && !event.paymentAmountEstimated ? '確定請求額' : '予定額（未照合）'}',
                    style: textStyle,
                  ),
                ),
              ),
          ],
        ),
        const Text(
          '明細で支払方式・引落日・請求額を確認し、支払元口座の最新残高を照合してください。',
        ),
        if (onReviewPayments != null)
          TextButton.icon(
            key: const Key('asset_calendar_review_shortfall_evidence'),
            onPressed: onReviewPayments,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('支払設定と根拠を確認'),
          ),
      ],
    );
  }
}
