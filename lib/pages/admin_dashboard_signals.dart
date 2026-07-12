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
    var name = (entry['variant'] ?? '').toString().trim();
    if (name.isEmpty || name == 'unknown') continue;
    // R18: `${variant}_fallback`(定型フォールバックの劣化版)は base variant と
    // 同一戦略なので base に畳んで数える。daily_briefing + daily_briefing_fallback
    // を2種と誤認して「勝ち型」を false-unlock しない(実データはまだ1戦略のみ)。
    if (name.endsWith('_fallback')) {
      name = name.substring(0, name.length - '_fallback'.length);
    }
    if (name.isEmpty) continue;
    seen.add(name);
  }
  return seen.length;
}

/// R18: 週次ダイジェストカードの3状態。fetch 完了(loaded)とデータ有無(hasData)を
/// 分離し、静かに失敗/空の週を無限「読み込み中」ではなく正直な「計測待ち」にする。
enum WeeklyDigestCardState { loading, empty, data }

WeeklyDigestCardState weeklyDigestCardState({
  required bool loaded,
  required bool hasData,
}) {
  if (!loaded) return WeeklyDigestCardState.loading;
  return hasData ? WeeklyDigestCardState.data : WeeklyDigestCardState.empty;
}

/// R18: 連続登録ゼロ日が集計窓(30日)を使い切っているか。true のとき値は下限で、
/// 実際はそれ以上の可能性があるため「N日以上」と正直に表示する。
bool streakAtWindowCap(int streak, int windowLen) {
  return streak > 0 && windowLen > 0 && streak >= windowLen;
}

// R19: 登録ユーザー管理カードの契約バグ+捏造を吸収する純ロジック。
// admin-hub users.list は {id, email, created_at(snake)} しか返さないのに、UI は
// camelCase createdAt / 未送出の completionPct・lastSignInAt を読んで「登録日空」
// 「プロフィール 0%」を捏造していた。ここで snake 優先のキー吸収と、email 空を
// Supabase 匿名 auth の信頼プロキシとした実/匿名判定を提供する。

/// email が空 = Supabase 匿名 auth ユーザー(headless 検証用 anon-signup)の信頼
/// プロキシ。実ユーザー(実登録)と匿名テストを区別する。
bool adminUserIsAnonymous(Map<String, dynamic> user) {
  return (user['email'] ?? '').toString().trim().isEmpty;
}

/// 登録日時の生文字列を取り出す。edge の created_at(snake)を優先し、旧 UI が
/// 読んでいた createdAt(camel)へ後方互換フォールバックする(R19 契約バグ修正)。
String adminUserCreatedRaw(Map<String, dynamic> user) {
  final snake = (user['created_at'] ?? '').toString().trim();
  if (snake.isNotEmpty) return snake;
  return (user['createdAt'] ?? '').toString().trim();
}

/// 登録ユーザー一覧を「実ユーザー / 匿名テスト」に分割して数える。捏造の
/// completionPct(全員0)で bucket 化していた旧サマリの置き換え(合計44 vs 実CVR4
/// の乖離=匿名を実ユーザーと誤認する虚栄を防ぐ)。
({int real, int anon}) summarizeAdminUsers(List<Map<String, dynamic>> users) {
  var anon = 0;
  for (final user in users) {
    if (adminUserIsAnonymous(user)) anon += 1;
  }
  return (real: users.length - anon, anon: anon);
}

// R20: X成長ループ panel の鮮度フッター。R17 は鮮度だけ「今日の投稿の計測時刻」
// (_xTodayStatus.lastCollectedAt)を読んでいたため、12件計測済みでも今日未投稿だと
// 「計測待ち」と矛盾表示していた(偽の計測停止アラーム)。パネル自身が描く
// perf-context の行から鮮度を出す。

/// perf-context 行(各 {createdAt}) の中で最も新しい created_at を返す。行は
/// growth-hub 側で score 降順ソート済みなので rows[0] は最新でない → 全行走査で
/// max を取る。パース可能な行が無ければ null。
DateTime? newestMeasuredCreatedAt(List<dynamic>? rows) {
  if (rows == null) return null;
  DateTime? newest;
  for (final row in rows) {
    if (row is! Map) continue;
    final dt = DateTime.tryParse((row['createdAt'] ?? '').toString());
    if (dt == null) continue;
    if (newest == null || dt.isAfter(newest)) newest = dt;
  }
  return newest;
}

/// X成長ループ鮮度ラベル。計測済み(measuredCount>0)なら決して「計測待ち」と
/// 言わない。createdAt は投稿時刻で計測実行時刻ではないためラベルは「最新
/// サンプル」に留め「最終計測」と過剰主張しない。
String resolveXGrowthLoopFreshness({
  required int measuredCount,
  required DateTime? newestMeasuredAt,
  required DateTime now,
}) {
  if (measuredCount <= 0) return '最終計測: 計測待ち';
  if (newestMeasuredAt == null) return '計測済み $measuredCount件';
  final diff = now.difference(newestMeasuredAt);
  if (diff.isNegative) return '計測済み $measuredCount件';
  if (diff.inDays >= 1) return '最新サンプル: ${diff.inDays}日前';
  if (diff.inHours >= 1) return '最新サンプル: ${diff.inHours}時間前';
  return '最新サンプル: 1時間以内';
}

/// R20: 年なし MM/dd は 3か月前の機能リクエストや 2か月前のツール実行ログを
/// 「今月」に見せてしまう。別年、もしくは staleDays(既定30日=1か月超)超は
/// yyyy/MM/dd を返して年齢を明示する(パース不能は raw をそのまま返す)。
String formatAgeAwareDate(String? iso, DateTime now, {int staleDays = 30}) {
  final raw = (iso ?? '').toString();
  final dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return raw;
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final stale = dt.year != now.year || now.difference(dt).inDays > staleDays;
  return stale ? '${dt.year}/$m/$d' : '$m/$d';
}

/// R24: perf-context 行(各 {archetype, score})から「Archetype lift」表示行を作る。
/// #3953 で全投稿に content_archetype が記録され perf-context の rows に載る。
/// n>=1 のバケットを平均スコア降順で並べ、行が1つも無ければ null(非表示)。
/// ラベルは日本語(データレポート/ニュース要約/製品プロモ/不明)。
String? xGrowthArchetypeLiftLine(List<dynamic>? rows) {
  if (rows == null || rows.isEmpty) return null;
  const labels = {
    'data_report': 'データレポート',
    'news_summary': 'ニュース要約',
    'product_promo': '製品プロモ',
  };
  final buckets = <String, List<num>>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final raw = (row['archetype'] ?? '').toString().trim();
    final key = labels.containsKey(raw) ? raw : 'unknown';
    final score = row['score'];
    if (score is! num) continue;
    buckets.putIfAbsent(key, () => []).add(score);
  }
  if (buckets.isEmpty) return null;
  final parts = buckets.entries
      .map(
        (e) => (
          label: labels[e.key] ?? '不明',
          avg: (e.value.reduce((a, b) => a + b) / e.value.length).round(),
          n: e.value.length,
        ),
      )
      .toList()
    ..sort((a, b) => b.avg.compareTo(a.avg));
  final body = parts.map((p) => '${p.label} 平均${p.avg} (n=${p.n})').join(' / ');
  return '型別リフト: $body';
}
