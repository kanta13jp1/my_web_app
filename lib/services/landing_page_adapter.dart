import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'landing_oauth_callback_failure.dart';
import 'landing_share_service.dart';

class LandingPageAuthUnavailableException implements Exception {
  const LandingPageAuthUnavailableException();
}

enum LandingMagicLinkFailureCategory {
  invalidEmail,
  rateLimit,
  deliveryConfiguration,
  redirectConfiguration,
  network,
  unknown,
}

LandingMagicLinkFailureCategory classifyLandingMagicLinkFailure(Object error) {
  if (error is AuthException) {
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    final status = error.statusCode?.toString() ?? '';

    if (code == 'email_address_invalid' || message.contains('invalid email')) {
      return LandingMagicLinkFailureCategory.invalidEmail;
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        status == '429' ||
        message.contains('rate limit')) {
      return LandingMagicLinkFailureCategory.rateLimit;
    }
    if (code == 'email_provider_disabled' ||
        code == 'signup_disabled' ||
        message.contains('smtp') ||
        message.contains('email provider') ||
        message.contains('email address not authorized') ||
        message.contains('sending email')) {
      return LandingMagicLinkFailureCategory.deliveryConfiguration;
    }
    if (code == 'validation_failed' ||
        code == 'flow_state_expired' ||
        code == 'flow_state_not_found' ||
        message.contains('redirect')) {
      return LandingMagicLinkFailureCategory.redirectConfiguration;
    }
  }

  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('timeout') ||
      text.contains('clientexception')) {
    return LandingMagicLinkFailureCategory.network;
  }
  return LandingMagicLinkFailureCategory.unknown;
}

String landingMagicLinkFailureEventKey(
  LandingMagicLinkFailureCategory category,
) {
  switch (category) {
    case LandingMagicLinkFailureCategory.invalidEmail:
      return LandingShareService.funnelMagicLinkFailInvalidEmail;
    case LandingMagicLinkFailureCategory.rateLimit:
      return LandingShareService.funnelMagicLinkFailRateLimit;
    case LandingMagicLinkFailureCategory.deliveryConfiguration:
      return LandingShareService.funnelMagicLinkFailDeliveryConfig;
    case LandingMagicLinkFailureCategory.redirectConfiguration:
      return LandingShareService.funnelMagicLinkFailRedirect;
    case LandingMagicLinkFailureCategory.network:
      return LandingShareService.funnelMagicLinkFailNetwork;
    case LandingMagicLinkFailureCategory.unknown:
      return LandingShareService.funnelMagicLinkFailUnknown;
  }
}

String landingGoogleOAuthFailureEventKey(
  LandingOAuthCallbackFailureCategory category,
) {
  switch (category) {
    case LandingOAuthCallbackFailureCategory.cancelled:
      return LandingShareService.funnelGoogleOAuthFailCancelled;
    case LandingOAuthCallbackFailureCategory.rateLimited:
      return LandingShareService.funnelGoogleOAuthFailRateLimit;
    case LandingOAuthCallbackFailureCategory.providerConfiguration:
      return LandingShareService.funnelGoogleOAuthFailProviderConfig;
    case LandingOAuthCallbackFailureCategory.redirectConfiguration:
      return LandingShareService.funnelGoogleOAuthFailRedirect;
    case LandingOAuthCallbackFailureCategory.callbackExchange:
      return LandingShareService.funnelGoogleOAuthFailCallbackExchange;
    case LandingOAuthCallbackFailureCategory.unknown:
      return LandingShareService.funnelGoogleOAuthFailUnknown;
  }
}

class LandingTrialPreviewException implements Exception {
  final String code;
  final int? statusCode;
  final bool canUseInstantPreview;

  const LandingTrialPreviewException(
    this.code, {
    this.statusCode,
    this.canUseInstantPreview = false,
  });

  @override
  String toString() =>
      'LandingTrialPreviewException($code, $statusCode, $canUseInstantPreview)';
}

class LandingPageViewPoint {
  final DateTime? date;
  final double count;

  const LandingPageViewPoint({required this.date, required this.count});
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

class LandingSocialProofStats {
  final int totalUsers;
  final int publicMemoCount;

  const LandingSocialProofStats({
    required this.totalUsers,
    required this.publicMemoCount,
  });

  const LandingSocialProofStats.empty()
      : totalUsers = 0,
        publicMemoCount = 0;
}

abstract interface class LandingPageAdapter {
  Stream<AuthState> authStateChanges();

  Future<LandingShareSnapshot> loadShareSnapshot();

  Future<LandingShareSnapshot> shareLandingPage({required String channel});

  Future<LandingPageViewStats> loadLpViewStats();

  Future<LandingSocialProofStats> loadSocialProofStats();

  /// LP 表示を1回記録する (LP View カウンタ + 流入元帰属)。
  ///
  /// 2026-03-28 の LP 改修 (7b92a33d6) で loadLpViewStats ごと呼び出しが
  /// 消えて以来カウンタが凍結していたため、書き込みを読み出しから分離して
  /// LandingPage の initState から明示的に呼ぶ。
  Future<void> recordLpView();

  Future<String> improveTrialPrompt({required String prompt});

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  });

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<bool> signInWithGoogle({String? redirectTo});

  Future<void> recordGoogleOAuthCallbackFailure({
    required LandingOAuthCallbackFailureCategory category,
  });

  Future<void> sendMagicLink({
    required String email,
    String? emailRedirectTo,
    bool shouldCreateUser = true,
  });

  Future<void> recordTrialRun();

  Future<void> recordSaveCta();

  Future<void> recordInboxOpen();

  Future<void> recordConversionEvent({
    required String eventKey,
    required String visitorId,
  });
}

