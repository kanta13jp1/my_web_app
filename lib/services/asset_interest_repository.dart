import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/asset_interest_history.dart';

abstract class AssetInterestRepository {
  Future<List<AssetInterestMonth>> load();
  Future<void> save(AssetInterestMonth month);
}

/// Server-first: no device-only financial records and no schema/RLS changes.
/// One row per month, conditional updates prevent stale-device overwrites.
class SupabaseAssetInterestRepository implements AssetInterestRepository {
  final SupabaseClient client;
  final String userId;
  SupabaseAssetInterestRepository(this.client, this.userId);
  static const prefix = 'interest_paid_v1_';
  void _checkUser() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('ログイン状態が変わりました。再読み込みしてください');
    }
  }

  @override
  Future<List<AssetInterestMonth>> load() async {
    _checkUser();
    final rows = await client
        .from('asset_pref_mirror')
        .select('value,updated_at')
        .eq('user_id', userId)
        .like('pref_key', r'interest\_paid\_v1\_%')
        .order('pref_key', ascending: false)
        .limit(120);
    _checkUser();
    return rows
        .map((row) => AssetInterestMonth.fromJson(
            Map<String, dynamic>.from(row['value'] as Map),
            revision: row['updated_at'] as String))
        .toList();
  }

  @override
  Future<void> save(AssetInterestMonth month) async {
    _checkUser();
    final payload = <String, dynamic>{
      'user_id': userId,
      'pref_key': '$prefix${month.month}',
      'value': month.toJson(),
      'updated_at': DateTime.now().toUtc().toIso8601String()
    };
    if (month.revision == null) {
      // PK conflict is surfaced, never silently replace another device's month.
      await client.from('asset_pref_mirror').insert(payload);
    } else {
      final rows = await client
          .from('asset_pref_mirror')
          .update(payload)
          .eq('user_id', userId)
          .eq('pref_key', '$prefix${month.month}')
          .eq('updated_at', month.revision!)
          .select('pref_key');
      if (rows.length != 1) throw StateError('別端末の更新があります。再読み込みして照合してください');
    }
    _checkUser();
  }
}
