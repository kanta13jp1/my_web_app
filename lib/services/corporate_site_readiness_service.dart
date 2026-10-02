import 'package:supabase_flutter/supabase_flutter.dart';

typedef CorporateSiteAiHubInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class CorporateSiteReadinessInput {
  const CorporateSiteReadinessInput({
    required this.url,
    required this.companyName,
    required this.representativeName,
    required this.registeredAddress,
    required this.businessPlanSummary,
    required this.contact,
    required this.wbsMilestones,
    this.virtualOffice = false,
  });

  final String url;
  final String companyName;
  final String representativeName;
  final String registeredAddress;
  final String businessPlanSummary;
  final String contact;
  final List<String> wbsMilestones;
  final bool virtualOffice;

  Map<String, dynamic> toRequest({required String mode}) => <String, dynamic>{
        'action': 'corporate_site.readiness',
        'mode': mode,
        'url': url.trim(),
        'company_name': companyName.trim(),
        'representative_name': representativeName.trim(),
        'registered_address': registeredAddress.trim(),
        'business_plan_summary': businessPlanSummary.trim(),
        'contact': contact.trim(),
        'wbs_milestones': wbsMilestones
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(20)
            .toList(growable: false),
        'virtual_office': virtualOffice,
      };
}

class CorporateSiteReadinessCheck {
  const CorporateSiteReadinessCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.required,
    required this.guidance,
    this.evidence,
  });

  final String id;
  final String label;
  final String status;
  final bool required;
  final String guidance;
  final String? evidence;

  bool get isPresent => status == 'present';
  bool get isMissing => status == 'missing';
  bool get isManualReview => status == 'manual_review';

  factory CorporateSiteReadinessCheck.fromJson(Map<String, dynamic> json) {
    return CorporateSiteReadinessCheck(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      status: json['status']?.toString() ?? 'manual_review',
      required: json['required'] == true,
      guidance: json['guidance']?.toString() ?? '',
      evidence: _optionalString(json['evidence']),
    );
  }
}

class CorporateSiteReadinessReport {
  const CorporateSiteReadinessReport({
    required this.readyForDocumentReview,
    required this.score,
    required this.checks,
    required this.missingRequiredItems,
    required this.manualReviewItems,
    required this.disclaimer,
    required this.canonicalUrl,
    required this.sourceTitle,
  });

  final bool readyForDocumentReview;
  final int score;
  final List<CorporateSiteReadinessCheck> checks;
  final List<String> missingRequiredItems;
  final List<String> manualReviewItems;
  final String disclaimer;
  final String canonicalUrl;
  final String sourceTitle;

  factory CorporateSiteReadinessReport.fromJson(Map<String, dynamic> json) {
    final result = _asMap(json['result']);
    final source = _asMap(json['source']);
    return CorporateSiteReadinessReport(
      readyForDocumentReview: result['ready_for_document_review'] == true,
      score: _asInt(result['score']).clamp(0, 100).toInt(),
      checks: _asList(result['checks'])
          .whereType<Map>()
          .map(
            (value) => CorporateSiteReadinessCheck.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList(growable: false),
      missingRequiredItems: _asStringList(result['missing_required_items']),
      manualReviewItems: _asStringList(result['manual_review_items']),
      disclaimer: result['disclaimer']?.toString() ?? '',
      canonicalUrl: source['canonical_url']?.toString() ?? '',
      sourceTitle: source['title']?.toString() ?? '',
    );
  }
}

abstract class CorporateSiteReadinessGateway {
  Future<CorporateSiteReadinessReport> review(
    CorporateSiteReadinessInput input,
  );

  Future<String> generateHtml(CorporateSiteReadinessInput input);
}

class CorporateSiteReadinessService implements CorporateSiteReadinessGateway {
  const CorporateSiteReadinessService({
    SupabaseClient? supabaseClient,
    CorporateSiteAiHubInvoker? invoker,
  })  : _supabaseClient = supabaseClient,
        _invoker = invoker;

  final SupabaseClient? _supabaseClient;
  final CorporateSiteAiHubInvoker? _invoker;

  SupabaseClient get _supabase => _supabaseClient ?? Supabase.instance.client;

  @override
  Future<CorporateSiteReadinessReport> review(
    CorporateSiteReadinessInput input,
  ) async {
    final payload = await _invoke(input.toRequest(mode: 'review'));
    _requireSuccess(payload);
    return CorporateSiteReadinessReport.fromJson(payload);
  }

  @override
  Future<String> generateHtml(CorporateSiteReadinessInput input) async {
    final payload = await _invoke(input.toRequest(mode: 'generate'));
    _requireSuccess(payload);
    final html = payload['html']?.toString() ?? '';
    if (html.trim().isEmpty) {
      throw const FormatException('生成されたHTMLが空です。');
    }
    return html;
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return invoker(body);
    final response = await _supabase.functions.invoke('ai-hub', body: body);
    return _asMap(response.data);
  }

  static void _requireSuccess(Map<String, dynamic> payload) {
    if (payload['success'] == true) return;
    final message = payload['message']?.toString() ??
        payload['error']?.toString() ??
        '法人口座向けサイト処理に失敗しました。';
    throw StateError(message);
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('AI Hub response must be an object.');
}

List<dynamic> _asList(Object? value) => value is List ? value : const [];

List<String> _asStringList(Object? value) => _asList(value)
    .map((item) => item?.toString().trim() ?? '')
    .where((item) => item.isNotEmpty)
    .toList(growable: false);

int _asInt(Object? value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
