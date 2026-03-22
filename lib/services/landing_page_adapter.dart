import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'landing_share_service.dart';
import 'magi_system_settings_service.dart';

class LandingPageAuthUnavailableException implements Exception {
  const LandingPageAuthUnavailableException();
}

class LandingPageViewPoint {
  final DateTime? date;
  final double count;

  const LandingPageViewPoint({
    required this.date,
    required this.count,
  });
}

class LandingPageViewStats {
  final int todayViews;
  final int monthViews;
  final int totalViews;
  final List<LandingPageViewPoint> series;

  const LandingPageViewStats({
    required this.todayViews,
    required this.monthViews,
    required this.totalViews,
    required this.series,
  });

  const LandingPageViewStats.empty()
      : todayViews = 0,
        monthViews = 0,
        totalViews = 0,
        series = const <LandingPageViewPoint>[];
}

abstract interface class LandingPageAdapter {
  Stream<AuthState> authStateChanges();

  Future<LandingShareSnapshot> loadShareSnapshot();

  Future<LandingShareSnapshot> shareLandingPage({
    required String channel,
  });

  Future<LandingPageViewStats> loadLpViewStats();

  Future<String> improveTrialPrompt({
    required String prompt,
  });

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  });

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<bool> signInWithGoogle({
    String? redirectTo,
  });

  Future<void> sendMagicLink({
    required String email,
    String? emailRedirectTo,
    bool shouldCreateUser = true,
  });

  Future<void> recordTrialRun();

  Future<void> recordSaveCta();

  Future<void> recordInboxOpen();
}

class SupabaseLandingPageAdapter implements LandingPageAdapter {
  final MagiSystemSettingsService _magiSettingsService;

  const SupabaseLandingPageAdapter({
    MagiSystemSettingsService magiSettingsService =
        const MagiSystemSettingsService(),
  }) : _magiSettingsService = magiSettingsService;

  SupabaseClient? get _supabaseClientOrNull {
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }

  GoTrueClient _requireAuthClient() {
    final authClient = _supabaseClientOrNull?.auth;
    if (authClient == null) {
      throw const LandingPageAuthUnavailableException();
    }
    return authClient;
  }

  @override
  Stream<AuthState> authStateChanges() {
    return _supabaseClientOrNull?.auth.onAuthStateChange ??
        const Stream<AuthState>.empty();
  }

  @override
  Future<LandingShareSnapshot> loadShareSnapshot() {
    return LandingShareService.loadSnapshot();
  }

  @override
  Future<LandingShareSnapshot> shareLandingPage({
    required String channel,
  }) async {
    await LandingShareService.shareLandingPage(channel: channel);
    return LandingShareService.recordShareAction(
      channel: channel,
      client: _supabaseClientOrNull,
    );
  }

  @override
  Future<LandingPageViewStats> loadLpViewStats() async {
    final client = _supabaseClientOrNull;
    if (client == null) {
      return const LandingPageViewStats.empty();
    }

    try {
      await client.rpc('increment_lp_view');
      await LandingShareService.recordIncomingShareVisit(client: client);
      final dynamic raw = await client.rpc('get_lp_view_stats');
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final seriesRaw =
          data['series'] is List ? data['series'] as List : const <dynamic>[];

      final series = <LandingPageViewPoint>[];
      for (final rowRaw in seriesRaw) {
        if (rowRaw is! Map) {
          continue;
        }
        final row = Map<String, dynamic>.from(rowRaw);
        final date = DateTime.tryParse(row['date']?.toString() ?? '');
        final count = (row['count'] as num?)?.toDouble() ?? 0;
        series.add(LandingPageViewPoint(date: date, count: count));
      }

      return LandingPageViewStats(
        todayViews: (data['today'] as num?)?.toInt() ?? 0,
        monthViews: (data['month'] as num?)?.toInt() ?? 0,
        totalViews: (data['total'] as num?)?.toInt() ?? 0,
        series: series,
      );
    } catch (error) {
      debugPrint('LP view stats failed: $error');
      return const LandingPageViewStats.empty();
    }
  }

  @override
  Future<String> improveTrialPrompt({
    required String prompt,
  }) async {
    final client = _supabaseClientOrNull;
    if (client == null) {
      throw const LandingPageAuthUnavailableException();
    }

    final response = await client.functions.invoke(
      'ai-assistant',
      body: await _magiSettingsService.buildAiAssistantPayload(
        baseBody: <String, dynamic>{
          'action': 'improve',
          'content': prompt,
        },
      ),
    );
    final data =
        response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
    final result = data['result'];
    if (data['success'] == true && result is String) {
      return result;
    }

    throw Exception(
      data['error']?.toString() ?? 'Landing trial preview failed.',
    );
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) {
    return _requireAuthClient().signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo,
    );
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _requireAuthClient().signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<bool> signInWithGoogle({
    String? redirectTo,
  }) {
    return _requireAuthClient().signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  @override
  Future<void> sendMagicLink({
    required String email,
    String? emailRedirectTo,
    bool shouldCreateUser = true,
  }) async {
    final client = _requireAuthClient();
    await client.signInWithOtp(
      email: email,
      emailRedirectTo: emailRedirectTo,
      shouldCreateUser: shouldCreateUser,
    );
    await LandingShareService.recordFunnelEvent(
      eventKey: LandingShareService.funnelMagicLinkSend,
      client: _supabaseClientOrNull,
    );
  }

  @override
  Future<void> recordTrialRun() {
    return LandingShareService.recordFunnelEvent(
      eventKey: LandingShareService.funnelTrialRun,
      client: _supabaseClientOrNull,
    );
  }

  @override
  Future<void> recordSaveCta() {
    return LandingShareService.recordFunnelEvent(
      eventKey: LandingShareService.funnelSaveCta,
      client: _supabaseClientOrNull,
    );
  }

  @override
  Future<void> recordInboxOpen() {
    return LandingShareService.recordFunnelEvent(
      eventKey: LandingShareService.funnelInboxOpen,
      client: _supabaseClientOrNull,
    );
  }
}
