// R21: ブログ同期の結果/エラー文言の純ロジック(依存ゼロ・VM テスト可能)。
// blog_management_page.dart は supabase 依存を含むため、生 FunctionException を
// 管理者が次に取る行動が分かる文言へ変換する判定だけをここへ切り出す
// (admin_dashboard_signals.dart と同じ抽出パターン)。

/// FunctionException の status/details (または任意のエラー文字列) から、管理者
/// 向けの同期エラー文言を作る。Qiita 401 (トークン失効) を最優先で名指しし、
/// 是正手順 (トークン再発行 + Supabase secrets 更新) まで案内する。
String composeBlogSyncErrorMessage({
  int? status,
  Object? details,
  String? fallback,
}) {
  var detail = '';
  if (details is Map) {
    detail = (details['error'] ?? '').toString();
    // error キーを持たない Map でも情報を全損させない。
    if (detail.isEmpty && details.isNotEmpty) {
      detail = details.toString();
    }
  } else if (details != null) {
    detail = details.toString();
  }
  final probe = detail.isNotEmpty ? detail : (fallback ?? '');

  if (RegExp('qiita', caseSensitive: false).hasMatch(probe) &&
      probe.contains('401')) {
    return 'Qiitaトークンが失効しています(401)。Qiitaで新しいアクセストークンを発行し、'
        'Supabase secrets の QIITA_ACCESS_TOKEN を更新してから再同期してください。';
  }
  if (probe.contains('QIITA_ACCESS_TOKEN')) {
    return 'QIITA_ACCESS_TOKEN が未設定です。Supabase secrets に設定してください。';
  }
  if (probe.contains('DEVTO_API_KEY')) {
    return 'DEVTO_API_KEY が未設定です。Supabase secrets に設定してください。';
  }

  final head = status != null ? '同期に失敗しました (HTTP $status)' : '同期に失敗しました';
  return probe.isEmpty ? '$head。' : '$head: $probe';
}

/// 同期成功レスポンスから件数付きの結果文言を作る。Qiita は articles_synced、
/// dev.to は synced を返す(schedule-hub の blog.sync_engagement /
/// blog.devto_sync_engagement)。件数が読めない場合は「同期完了」に留める。
String composeBlogSyncSuccessLine(String label, Object? data) {
  if (data is Map) {
    final count = data['articles_synced'] ?? data['synced'];
    if (count is num) {
      return '$label: ${count.toInt()}件同期';
    }
  }
  return '$label: 同期完了';
}

/// blog_engagement 行(各 {updated_at})の最新同期時刻から鮮度ラベルを作る。
/// 同期が失敗し続けている間、凍結した いいね/閲覧数を「今の数値」に見せない
/// (R20 の age-aware 規律)。パース可能な行が無ければ null。
String? blogEngagementFreshnessLabel(
  List<Map<String, dynamic>> rows,
  DateTime now,
) {
  final age = _freshnessAge(rows, now);
  return age == null ? null : '最終同期: $age';
}

String? _freshnessAge(List<Map<String, dynamic>> rows, DateTime now) {
  DateTime? newest;
  for (final row in rows) {
    final dt = DateTime.tryParse((row['updated_at'] ?? '').toString());
    if (dt == null) continue;
    if (newest == null || dt.isAfter(newest)) newest = dt;
  }
  if (newest == null) return null;
  final diff = now.difference(newest);
  if (diff.isNegative) return '1時間以内';
  if (diff.inDays >= 1) return '${diff.inDays}日前';
  if (diff.inHours >= 1) return '${diff.inHours}時間前';
  return '1時間以内';
}

String _platformDisplayName(String platform) {
  switch (platform) {
    case 'qiita':
      return 'Qiita';
    case 'devto':
      return 'dev.to';
    default:
      return platform;
  }
}

/// platform 別の鮮度ラベル(例:「最終同期 — Qiita: 3日前 / dev.to: 1時間以内」)。
/// Qiita と dev.to は独立に同期されるため全体 max では「片方だけ数日凍結」が
/// 新鮮側に隠れる — platform ごとに出して凍結を可視化する。platform 列が
/// 無い行しか無ければ全体ラベルへフォールバック。
String? blogEngagementFreshnessByPlatform(
  List<Map<String, dynamic>> rows,
  DateTime now,
) {
  final platforms = <String>[];
  for (final row in rows) {
    final platform = (row['platform'] ?? '').toString();
    if (platform.isNotEmpty && !platforms.contains(platform)) {
      platforms.add(platform);
    }
  }
  if (platforms.isEmpty) return blogEngagementFreshnessLabel(rows, now);
  if (platforms.length == 1) {
    return blogEngagementFreshnessLabel(rows, now);
  }

  final parts = <String>[];
  for (final platform in platforms) {
    final subset = rows
        .where((row) => (row['platform'] ?? '').toString() == platform)
        .toList();
    final age = _freshnessAge(subset, now);
    if (age != null) {
      parts.add('${_platformDisplayName(platform)}: $age');
    }
  }
  if (parts.isEmpty) return null;
  return '最終同期 — ${parts.join(' / ')}';
}
