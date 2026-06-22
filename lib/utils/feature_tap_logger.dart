import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> recordFeatureTap(String route, String label) async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('user_feature_usage').insert({
      'user_id': user.id,
      'feature_route': route,
      'feature_label': label,
    });
  } catch (_) {
    // fire-and-forget; Supabase 未初期化やネットワーク失敗でも遷移を妨げない。
    // onGenerateRoute から全遷移で呼ばれるため、ここで必ず例外を吸収する。
  }
}
