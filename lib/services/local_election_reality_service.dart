import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/local_election_reality.dart';

class LocalElectionRealityService {
  static const String _storageKey = 'local_election_reality_snapshot_v1';

  final SupabaseClient? _client;

  const LocalElectionRealityService({
    SupabaseClient? client,
  }) : _client = client;

  SupabaseClient? get _resolvedClient {
    if (_client != null) {
      return _client;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<LocalElectionRealitySnapshot?> loadCachedSnapshot({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final snapshot = LocalElectionRealitySnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return snapshot.hasData ? snapshot : null;
    } catch (error) {
      debugPrint('Local election cached snapshot parse failed: $error');
      return null;
    }
  }

  Future<void> cacheSnapshot(
    LocalElectionRealitySnapshot snapshot, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setString(_storageKey, jsonEncode(snapshot.toJson()));
  }

  Future<LocalElectionRealitySnapshot> fetchLatestSnapshot({
    bool includeAiSummary = true,
    SharedPreferences? prefs,
  }) async {
    final client = _resolvedClient;
    if (client == null) {
      throw Exception('Supabase client is not available.');
    }

    final response = await client.functions.invoke(
      'local-election-intelligence',
      body: <String, dynamic>{
        'includeAiSummary': includeAiSummary,
      },
    );
    final data = _toMap(response.data);
    if (data['success'] != true) {
      throw Exception(
        data['error']?.toString() ?? 'Latest local election fetch failed.',
      );
    }

    final snapshot = LocalElectionRealitySnapshot.fromJson(
      _toMap(data['snapshot']),
    );
    await cacheSnapshot(snapshot, prefs: prefs);
    return snapshot;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }
}
