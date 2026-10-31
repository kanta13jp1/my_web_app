import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AssetMustTaskRepository {
  Future<List<Map<String, dynamic>>> load();
  Future<void> add(String title, DateTime deadline);
  Future<void> setCompleted(String id, bool completed);
}

class SupabaseAssetMustTaskRepository implements AssetMustTaskRepository {
  final SupabaseClient client;
  SupabaseAssetMustTaskRepository(this.client);

  String _owner() {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in required');
    return id;
  }

  void _sameOwner(String owner) {
    if (_owner() != owner) throw StateError('Account changed');
  }

  @override
  Future<List<Map<String, dynamic>>> load() async {
    final owner = _owner();
    final rows = await client
        .from('must_tasks')
        .select()
        .eq('user_id', owner)
        .order('deadline', ascending: true);
    _sameOwner(owner);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<void> add(String title, DateTime deadline) async {
    if (title.trim().isEmpty) throw ArgumentError('Title required');
    final owner = _owner();
    final rows = await client.from('must_tasks').insert({
      'user_id': owner,
      'title': title.trim(),
      'deadline': deadline.toUtc().toIso8601String(),
      'is_completed': false,
    }).select('id');
    _sameOwner(owner);
    if (rows.length != 1) throw StateError('Task save not confirmed');
  }

  @override
  Future<void> setCompleted(String id, bool completed) async {
    if (id.isEmpty) throw ArgumentError('Task ID required');
    final owner = _owner();
    final rows = await client
        .from('must_tasks')
        .update({'is_completed': completed})
        .eq('user_id', owner)
        .eq('id', id)
        .select('id');
    _sameOwner(owner);
    if (rows.length != 1 || rows.single['id'].toString() != id) {
      throw StateError('Task update not confirmed');
    }
  }
}
