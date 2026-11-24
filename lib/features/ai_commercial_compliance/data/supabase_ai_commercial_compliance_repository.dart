import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_commercial_compliance_models.dart';

/// 商用利用ライセンス・著作権コンプライアンスリポジトリ抽象 (#2664).
abstract class AiCommercialComplianceRepository {
  Future<AiComplianceDashboardData> fetchDashboardData();

  Future<AiCommercialAssetSubmission> submitComplianceConsent(
    final SubmitCommercialComplianceInput input,
  );

  Future<AiComplianceRule> upsertChecklistRule(
    final UpsertComplianceRuleInput input,
  );
}

/// Supabase RPC / テーブル経由で動的チェックリストと同意監査ログを永続化する実装 (#2664).
class SupabaseAiCommercialComplianceRepository
    implements AiCommercialComplianceRepository {
  SupabaseAiCommercialComplianceRepository({final SupabaseClient? client})
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Map<String, Object?> _normalizeMap(final Map<Object?, Object?> raw) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in raw.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }

  List<Map<String, Object?>> _extractRows(final List<Object?> rows) {
    return rows.whereType<Map<Object?, Object?>>().map(_normalizeMap).toList();
  }

  @override
  Future<AiComplianceDashboardData> fetchDashboardData() async {
    final User? user = _client.auth.currentUser;
    bool isAdmin = false;
    if (user != null) {
      final List<Object?> profileRows = await _client
          .from('user_profiles')
          .select('is_admin')
          .eq('user_id', user.id)
          .limit(1);
      final List<Map<String, Object?>> normalized = _extractRows(profileRows);
      isAdmin = normalized.isNotEmpty && normalized.first['is_admin'] == true;
    }

    final List<Object?> ruleRows = await _client
        .from('ai_compliance_checklist_rules')
        .select()
        .order('sort_order', ascending: true);
    final List<Object?> subRows = await _client
        .from('ai_commercial_asset_submissions')
        .select()
        .order('created_at', ascending: false)
        .limit(40);
    final List<Object?> auditRows = await _client
        .from('ai_compliance_consent_audit_logs')
        .select()
        .order('consented_at', ascending: false)
        .limit(40);

    return AiComplianceDashboardData(
      isAdmin: isAdmin,
      rules: _extractRows(ruleRows).map(AiComplianceRule.fromMap).toList(),
      submissions: _extractRows(subRows)
          .map(AiCommercialAssetSubmission.fromMap)
          .toList(),
      auditLogs: _extractRows(auditRows)
          .map(AiComplianceConsentAuditLog.fromMap)
          .toList(),
    );
  }

  @override
  Future<AiCommercialAssetSubmission> submitComplianceConsent(
    final SubmitCommercialComplianceInput input,
  ) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('コンプライアンス同意の記録にはログインが必要です。');
    }

    final Map<String, Object?> rpcResult = _normalizeMap(
      await _client.rpc(
        'submit_ai_commercial_compliance',
        params: <String, Object?>{
          'p_asset_title': input.assetTitle.trim(),
          'p_ai_provider': input.aiProvider.wireName,
          'p_plan_tier_at_generation': input.planTier.wireName,
          'p_commercial_license_verified': input.commercialLicenseVerified,
          'p_copyright_non_similarity_confirmed':
              input.copyrightNonSimilarityConfirmed,
          'p_accepted_rule_ids': input.acceptedRuleIds.toList()..sort(),
        },
      ) as Map<Object?, Object?>,
    );
    return AiCommercialAssetSubmission.fromMap(rpcResult);
  }

  @override
  Future<AiComplianceRule> upsertChecklistRule(
    final UpsertComplianceRuleInput input,
  ) async {
    final String? validationError = input.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final Map<String, Object?> rpcResult = _normalizeMap(
      await _client.rpc(
        'upsert_ai_compliance_checklist_rule',
        params: <String, Object?>{
          'p_rule_key': input.ruleKey.trim().toLowerCase(),
          'p_ai_provider': input.aiProvider.wireName,
          'p_title': input.title.trim(),
          'p_disclaimer_body': input.disclaimerBody.trim(),
          'p_is_required': input.isRequired,
          'p_is_active': input.isActive,
          'p_sort_order': input.sortOrder,
          'p_terms_version': input.termsVersion.trim(),
        },
      ) as Map<Object?, Object?>,
    );
    return AiComplianceRule.fromMap(rpcResult);
  }
}
