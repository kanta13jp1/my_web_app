import 'package:supabase_flutter/supabase_flutter.dart';

/// prefecture_election_news を 1 クエリで全県分取得し、県別に配布する。
///
/// 従来は ElectionNewsBadge が県連カードごとに個別クエリを発行しており、
/// 本番で県数分 (数十件) の fetch + CORS preflight が観測されたための一括化
/// (2026-07-18)。ページ側は [fetchActiveNewsByPrefecture] の結果を
/// [normalizePrefectureKey] で引いて各カードへ渡す。
class PrefectureElectionNewsService {
  /// 1 県あたりの表示上限 (旧 ElectionNewsBadge の limit(3) と同値)。
  static const int maxItemsPerPrefecture = 3;

  /// 47 都道府県 × 蓄積 news 件数に対する安全上限。
  static const int _fetchLimit = 400;

  static const Duration _fetchTimeout = Duration(seconds: 8);

  final SupabaseClient? _client;

  const PrefectureElectionNewsService({SupabaseClient? client})
      : _client = client;

  SupabaseClient? get _resolvedClient {
    if (_client != null) {
      return _client;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// active な news を announced_at 降順で一括取得し、正規化県名キー →
  /// 上位 [maxItemsPerPrefecture] 件の Map として返す。
  Future<Map<String, List<Map<String, dynamic>>>>
      fetchActiveNewsByPrefecture() async {
    final client = _resolvedClient;
    if (client == null) {
      return const <String, List<Map<String, dynamic>>>{};
    }
    final rows = await client
        .from('prefecture_election_news')
        .select(
          'prefecture, news_title, news_summary, news_source_url, '
          'news_source_label, announced_at, total_candidate_target, '
          'confirmed_candidate_count, public_recruitment_count, '
          'representative_name',
        )
        .eq('is_active', true)
        .order('announced_at', ascending: false)
        .limit(_fetchLimit)
        .timeout(_fetchTimeout);
    return groupByPrefecture(List<Map<String, dynamic>>.from(rows));
  }

  /// announced_at 降順で並んだ行を県別に振り分け、各県先頭
  /// [maxItemsPerPrefecture] 件のみ保持する。
  static Map<String, List<Map<String, dynamic>>> groupByPrefecture(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = normalizePrefectureKey(row['prefecture'] as String? ?? '');
      if (key.isEmpty) {
        continue;
      }
      final bucket = grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]);
      if (bucket.length < maxItemsPerPrefecture) {
        bucket.add(row);
      }
    }
    return grouped;
  }

  /// プラン側の長形式 ('宮崎県'/'東京都'/'大阪府') と DB 格納の短形式
  /// ('宮崎'/'東京'/'大阪') を同一キーへ正規化する。短形式の '京都' を
  /// '京' に潰さないため 2 文字以下は suffix を落とさない。北海道はそのまま。
  static String normalizePrefectureKey(String value) {
    final trimmed = value.trim();
    if (trimmed == '北海道') {
      return trimmed;
    }
    if (trimmed.length > 2 &&
        (trimmed.endsWith('都') ||
            trimmed.endsWith('府') ||
            trimmed.endsWith('県'))) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
