import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アプリ共有の SupabaseClient 供給点 (main.dart から移設 / #3260)。
/// main.dart 経由の import は全アプリのページグラフ (web 専用 page 含む) を
/// 巻き込み VM テストをコンパイル不能にするため、独立ファイルに分離した。
/// main.dart は本ファイルを export しており既存 import は影響を受けない。
SupabaseClient? _testSupabaseClient;

@visibleForTesting
set supabaseClientForTesting(SupabaseClient client) =>
    _testSupabaseClient = client;

SupabaseClient get supabase => _testSupabaseClient ?? Supabase.instance.client;
