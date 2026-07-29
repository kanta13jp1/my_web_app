// IQテスト / トレーニングで共有する表示部品。

import 'package:flutter/material.dart';

import '../models/iq_test.dart';
import '../theme/design_tokens.dart';

/// 総合スコアの大きな表示。信頼区間を必ず併記する。
class IqScoreDial extends StatelessWidget {
  final int iq;
  final double percentile;
  final int? lower;
  final int? upper;
  final String label;

  const IqScoreDial({
    super.key,
    required this.iq,
    required this.percentile,
    this.lower,
    this.upper,
    this.label = '推定IQ',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: DesignTokens.space32,
        horizontal: DesignTokens.space20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A2E), Color(0xFF0A1A3E)],
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            '$iq',
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 64,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          if (lower != null && upper != null) ...[
            const SizedBox(height: DesignTokens.space8),
            Text(
              '95%信頼区間  $lower 〜 $upper',
              style: const TextStyle(
                color: DesignTokens.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.space12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space12,
              vertical: DesignTokens.space4,
            ),
            decoration: BoxDecoration(
              color: DesignTokens.indigo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
            ),
            // 実在の規準集団と比べた順位ではなく、仮定した正規分布上の位置。
            // 「上位X%」と言い切ると存在しない比較対象を含意してしまう。
            // さらに信頼区間の幅を考えると小数第1位に意味は無い
            // (IQ110 の CI 内でパーセンタイルは 4%〜66% まで動く) ため
            // 整数の概数で示す。
            child: Text(
              '仮定分布上では上位 ${(100 - percentile).round()}% 前後',
              style: const TextStyle(
                color: DesignTokens.indigoLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 領域別スコアのバー。総合値との関係が一目で分かるようにする。
class IqCategoryBar extends StatelessWidget {
  final IqCategoryScore score;

  /// 比較基準となる総合IQ。null なら基準線を描かない。
  final int? referenceIq;

  /// 学習対象に選ばれている領域か。
  final bool isTarget;

  const IqCategoryBar({
    super.key,
    required this.score,
    this.referenceIq,
    this.isTarget = false,
  });

  /// バー描画のレンジ。偏差IQの実用域に合わせる。
  static const int _minScale = 55;
  static const int _maxScale = 145;

  double _fraction(int iq) =>
      ((iq - _minScale) / (_maxScale - _minScale)).clamp(0.0, 1.0);

  Color get _barColor {
    if (referenceIq == null) return DesignTokens.indigo;
    if (score.iq <= referenceIq! - 5) return DesignTokens.orange;
    if (score.iq >= referenceIq! + 5) return DesignTokens.green;
    return DesignTokens.indigo;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      score.category.labelJa,
                      style: const TextStyle(
                        color: DesignTokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isTarget) ...[
                      const SizedBox(width: DesignTokens.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space8,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: DesignTokens.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusSmall,
                          ),
                        ),
                        child: const Text(
                          '学習対象',
                          style: TextStyle(
                            color: DesignTokens.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${score.iq}',
                style: TextStyle(
                  color: _barColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: DesignTokens.surface3,
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusCircle),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _fraction(score.iq),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _barColor,
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusCircle),
                        ),
                      ),
                    ),
                    // 総合IQの基準線
                    if (referenceIq != null)
                      Positioned(
                        left: (_fraction(referenceIq!) * width)
                            .clamp(0.0, width - 2),
                        child: Container(
                          width: 2,
                          height: 10,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: DesignTokens.space4),
          Text(
            '正答 ${score.correctCount}/${score.questionCount}'
            '  ・  推定幅 ${score.iqLower}〜${score.iqUpper}',
            style: const TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 推定値の性質を明示する注意書き。結果を見せる画面には必ず置く。
class IqDisclaimerCard extends StatelessWidget {
  const IqDisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: DesignTokens.textSecondary,
            size: 18,
          ),
          SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Text(
              'この数値は25問の簡易推定です。標準化された規準集団にもとづく検査ではないため、'
              '医学的・診断的な指標としては使えません。\n'
              '同じ問題を再受験すると練習効果で高く出ます。'
              '重要なのは絶対値ではなく、領域ごとの凸凹と、その推移です。',
              style: TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
