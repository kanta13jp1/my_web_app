/// SNS 予約投稿モデル。
///
/// `social-commerce-hub` の `schedule.list` (`{success, posts: [hub_data 行]}`)
/// を解析する純データモデル。実フィールドは `metadata.content` /
/// `metadata.platforms` (配列) / `metadata.scheduled_at` / `metadata.status`。
/// 旧実装は flat `post['platform']` (単数・不存在) と `post['scheduled_at']`
/// を読み、見出し全空 + 予約時刻が作成時刻に化けていた。
library;

import 'hub_data_parsing.dart';

class ScheduledPostEntry {
  const ScheduledPostEntry({
    required this.content,
    required this.platforms,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
  });

  final String content;

  /// 予約先プラットフォーム (例: ['x', 'facebook'])。
  final List<String> platforms;

  /// 予約時刻 (ISO / 未設定は空文字)。
  final String scheduledAt;
  final String status;
  final String createdAt;

  /// アイコン表示用の代表プラットフォーム。
  String? get primaryPlatform => platforms.isEmpty ? null : platforms.first;

  /// 'X | FACEBOOK' 形式の表示ラベル (空なら '-')。
  String get platformsLabel => platforms.isEmpty
      ? '-'
      : platforms.map((p) => p.toUpperCase()).join(' / ');

  /// 一覧に出す時刻: 予約時刻があればそれ、無ければ作成時刻。
  String get displayTime => scheduledAt.isNotEmpty ? scheduledAt : createdAt;

  factory ScheduledPostEntry.fromMap(Map<String, dynamic> raw) {
    final rawPlatforms = hubField(raw, 'platforms');
    final platforms = rawPlatforms is List
        ? rawPlatforms
            .map((p) => hubString(p))
            .where((p) => p.isNotEmpty)
            .toList()
        : <String>[];
    return ScheduledPostEntry(
      content: hubString(hubField(raw, 'content')),
      platforms: platforms,
      scheduledAt: hubString(hubField(raw, 'scheduled_at')),
      status: hubString(hubField(raw, 'status')),
      createdAt: hubString(raw['created_at']),
    );
  }

  static List<ScheduledPostEntry> listFromResponse(dynamic data) =>
      hubRowsFromResponse(data, 'posts')
          .map(ScheduledPostEntry.fromMap)
          .toList();
}
