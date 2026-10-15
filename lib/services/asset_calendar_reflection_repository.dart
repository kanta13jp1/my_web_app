import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/asset_calendar_reflection.dart';

class AssetCalendarReflectionRepository {
  AssetCalendarReflectionRepository(this.client);
  final SupabaseClient client;

  Future<List<AssetCalendarReflection>> load(
    DateTime start,
    DateTime end,
  ) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw StateError('ログインしてください');
    final rows = await client
        .from('asset_calendar_reflections')
        .select()
        .eq('user_id', owner)
        .gte('occurred_on', start.toIso8601String().substring(0, 10))
        .lt('occurred_on', end.toIso8601String().substring(0, 10))
        .order('occurred_on')
        .order('source_key')
        .limit(1001);
    if (client.auth.currentUser?.id != owner) throw StateError('ログイン状態が変わりました');
    if (rows.length > 1000) throw StateError('記録が多いため期間を短くしてください');
    return rows.map(AssetCalendarReflection.fromJson).toList(growable: false);
  }

  Future<void> import(List<AssetCalendarReflection> events) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw StateError('ログインしてください');
    if (events.isEmpty || events.length > 200) {
      throw ArgumentError('1〜200件ずつ取り込んでください');
    }
    await client.from('asset_calendar_reflections').upsert(
      [
        for (final event in events) {...event.toJson(), 'user_id': owner},
      ],
      onConflict: 'user_id,source_key',
      ignoreDuplicates: true,
    );
    if (client.auth.currentUser?.id != owner) throw StateError('ログイン状態が変わりました');
  }
}
