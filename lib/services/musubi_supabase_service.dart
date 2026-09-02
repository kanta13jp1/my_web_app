import 'package:supabase_flutter/supabase_flutter.dart';

/// MUSUBIの外部I/Oだけを担当する薄いSupabaseアダプター。
///
/// Domain変換、キャッシュ、プレビューへのフォールバックはRepository側で行う。
class MusubiSupabaseService {
  MusubiSupabaseService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  bool get isAuthenticated => _client.auth.currentUser != null;
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<void> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final displayName =
        (metadata['display_name'] ?? metadata['full_name'] ?? 'MUSUBIメンバー')
            .toString();
    final requestedHandle =
        (metadata['user_name'] ?? metadata['preferred_username'] ?? '')
            .toString()
            .trim();
    final fallbackHandle =
        'user_${user.id.replaceAll('-', '').substring(0, 8)}';
    await _client.from('musubi_profiles').upsert(
      <String, dynamic>{
        'user_id': user.id,
        'display_name': displayName,
        'handle': requestedHandle.isEmpty ? fallbackHandle : requestedHandle,
        'avatar_label': String.fromCharCodes(displayName.runes.take(2)),
      },
      onConflict: 'user_id',
    );
  }

  Future<List<Map<String, dynamic>>> fetchPosts({int limit = 50}) async {
    final response = await _client
        .from('musubi_posts')
        .select(
          'id,author_id,content,audience,ai_assisted,language_label,'
          'source_title,context_note,tags,reaction_count,reply_count,'
          'boost_count,resonance,created_at,'
          'musubi_profiles!musubi_posts_author_id_fkey('
          'display_name,handle,avatar_label,verified_human)',
        )
        .eq('moderation_status', 'published')
        .order('created_at', ascending: false)
        .limit(limit);
    return _rows(response);
  }

  Stream<List<Map<String, dynamic>>> watchPosts({int limit = 50}) {
    return _client
        .from('musubi_posts')
        .stream(primaryKey: const <String>['id'])
        .eq('moderation_status', 'published')
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map(Map<String, dynamic>.from).toList());
  }

  Future<Map<String, dynamic>> insertPost({
    required String content,
    required String audience,
    required bool aiAssisted,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Authentication required');
    await ensureProfile();
    final response = await _client
        .from('musubi_posts')
        .insert(<String, dynamic>{
          'author_id': userId,
          'content': content,
          'audience': audience,
          'ai_assisted': aiAssisted,
        })
        .select(
          'id,author_id,content,audience,ai_assisted,language_label,'
          'source_title,context_note,tags,reaction_count,reply_count,'
          'boost_count,resonance,created_at,'
          'musubi_profiles!musubi_posts_author_id_fkey('
          'display_name,handle,avatar_label,verified_human)',
        )
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<dynamic> invokeLegacyFeed(
    String action, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final response = await _client.functions.invoke(
      'social-commerce-hub',
      body: <String, dynamic>{'action': action, ...body},
    );
    return response.data;
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 30,
  }) async {
    final response = await _client.rpc(
      'search_musubi',
      params: <String, dynamic>{
        'search_query': query,
        'result_limit': limit,
      },
    );
    return _rows(response);
  }

  Future<List<Map<String, dynamic>>> listThreads() async {
    final response = await _client.rpc('musubi_list_threads');
    return _rows(response);
  }

  Future<String> startDirectThread(String participantId) async {
    await ensureProfile();
    final response = await _client.rpc(
      'musubi_start_direct_thread',
      params: <String, dynamic>{'recipient_id': participantId},
    );
    return response.toString();
  }

  Future<List<Map<String, dynamic>>> listMessages(String threadId) async {
    final response = await _client
        .from('musubi_messages')
        .select('id,thread_id,sender_id,body,created_at')
        .eq('thread_id', threadId)
        .order('created_at');
    return _rows(response);
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String threadId) {
    return _client
        .from('musubi_messages')
        .stream(primaryKey: const <String>['id'])
        .eq('thread_id', threadId)
        .order('created_at')
        .map((rows) => rows.map(Map<String, dynamic>.from).toList());
  }

  Future<Map<String, dynamic>> sendMessage({
    required String threadId,
    required String body,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Authentication required');
    final response = await _client
        .from('musubi_messages')
        .insert(<String, dynamic>{
          'thread_id': threadId,
          'sender_id': userId,
          'body': body,
        })
        .select('id,thread_id,sender_id,body,created_at')
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<void> createReport({
    required String targetPostId,
    required String reason,
    required String details,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Authentication required');
    await _client.from('musubi_reports').insert(<String, dynamic>{
      'reporter_id': userId,
      'target_post_id': targetPostId,
      'reason': reason,
      'details': details,
    });
  }

  Future<List<Map<String, dynamic>>> listModerationQueue() async {
    final response = await _client
        .from('musubi_reports')
        .select(
          'id,target_post_id,reason,details,status,created_at,'
          'musubi_posts!musubi_reports_target_post_id_fkey(content)',
        )
        .inFilter(
      'status',
      const <String>['open', 'reviewing'],
    ).order('created_at');
    return _rows(response);
  }

  Future<void> updateModerationStatus(String caseId, String status) async {
    await _client
        .from('musubi_reports')
        .update(<String, dynamic>{'status': status}).eq('id', caseId);
  }

  Future<void> insertResearchFeedback(Map<String, dynamic> payload) async {
    await _client.from('musubi_research_feedback').insert(payload);
  }

  Future<Map<String, dynamic>?> fetchLatestResearchConsent() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final response = await _client
        .from('musubi_research_feedback')
        .select('cohort,consent_version,consented_at')
        .eq('user_id', userId)
        .eq('consent_to_research', true)
        .order('consented_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<void> deleteResearchData() async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client
        .from('musubi_research_feedback')
        .delete()
        .eq('user_id', userId);
    await _client.from('musubi_research_events').delete().eq('user_id', userId);
  }

  Future<void> insertResearchEvent(Map<String, dynamic> payload) async {
    await _client.from('musubi_research_events').insert(payload);
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
