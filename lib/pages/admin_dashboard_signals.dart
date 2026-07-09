// R17: /admin 経営分析ダッシュボードの純ロジック(依存ゼロ・VM テスト可能)。
// admin_analytics_page.dart は supabase/url_launcher 等の web 専用 JS interop を
// 含み VM テストで直接コンパイルできないため、テストしたい判定ロジックだけを
// この依存ゼロのファイルへ切り出す(admin_x_posted_today.dart / edge の
// x_today_status.ts と同じ抽出パターン / part321 の教訓)。

/// 率(%)表示。分母0のときは捏造した「0.0%」ではなく計測不能を表す「—」を返す。
/// ダッシュボードのファネル率セル(_formatRate)と同じ誠実性規律に揃える。
String formatRatePercent(int numerator, int denominator) {
  if (denominator <= 0) return '—';
  return '${(numerator / denominator * 100).toStringAsFixed(1)}%';
}

/// X 成長ループ panel の表示状態。
enum XGrowthLoopState {
  /// 計測データも本日投稿も無い → panel を出さない(空を勝ち型に見せない)。
  hidden,

  /// 本日投稿はあるが計測0件 → metrics cron / spend-cap 確認の警告。
  /// spend-cap で計測が止まった実績があるこのアカウントで最も効く signal。
  awaitingMetrics,

  /// 計測はあるが variant が1種のみ → 学習サンプル蓄積中(勝ち型はまだ)。
  sampling,

  /// variant が2種以上 → 勝ち型の比較を提示できる。
  unlocked,
}

class XGrowthLoop {
  final XGrowthLoopState state;
  final int measuredCount;
  final int distinctVariantCount;

  const XGrowthLoop({
    required this.state,
    required this.measuredCount,
    required this.distinctVariantCount,
  });
}

/// perf-context の計測済み投稿数・variant 種数(unknown 除く)と本日投稿数から、
/// 成長ループ panel の状態を純粋に決める。計測0でも本日投稿があれば
/// awaitingMetrics(cron 警告)、投稿も無ければ hidden。
XGrowthLoop resolveXGrowthLoop({
  required int measuredCount,
  required int distinctVariantCount,
  required int postedTodayCount,
}) {
  if (measuredCount <= 0) {
    return XGrowthLoop(
      state: postedTodayCount > 0
          ? XGrowthLoopState.awaitingMetrics
          : XGrowthLoopState.hidden,
      measuredCount: 0,
      distinctVariantCount: 0,
    );
  }
  return XGrowthLoop(
    state: distinctVariantCount >= 2
        ? XGrowthLoopState.unlocked
        : XGrowthLoopState.sampling,
    measuredCount: measuredCount,
    distinctVariantCount: distinctVariantCount,
  );
}

/// perf-context の variants 配列(各要素 {variant, averageScore, count})から、
/// 比較可能な variant 種数を数える(unknown / 空を除外)。
int distinctMeasuredVariants(List<dynamic>? variants) {
  if (variants == null) return 0;
  final seen = <String>{};
  for (final entry in variants) {
    if (entry is! Map) continue;
    final name = (entry['variant'] ?? '').toString().trim();
    if (name.isEmpty || name == 'unknown') continue;
    seen.add(name);
  }
  return seen.length;
}
