import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

abstract class NoteCommentsService {
  Future<List<NoteComment>> fetchComments({required int noteId});

  Future<NoteComment> addComment({
    required int noteId,
    required String content,
  });

  Future<void> deleteComment({required String commentId});

  Future<int> getCommentCount({required int noteId});

  Stream<void> watchCommentChanges({required int noteId});
}

bool isExpectedNoteCommentRealtimeDisconnect(Object error) {
  final message = error.toString();
  if (!message.contains('RealtimeSubscribeException') ||
      !message.contains('RealtimeSubscribeStatus.channelError')) {
    return false;
  }
  return message.contains('RealtimeCloseEvent(code: 1000') ||
      message.contains('details: null');
}

class SupabaseNoteCommentsService implements NoteCommentsService {
  SupabaseNoteCommentsService(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<List<NoteComment>> fetchComments({required int noteId}) async {
    final response = await _supabase.from('note_comments').select('''
          id,
          note_id,
          user_id,
          content,
          created_at,
          updated_at,
          user_profiles(display_name, avatar_url)
        ''').eq('note_id', noteId).order('created_at', ascending: true);

    return (response as List)
        .map((raw) => _mapCommentJson(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  @override
  Future<NoteComment> addComment({
    required int noteId,
    required String content,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Login is required.');
    }

    final response = await _supabase.from('note_comments').insert({
      'note_id': noteId,
      'user_id': userId,
      'content': content.trim(),
    }).select('''
          id,
          note_id,
          user_id,
          content,
          created_at,
          updated_at,
          user_profiles(display_name, avatar_url)
        ''').single();

    return _mapCommentJson(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<void> deleteComment({required String commentId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Login is required.');
    }

    await _supabase
        .from('note_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', userId)
        .select();
  }

  @override
  Future<int> getCommentCount({required int noteId}) async {
    final response = await _supabase
        .from('note_comments')
        .select()
        .eq('note_id', noteId)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Stream<void> watchCommentChanges({required int noteId}) {
    return _supabase
        .from('note_comments')
        .stream(primaryKey: ['id'])
        .eq('note_id', noteId)
        .map((_) {});
  }

  NoteComment _mapCommentJson(Map<String, dynamic> raw) {
    final profile = raw['user_profiles'];
    Map<String, dynamic>? userProfile;
    if (profile is Map<String, dynamic>) {
      userProfile = profile;
    } else if (profile is List && profile.isNotEmpty && profile.first is Map) {
      userProfile = Map<String, dynamic>.from(profile.first as Map);
    }

    return NoteComment.fromJson({
      ...raw,
      'note_id': raw['note_id']?.toString(),
      'user_display_name': userProfile?['display_name'],
      'user_avatar_url': userProfile?['avatar_url'],
    });
  }
}
