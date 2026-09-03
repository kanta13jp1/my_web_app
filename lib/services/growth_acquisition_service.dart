import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FirstUserGrowthAttribution {
  const FirstUserGrowthAttribution({
    required this.visitorId,
    required this.utmSource,
    required this.utmMedium,
    required this.utmCampaign,
    required this.utmContent,
    required this.capturedAt,
  });

  static final RegExp _visitorIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _tokenPattern = RegExp(r'^[a-z0-9_-]{1,64}$');
  static const Set<String> supportedSources = <String>{
    'x',
    'zenn',
    'producthunt',
    'hackernews',
  };

  final String visitorId;
  final String utmSource;
  final String utmMedium;
  final String utmCampaign;
  final String utmContent;
  final DateTime capturedAt;

  static FirstUserGrowthAttribution? fromUri({
    required Uri uri,
    required String visitorId,
    DateTime? capturedAt,
  }) {
    final normalizedVisitorId = visitorId.trim().toLowerCase();
    final params = uri.queryParameters;
    final source = _token(params['utm_source']);
    final campaign = _token(params['utm_campaign']);
    if (!_visitorIdPattern.hasMatch(normalizedVisitorId) ||
        !supportedSources.contains(source) ||
        campaign != 'first_user_growth') {
      return null;
    }
    final medium = _token(params['utm_medium'], fallback: 'organic');
    final content = _token(params['utm_content'], fallback: 'unknown');
    if (!_tokenPattern.hasMatch(medium) || !_tokenPattern.hasMatch(content)) {
      return null;
    }
    return FirstUserGrowthAttribution(
      visitorId: normalizedVisitorId,
      utmSource: source,
      utmMedium: medium,
      utmCampaign: campaign,
      utmContent: content,
      capturedAt: (capturedAt ?? DateTime.now()).toUtc(),
    );
  }

  static FirstUserGrowthAttribution? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final visitorId = json['visitor_id']?.toString().trim().toLowerCase() ?? '';
    final source = _token(json['utm_source']);
    final medium = _token(json['utm_medium']);
    final campaign = _token(json['utm_campaign']);
    final content = _token(json['utm_content']);
    final capturedAt = DateTime.tryParse(
      json['captured_at']?.toString() ?? '',
    )?.toUtc();
    if (!_visitorIdPattern.hasMatch(visitorId) ||
        !supportedSources.contains(source) ||
        campaign != 'first_user_growth' ||
        !_tokenPattern.hasMatch(medium) ||
        !_tokenPattern.hasMatch(content) ||
        capturedAt == null) {
      return null;
    }
    return FirstUserGrowthAttribution(
      visitorId: visitorId,
      utmSource: source,
      utmMedium: medium,
      utmCampaign: campaign,
      utmContent: content,
      capturedAt: capturedAt,
    );
  }

  bool isExpired(DateTime now, Duration ttl) {
    return now.toUtc().difference(capturedAt) >= ttl;
  }

  FirstUserGrowthAttribution withVisitorId(String value) {
    final normalized = value.trim().toLowerCase();
    if (!_visitorIdPattern.hasMatch(normalized)) return this;
    return FirstUserGrowthAttribution(
      visitorId: normalized,
      utmSource: utmSource,
      utmMedium: utmMedium,
      utmCampaign: utmCampaign,
      utmContent: utmContent,
      capturedAt: capturedAt,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'version': 1,
        'visitor_id': visitorId,
        'utm_source': utmSource,
        'utm_medium': utmMedium,
        'utm_campaign': utmCampaign,
        'utm_content': utmContent,
        'captured_at': capturedAt.toUtc().toIso8601String(),
      };

  static String _token(Object? value, {String fallback = ''}) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }
}

class GrowthAcquisitionService {
  static const String touchLanding = 'touch_landing';
  static const String touchProfile = 'touch_profile';
  static const String touchXFirstUserGrowth = 'touch_x_first_user_growth';
  static const String touchZennFirstUserGrowth = 'touch_zenn_first_user_growth';
  static const String touchProductHuntFirstUserGrowth =
      'touch_producthunt_first_user_growth';
  static const String touchHackerNewsFirstUserGrowth =
      'touch_hackernews_first_user_growth';
  static const String touchImport = 'touch_import';
  static const String touchPublicMemo = 'touch_public_memo';
  static const String touchReferral = 'touch_referral';
  static const String touchComparison = 'touch_comparison';

