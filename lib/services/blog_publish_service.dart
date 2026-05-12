import 'package:supabase_flutter/supabase_flutter.dart';

class BlogPublishService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> publishPost({
    required String id,
    List<String> tags = const [],
  }) async {
    final res = await _supabase.functions.invoke(
      'schedule-hub',
      body: {'action': 'blog.publish_post', 'id': id, 'tags': tags},
    );
    if (res.status != 200) {
      final msg =
          (res.data as Map?)?['error'] ?? 'publish failed (HTTP ${res.status})';
      throw Exception(msg);
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<void> updatePost(
    String id, {
    String? title,
    String? content,
    String? notes,
    List<String>? targetPlatforms,
    List<String>? tags,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (notes != null) updates['notes'] = notes;
    if (targetPlatforms != null) updates['target_platforms'] = targetPlatforms;
    if (tags != null) updates['tags'] = tags;
    if (updates.isEmpty) return;
    await _supabase.from('blog_posts').update(updates).eq('id', id);
  }

  static Future<void> deletePost(String id) async {
    await _supabase.from('blog_posts').delete().eq('id', id);
  }

  static Future<Map<String, dynamic>> insertPost({
    required String title,
    String content = '',
    String notes = '',
    List<String> targetPlatforms = const ['qiita', 'devto'],
    List<String> tags = const [],
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    final result = await _supabase
        .from('blog_posts')
        .insert({
          'title': title,
          if (content.isNotEmpty) 'content': content,
          if (notes.isNotEmpty) 'notes': notes,
          'status': 'draft',
          'target_platforms': targetPlatforms,
          'tags': tags,
          if (userId != null) 'created_by': userId,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(result as Map);
  }

  /// 公開済み記事一覧 (anon 可)
  static Future<List<Map<String, dynamic>>> listPublicPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _supabase
        .from('blog_posts')
        .select(
          'id, title, content, excerpt, status, posted_at, published_at, url, created_by, created_at, target_platforms, tags',
        )
        .eq('status', 'posted')
        .order('posted_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// 単記事取得 (anon: posted のみ / authenticated: 全 status)
  static Future<Map<String, dynamic>?> getPostById(String id) async {
    final data = await _supabase
        .from('blog_posts')
        .select(
          'id, title, content, excerpt, status, posted_at, published_at, url, notes, created_by, created_at, target_platforms, tags',
        )
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }
}
