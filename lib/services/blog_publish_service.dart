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
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (notes != null) updates['notes'] = notes;
    if (targetPlatforms != null) updates['target_platforms'] = targetPlatforms;
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
  }) async {
    final result = await _supabase
        .from('blog_posts')
        .insert({
          'title': title,
          if (content.isNotEmpty) 'content': content,
          if (notes.isNotEmpty) 'notes': notes,
          'status': 'draft',
          'target_platforms': targetPlatforms,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(result as Map);
  }
}
