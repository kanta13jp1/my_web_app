import 'package:supabase_flutter/supabase_flutter.dart';

class BillingServiceException implements Exception {
  BillingServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BillingServiceException($statusCode): $message';
}

class BillingStatus {
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

class BillingService {
  BillingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<BillingStatus> fetchStatus() async {
    final data = await _invokeBillingAction('billing.status', {});
    return BillingStatus.fromJson(data);
  }

  Future<BillingCheckoutSession> createCheckoutSession({
    required String tier,
    required String returnUrl,
  }) async {
    final data = await _invokeBillingAction('billing.create_checkout_session', {
      'tier': tier,
      'return_url': returnUrl,
    });
    return BillingCheckoutSession.fromJson(data);
  }

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
