import 'package:supabase_flutter/supabase_flutter.dart';

class SavoredMomentService {
  const SavoredMomentService({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  static const _table = 'prison_savored_moments';
  static const _columns = 'id, note, moment_date, created_at';

  /// Upper bound for one read. Entries are typed by hand one line at a time,
  /// so a two-week window stays far below this; the newest rows win if it is
  /// ever reached.
  static const readLimit = 200;

  /// Moments on or after [sinceDate] (yyyy-MM-dd), newest first.
  Future<List<Map<String, dynamic>>> loadSince({
    required String userId,
    required String sinceDate,
  }) async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .eq('user_id', userId)
        .gte('moment_date', sinceDate)
        .order('moment_date', ascending: false)
        .order('id', ascending: false)
        .limit(readLimit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> append({
    required String userId,
    required String momentDate,
    required String note,
  }) async {
    final row = await _client
        .from(_table)
        .insert(<String, dynamic>{
          'user_id': userId,
          'moment_date': momentDate,
          'note': note,
        })
        .select(_columns)
        .single();
    return Map<String, dynamic>.from(row);
  }
}