  /// R24: 公開データトラッカー (例 `/public/local-election-700`) への着地。
  /// 実測 (X analytics 2026-04-27〜07-25 / 350 投稿) では、サイトへの URL
  /// クリック 304 件のうち 286 件 (94%) がこの公開トラッカーへ着地していた。
  /// これまで着地点にプロダクト導線も計測もなく、最大の流入がそのまま
  /// 行き止まりになっていたため、専用のタッチポイントとして計上する。
  static const String touchPublicTracker = 'touch_public_tracker';

  static const String importPreviewNotion = 'import_preview_notion';
  static const String importPreviewEvernote = 'import_preview_evernote';
  static const String importPreviewMarkdown = 'import_preview_markdown';

  static const String importSignupCta = 'import_signup_cta';
  static const String publicMemoSignupCta = 'public_memo_signup_cta';
  static const String publicTrackerSignupCta = 'public_tracker_signup_cta';

  static const String signupSubmitLanding = 'signup_submit_landing';
  static const String signupSubmitProfile = 'signup_submit_profile';
  static const String signupSubmitXFirstUserGrowth =
      'signup_submit_x_first_user_growth';
  static const String signupSubmitZennFirstUserGrowth =
      'signup_submit_zenn_first_user_growth';
  static const String signupSubmitProductHuntFirstUserGrowth =
      'signup_submit_producthunt_first_user_growth';
  static const String signupSubmitHackerNewsFirstUserGrowth =
      'signup_submit_hackernews_first_user_growth';
  static const String signupSubmitImport = 'signup_submit_import';
  static const String signupSubmitPublicMemo = 'signup_submit_public_memo';
  static const String signupSubmitReferral = 'signup_submit_referral';
  static const String signupSubmitComparison = 'signup_submit_comparison';
  static const String signupSubmitPublicTracker =
      'signup_submit_public_tracker';

  static const String funnelBillingView = 'funnel_billing_view';
  static const String funnelUpgradeClick = 'funnel_upgrade_click';
  static const String funnelCheckoutSuccess = 'funnel_checkout_success';
  static const String funnelCheckoutCancel = 'funnel_checkout_cancel';
  static const Set<String> billingFunnelStages = <String>{
    funnelBillingView,
    funnelUpgradeClick,
    funnelCheckoutSuccess,
    funnelCheckoutCancel,
  };

  static const String _latestTouchpointKey = 'growth_latest_touchpoint';
  static const String _latestTouchpointUpdatedAtKey =
      'growth_latest_touchpoint_updated_at';
  static const String firstUserAttributionStorageKey =
      'growth_first_user_attribution_v1';
  static const Duration firstUserAttributionTtl = Duration(days: 7);
  static const Set<String> firstUserFunnelStages = <String>{
    'view',
    'trial',
    'signup_submit',
    'signup_complete',
    'first_action_completed',
    'billing_view',
    'supporter_checkout',
  };
  static const Set<String> _landingFirstUserFunnelStages = <String>{
    'view',
    'trial',
    'signup_submit',
  };

  final SupabaseClient? _clientOverride;

  const GrowthAcquisitionService({SupabaseClient? clientOverride})
      : _clientOverride = clientOverride;

