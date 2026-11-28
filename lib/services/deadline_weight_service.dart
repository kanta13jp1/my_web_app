import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/deadline_weight_models.dart';

/// 「締め切りの重さ」のデータ供給。
///
/// `deadline_weight_items` / `deadline_weight_settings` を RLS 下で読み書きする。
/// どちらもオーナー本人の個人データなので、ログイン済みでなければ何もしない。
class DeadlineWeightService {
  DeadlineWeightService({SupabaseClient? client}) : _injected = client;

  // テストでサブクラスが差し替えられるよう、Supabase.instance は遅延解決する。
  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  /// ログイン済みか。
  bool get isSignedIn => _client.auth.currentSession != null;

  String get _userId => _client.auth.currentUser?.id ?? '';

  /// 未完了の締め切りを期日の近い順に取得する。
  Future<List<Map<String, dynamic>>> fetchItems() async {
    final data = await _client
        .from('deadline_weight_items')
        .select('id,title,due_on,required_minutes,completed_at')
        .isFilter('completed_at', null)
        .order('due_on')
        .limit(200);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// 曜日ごとの可処分時間設定。未保存なら null (呼び出し側で初期値を使う)。
  Future<Map<String, dynamic>?> fetchSettings() async {
    final data = await _client
        .from('deadline_weight_settings')
        .select(
          'monday_minutes,tuesday_minutes,wednesday_minutes,thursday_minutes,'
          'friday_minutes,saturday_minutes,sunday_minutes',
        )
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  /// 締め切りを 1 件追加する。
  Future<void> addItem({
    required String title,
    required DateTime dueOn,
    required int requiredMinutes,
  }) async {
    await _client.from('deadline_weight_items').insert(<String, dynamic>{
      'user_id': _userId,
      'title': title.trim(),
      'due_on': _formatDate(dueOn),
      'required_minutes': requiredMinutes,
    });
  }

  /// 期日を動かす (「責めない 3 択」の 1 つ目)。
  Future<void> updateDueOn(String id, DateTime dueOn) async {
    await _client.from('deadline_weight_items').update(<String, dynamic>{
      'due_on': _formatDate(dueOn),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// 必要時間を削る (「責めない 3 択」の 2 つ目)。
  Future<void> updateRequiredMinutes(String id, int requiredMinutes) async {
    await _client.from('deadline_weight_items').update(<String, dynamic>{
      'required_minutes': requiredMinutes.clamp(1, 60000),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// 完了にする (一覧からは外れる)。
  Future<void> completeItem(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('deadline_weight_items').update(<String, dynamic>{
      'completed_at': now,
      'updated_at': now,
    }).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('deadline_weight_items').delete().eq('id', id);
  }

  /// 曜日ごとの可処分時間を保存する (1 ユーザー 1 行の upsert)。
  Future<void> saveSettings(DisposableTimeSettings settings) async {
    final payload = <String, dynamic>{
      'user_id': _userId,
      ...settings.toRow(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client
        .from('deadline_weight_settings')
        .upsert(payload, onConflict: 'user_id');
  }

  /// `date` 型の列に渡す YYYY-MM-DD 文字列 (タイムゾーンで日がずれないようにする)。
  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
