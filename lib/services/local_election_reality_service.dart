import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/local_election_reality.dart';
import '../models/election_intelligence.dart';

class LocalElectionRealityService {
  static const String _snapshotStoragePrefix =
      'election_intelligence_snapshot_v6_';
  static const String _historyStorageKey =
      'local_election_reality_snapshot_history_v1';
  static const String _memberProfileStoragePrefix =
      'local_election_member_profile_v1_';
  static const Duration _freshSnapshotWindow = Duration(hours: 2);
  static const Duration _edgeFunctionTimeout = Duration(seconds: 90);
  static LocalElectionRealitySnapshot? _memorySnapshot;
  static Future<LocalElectionRealitySnapshot>? _latestSnapshotInFlight;
  static ElectionModeId? _latestSnapshotInFlightMode;

  final SupabaseClient? _client;

  const LocalElectionRealityService({SupabaseClient? client})
      : _client = client;

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
    ElectionModeId mode = ElectionModeId.local,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(_snapshotStorageKey(mode));
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
      if (snapshot.electionIntelligence.selectedMode != mode) {
        return null;
      }
      if (snapshot.hasSuspiciousEmptyOfficialPrefecture) {
        debugPrint(
          'Ignoring suspicious local election snapshot: '
          '${snapshot.suspiciousEmptyOfficialPrefectures.join(', ')}',
        );
        return null;
      }
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
    if (snapshot.hasSuspiciousEmptyOfficialPrefecture) {
      debugPrint(
        'Skipping suspicious local election snapshot cache: '
        '${snapshot.suspiciousEmptyOfficialPrefectures.join(', ')}',
      );
      return;
    }
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setString(
      _snapshotStorageKey(snapshot.electionIntelligence.selectedMode),
      jsonEncode(snapshot.toJson()),
    );
    if (snapshot.electionIntelligence.selectedMode == ElectionModeId.local) {
      await _cacheHistoryPoint(snapshot, prefs: store);
    }
  }

  Future<List<LocalElectionRealityHistoryPoint>> loadSnapshotHistory({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(_historyStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <LocalElectionRealityHistoryPoint>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <LocalElectionRealityHistoryPoint>[];
      }
      final points = decoded
          .whereType<Map>()
          .map(
            (item) => LocalElectionRealityHistoryPoint.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.officialCurrentLocalMembers > 0)
          .toList()
        ..sort((left, right) => left.fetchedAt.compareTo(right.fetchedAt));
      return points;
    } catch (error) {
      debugPrint('Local election history parse failed: $error');
      return const <LocalElectionRealityHistoryPoint>[];
    }
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
    bool forceRefresh = false,
    ElectionModeId mode = ElectionModeId.local,
  }) async {
    final client = _resolvedClient;
    if (client == null) {
      throw Exception('Supabase client is not available.');
    }

    final store = prefs ?? await SharedPreferences.getInstance();
    final LocalElectionRealitySnapshot? cachedSnapshot =
        await loadCachedSnapshot(prefs: store, mode: mode);
    final memorySnapshot =
        _memorySnapshot?.electionIntelligence.selectedMode == mode
            ? _memorySnapshot
            : null;
    final LocalElectionRealitySnapshot? fallbackSnapshot = _pickNewerSnapshot(
      memorySnapshot,
      cachedSnapshot,
    );

    if (!forceRefresh &&
        fallbackSnapshot != null &&
        _isSnapshotFresh(fallbackSnapshot)) {
      _memorySnapshot = fallbackSnapshot;
      return fallbackSnapshot;
    }

    final Future<LocalElectionRealitySnapshot>? inFlight =
        _latestSnapshotInFlight;
    if (inFlight != null && _latestSnapshotInFlightMode == mode) {
      return inFlight;
    }

    final Future<LocalElectionRealitySnapshot> request =
        _fetchLatestSnapshotFromEdgeFunction(
      client: client,
      includeAiSummary: includeAiSummary,
      mode: mode,
    ).then(_rejectSuspiciousSnapshot);
    _latestSnapshotInFlight = request;
    _latestSnapshotInFlightMode = mode;

    try {
      final snapshot = await request;
      _memorySnapshot = snapshot;
      await cacheSnapshot(snapshot, prefs: store);
      return snapshot;
    } catch (error) {
      if (fallbackSnapshot != null && fallbackSnapshot.hasData) {
        debugPrint(
          'Local election fetch failed, using cached snapshot instead: $error',
        );
        _memorySnapshot = fallbackSnapshot;
        return fallbackSnapshot;
      }
      rethrow;
    } finally {
      if (identical(_latestSnapshotInFlight, request)) {
        _latestSnapshotInFlight = null;
        _latestSnapshotInFlightMode = null;
      }
    }
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

  String _snapshotStorageKey(ElectionModeId mode) {
    return '$_snapshotStoragePrefix${mode.wireName}';
  }

  Future<LocalElectionRealitySnapshot> _fetchLatestSnapshotFromEdgeFunction({
    required SupabaseClient client,
    required bool includeAiSummary,
    required ElectionModeId mode,
  }) async {
    final response = await client.functions.invoke(
      'local-election-intelligence',
      body: <String, dynamic>{
        'mode': mode.wireName,
        'includeAiSummary': includeAiSummary,
      },
    ).timeout(_edgeFunctionTimeout);
    final data = _toMap(response.data);
    if (data['success'] != true) {
      throw Exception(
        data['error']?.toString() ?? 'Latest local election fetch failed.',
      );
    }

    return LocalElectionRealitySnapshot.fromJson(_toMap(data['snapshot']));
  }

  bool _isSnapshotFresh(LocalElectionRealitySnapshot snapshot) {
    if (!snapshot.hasData) {
      return false;
    }
    if (snapshot.hasSuspiciousEmptyOfficialPrefecture) {
      return false;
    }
    if (_hasUnresolvedRecentPastCandidateElection(snapshot)) {
      return false;
    }
    return DateTime.now().difference(snapshot.fetchedAt) <=
        _freshSnapshotWindow;
  }

  bool _hasUnresolvedRecentPastCandidateElection(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(const Duration(days: 14));

    for (final schedule in snapshot.targetElectionSchedules) {
      final voteDate = schedule.parsedVoteDate;
      if (voteDate == null || schedule.kokuminCandidateCount <= 0) {
        continue;
      }
      final electionDate = DateTime(
        voteDate.year,
        voteDate.month,
        voteDate.day,
      );
      if (electionDate.isAfter(today) || electionDate.isBefore(cutoff)) {
        continue;
      }

      final candidateCount = schedule.kokuminCandidateNames.isNotEmpty
          ? schedule.kokuminCandidateNames.length
          : schedule.kokuminCandidateCount;
      for (var index = 0; index < candidateCount; index++) {
        final name = index < schedule.kokuminCandidateNames.length
            ? schedule.kokuminCandidateNames[index].trim()
            : '';
        final status = index < schedule.kokuminCandidateStatuses.length
            ? schedule.kokuminCandidateStatuses[index].trim()
            : '';
        if ((name.isNotEmpty || schedule.kokuminCandidateCount > 0) &&
            !PastElectionCandidate.hasResolvedOutcomeStatus(status)) {
          return true;
        }
      }
    }
    return false;
  }

  LocalElectionRealitySnapshot _rejectSuspiciousSnapshot(
    LocalElectionRealitySnapshot snapshot,
  ) {
    if (snapshot.hasSuspiciousEmptyOfficialPrefecture) {
      throw Exception(
        'Official prefecture pages parsed as zero members: '
        '${snapshot.suspiciousEmptyOfficialPrefectures.join(', ')}',
      );
    }
    return snapshot;
  }

  LocalElectionRealitySnapshot? _pickNewerSnapshot(
    LocalElectionRealitySnapshot? left,
    LocalElectionRealitySnapshot? right,
  ) {
    if (left == null) {
      return right;
    }
    if (right == null) {
      return left;
    }
    return left.fetchedAt.isAfter(right.fetchedAt) ? left : right;
  }

  Future<void> _cacheHistoryPoint(
    LocalElectionRealitySnapshot snapshot, {
    SharedPreferences? prefs,
  }) async {
    if (!snapshot.hasData) {
      return;
    }

    final store = prefs ?? await SharedPreferences.getInstance();
    final currentPoint = LocalElectionRealityHistoryPoint(
      fetchedAt: snapshot.fetchedAt,
      officialCurrentLocalMembers: snapshot.officialCurrentLocalMembers,
      actualNetIncreaseRequired: snapshot.actualNetIncreaseRequired,
    );

    final history = await loadSnapshotHistory(prefs: store);
    final currentDayKey = _historyDayKey(currentPoint.fetchedAt.toLocal());
    final updated = history
        .where(
          (item) => _historyDayKey(item.fetchedAt.toLocal()) != currentDayKey,
        )
        .toList()
      ..add(currentPoint)
      ..sort((left, right) => left.fetchedAt.compareTo(right.fetchedAt));

    const maxPoints = 180;
    final trimmed = updated.length > maxPoints
        ? updated.sublist(updated.length - maxPoints)
        : updated;

    await store.setString(
      _historyStorageKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
  }

  String _historyDayKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String();
  }
}
