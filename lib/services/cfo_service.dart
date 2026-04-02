import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_source.dart';

class CfoService {
  final _client = Supabase.instance.client;

  Future<List<PaymentSource>> getPaymentSources() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final response = await _client
        .from('payment_sources')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final sources =
        (response as List).map((data) => PaymentSource.fromMap(data)).toList();

    return sources;
  }

  Future<void> auditPaymentSource(String id) async {
    await _client.from('payment_sources').update(
      {'last_audited_at': DateTime.now().toIso8601String()},
    ).eq('id', id);
  }
}
