// R26: X投稿候補キュー(トラッカー量産の HITL 承認面)の純ロジック。
//
// 背景: データレポート型の実測が 17.2K(選挙集計) vs 1.2K(要約) vs 40(製品
// 転換)と圧倒的で、量産の生成側は既に揃っている(選挙 diff 候補=日次 cron /
// 家計トラッカー=週次 / X運用実測=週次 / briefing=候補化済み)。一方で候補は
// hub_data(source=x_post_candidate)に status=pending_approval で溜まるのに、
// 承認→投稿の操作面が無く「UUID を手掘りして workflow dispatch」する運用が
// ボトルネックだった。x.candidate.approve が approval_channel="admin_ui" を
// 想定済みなのに UI が存在しない。
//
// このファイルは一覧/承認/投稿/確定の判定ロジックを依存ゼロで提供する
// (admin_dashboard_signals.dart と同じ抽出パターン = VM テスト可能)。
// 無審査の全自動投稿は行わない(Qiita アカウント停止事件の教訓 = 自動化は
// 生成と計測まで、公開の最終判断は人間)。

/// variant → 系列ラベル。系列を増やしたら docs/X_TRACKER_SERIES_PLAYBOOK.md と
/// ここへ追記する(欠けても raw variant がそのまま表示されるだけで壊れない)。
const Map<String, String> kXTrackerSeriesLabels = <String, String>{
  'local_election_tally': '選挙集計(全文)',
  'local_election_tracker': '選挙予定スレ',
  'member_delta_national_progress': '選挙: 議員数増減',
  'scheduled_candidate_delta': '選挙: 公認・候補予定',
  'local_election_schedule_delta': '選挙: 選挙予定更新',
  'weekly_data_report': 'X運用実測',
  'household_tracker': '家計トラッカー',
};

/// variant から系列ラベルを解決する。daily_briefing 系はバリアント名が
/// A/B サフィックスで増えるため前方一致で畳む。未知は variant をそのまま返す
/// (隠すより見せる=新系列の追い漏れに気づける)。
String xTrackerSeriesLabel(String variant) {
  final key = variant.trim();
  if (key.isEmpty) return '(variant未設定)';
  final exact = kXTrackerSeriesLabels[key];
  if (exact != null) return exact;
  if (key.startsWith('daily_briefing')) return 'デイリーブリーフィング';
  return key;
}

/// hub_data 候補行の表示用サマリ。
class XPostCandidateSummary {
  final String id;
  final String status;
  final String candidateType;
  final String variant;
  final String archetype;
  final String text;
  final int replyCount;
  final DateTime? generatedAt;

  const XPostCandidateSummary({
    required this.id,
    required this.status,
    required this.candidateType,
    required this.variant,
    required this.archetype,
    required this.text,
    required this.replyCount,
    required this.generatedAt,
  });

  String get seriesLabel => xTrackerSeriesLabel(variant);

  bool get isPendingApproval => status == 'pending_approval';
}

/// x.candidate.list の応答行([{id, metadata, created_at}])を表示用サマリへ。
/// 壊れた行(id/text 欠落)は捨てる。新しい順に整列。
List<XPostCandidateSummary> parseXPostCandidates(dynamic rows) {
  if (rows is! List) return const [];
  final result = <XPostCandidateSummary>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final id = (row['id'] ?? '').toString().trim();
    final metadata = row['metadata'];
    if (id.isEmpty || metadata is! Map) continue;
    final text = (metadata['text'] ?? '').toString();
    if (text.trim().isEmpty) continue;
    final replyTexts = metadata['reply_texts'];
    final generatedRaw =
        (metadata['generated_at'] ?? row['created_at'] ?? '').toString();
    result.add(
      XPostCandidateSummary(
        id: id,
        status: (metadata['status'] ?? '').toString(),
        candidateType: (metadata['candidate_type'] ?? '').toString(),
        variant: (metadata['variant'] ?? '').toString(),
        archetype: (metadata['content_archetype'] ?? '').toString(),
        text: text,
        replyCount: replyTexts is List ? replyTexts.length : 0,
        generatedAt: DateTime.tryParse(generatedRaw),
      ),
    );
  }
  result.sort((a, b) {
    final at = a.generatedAt?.millisecondsSinceEpoch ?? 0;
    final bt = b.generatedAt?.millisecondsSinceEpoch ?? 0;
    return bt.compareTo(at);
  });
  return result;
}

/// 一覧カードの本文プレビュー(1行化+切り詰め)。
String candidatePreviewText(String text, {int maxChars = 200}) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= maxChars) return clean;
  return '${clean.substring(0, maxChars - 1)}…';
}

/// 候補の経過時間ラベル。パース不能は空文字(表示しない)。
String candidateAgeLabel(DateTime? generatedAt, DateTime now) {
  if (generatedAt == null) return '';
  final diff = now.difference(generatedAt);
  if (diff.isNegative) return '';
  if (diff.inDays >= 1) return '${diff.inDays}日前';
  if (diff.inHours >= 1) return '${diff.inHours}時間前';
  return '1時間以内';
}

/// x.post 応答から x.candidate.finalize へ渡す result payload を組む。
/// finalize 側(finalizeXPostCandidateMetadata)は posted+tweetId で posted、
/// code=duplicate_content で rejected_duplicate、それ以外を publish_failed に
/// 落とすので、その判定材料をそのまま写す。
Map<String, dynamic> buildCandidateFinalizeResult(
  Map<String, dynamic> postResponse,
) {
  final log = postResponse['log'];
  return <String, dynamic>{
    'posted': postResponse['posted'] == true,
    if (postResponse['tweetId'] != null)
      'tweetId': postResponse['tweetId'].toString(),
    if (postResponse['replyTweetId'] != null)
      'replyTweetId': postResponse['replyTweetId'].toString(),
    if (postResponse['replyTweetIds'] is List)
      'replyTweetIds': postResponse['replyTweetIds'],
    if (postResponse['code'] != null) 'code': postResponse['code'].toString(),
    if (postResponse['error'] != null)
      'error': postResponse['error'].toString(),
    if (log is Map && log['id'] != null) 'logId': log['id'].toString(),
  };
}

/// 投稿結果 → 運用者向けメッセージ。誠実性: 見送り(近似重複)と失敗を
/// 区別し、成功は計測ループへの記録まで言い切る。
String candidatePublishOutcomeMessage(Map<String, dynamic> postResponse) {
  if (postResponse['posted'] == true) {
    return '投稿しました(x_post_log に記録済み=Archetype lift 計測対象)';
  }
  if ((postResponse['code'] ?? '') == 'duplicate_content') {
    return '直近の投稿と近似重複のため見送りました(rejected_duplicate として記録)';
  }
  final error =
      (postResponse['error'] ?? postResponse['warning'] ?? '').toString();
  return error.isEmpty ? '投稿に失敗しました' : '投稿に失敗しました: $error';
}
