/// ソーシャルフィード投稿モデル。
///
/// `social-commerce-hub` の `feed.timeline` (`{success, posts: [hub_data 行]}`)
/// を解析する純データモデル。実フィールドは `metadata.content` /
/// `metadata.likes` / `metadata.comments` (旧実装は flat キー読みで
/// 本文全空・件数消失)。`username` は EF に保存されず、timeline は
/// 自分の投稿のみ返す (metadata->>user_id filter) ため作者は「自分」。
library;

import 'hub_data_parsing.dart';

class SocialFeedPost {
  const SocialFeedPost({
    required this.content,
    required this.likes,
    required this.comments,
    required this.createdAt,
  });

  final String content;
  final num likes;
  final num comments;

  /// トップレベル `created_at` (ISO / 空文字あり)。
  final String createdAt;

  factory SocialFeedPost.fromMap(Map<String, dynamic> raw) {
    return SocialFeedPost(
      content: hubString(hubField(raw, 'content')),
      likes: hubNum(hubField(raw, 'likes')),
      comments: hubNum(hubField(raw, 'comments')),
      createdAt: hubString(raw['created_at']),
    );
  }

  static List<SocialFeedPost> listFromResponse(dynamic data) =>
      hubRowsFromResponse(data, 'posts').map(SocialFeedPost.fromMap).toList();
}
