import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/local_election_reality.dart';

class LocalElectionRealityService {
  static const String _snapshotStorageKey =
      'local_election_reality_snapshot_v3';
  static const String _memberProfileStoragePrefix =
      'local_election_member_profile_v1_';

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
    final raw = store.getString(_snapshotStorageKey);
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
    await store.setString(_snapshotStorageKey, jsonEncode(snapshot.toJson()));
  }

  Future<LocalElectionLegislatorProfile?> loadCachedMemberProfile(
    String detailUrl, {
    SharedPreferences? prefs,
  }) async {
    final normalizedUrl = detailUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(_memberProfileKey(normalizedUrl));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return LocalElectionLegislatorProfile.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (error) {
      debugPrint('Local election member profile parse failed: $error');
      return null;
    }
  }

  Future<void> cacheMemberProfile(
    LocalElectionLegislatorProfile profile, {
    SharedPreferences? prefs,
  }) async {
    final normalizedUrl = profile.detailUrl.trim();
    if (normalizedUrl.isEmpty) {
      return;
    }

    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setString(
      _memberProfileKey(normalizedUrl),
      jsonEncode(profile.toJson()),
    );
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

  Future<LocalElectionLegislatorProfile> fetchMemberProfile(
    String detailUrl, {
    String prefectureHint = '',
    SharedPreferences? prefs,
  }) async {
    final normalizedUrl = detailUrl.trim();
    if (normalizedUrl.isEmpty) {
      throw Exception('Member detail URL is empty.');
    }

    final client = _resolvedClient;
    if (client == null) {
      throw Exception('Supabase client is not available.');
    }

    final response = await client.functions.invoke(
      'local-election-intelligence',
      body: <String, dynamic>{
        'action': 'memberDetail',
        'detailUrl': normalizedUrl,
        'prefectureHint': prefectureHint.trim(),
      },
    );
    final data = _toMap(response.data);
    if (data['success'] != true) {
      throw Exception(
        data['error']?.toString() ?? 'Member detail fetch failed.',
      );
    }

    final profile = LocalElectionLegislatorProfile.fromJson(
      _toMap(data['profile']),
    );
    await cacheMemberProfile(profile, prefs: prefs);
    return profile;
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

  String _memberProfileKey(String detailUrl) {
    return '$_memberProfileStoragePrefix${Uri.encodeComponent(detailUrl)}';
  }
}
