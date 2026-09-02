// IQ推定のスコアリング。
//
// 重要な前提 (UI にも明示すること):
// ここで出す数値は「簡易推定」であり、標準化サンプルにもとづく規準ではない。
// 換算に使う平均・標準偏差は下記 IqCalibration の仮定値であって、実測の
// 規準集団から得たものではない。臨床的・診断的な用途には使えない。
//
// アルゴリズム:
//   1. 難易度を重みとした重み付き正答率 ability (0..1) を出す
//   2. 仮定した母集団分布 (mean/sd) で z 得点に変換
//   3. 偏差 IQ = 100 + 15z にマップし、レンジでクランプ
//   4. 正規分布 CDF でパーセンタイルを出す

import 'dart:math' as math;

import '../models/iq_test.dart';

/// 換算定数。すべて仮定値であることを明示するため 1 箇所に集約する。
class IqCalibration {
  /// 想定する母集団の重み付き正答率の平均。
  /// 出題バンクを「平均的な受験者が約 55% 取れる」難度に設計した前提。
  static const double populationMeanAbility = 0.55;

  /// 同じく標準偏差の仮定値。
  static const double populationSdAbility = 0.18;

  /// 偏差 IQ の中心と 1SD。
  static const double iqMean = 100;
  static const double iqSd = 15;

  /// 出力レンジ。25問程度の簡易テストでこれ以上の外挿は意味がないため切る。
  ///
  /// 注意: 上記の mean/sd では ability=1.0 (全問正解) でも約 138 にしかならず、
  /// [maxIq] には届かない。これは意図した挙動で、25問では高得点側を細かく
  /// 弁別できないため天井を低めに置いている。[maxIq] は換算定数を将来変更した
  /// ときの安全弁として残している。
  /// 実効レンジは約 55〜138 (下限側は ability=0 で 54 となりクランプが効く)。
  static const int minIq = 55;
  static const int maxIq = 145;

  /// 領域別スコアはさらに設問数が少ないので、より狭くクランプする。
  static const int minCategoryIq = 60;
  static const int maxCategoryIq = 140;
}

class IqScoring {
  const IqScoring._();

  /// 難易度重み。難しい問題の正解ほど能力の証拠として重い。
  static double weightForDifficulty(int difficulty) {
    final d = difficulty.clamp(1, 5);
    return d.toDouble();
  }

  /// 重み付き正答率。回答が空なら 0。
  static double weightedAccuracy(List<IqAnswerRecord> answers) {
    if (answers.isEmpty) return 0;
    double earned = 0;
    double total = 0;
    for (final a in answers) {
      final w = weightForDifficulty(a.difficulty);
      total += w;
      if (a.isCorrect) earned += w;
    }
    if (total == 0) return 0;
    return earned / total;
  }

  /// ability (0..1) → 偏差 IQ。
  static int abilityToIq(
    double ability, {
    int minIq = IqCalibration.minIq,
    int maxIq = IqCalibration.maxIq,
  }) {
    final z = (ability - IqCalibration.populationMeanAbility) /
        IqCalibration.populationSdAbility;
    final raw = IqCalibration.iqMean + IqCalibration.iqSd * z;
    return raw.round().clamp(minIq, maxIq);
  }

  /// 標準正規分布の CDF。Abramowitz & Stegun 7.1.26 の erf 近似を使う。
  static double normalCdf(double z) {
    return 0.5 * (1 + _erf(z / math.sqrt2));
  }

  static double _erf(double x) {
    final sign = x < 0 ? -1.0 : 1.0;
    final ax = x.abs();

    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p = 0.3275911;

    final t = 1.0 / (1.0 + p * ax);
    final y = 1.0 -
        (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) *
            t *
            math.exp(-ax * ax);
    return sign * y;
  }

  /// IQ → パーセンタイル (0..100)。
  static double percentileForIq(int iq) {
    final z = (iq - IqCalibration.iqMean) / IqCalibration.iqSd;
    final p = normalCdf(z) * 100;
    // 0/100 ちょうどは誤解を生むので端を丸めない範囲に留める。
    return p.clamp(0.1, 99.9);
  }

