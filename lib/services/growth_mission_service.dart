import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/referral_code.dart';
import '../models/site_statistics.dart';
import 'app_share_service.dart';

class GrowthBenchmarks {
  static const int notionUsersFloor = 100000000;
  static const int evernoteUsersFloor = 250000000;
  static const int beatNotionTarget = notionUsersFloor + 1;
  static const int beatEvernoteTarget = evernoteUsersFloor + 1;
}

class ReferralGrowthSnapshot {
  final ReferralCode? myReferralCode;
  final int totalReferrals;
  final int successfulReferrals;
  final String? pendingReferralCode;

  const ReferralGrowthSnapshot({
    required this.myReferralCode,
    required this.totalReferrals,
    required this.successfulReferrals,
    required this.pendingReferralCode,
  });

  const ReferralGrowthSnapshot.empty()
      : myReferralCode = null,
        totalReferrals = 0,
        successfulReferrals = 0,
        pendingReferralCode = null;

  String? get referralCode => myReferralCode?.referralCode;

  String? get inviteUrl {
    final code = referralCode;
    if (code == null || code.isEmpty) {
      return null;
    }
    return GrowthMissionService.buildInviteUrlForCode(code);
  }
}

class GrowthMissionDashboard {
  final int totalRegisteredUsers;
  final int todayRegistrations;
  final int activeUsersToday;
  final int liveRegisteredUsers;
  final int liveGuestViewers;
  final int todayLandingViews;
  final int monthLandingViews;
  final int totalLandingViews;
  final int todayShares;
  final ReferralGrowthSnapshot referralSnapshot;
  final DateTime refreshedAt;

  const GrowthMissionDashboard({
    required this.totalRegisteredUsers,
    required this.todayRegistrations,
    required this.activeUsersToday,
    required this.liveRegisteredUsers,
    required this.liveGuestViewers,
    required this.todayLandingViews,
    required this.monthLandingViews,
    required this.totalLandingViews,
    required this.todayShares,
    required this.referralSnapshot,
    required this.refreshedAt,
  });

  factory GrowthMissionDashboard.empty() {
    return GrowthMissionDashboard(
      totalRegisteredUsers: 0,
      todayRegistrations: 0,
      activeUsersToday: 0,
      liveRegisteredUsers: 0,
      liveGuestViewers: 0,
      todayLandingViews: 0,
      monthLandingViews: 0,
      totalLandingViews: 0,
      todayShares: 0,
      referralSnapshot: const ReferralGrowthSnapshot.empty(),
      refreshedAt: DateTime.now(),
    );
  }

  int get liveViewers => liveRegisteredUsers + liveGuestViewers;

  int get gapToBeatNotion =>
      math.max(0, GrowthBenchmarks.beatNotionTarget - totalRegisteredUsers);

  int get gapToBeatEvernote =>
      math.max(0, GrowthBenchmarks.beatEvernoteTarget - totalRegisteredUsers);

  double get progressToBeatNotion =>
      totalRegisteredUsers / GrowthBenchmarks.beatNotionTarget;

  double get progressToBeatEvernote =>
      totalRegisteredUsers / GrowthBenchmarks.beatEvernoteTarget;
}

class GrowthMissionService {
  static const _guestSessionIdKey = 'growth_guest_session_id';
  static const _pendingReferralCodeKey = 'growth_pending_referral_code';
  static const _referralAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final SupabaseClient? _clientOverride;

  const GrowthMissionService({
    SupabaseClient? clientOverride,
  }) : _clientOverride = clientOverride;

  SupabaseClient? get _client {
    if (_clientOverride != null) {
      return _clientOverride;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static String buildInviteUrlForCode(String code) {
    final baseUri = Uri.parse(AppShareService.appUrl);
    final nextQuery = Map<String, String>.from(baseUri.queryParameters)
      ..['ref'] = code
      ..['utm_source'] = 'referral'
      ..['utm_medium'] = 'invite'
      ..['utm_campaign'] = 'growth_mission';
    return baseUri.replace(queryParameters: nextQuery).toString();
  }

  static String buildInviteCopyText({
    required String inviteUrl,
    required int totalRegisteredUsers,
    required int liveViewers,
  }) {
    return '''
自分株式会社を一緒に試してください。
今は登録者 $totalRegisteredUsers 人、現在閲覧 $liveViewers 人です。

招待リンク:
$inviteUrl
''';
  }

  Future<void> capturePendingReferralFromUri({
    Uri? currentUri,
  }) async {
    final refCode =
        (currentUri ?? Uri.base).queryParameters['ref']?.trim().toUpperCase();
    if (refCode == null || refCode.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingReferralCodeKey, refCode);
  }

  Future<String?> loadPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingReferralCodeKey)?.trim().toUpperCase();
    if (code == null || code.isEmpty) {
      return null;
    }
    return code;
  }

