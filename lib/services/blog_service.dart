// lib/services/blog_service.dart
// schedule-hub の blog.* actions への薄い Flutter wrapper
// 利用元は blog_draft_editor_page / news_rss_aggregator_page のみ。
// 管理ページ (blog_management_page) は schedule-hub を直接 invoke する
// 独自実装を持つため、ここに wrapper を足しても配線されない (PR #3958 参照)。

import 'package:supabase_flutter/supabase_flutter.dart';

class BlogServiceException implements Exception {
  final String message;
  final int? statusCode;
  BlogServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'BlogServiceException($statusCode): $message';
}

class BlogService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> _invokeBlogAction(
    String action,
    Map<String, dynamic> params,
  ) async {
    final res = await _client.functions.invoke(
      'schedule-hub',
      body: {'action': action, ...params},
    );
    if (res.status != 200) {
      final msg = (res.data as Map?)?.containsKey('error') == true
          ? (res.data as Map)['error'].toString()
          : 'HTTP ${res.status}';
      throw BlogServiceException(msg, statusCode: res.status);
    }
    return (res.data as Map<String, dynamic>?) ?? {};
  }

  // ── Draft CRUD (blog_posts テーブル) ────────────────────────────

  Future<Map<String, dynamic>> insertPost({
    required String title,
    required String content,
    List<String> targetPlatforms = const ['qiita', 'devto'],
    List<String> tags = const [],
    String notes = '',
  }) async {
    return _invokeBlogAction('blog.insert_post', {
      'title': title,
      'content': content,
      'target_platforms': targetPlatforms,
      'tags': tags,
      'notes': notes,
    });
  }

  Future<void> updatePost({
    required String id,
    String? title,
    String? content,
    List<String>? targetPlatforms,
    List<String>? tags,
    String? status,
    String? notes,
  }) async {
    final params = <String, dynamic>{'id': id};
    if (title != null) params['title'] = title;
    if (content != null) params['content'] = content;
    if (targetPlatforms != null) params['target_platforms'] = targetPlatforms;
    if (tags != null) params['tags'] = tags;
    if (status != null) params['status'] = status;
    if (notes != null) params['notes'] = notes;
    await _invokeBlogAction('blog.update_post', params);
  }

  // ── 公開 ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> publishPost(String id) async {
    return _invokeBlogAction('blog.publish_post', {'id': id});
  }

  // ── blog_posts 単件取得 (エディタ用) ─────────────────────────────

  Future<Map<String, dynamic>?> fetchPost(String id) async {
    final res = await _client
        .from('blog_posts')
        .select(
          'id, title, content, status, target_platforms, tags, notes, created_at, updated_at',
        )
        .eq('id', id)
        .maybeSingle();
    return res;
  }
}