  SupabaseClient? get _client {
    if (_clientOverride != null) {
      return _clientOverride;
    }
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? signalForPagePath(String pagePath) {
    if (pagePath.startsWith('/vs-')) {
      return touchComparison;
    }
    switch (pagePath) {
      case '/':
      case '/landing':
        return touchLanding;
      case '/import':
        return touchImport;
      case '/public-memo':
      case '/public-memos':
        return touchPublicMemo;
      // 公開トラッカーは UTM 無しの生 URL で共有されてきた実績があるため、
      // ルートパスからも必ず計上する (UTM 付き着地は utm 側の判定が優先)。
      case '/public/local-election-700':
        return touchPublicTracker;
      case '/referral':
        return touchReferral;
      default:
        return null;
    }
  }

  static bool isFirstUserGrowthUri(Uri uri) {
    final params = uri.queryParameters;
    return FirstUserGrowthAttribution.supportedSources.contains(
          _lowerParam(params, 'utm_source'),
        ) &&
        _lowerParam(params, 'utm_campaign') == 'first_user_growth';
  }

  static String? signalForIncomingUri(Uri uri) {
    if (!isFirstUserGrowthUri(uri)) {
      return null;
    }
    switch (_lowerParam(uri.queryParameters, 'utm_source')) {
      case 'zenn':
        return touchZennFirstUserGrowth;
      case 'producthunt':
        return touchProductHuntFirstUserGrowth;
      case 'hackernews':
        return touchHackerNewsFirstUserGrowth;
    }
    switch (_lowerParam(uri.queryParameters, 'utm_medium')) {
      case 'profile':
        return touchProfile;
      default:
        return touchXFirstUserGrowth;
    }
  }

  static String? previewSignalForSourceType(String sourceType) {
    switch (sourceType) {
      case 'notion':
        return importPreviewNotion;
      case 'evernote':
        return importPreviewEvernote;
      case 'markdown':
        return importPreviewMarkdown;
      default:
        return null;
    }
  }

  static String resolveSignupSubmitSignal(String? latestTouchpoint) {
    switch (latestTouchpoint) {
      case touchProfile:
        return signupSubmitProfile;
      case touchXFirstUserGrowth:
        return signupSubmitXFirstUserGrowth;
      case touchZennFirstUserGrowth:
        return signupSubmitZennFirstUserGrowth;
      case touchProductHuntFirstUserGrowth:
        return signupSubmitProductHuntFirstUserGrowth;
      case touchHackerNewsFirstUserGrowth:
        return signupSubmitHackerNewsFirstUserGrowth;
      case touchImport:
        return signupSubmitImport;
      case touchPublicMemo:
        return signupSubmitPublicMemo;
      case touchReferral:
        return signupSubmitReferral;
      case touchComparison:
        return signupSubmitComparison;
      case touchPublicTracker:
        return signupSubmitPublicTracker;
      default:
        return signupSubmitLanding;
    }
  }

  Future<String?> loadLatestTouchpoint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final touchpoint = prefs.getString(_latestTouchpointKey)?.trim();
      if (touchpoint == null || touchpoint.isEmpty) {
        return null;
      }
      return touchpoint;
    } catch (error) {
      debugPrint('Growth touchpoint read failed: $error');
      return null;
    }
  }

  Future<void> recordTouchpointForPagePath(
    String pagePath, {
    Uri? currentUri,
  }) async {
    final signalKey = signalForIncomingUri(currentUri ?? Uri.base) ??
        signalForPagePath(pagePath);
    if (signalKey == null) {
      return;
    }
    await _persistLatestTouchpoint(signalKey);
    await _recordSignal(signalKey);
  }

  Future<void> recordReferralTouch() async {
    await _persistLatestTouchpoint(touchReferral);
    await _recordSignal(touchReferral);
  }

  /// 比較ページ (/vs-*) 訪問時に呼び出す。
  /// [competitorKey] は 'notion' / 'slack' 等のキー。
  /// `touch_comparison_{key}` を記録し、latest touchpoint を `touch_comparison` に設定する。
  Future<void> recordComparisonTouch(String competitorKey) async {
    await _persistLatestTouchpoint(touchComparison);
    await _recordSignal('touch_comparison_$competitorKey');
  }

  Future<void> recordImportPreview(String sourceType) async {
    final signalKey = previewSignalForSourceType(sourceType);
    if (signalKey == null) {
      return;
    }
    await _persistLatestTouchpoint(touchImport);
    await _recordSignal(signalKey);
  }

  Future<void> recordImportSignUpCta() async {
    await _persistLatestTouchpoint(touchImport);
    await _recordSignal(importSignupCta);
  }

  Future<void> recordPublicMemoSignUpCta() async {
    await _persistLatestTouchpoint(touchPublicMemo);
    await _recordSignal(publicMemoSignupCta);
  }

  /// 公開トラッカーの着地ページに置いた「本体を試す」CTA の押下を記録する。
  Future<void> recordPublicTrackerSignUpCta() async {
    await _persistLatestTouchpoint(touchPublicTracker);
    await _recordSignal(publicTrackerSignupCta);
  }

  Future<void> recordLandingSignupSubmit() async {
    final latestTouchpoint = await loadLatestTouchpoint();
    await _recordSignal(resolveSignupSubmitSignal(latestTouchpoint));
  }

  Future<void> recordBillingFunnelStage({required String stage}) async {
    if (!billingFunnelStages.contains(stage)) {
      throw ArgumentError.value(
        stage,
        'stage',
        'Unsupported billing funnel stage',
      );
    }
    await _recordSignal(stage);
  }

  Future<bool> recordFirstUserFunnelStage({
    required String stage,
    String? visitorId,
    Uri? currentUri,
    SharedPreferences? preferences,
    DateTime? now,
  }) async {
    if (!firstUserFunnelStages.contains(stage)) {
      throw ArgumentError.value(
        stage,
        'stage',
        'Unsupported first-user funnel stage',
      );
    }
    final clock = (now ?? DateTime.now()).toUtc();
    final prefs = preferences ?? await SharedPreferences.getInstance();
    FirstUserGrowthAttribution? attribution;

    if (currentUri != null && isFirstUserGrowthUri(currentUri)) {
      final normalizedVisitorId = visitorId?.trim() ?? '';
      attribution = FirstUserGrowthAttribution.fromUri(
        uri: currentUri,
        visitorId: normalizedVisitorId,
        capturedAt: clock,
      );
      if (attribution == null) return false;
      await prefs.setString(
        firstUserAttributionStorageKey,
        jsonEncode(attribution.toJson()),
      );
    } else {
      // A direct/non-campaign LP visit must not inherit an older campaign.
      // Post-auth activation and billing routes intentionally load the stored
      // seven-day attribution because auth redirects strip the original UTM.
      if (_landingFirstUserFunnelStages.contains(stage)) {
        return false;
      }
      attribution = await loadFirstUserAttribution(
        preferences: prefs,
        now: clock,
      );
      if (attribution == null) return false;
      final normalizedVisitorId = visitorId?.trim() ?? '';
      if (normalizedVisitorId.isNotEmpty) {
        attribution = attribution.withVisitorId(normalizedVisitorId);
      }
    }

    final client = _client;
    if (client == null) return false;
    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'acquisition.funnel_signal',
          'stage': stage,
          'visitorId': attribution.visitorId,
          'utmSource': attribution.utmSource,
          'utmMedium': attribution.utmMedium,
          'utmCampaign': attribution.utmCampaign,
          'utmContent': attribution.utmContent,
        },
      );
      final payload = _asMap(response.data);
      return payload['success'] == true || payload['duplicate'] == true;
    } catch (error, stackTrace) {
      debugPrint('First-user funnel signal failed ($stage): $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<FirstUserGrowthAttribution?> loadFirstUserAttribution({
    SharedPreferences? preferences,
    DateTime? now,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final encoded = prefs.getString(firstUserAttributionStorageKey);
    if (encoded == null || encoded.isEmpty) return null;
    FirstUserGrowthAttribution? attribution;
    try {
      attribution = FirstUserGrowthAttribution.fromJson(jsonDecode(encoded));
    } catch (_) {
      attribution = null;
    }
    if (attribution == null ||
        attribution.isExpired(
          (now ?? DateTime.now()).toUtc(),
          firstUserAttributionTtl,
        )) {
      await prefs.remove(firstUserAttributionStorageKey);
      return null;
    }
    return attribution;
  }

  Future<void> notifySignupSuccess({required String? signupUserId}) async {
    final userId = signupUserId?.trim();
    if (userId == null || userId.isEmpty) {
      return;
    }
    final client = _client;
    if (client == null) {
      return;
    }

    final latestTouchpoint = await loadLatestTouchpoint();
    final signalKey = resolveSignupSubmitSignal(latestTouchpoint);
    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'signup.notify',
          'signupUserId': userId,
          'signalKey': signalKey,
          'latestTouchpoint': latestTouchpoint,
        },
      );
      final payload = _asMap(response.data);
      if (payload['success'] == true || payload['skipped'] == true) {
        return;
      }
      debugPrint(
        'Signup Slack notification returned an unexpected payload: $payload',
      );
    } catch (error, stackTrace) {
      debugPrint('Signup Slack notification failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _persistLatestTouchpoint(String signalKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_latestTouchpointKey, signalKey);
      await prefs.setString(
        _latestTouchpointUpdatedAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (error) {
      debugPrint('Growth touchpoint persist failed: $error');
    }
  }

  Future<void> _recordSignal(String signalKey, {DateTime? now}) async {
    final client = _client;
    if (client == null) {
      return;
    }

    final dateKey = _formatDate(now ?? DateTime.now());

    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'acquisition.signal',
          'signalKey': signalKey,
          'dateKey': dateKey,
        },
      );
      final payload = _asMap(response.data);
      if (payload['success'] == true) {
        return;
      }
      debugPrint(
        'Growth acquisition signal returned an unexpected payload: $payload',
      );
    } catch (error, stackTrace) {
      debugPrint('Growth acquisition signal failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static String _lowerParam(Map<String, String> params, String key) {
    return params[key]?.trim().toLowerCase() ?? '';
  }
}