class SupabaseLandingPageAdapter implements LandingPageAdapter {
  const SupabaseLandingPageAdapter();

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
  Future<void> recordLpView() async {
    final client = _supabaseClientOrNull;
    if (client == null) {
      return;
    }
    try {
      await client.rpc('increment_lp_view');
      await LandingShareService.recordIncomingShareVisit(client: client);
    } catch (error) {
      // 計測失敗で LP 表示自体を妨げない。
      debugPrint('LP view record failed: $error');
    }
  }

  @override
  Future<LandingPageViewStats> loadLpViewStats() async {
    final client = _supabaseClientOrNull;
    if (client == null) {
      return const LandingPageViewStats.empty();
    }

    try {
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
  Future<LandingSocialProofStats> loadSocialProofStats() async {
    final client = _supabaseClientOrNull;
    if (client == null) {
      return const LandingSocialProofStats.empty();
    }

    var totalUsers = 0;
    var publicMemoCount = 0;

    try {
      final row = await client
          .from('site_statistics')
          .select('total_users')
          .order('stat_date', ascending: false)
          .limit(1)
          .maybeSingle();
      totalUsers = (row?['total_users'] as num?)?.toInt() ?? 0;
    } catch (error) {
      debugPrint('Public site statistics load failed: $error');
    }

    if (totalUsers <= 0) {
      try {
        final row = await client
            .from('growth_metrics')
            .select('total_users')
            .order('metric_date', ascending: false)
            .limit(1)
            .maybeSingle();
        totalUsers = (row?['total_users'] as num?)?.toInt() ?? 0;
      } catch (error) {
        debugPrint('Public growth metrics fallback failed: $error');
      }
    }

    try {
      final response = await client
          .from('public_memos')
          .select('id')
          .eq('is_public', true)
          .count(CountOption.exact);
      publicMemoCount = response.count;
    } catch (error) {
      debugPrint('Public memo count load failed: $error');
    }

    return LandingSocialProofStats(
      totalUsers: totalUsers < 0 ? 0 : totalUsers,
      publicMemoCount: publicMemoCount < 0 ? 0 : publicMemoCount,
    );
  }

  @override
  Future<String> improveTrialPrompt({required String prompt}) async {
    final client = _supabaseClientOrNull;
    if (client == null) {
      throw const LandingPageAuthUnavailableException();
    }

    late final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{'action': 'landing.trial', 'prompt': prompt},
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final errorCode =
          details is Map ? details['error']?.toString().trim() : null;
      final canUseInstantPreview =
          details is Map && details['canUseInstantPreview'] == true;
      throw LandingTrialPreviewException(
        (errorCode == null || errorCode.isEmpty)
            ? 'trial_ai_unavailable'
            : errorCode,
        statusCode: error.status,
        canUseInstantPreview: canUseInstantPreview,
      );
    }
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : Map<String, dynamic>.from(response.data as Map);
    final action = data['action']?.toString().trim() ?? '';
    final reason = data['reason']?.toString().trim() ?? '';
    if (data['success'] == true && action.isNotEmpty && reason.isNotEmpty) {
      return 'ACTION: $action\nREASON: $reason';
    }

    throw LandingTrialPreviewException(
      data['error']?.toString().trim().isNotEmpty == true
          ? data['error'].toString().trim()
          : 'trial_ai_unavailable',
      statusCode: response.status,
      canUseInstantPreview: data['canUseInstantPreview'] == true,
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
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    final launched = await _requireAuthClient().signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
    if (launched) {
      await _recordFunnelEventBestEffort(
        LandingShareService.funnelGoogleOAuthStart,
      );
    }
    return launched;
  }

  @override
  Future<void> recordGoogleOAuthCallbackFailure({
    required LandingOAuthCallbackFailureCategory category,
  }) {
    return _recordFunnelEventBestEffort(
      landingGoogleOAuthFailureEventKey(category),
    );
  }

  @override
  Future<void> sendMagicLink({
    required String email,
    String? emailRedirectTo,
    bool shouldCreateUser = true,
  }) async {
    final client = _requireAuthClient();
    await _recordFunnelEventBestEffort(
      LandingShareService.funnelMagicLinkAttempt,
    );
    try {
      await client.signInWithOtp(
        email: email,
        emailRedirectTo: emailRedirectTo,
        shouldCreateUser: shouldCreateUser,
      );
      await _recordFunnelEventBestEffort(
        LandingShareService.funnelMagicLinkSend,
      );
    } catch (error) {
      await _recordFunnelEventBestEffort(
        landingMagicLinkFailureEventKey(classifyLandingMagicLinkFailure(error)),
      );
      rethrow;
    }
  }

  Future<void> _recordFunnelEventBestEffort(String eventKey) async {
    try {
      await LandingShareService.recordFunnelEvent(
        eventKey: eventKey,
        client: _supabaseClientOrNull,
      );
    } catch (error) {
      debugPrint('Landing auth funnel analytics failed: $error');
    }
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

  @override
  Future<void> recordConversionEvent({
    required String eventKey,
    required String visitorId,
  }) async {
    final client = _supabaseClientOrNull;
    await LandingShareService.recordFunnelEvent(
      eventKey: eventKey,
      client: client,
    );
    if (client == null) {
      return;
    }

    try {
      await client.rpc(
        'record_landing_experiment_event',
        params: <String, dynamic>{
          'p_visitor_id': visitorId,
          'p_event_key': eventKey,
        },
      );
    } catch (error) {
      debugPrint('Unique LP experiment event failed: $error');
    }
  }
}
