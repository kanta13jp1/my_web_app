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

/// R27: 鮮度が閾値(既定3日)を超えたときだけ返る警告文。従来は unlocked に
/// なった時点で cron 停止系の警告経路が消え、「最新サンプル: 3日前」が灰色
/// フッターに埋もれて計測停止に気づけなかった。createdAt は投稿時刻なので
/// 「投稿が止まった」「計測 cron が止まった」のどちらも有り得る旨を両論併記
/// する(どちらか断定はデータ上できない)。
String? xGrowthLoopStalenessWarning({
  required int measuredCount,
  required DateTime? newestMeasuredAt,
  required DateTime now,
  int staleAfterDays = 3,
}) {
  if (measuredCount <= 0 || newestMeasuredAt == null) return null;
  final diff = now.difference(newestMeasuredAt);
  if (diff.isNegative || diff.inDays < staleAfterDays) return null;
  return '計測サンプルが${diff.inDays}日間増えていません。投稿が止まっているか、'
      'metrics 収集 cron / spend-cap を確認してください。';
}

/// 畳み込み済み variant 実測。edge の x_best_variant.ts FoldedVariant と対の
/// クライアント表現。
class FoldedVariant {
  final String variant;
  final int averageScore;
  final int count;

  const FoldedVariant({
    required this.variant,
    required this.averageScore,
    required this.count,
  });
}

/// R28: variants(各 {variant, averageScore, count})を unknown 除外 + `_fallback`
/// を base へ畳んで再集計する。edge の x_best_variant.ts foldVariants と同じ戦略
/// 同一視。クライアントには totalScore が無いため averageScore*count で近似
/// (edge は exact totalScore を持つ)。平均降順・同点は件数降順。
List<FoldedVariant> foldVariantsForDisplay(List<dynamic>? variants) {
  if (variants == null) return const [];
  final totals = <String, num>{};
  final counts = <String, int>{};
  for (final entry in variants) {
    if (entry is! Map) continue;
    var name = (entry['variant'] ?? '').toString().trim();
    if (name.isEmpty || name == 'unknown') continue;
    if (name.endsWith('_fallback')) {
      name = name.substring(0, name.length - '_fallback'.length);
    }
    if (name.isEmpty) continue;
    final count = _toIntSignal(entry['count']);
    final effectiveCount = count <= 0 ? 1 : count;
    final avg = _toIntSignal(entry['averageScore']);
    totals[name] = (totals[name] ?? 0) + avg * effectiveCount;
    counts[name] = (counts[name] ?? 0) + effectiveCount;
  }
  final folded = counts.keys
      .map(
        (name) => FoldedVariant(
          variant: name,
          averageScore: (totals[name]! / counts[name]!).round(),
          count: counts[name]!,
        ),
      )
      .toList()
    ..sort((a, b) {
      final byAvg = b.averageScore.compareTo(a.averageScore);
      if (byAvg != 0) return byAvg;
      return b.count.compareTo(a.count);
    });
  return folded;
}

