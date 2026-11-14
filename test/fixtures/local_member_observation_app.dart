import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_web_app/pages/election_victory_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cacheKey = 'election_intelligence_snapshot_v6_local';
const _seedKey = 'local_member_fixture_seed_v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final location = Uri.base;
  if (!const bool.fromEnvironment('LOCAL_MEMBER_OBSERVATION_FIXTURE') ||
      location.scheme != 'http' ||
      location.host != '127.0.0.1' ||
      location.port != 7362) {
    throw StateError('The synthetic member fixture requires loopback:7362.');
  }
  final scenario = location.queryParameters['cache'] ?? 'legacy';
  if (scenario != 'legacy' && scenario != 'empty') {
    throw StateError('Unknown synthetic cache scenario.');
  }
  await initializeDateFormatting('ja_JP');
  WidgetsBinding.instance.ensureSemantics();
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_seedKey) != scenario) {
    await prefs.remove(_cacheKey);
    await prefs.remove('local_election_plan_v1');
    await prefs.remove('local_election_reality_snapshot_history_v1');
    if (scenario == 'legacy') {
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'fetchedAt': '2026-10-11T00:00:00Z',
          'officialCurrentLocalMembers': 394,
          'targetLocalMembers': 700,
          'actualNetIncreaseRequired': 306,
          // No actual person, prefecture or candidate rows.
          'prefectures': <dynamic>[],
          'members': <dynamic>[],
          'electionIntelligence': {
            'schemaVersion': 1,
            'selectedMode': 'local',
          },
        }),
      );
    }
    await prefs.setString(_seedKey, scenario);
  }
  await prefs.setInt('local_member_fixture_edge_failures', 0);
  // No real host or credentials. All Supabase HTTP stays in memory.
  await Supabase.initialize(
    url: 'http://127.0.0.1:7362/synthetic-supabase',
    anonKey: 'synthetic-fixture-key-not-a-credential',
    httpClient: MockClient((request) async {
      if (request.url.path.contains('/functions/')) {
        final count = prefs.getInt('local_member_fixture_edge_failures') ?? 0;
        await prefs.setInt('local_member_fixture_edge_failures', count + 1);
        return http.Response(
          '{"error":"synthetic_edge_unavailable"}',
          503,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: false,
      detectSessionInUri: false,
    ),
  );
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansJP'),
      home: const ElectionVictoryPage(publicView: true),
    ),
  );
}