  Future<void> clearPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingReferralCodeKey);
  }

  Future<String> ensureGuestSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestSessionIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = const Uuid().v4();
    await prefs.setString(_guestSessionIdKey, created);
    return created;
  }

  Future<void> syncPresence({
    required String pagePath,
  }) async {
    final client = _client;
    if (client == null) {
      return;
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final sessionId = await ensureGuestSessionId();
    final user = client.auth.currentUser;

    try {
      if (user != null) {
        await client.from('user_presence').upsert(
          <String, dynamic>{
            'user_id': user.id,
            'session_id': sessionId,
            'is_online': true,
            'last_seen': nowIso,
            'page_path': pagePath,
          },
          onConflict: 'user_id,session_id',
        );

        await client
            .from('guest_presence')
            .delete()
            .eq('session_id', sessionId);
      } else {
        await client.from('guest_presence').upsert(
          <String, dynamic>{
            'session_id': sessionId,
            'last_seen': nowIso,
            'page_path': pagePath,
          },
          onConflict: 'session_id',
        );
      }
    } catch (error) {
      debugPrint('Growth presence sync failed: $error');
    }

    await refreshAggregateMetrics();
  }

  Future<void> refreshAggregateMetrics() async {
    final client = _client;
    if (client == null) {
      return;
    }

    try {
      await client.rpc('cleanup_old_presence');
    } catch (error) {
      debugPrint('cleanup_old_presence failed: $error');
    }

    try {
      await client.rpc('update_site_statistics');
    } catch (error) {
      debugPrint('update_site_statistics failed: $error');
    }
  }

  Future<ReferralCode?> ensureMyReferralCode() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return null;
    }

    final existingCode = await _fetchMyReferralCode(
      client: client,
      userId: user.id,
    );
    if (existingCode != null) {
      return existingCode;
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      final generatedCode = _generateReferralCode();
      try {
        await client.from('referral_codes').insert(<String, dynamic>{
          'user_id': user.id,
          'referral_code': generatedCode,
        });
        return await _fetchMyReferralCode(client: client, userId: user.id);
      } catch (error) {
        debugPrint('Referral code insert retry $attempt failed: $error');
      }
    }

    return _fetchMyReferralCode(client: client, userId: user.id);
  }

  Future<ReferralCode?> _fetchMyReferralCode({
    required SupabaseClient client,
    required String userId,
  }) async {
    try {
      final existing = await client
          .from('referral_codes')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (existing is Map) {
        return ReferralCode.fromJson(Map<String, dynamic>.from(existing));
      }
    } catch (error) {
      debugPrint('Referral code fetch failed: $error');
    }
    return null;
  }

  Future<void> applyPendingReferralIfPossible() async {
    final client = _client;
    final user = client?.auth.currentUser;
    final pendingCode = await loadPendingReferralCode();
    if (client == null || user == null || pendingCode == null) {
      return;
    }

    try {
      final existing = await client
          .from('referrals')
          .select('id')
          .eq('referred_user_id', user.id)
          .maybeSingle();
      if (existing != null) {
        await clearPendingReferralCode();
        return;
      }

      final referrer = await client
          .from('referral_codes')
          .select('user_id, referral_code')
          .eq('referral_code', pendingCode)
          .maybeSingle();
      if (referrer is! Map) {
        return;
      }

      final referrerUserId = referrer['user_id']?.toString();
      if (referrerUserId == null || referrerUserId == user.id) {
        await clearPendingReferralCode();
        return;
      }

      await client.from('referrals').insert(<String, dynamic>{
        'referrer_user_id': referrerUserId,
        'referred_user_id': user.id,
        'referral_code': pendingCode,
        'bonus_points': 500,
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      });

      await clearPendingReferralCode();
    } catch (error) {
      debugPrint('Applying pending referral failed: $error');
    }
  }

  Future<ReferralGrowthSnapshot> loadReferralSnapshot() async {
    final pendingCode = await loadPendingReferralCode();
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return ReferralGrowthSnapshot(
        myReferralCode: null,
        totalReferrals: 0,
        successfulReferrals: 0,
        pendingReferralCode: pendingCode,
      );
    }

    final myCode = await ensureMyReferralCode();
    try {
      final rows = await client
          .from('referrals')
          .select('status')
          .eq('referrer_user_id', user.id);
      final referralRows = rows;
      final successful = referralRows.where((row) {
        return row['status']?.toString() == 'completed';
      }).length;

      return ReferralGrowthSnapshot(
        myReferralCode: myCode,
        totalReferrals: referralRows.length,
        successfulReferrals: successful,
        pendingReferralCode: pendingCode,
      );
    } catch (error) {
      debugPrint('Referral snapshot failed: $error');
      return ReferralGrowthSnapshot(
        myReferralCode: myCode,
        totalReferrals: 0,
        successfulReferrals: 0,
        pendingReferralCode: pendingCode,
      );
    }
  }

  Future<GrowthMissionDashboard> loadDashboard() async {
    final client = _client;
    if (client == null) {
      return GrowthMissionDashboard.empty();
    }

    await refreshAggregateMetrics();

    final now = DateTime.now();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final activeUserCutoff =
        now.subtract(const Duration(minutes: 5)).toUtc().toIso8601String();
    final guestCutoff =
        now.subtract(const Duration(minutes: 30)).toUtc().toIso8601String();

    try {
      final results = await Future.wait<dynamic>([
        client
            .from('site_statistics')
            .select()
            .order('stat_date', ascending: false)
            .limit(1)
            .maybeSingle(),
        client
            .from('user_presence')
            .select('session_id')
            .eq('is_online', true)
            .gte('last_seen', activeUserCutoff),
        client
            .from('guest_presence')
            .select('session_id')
            .gte('last_seen', guestCutoff),
        client.rpc('get_lp_view_stats'),
        client
            .from('app_analytics')
            .select('share_count')
            .eq('date', todayKey)
            .maybeSingle(),
        loadReferralSnapshot(),
      ]);

      final statRow = results[0] is Map
          ? Map<String, dynamic>.from(results[0] as Map)
          : null;
      final latestStat =
          statRow == null ? null : SiteStatistics.fromJson(statRow);
      final activeUserRows =
          results[1] is List ? results[1] as List<dynamic> : const <dynamic>[];
      final guestRows =
          results[2] is List ? results[2] as List<dynamic> : const <dynamic>[];
      final lpStats = results[3] is Map
          ? Map<String, dynamic>.from(results[3] as Map)
          : <String, dynamic>{};
      final analyticsRow = results[4] is Map
          ? Map<String, dynamic>.from(results[4] as Map)
          : <String, dynamic>{};
      final referralSnapshot = results[5] is ReferralGrowthSnapshot
          ? results[5] as ReferralGrowthSnapshot
          : const ReferralGrowthSnapshot.empty();

      return GrowthMissionDashboard(
        totalRegisteredUsers: latestStat?.totalUsers ?? 0,
        todayRegistrations: latestStat?.newUsersToday ?? 0,
        activeUsersToday: latestStat?.activeUsersToday ?? 0,
        liveRegisteredUsers: activeUserRows.length,
        liveGuestViewers: guestRows.length,
        todayLandingViews: _toIntValue(lpStats['today']),
        monthLandingViews: _toIntValue(lpStats['month']),
        totalLandingViews: _toIntValue(lpStats['total']),
        todayShares: _toIntValue(analyticsRow['share_count']),
        referralSnapshot: referralSnapshot,
        refreshedAt: now,
      );
    } catch (error) {
      debugPrint('Growth dashboard load failed: $error');
      return GrowthMissionDashboard.empty();
    }
  }

  String _generateReferralCode() {
    final random = math.Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      final index = random.nextInt(_referralAlphabet.length);
      buffer.write(_referralAlphabet[index]);
    }
    return buffer.toString();
  }

  int _toIntValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class GrowthPresenceNavigatorObserver extends NavigatorObserver {
  final GrowthMissionService _service;
  Timer? _heartbeatTimer;
  String _currentPagePath = '/';

  GrowthPresenceNavigatorObserver({
    GrowthMissionService service = const GrowthMissionService(),
  }) : _service = service;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackRoute(previousRoute);
    }
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackRoute(newRoute);
    }
  }

  void _trackRoute(Route<dynamic> route) {
    _currentPagePath = _resolvePagePath(route);
    unawaited(_service.capturePendingReferralFromUri());
    unawaited(_service.applyPendingReferralIfPossible());
    unawaited(_service.syncPresence(pagePath: _currentPagePath));

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_service.syncPresence(pagePath: _currentPagePath));
    });
  }

  String _resolvePagePath(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.trim().isNotEmpty) {
      final uri = Uri.tryParse(name);
      if (uri != null && uri.path.trim().isNotEmpty) {
        return uri.path;
      }
      return name;
    }
    return route.runtimeType.toString();
  }
}