int _toIntSignal(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// R28: 勝ち型は畳み込み後 count>=minSample の最上位のみ。n=1 の外れ値や
/// `_fallback` 単独 (part338 で unknown 除外を入れた副作用で 1 サンプルの
/// daily_briefing_fallback が n=7 の daily_briefing を抑えて昇格していた) を
/// 勝ち型に断定しない。該当が無ければ null(勝ち型行を出さない)。第1引数
/// bestVariant はサーバ計算値だが、畳み込み前の生値なので信用せず variants
/// から再判定する(古いレスポンス/キャッシュにも安全側)。
String? resolveDisplayBestVariant(
  String? bestVariant,
  List<dynamic>? variants, {
  int minSample = 2,
}) {
  for (final folded in foldVariantsForDisplay(variants)) {
    if (folded.count >= minSample) return folded.variant;
  }
  return null;
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

// R25: R23 の内容アーキタイプ別実測(Archetype lift)を X成長ループ panel へ
// 露出する純ロジック。perf-context rows の正規化済み I72h impressions
// 同士だけで型別平均を出す。n>=2 のみ「実測」とみなし、n<2 は実測不足として
// 勝ち型を主張しない。累積の歴史ベンチマークは比較母集団へ混ぜない
// (edge の buildArchetypeLiftLine と同じ閾値)。旧ログ(archetype 欠落)は
// unknown として保持しデータを捨てない。
// 注: 初版(#3965 の xGrowthArchetypeLiftLine)は edge の実バケット値
// news_briefing を news_summary と誤記しニュース要約行が全て「不明」へ落ちる
// R19 型の契約バグがあり、この実装で置き換えた。

/// アーキタイプ意味値 → 表示ラベル。キー集合は edge の正本
/// supabase/functions/growth-hub/x_post_archetype.ts の ArchetypeBucket と
/// 同期を保つこと(新バケット追加時はここへ日本語ラベルも足す。欠けると
/// panel には raw キーがそのまま出る)。
const Map<String, String> kArchetypeLiftLabels = <String, String>{
  'data_report': 'データレポート型',
  'news_briefing': 'ニュース要約型',
  'product_promo': '製品紹介型',
  'general': 'その他',
  'unknown': '分類前(旧ログ)',
};

class ArchetypeLiftEntry {
  final String archetype;
  final int averageImpressions;
  final int count;
  final int pendingCount;

  const ArchetypeLiftEntry({
    required this.archetype,
    required this.averageImpressions,
    required this.count,
    this.pendingCount = 0,
  });

  /// n>=2 のときだけ平均を実測として扱う(1件平均は勝ち型に見せない)。
  bool get measured => count >= 2;

  String get label => kArchetypeLiftLabels[archetype] ?? archetype;
}

/// perf-context rows から型別の平均 impressions を集計する。実測(n>=2)を平均降順で
/// 先に、実測不足を後に並べ、unknown は常に最後(分類前の旧ログが勝ち型の
/// 位置に見えないように)。
List<ArchetypeLiftEntry> resolveArchetypeLift(List<dynamic>? rows) {
  if (rows == null) return const [];
  final totals = <String, double>{};
  final counts = <String, int>{};
  final pendingCounts = <String, int>{};
  for (final row in rows) {
    if (row is! Map) continue;
    if (row['learningCohort'] == 'historical_benchmark') continue;
    var key = (row['archetype'] ?? '').toString().trim();
    if (key.isEmpty) key = 'unknown';
    final rawImpressions = row['i72h'];
    final impressions = rawImpressions is num
        ? rawImpressions.toDouble()
        : double.tryParse('$rawImpressions');
    final mature =
        impressions != null && impressions.isFinite && impressions >= 0;
    if (!mature) {
      pendingCounts[key] = (pendingCounts[key] ?? 0) + 1;
      continue;
    }
    totals[key] = (totals[key] ?? 0) + impressions;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final keys = <String>{...counts.keys, ...pendingCounts.keys};
  final entries = keys
      .map(
        (key) => ArchetypeLiftEntry(
          archetype: key,
          averageImpressions:
              counts[key] == null ? 0 : (totals[key]! / counts[key]!).round(),
          count: counts[key] ?? 0,
          pendingCount: pendingCounts[key] ?? 0,
        ),
      )
      .toList();
  int rank(ArchetypeLiftEntry e) {
    if (e.archetype == 'unknown') return 2;
    return e.measured ? 0 : 1;
  }

  entries.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return b.averageImpressions.compareTo(a.averageImpressions);
  });
  return entries;
}

/// 実測バケットが2種以上あるときだけ勝ちアーキタイプを返す(1種では比較に
/// ならないため null = 勝ち型を主張しない)。
ArchetypeLiftEntry? archetypeLiftWinner(List<ArchetypeLiftEntry> entries) {
  final measured =
      entries.where((e) => e.measured && e.archetype != 'unknown').toList();
  if (measured.length < 2) return null;
  if (measured[0].averageImpressions <= measured[1].averageImpressions) {
    return null;
  }
  return measured.first;
}

/// panel 表示用の1行サマリ。空データは null(行自体を出さない)。
String? archetypeLiftSummaryLine(List<ArchetypeLiftEntry> entries) {
  if (entries.isEmpty) return null;
  final parts = entries.map((e) {
    final pending = e.pendingCount > 0 ? '・計測中${e.pendingCount}件' : '';
    if (e.measured) {
      return '${e.label} 平均${e.averageImpressions} imp (${e.count}件$pending)';
    }
    // R28: 実測 0 件のバケット(全て計測中)は「実測不足 (0件・計測中N件)」だと
    // 「0件」が二重に不自然。計測中のみ簡潔に出す。
    if (e.count == 0) {
      return '${e.label} 計測中${e.pendingCount}件';
    }
    return '${e.label} 実測不足 (${e.count}件$pending)';
  });
  return '型別実測（投稿72時間後・imp）: ${parts.join(' / ')}';
}

// R29: error_reporter が hub_data へ無言で送っている caught error
// (auto_error_report) を /admin で可視化するカードの純ロジック。edge の
// admin-hub errors.recent が {id, message, firstLine, createdAt} を返す。

class AutoErrorReportEntry {
  final String id;
  final String firstLine;
  final String createdAt;

  const AutoErrorReportEntry({
    required this.id,
    required this.firstLine,
    required this.createdAt,
  });
}

const String _autoErrorHeader = '[自動エラー報告]';

/// message から表示用の先頭意味行を抽出する (edge の extractAutoErrorFirstLine
/// と同じ規律)。firstLine が edge から来ていればそれを優先し、無ければ message
/// から復元する (後方互換・防御)。
String autoErrorPreviewLine(Map<String, dynamic> row) {
  final firstLine = (row['firstLine'] ?? '').toString().trim();
  if (firstLine.isNotEmpty) return firstLine;
  final message = (row['message'] ?? '').toString();
  final lines = message
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final meaningful = lines.firstWhere(
    (line) => line != _autoErrorHeader,
    orElse: () => '',
  );
  return meaningful.length > 140
      ? '${meaningful.substring(0, 138)}…'
      : meaningful;
}

/// errors.recent のレスポンス行を表示用エントリへ写像する。
List<AutoErrorReportEntry> parseAutoErrorReports(dynamic rawErrors) {
  if (rawErrors is! List) return const [];
  final entries = <AutoErrorReportEntry>[];
  for (final row in rawErrors) {
    if (row is! Map) continue;
    final map = Map<String, dynamic>.from(row);
    entries.add(
      AutoErrorReportEntry(
        id: (map['id'] ?? '').toString(),
        firstLine: autoErrorPreviewLine(map),
        createdAt: (map['createdAt'] ?? map['created_at'] ?? '').toString(),
      ),
    );
  }
  return entries;
}

/// カードのヘッダラベル。0件は「異常なし」を明示し、誤って警戒させない。
String autoErrorReportsHealthLabel(int count) {
  if (count <= 0) return '自動エラー報告なし（正常）';
  return '自動エラー報告 $count件';
}

// R30: 成長実績サマリーカードは growth-hub `achievement.list` を呼ぶが、この
// action は {success, items:[]} を返すだけで newUsers/totalUsersEver/
// acquisitionSignals/referralsCompleted/importPreviews を一切返さない。カードは
// それらのキーを `?? 0` で読むため、実データがあっても常に「0人/0件」を捏造表示
// していた。集計 action が未実装なので、期待キーが無いレスポンスを「集計未接続」
// として扱い、捏造ゼロを出さないためのガード。
bool growthSummaryHasMetrics(Map<String, dynamic>? summary) {
  if (summary == null) return false;
  const metricKeys = [
    'newUsers',
    'totalUsersEver',
    'acquisitionSignals',
    'referralsCompleted',
    'importPreviews',
  ];
  return metricKeys.any(summary.containsKey);
}
