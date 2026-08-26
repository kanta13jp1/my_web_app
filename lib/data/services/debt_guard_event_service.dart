import 'package:supabase_flutter/supabase_flutter.dart';

class DebtGuardEventService {
  const DebtGuardEventService({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> loadDailyEvents({
    required String userId,
    required String eventDate,
  }) async {
    final rows = await _client
        .from('prison_rule_events')
        .select('id, rule_id, event_type, note, event_date, created_at')
        .eq('user_id', userId)
        .eq('event_date', eventDate)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> appendEvents(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const <Map<String, dynamic>>[];
    final inserted = await _client
        .from('prison_rule_events')
        .insert(rows)
        .select('id, rule_id, event_type, note, event_date, created_at');
    return List<Map<String, dynamic>>.from(inserted);
  }
}
