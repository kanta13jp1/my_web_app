import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> recordFeatureTap(String route, String label) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    await Supabase.instance.client.from('user_feature_usage').insert({
      'user_id': user.id,
      'feature_route': route,
      'feature_label': label,
    });
  } catch (_) {
    // fire-and-forget; don't block navigation on failure
  }
}
