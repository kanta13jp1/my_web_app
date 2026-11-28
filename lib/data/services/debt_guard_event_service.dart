import 'package:supabase_flutter/supabase_flutter.dart';

class DebtGuardEventService {
  const DebtGuardEventService({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  static const _columns = 'id, rule_id, event_type, note, emotion, '
      'stall_thought, event_date, created_at';

  /// Upper bound for one labelled-history read. Labelling is optional and
  /// manual, so a four-week window stays far below this; the newest rows win
  /// if it is ever reached.
  static const labelledEventLimit = 1000;

  Future<List<Map<String, dynamic>>> loadDailyEvents({
    required String userId,
    required String eventDate,
  }) async {
    final rows = await _client
        .from('prison_rule_events')
        .select(_columns)
        .eq('user_id', userId)
        .eq('event_date', eventDate)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Events that carry an emotion or stall-thought label on or after
  /// [sinceDate] (yyyy-MM-dd).
  Future<List<Map<String, dynamic>>> loadLabelledEvents({
    required String userId,
    required String sinceDate,
  }) async {
    final rows = await _client
        .from('prison_rule_events')
        .select(_columns)
        .eq('user_id', userId)
        .gte('event_date', sinceDate)
        .or('emotion.not.is.null,stall_thought.not.is.null')
        .order('event_date', ascending: false)
        .order('id', ascending: false)
        .limit(labelledEventLimit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> appendEvents(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const <Map<String, dynamic>>[];
    final inserted =
        await _client.from('prison_rule_events').insert(rows).select(_columns);
    return List<Map<String, dynamic>>.from(inserted);
  }
}
