// lib/services/blog_service.dart
// schedule-hub の blog.* actions への薄い Flutter wrapper

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

  Future<void> deletePost(String id) async {
    await _invokeBlogAction('blog.delete_post', {'id': id});
  }

  // ── 公開 ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> publishPost(String id) async {
    return _invokeBlogAction('blog.publish_post', {'id': id});
  }

  // ── Engagement 同期 ──────────────────────────────────────────────

  Future<Map<String, dynamic>> syncEngagement() async {
    return _invokeBlogAction('blog.sync_engagement', {});
  }

  // ── Qiita コメント返信 (item_id = Qiita 記事 ID) ──────────────
  Future<void> qiitaCommentPost({
    required String articleId,
    required String body,
  }) async {
    await _invokeBlogAction('blog.qiita_comment_post', {
      'item_id': articleId,
      'body': body,
    });
  }

  // ── Qiita 記事本文取得 ────────────────────────────────────────
  Future<Map<String, dynamic>> qiitaGetItem(String itemId) async {
    return _invokeBlogAction('blog.qiita_get_item', {'item_id': itemId});
  }

  // ── 訂正承認 ────────────────────────────────────────────────────
  Future<void> qiitaUpdate({
    required String articleId,
    required String title,
    required String body,
  }) async {
    await _invokeBlogAction('blog.qiita_update', {
      'item_id': articleId,
      'title': title,
      'body': body,
    });
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

  // ── blog_posts slug 単件取得 (公開記事閲覧用) ─────────────────────

  Future<Map<String, dynamic>?> fetchPostBySlug(String slug) async {
    final res = await _client
        .from('blog_posts')
        .select(
          'id, slug, title, content, excerpt, tags, posted_at, published_at, target_platforms, url, cover_image_url',
        )
        .eq('slug', slug)
        .eq('status', 'posted')
        .maybeSingle();
    return res;
  }

  // ── 訂正 pending 一覧 ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPendingCorrections() async {
    final res = await _client
        .from('blog_corrections')
        .select(
          'id, platform, article_id, title, url, confidence, errors_json, detected_at',
        )
        .eq('approved', false)
        .isFilter('applied_at', null)
        .order('detected_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> approveCorrection({
    required String correctionId,
    required String articleId,
    required String title,
    required String body,
  }) async {
    await qiitaUpdate(articleId: articleId, title: title, body: body);
    await _client
        .from('blog_corrections')
        .update({
          'approved': true,
          'approved_at': DateTime.now().toIso8601String(),
          'applied_at': DateTime.now().toIso8601String(),
        })
        .eq('id', correctionId);
  }

  Future<void> rejectCorrection(String correctionId) async {
    await _client
        .from('blog_corrections')
        .update({'approved': false})
        .eq('id', correctionId);
  }

  // ── Draft health check ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchStaleDrafts() async {
    return _invokeBlogAction(
      'blog.draft_health_check',
      {},
    ).then((r) => List<Map<String, dynamic>>.from(r['stale'] as List? ?? []));
  }
}
