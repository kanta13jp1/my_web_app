import 'package:flutter/material.dart';

import '../services/asset_recurring_transaction_detector.dart';
import 'recurring_fixed_cost_card.dart';

/// 定期取引の自動検出カード。
///
/// 純関数 [AssetRecurringTransactionDetector] が検出した
/// [DetectedRecurringTransaction] 列を受け取り、「毎月◯日頃に約◯円」の
/// 繰り返し支出を一覧表示する。各行の「固定費に登録」ボタンで [onRegister] を呼び、
/// part 299 の固定費登録ダイアログへ pre-fill する。ページ状態に依存しないため
/// ウィジェットテストで単体検証できる。検出ゼロなら `SizedBox.shrink()`。
class AssetRecurringTransactionSuggestionCard extends StatelessWidget {
  const AssetRecurringTransactionSuggestionCard({
    super.key,
    required this.suggestions,
    required this.onRegister,
    required this.onIgnore,
    this.currencyFormatter,
  });

  final List<DetectedRecurringTransaction> suggestions;

  /// 「固定費に登録」押下時のコールバック。
  final void Function(DetectedRecurringTransaction detected) onRegister;

  /// 「無視」押下時のコールバック(検出結果から除外して永続化する)。
  final void Function(DetectedRecurringTransaction detected) onIgnore;

  /// 金額整形(ページの `_formatYen` を渡す)。null なら簡易整形。
  final String Function(double value)? currencyFormatter;

  static const Color _accent = Color(0xFF4F46E5);
  static const Color _high = Color(0xFF059669);
  static const Color _medium = Color(0xFFD97706);
  static const Color _muted = Color(0xFF6B7280);

  String _yen(int value) {
    final formatter = currencyFormatter;
    if (formatter != null) {
      return formatter(value.toDouble());
    }
    return '¥$value';
  }

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      key: const Key('asset_recurring_transaction_suggestion_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.autorenew, color: _accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '定期取引の自動検出',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '過去の支出から繰り返しを検出しました。固定費に登録すると将来予測に反映されます。',
              style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < suggestions.length; i++)
              _buildSuggestionRow(suggestions[i], i),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionRow(DetectedRecurringTransaction detected, int index) {
    final isHigh = detected.confidence == RecurringTransactionConfidence.high;
    final confidenceLabel = isHigh ? '確度 高' : '確度 中';
    final confidenceColor = isHigh ? _high : _medium;
    final scheduleLabel =
        '${RecurringFixedCostCard.cadenceLabel(detected.cadence)}'
        '${detected.typicalPaymentDay}日頃';
    final summary = '${detected.label}、$scheduleLabel、約'
        '${_yen(detected.typicalAmount)}、$confidenceLabel、'
        '直近${detected.monthsObserved}ヶ月分を検出';
    return Padding(
      key: Key('asset_recurring_suggestion_$index'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 情報部分は 1 ノードへまとめて読み上げる。操作ボタンは別ノードに分離。
          Semantics(
            container: true,
            label: summary,
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          detected.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        scheduleLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '約${_yen(detected.typicalAmount)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: confidenceColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          confidenceLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: confidenceColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '直近${detected.monthsObserved}ヶ月分',
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: Key('asset_recurring_suggestion_ignore_$index'),
                onPressed: () => onIgnore(detected),
                style: TextButton.styleFrom(foregroundColor: _muted),
                child: const Text('無視'),
              ),
              const SizedBox(width: 4),
              TextButton(
                key: Key('asset_recurring_suggestion_register_$index'),
                onPressed: () => onRegister(detected),
                child: const Text('固定費に登録'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
