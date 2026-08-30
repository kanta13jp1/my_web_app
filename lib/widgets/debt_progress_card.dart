import 'package:flutter/material.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';

/// 借金返済の月次進捗カード (公開投稿用の画像として書き出される)。
///
/// 🔒 描画するのは [DebtProgressCardData] が持つ項目だけ。
/// 年収・口座残高・借入先名はモデルに存在しないので描画しようがない。
class DebtProgressCard extends StatelessWidget {
  final DebtProgressCardData data;
  final DateTime month;

  /// 画像化したときに読める固定幅。SNS のタイムラインでの視認性を優先する。
  static const double cardWidth = 480;

  const DebtProgressCard({super.key, required this.data, required this.month});

  @override
  Widget build(BuildContext context) {
    final delta = data.monthOverMonthDelta;
    final improving = data.isImproving;
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${month.year}年${month.month}月の返済報告',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '残債',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 2),
          // 桁数が伸びても崩れないよう縮小に逃がす (金額は桁が増えるほど
          // 重要なのに、はみ出して切れると読めなくなる)。
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _yen(data.totalDebt),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (delta != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${delta < 0 ? '−' : '+'}${_yen(delta.abs())}',
                    maxLines: 1,
                    style: TextStyle(
                      // 借金は減る方が良い = 減少を緑にする。増加を緑にすると
                      // 悪化を好調に見せてしまう。
                      color: improving == true
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFF87171),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _row('今月の返済', _yen(data.monthlyPayment)),
          const SizedBox(height: 10),
          _row(
            '完済まで',
            data.payoffLabel == null ? '— (要見直し)' : 'あと${data.payoffLabel}',
            emphasize: data.payoffLabel == null,
          ),
          if (data.estimatedInterest != null) ...[
            const SizedBox(height: 10),
            _row('利息見込み', _yen(data.estimatedInterest!)),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '返済中 ${data.debtCount}件',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
              const Text(
                '自分株式会社',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? const Color(0xFFFBBF24) : Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static String _yen(double value) {
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${rounded < 0 ? '-' : ''}$buffer円';
  }
}
