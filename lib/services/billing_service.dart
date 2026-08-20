import 'package:supabase_flutter/supabase_flutter.dart';

import 'growth_acquisition_service.dart';

class BillingServiceException implements Exception {
  BillingServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BillingServiceException($statusCode): $message';
}

class BillingStatus {
  static const int freeAiQueryLimit = 30;

  const BillingStatus({
    required this.tier,
    required this.status,
    required this.aiQueryCount,
    required this.efCallCount,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  final String tier;
  final String status;
  final int aiQueryCount;
  final int efCallCount;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  bool get isPro => tier == 'pro' || tier == 'team';

  int get remainingAiQueries =>
      (freeAiQueryLimit - aiQueryCount).clamp(0, freeAiQueryLimit).toInt();

  double get aiQueryUsageRatio =>
      (aiQueryCount / freeAiQueryLimit).clamp(0.0, 1.0).toDouble();

  factory BillingStatus.fromJson(Map<String, dynamic> json) {
    final billing = _asMap(json['billing']);
    final usage = _asMap(json['usage']);
    return BillingStatus(
      tier: billing['tier']?.toString() ?? 'free',
      status: billing['status']?.toString() ?? 'active',
      aiQueryCount: _asInt(usage['ai_query_count']),
      efCallCount: _asInt(usage['ef_call_count']),
      currentPeriodEnd: _parseDate(billing['current_period_end']),
      cancelAtPeriodEnd: billing['cancel_at_period_end'] == true,
    );
  }
}

class BillingCheckoutSession {
  const BillingCheckoutSession({required this.url, this.id});

  final String url;
  final String? id;

  factory BillingCheckoutSession.fromJson(Map<String, dynamic> json) {
    final url = json['checkout_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw BillingServiceException('Stripe Checkout URL が返されませんでした');
    }
    return BillingCheckoutSession(url: url, id: json['id']?.toString());
  }
}

class BillingCheckoutAttribution {
  const BillingCheckoutAttribution({
    this.latestTouchpoint,
    this.signupSignal,
    this.referralChannel,
  });

  final String? latestTouchpoint;
  final String? signupSignal;
  final String? referralChannel;

  factory BillingCheckoutAttribution.fromLatestTouchpoint(
    String? latestTouchpoint,
  ) {
    final normalized = latestTouchpoint?.trim();
    final touchpoint =
        normalized == null || normalized.isEmpty ? null : normalized;
    final signupSignal = GrowthAcquisitionService.resolveSignupSubmitSignal(
      touchpoint,
    );
    final isReferral = touchpoint == GrowthAcquisitionService.touchReferral ||
        signupSignal == GrowthAcquisitionService.signupSubmitReferral;
    return BillingCheckoutAttribution(
      latestTouchpoint: touchpoint,
      signupSignal: signupSignal,
      referralChannel: isReferral ? 'referral' : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    void add(String key, String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return;
      json[key] =
          normalized.length > 160 ? normalized.substring(0, 160) : normalized;
    }

    add('latest_touchpoint', latestTouchpoint);
    add('signup_signal', signupSignal);
    add('referral_channel', referralChannel);
    return json;
  }
}

class BillingSupporterAttribution {
  const BillingSupporterAttribution({
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
    this.experimentKey,
    this.variant,
    this.sourceLogId,
    this.landingTouchpoint,
  });

  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;
  final String? experimentKey;
  final String? variant;
  final String? sourceLogId;
  final String? landingTouchpoint;

  factory BillingSupporterAttribution.fromUri(
    Uri uri, {
    String landingTouchpoint = 'subscription_billing',
    String? fallbackTouchpoint,
    FirstUserGrowthAttribution? firstUserAttribution,
  }) {
    final params = uri.queryParameters;
    final isXProfile =
        fallbackTouchpoint == GrowthAcquisitionService.touchProfile;
    final isXFirstUserGrowth = firstUserAttribution != null ||
        isXProfile ||
        fallbackTouchpoint == GrowthAcquisitionService.touchXFirstUserGrowth;
    return BillingSupporterAttribution(
      utmSource: params['utm_source'] ??
          firstUserAttribution?.utmSource ??
          (isXFirstUserGrowth ? 'x' : null),
      utmMedium: params['utm_medium'] ??
          firstUserAttribution?.utmMedium ??
          (isXFirstUserGrowth ? (isXProfile ? 'profile' : 'organic') : null),
      utmCampaign: params['utm_campaign'] ??
          firstUserAttribution?.utmCampaign ??
          (isXFirstUserGrowth ? 'first_user_growth' : null),
      utmContent: params['utm_content'] ??
          firstUserAttribution?.utmContent ??
          (isXFirstUserGrowth ? 'activation_to_paid' : null),
      experimentKey: params['experiment_key'] ??
          params['utm_campaign'] ??
          firstUserAttribution?.utmCampaign ??
          (isXFirstUserGrowth ? 'first_user_growth' : null),
      variant: params['variant'] ??
          params['utm_content'] ??
          firstUserAttribution?.utmContent ??
          (isXFirstUserGrowth ? 'activation_to_paid' : null),
      sourceLogId: params['source_log_id'] ?? params['x_post_log_id'],
      landingTouchpoint: fallbackTouchpoint ?? landingTouchpoint,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    void add(String key, String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return;
      json[key] =
          normalized.length > 160 ? normalized.substring(0, 160) : normalized;
    }

    add('utm_source', utmSource);
    add('utm_medium', utmMedium);
    add('utm_campaign', utmCampaign);
    add('utm_content', utmContent);
    add('experiment_key', experimentKey);
    add('variant', variant);
    add('source_log_id', sourceLogId);
    add('landing_touchpoint', landingTouchpoint);
    return json;
  }
}

class BillingPortalSession {
  const BillingPortalSession({required this.url, this.id});

  final String url;
  final String? id;

  factory BillingPortalSession.fromJson(Map<String, dynamic> json) {
    final url = json['portal_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw BillingServiceException('Stripe Portal URL が返されませんでした');
    }
    return BillingPortalSession(url: url, id: json['id']?.toString());
  }
}

abstract class BillingGateway {
  Future<BillingStatus> fetchStatus();

  Future<BillingCheckoutSession> createCheckoutSession({
    required String tier,
    required String returnUrl,
    BillingCheckoutAttribution attribution = const BillingCheckoutAttribution(),
  });

  Future<BillingCheckoutSession> createSupporterCheckoutSession({
    required String returnUrl,
    BillingSupporterAttribution attribution =
        const BillingSupporterAttribution(),
  });

  Future<BillingPortalSession> createPortalSession({required String returnUrl});
}

class BillingService implements BillingGateway {
  BillingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<BillingStatus> fetchStatus() async {
    final data = await _invokeBillingAction('billing.status', {});
    return BillingStatus.fromJson(data);
  }

  @override
  Future<BillingCheckoutSession> createCheckoutSession({
    required String tier,
    required String returnUrl,
    BillingCheckoutAttribution attribution = const BillingCheckoutAttribution(),
  }) async {
    final data = await _invokeBillingAction('billing.create_checkout_session', {
      'tier': tier,
      'return_url': returnUrl,
      ...attribution.toJson(),
    });
    return BillingCheckoutSession.fromJson(data);
  }

  @override
  Future<BillingCheckoutSession> createSupporterCheckoutSession({
    required String returnUrl,
    BillingSupporterAttribution attribution =
        const BillingSupporterAttribution(),
  }) async {
    final data = await _invokeBillingAction(
      'billing.create_supporter_checkout_session',
      {'return_url': returnUrl, ...attribution.toJson()},
    );
    return BillingCheckoutSession.fromJson(data);
  }

  @override
  Future<BillingPortalSession> createPortalSession({
    required String returnUrl,
  }) async {
    final data = await _invokeBillingAction('billing.create_portal_session', {
      'return_url': returnUrl,
    });
    return BillingPortalSession.fromJson(data);
  }

  Future<Map<String, dynamic>> _invokeBillingAction(
    String action,
    Map<String, dynamic> params,
  ) async {
    final res = await _client.functions.invoke(
      'schedule-hub',
      body: {'action': action, ...params},
    );
    final data = _asMap(res.data);
    if (res.status != 200 || data['success'] == false) {
      final message = data['error']?.toString() ?? 'HTTP ${res.status}';
      throw BillingServiceException(message, statusCode: res.status);
    }
    return data;
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDate(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : DateTime.tryParse(text);
}
