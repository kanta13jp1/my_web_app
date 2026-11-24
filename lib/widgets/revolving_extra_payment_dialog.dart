import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_revolving_extra_payment_simulator.dart';

/// リボ払い負債の「毎月の上乗せ額」を動かして完済期間・総利息の変化を見る
/// 簡易シミュレーター (概算・クライアント完結)。
class RevolvingExtraPaymentDialog extends StatefulWidget {
  final AssetLiabilityDebtRow row;

  const RevolvingExtraPaymentDialog({super.key, required this.row});

  static Future<void> show(BuildContext context, AssetLiabilityDebtRow row) {
    return showDialog<void>(
      context: context,
      builder: (_) => RevolvingExtraPaymentDialog(row: row),
    );
  }

  @override
  State<RevolvingExtraPaymentDialog> createState() =>
      _RevolvingExtraPaymentDialogState();
}

class _RevolvingExtraPaymentDialogState
    extends State<RevolvingExtraPaymentDialog> {
  static const double _maxExtra = 100000;
  late final TextEditingController _controller;
  double _extra = 5000;
  bool _isLumpSum = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _extra.round().toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setExtra(double value, {bool syncText = true}) {
    setState(() => _extra = value.clamp(0, double.infinity).toDouble());
    if (syncText) _controller.text = _extra.round().toString();
  }

  static String _yen(num value) {
    final digits = value.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}$buf円';
  }

  static String _months(int? months) =>
      months == null ? '完済見込みなし' : '約$monthsヶ月';

  @override
  Widget build(BuildContext context) {
    final result = _isLumpSum
        ? AssetRevolvingExtraPaymentSimulator.simulateLumpSum(
            row: widget.row,
            lumpSumAmount: _extra,
          )
        : AssetRevolvingExtraPaymentSimulator.simulate(
            row: widget.row,
            extraPayment: _extra,
          );
    final saved = result.monthsSaved;
    final interestSaved = result.interestSaved;
    final String summary;
    if (result.becomesPayable) {
      summary = _isLumpSum ? '繰り上げ返済すると完済できる見込みになります。' : '上乗せすると完済できる見込みになります。';
    } else if (saved != null && saved > 0 && interestSaved != null) {
      summary = '完済が$savedヶ月早まり、利息を約${_yen(interestSaved)}減らせます。';
    } else {
      summary = _isLumpSum ? '繰り上げ返済額を入力すると変化を表示します。' : '上乗せ額を入力すると変化を表示します。';
    }
    final sliderMax =
        _isLumpSum ? max(_maxExtra, widget.row.balance.abs()) : _maxExtra;
    final isHighRate = widget.row.annualRate >=
        AssetRevolvingExtraPaymentSimulator.highInterestAnnualRateThreshold;
    final showComparisonBar = result.baseline.everPaysOff &&
        result.boosted.everPaysOff &&
        result.baseline.totalInterest > 0;
    final boostedInterestRatio = showComparisonBar
        ? (result.boosted.totalInterest / result.baseline.totalInterest)
            .clamp(0.0, 1.0)
        : 1.0;

    return AlertDialog(
      title: Text('${widget.row.name} 返済シミュレーション'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isHighRate) ...[
              Container(
                key: const Key('revolving_extra_payment_high_rate_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  '年利 ${(widget.row.annualRate * 100).toStringAsFixed(1)}%・高金利優先',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              '残高 ${_yen(widget.row.balance.abs())} / '
              '現在の月返済 ${_yen(widget.row.scheduledPaymentAmount)}',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  key: const Key('extra_payment_mode_monthly'),
                  label: const Text('毎月の上乗せ'),
                  selected: !_isLumpSum,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _isLumpSum = false);
                    }
                  },
                ),
                ChoiceChip(
                  key: const Key('extra_payment_mode_lump_sum'),
                  label: const Text('一括繰り上げ返済'),
                  selected: _isLumpSum,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _isLumpSum = true);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('revolving_extra_payment_input'),
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _isLumpSum ? '一括繰り上げ返済額 (円)' : '毎月の上乗せ額 (円)',
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _setExtra(
                double.tryParse(v.replaceAll(',', '')) ?? 0,
                syncText: false,
              ),
            ),
            Slider(
              value: _extra.clamp(0, sliderMax).toDouble(),
              max: sliderMax,
              divisions: 100,
              onChanged: _setExtra,
            ),
            const SizedBox(height: 8),
            Text(
              '現ペース: ${_months(result.baseline.months)} / '
              '総利息 ${_yen(result.baseline.totalInterest)}',
            ),
            Text(
              '${_isLumpSum ? '繰り上げ後' : '上乗せ後'}: '
              '${_months(result.boosted.months)} / '
              '総利息 ${_yen(result.boosted.totalInterest)}',
            ),
            if (showComparisonBar) ...[
              const SizedBox(height: 8),
              Column(
                key: const Key('revolving_extra_payment_comparison_bar'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '総利息比較',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 8,
                    color: Color(0xFFB91C1C),
                    backgroundColor: Color(0xFFFEE2E2),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: boostedInterestRatio,
                    minHeight: 8,
                    color: const Color(0xFF047857),
                    backgroundColor: const Color(0xFFD1FAE5),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              summary,
              key: const Key('revolving_extra_payment_summary'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '概算です。実際の請求は各カード会社の明細を確認してください。',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
