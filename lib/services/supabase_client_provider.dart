import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient? _testSupabaseClient;

@visibleForTesting
set supabaseClientForTesting(SupabaseClient client) =>
    _testSupabaseClient = client;

@visibleForTesting
void clearSupabaseClientForTesting() {
  _testSupabaseClient = null;
}

SupabaseClient get supabase => _testSupabaseClient ?? Supabase.instance.client;