  /// 推定の標準誤差 (IQポイント)。設問数が少ないほど大きくなる。
  ///
  /// 二項比率の標準誤差 sqrt(p(1-p)/n) を ability スケールから IQ スケールへ
  /// 線形変換したもの。少問数の推定を断定的に見せないために使う。
  static double standardError(double ability, int questionCount) {
    if (questionCount <= 0) return IqCalibration.iqSd;
    final p = ability.clamp(0.0, 1.0);
    final seAbility = math.sqrt((p * (1 - p)) / questionCount);
    final seIq =
        seAbility / IqCalibration.populationSdAbility * IqCalibration.iqSd;
    // 下限を設けないと満点/0点で SE=0 になり「誤差ゼロ」に見えてしまう。
    return math.max(seIq, 3.0);
  }

  /// 領域別スコアを算出。
  static List<IqCategoryScore> categoryScores(List<IqAnswerRecord> answers) {
    final byCategory = <IqCategory, List<IqAnswerRecord>>{};
    for (final a in answers) {
      byCategory.putIfAbsent(a.category, () => []).add(a);
    }

    final scores = <IqCategoryScore>[];
    for (final category in IqCategory.values) {
      final items = byCategory[category];
      if (items == null || items.isEmpty) continue;

      final ability = weightedAccuracy(items);
      scores.add(
        IqCategoryScore(
          category: category,
          correctCount: items.where((a) => a.isCorrect).length,
          questionCount: items.length,
          weightedAccuracy: ability,
          iq: abilityToIq(
            ability,
            minIq: IqCalibration.minCategoryIq,
            maxIq: IqCalibration.maxCategoryIq,
          ),
          standardError: standardError(ability, items.length),
        ),
      );
    }
    return scores;
  }

  /// 総合結果を算出する。DB 保存前の純粋計算。
  static IqScoreSummary summarize(List<IqAnswerRecord> answers) {
    final ability = weightedAccuracy(answers);
    final iq = abilityToIq(ability);
    return IqScoreSummary(
      totalIq: iq,
      percentile: percentileForIq(iq),
      weightedAccuracy: ability,
      correctCount: answers.where((a) => a.isCorrect).length,
      questionCount: answers.length,
      // 未回答 (selectedIndex == null) を除いた実際に着手した問題数。
      // これを持たないと「3問だけ解いて時間切れ」と「25問解いて低得点」が
      // 結果上まったく区別できない。
      attemptedCount: answers.where((a) => a.selectedIndex != null).length,
      standardError: standardError(ability, answers.length),
      categoryScores: categoryScores(answers),
    );
  }
}

/// [IqScoring.summarize] の戻り値。DB へ書く前の計算結果。
class IqScoreSummary {
  final int totalIq;
  final double percentile;
  final double weightedAccuracy;
  final int correctCount;
  final int questionCount;

  /// 実際に着手した問題数。[questionCount] との差が未回答数。
  final int attemptedCount;
  final double standardError;
  final List<IqCategoryScore> categoryScores;

  const IqScoreSummary({
    required this.totalIq,
    required this.percentile,
    required this.weightedAccuracy,
    required this.correctCount,
    required this.questionCount,
    required this.attemptedCount,
    required this.standardError,
    required this.categoryScores,
  });

  int get iqLower => (totalIq - 1.96 * standardError).round();
  int get iqUpper => (totalIq + 1.96 * standardError).round();

  /// 完答率 0.0..1.0。
  double get completionRate =>
      questionCount == 0 ? 0 : attemptedCount / questionCount;

  /// スコアを額面どおり読んでよいか。
  ///
  /// 未着手が多い回は「実力が低い」のではなく「測れていない」。
  /// 両者を同じ数値として提示すると利用者は判断を誤る。
  bool get isReliable => completionRate >= 0.9;

  /// 弱点と呼べる領域。
  ///
  /// 固定値ではなく **その領域自身の測定誤差を上回る差** だけを弱点とする。
  /// 5問しかない領域スコアの標準誤差は約 18 IQ あり、旧実装の固定閾値 5 は
  /// 誤差の 0.27 SE にすぎなかった (= ほぼノイズを弱点と呼んでいた)。
  List<IqCategoryScore> weakAreas({double sigmaThreshold = 1.0}) {
    final weak = categoryScores
        .where((s) => (totalIq - s.iq) > sigmaThreshold * s.standardError)
        .toList()
      ..sort((a, b) => a.iq.compareTo(b.iq));
    return weak;
  }
}
