import 'package:flutter/foundation.dart';

/// 商用利用チェック対象の AI 生成ツール種別 (#2664).
enum ComplianceAiProvider {
  elevenlabs('elevenlabs', 'ElevenLabs'),
  leonardoAi('leonardo_ai', 'Leonardo.Ai'),
  did('d_id', 'D-ID'),
  general('general', '汎用 / 共通');

  const ComplianceAiProvider(this.wireName, this.labelJa);

  final String wireName;
  final String labelJa;

  static ComplianceAiProvider fromWire(final String raw) {
    final String normalized = raw.trim().toLowerCase();
    for (final ComplianceAiProvider item in ComplianceAiProvider.values) {
      if (item.wireName == normalized) {
        return item;
      }
    }
    return ComplianceAiProvider.general;
  }
}

/// 生成時点の契約プラン区分 (#2664).
enum GenerationPlanTier {
  free('free', 'Free (商用利用不可)'),
  paid('paid', 'Paid / Pro (商用利用可)'),
  enterprise('enterprise', 'Enterprise (商用・専有契約)');

  const GenerationPlanTier(this.wireName, this.labelJa);

  final String wireName;
  final String labelJa;

  bool get isCommercialAllowed => this != GenerationPlanTier.free;

  static GenerationPlanTier fromWire(final String raw) {
    final String normalized = raw.trim().toLowerCase();
    for (final GenerationPlanTier tier in GenerationPlanTier.values) {
      if (tier.wireName == normalized) {
        return tier;
      }
    }
    return GenerationPlanTier.free;
  }
}

/// 動的コンプライアンスチェック項目と免責事項 (#2664).
@immutable
class AiComplianceRule {
  const AiComplianceRule({
    required this.id,
    required this.ruleKey,
    required this.aiProvider,
    required this.title,
    required this.disclaimerBody,
    required this.isRequired,
    required this.isActive,
    required this.sortOrder,
    required this.termsVersion,
  });

  factory AiComplianceRule.fromMap(final Map<String, Object?> row) {
    return AiComplianceRule(
      id: (row['id']?.toString() ?? '').trim(),
      ruleKey: (row['rule_key']?.toString() ?? '').trim(),
      aiProvider: ComplianceAiProvider.fromWire(
        row['ai_provider']?.toString() ?? 'general',
      ),
      title: (row['title']?.toString() ?? '').trim(),
      disclaimerBody: (row['disclaimer_body']?.toString() ?? '').trim(),
      isRequired: row['is_required'] != false,
      isActive: row['is_active'] != false,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
      termsVersion: (row['terms_version']?.toString() ?? '2026-11').trim(),
    );
  }

  final String id;
  final String ruleKey;
  final ComplianceAiProvider aiProvider;
  final String title;
  final String disclaimerBody;
  final bool isRequired;
  final bool isActive;
  final int sortOrder;
  final String termsVersion;

  bool appliesTo(final ComplianceAiProvider targetProvider) {
    if (!isActive) {
      return false;
    }
    return aiProvider == ComplianceAiProvider.general ||
        aiProvider == targetProvider;
  }
}

/// 提出・審査済み商用 AI 生成アセット記録 (#2664).
@immutable
class AiCommercialAssetSubmission {
  const AiCommercialAssetSubmission({
    required this.id,
    required this.assetTitle,
    required this.aiProvider,
    required this.planTier,
    required this.commercialLicenseVerified,
    required this.copyrightNonSimilarityConfirmed,
    required this.publishStatus,
    required this.createdAt,
  });

  factory AiCommercialAssetSubmission.fromMap(final Map<String, Object?> row) {
    return AiCommercialAssetSubmission(
      id: (row['id']?.toString() ?? '').trim(),
      assetTitle: (row['asset_title']?.toString() ?? '').trim(),
      aiProvider: ComplianceAiProvider.fromWire(
        row['ai_provider']?.toString() ?? 'general',
      ),
      planTier: GenerationPlanTier.fromWire(
        row['plan_tier_at_generation']?.toString() ?? 'free',
      ),
      commercialLicenseVerified: row['commercial_license_verified'] == true,
      copyrightNonSimilarityConfirmed:
          row['copyright_non_similarity_confirmed'] == true,
      publishStatus: (row['publish_status']?.toString() ?? 'draft').trim(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String assetTitle;
  final ComplianceAiProvider aiProvider;
  final GenerationPlanTier planTier;
  final bool commercialLicenseVerified;
  final bool copyrightNonSimilarityConfirmed;
  final String publishStatus;
  final DateTime createdAt;
}

/// 改ざん不可の同意監査ログ記録 (#2664).
@immutable
class AiComplianceConsentAuditLog {
  const AiComplianceConsentAuditLog({
    required this.id,
    required this.submissionId,
    required this.userId,
    required this.acceptedRuleKeys,
    required this.consentedAt,
  });

  factory AiComplianceConsentAuditLog.fromMap(final Map<String, Object?> row) {
    final List<String> keys = <String>[];
    if (row['accepted_rule_keys'] is List<Object?>) {
      for (final String item
          in (row['accepted_rule_keys'] as List<Object?>).whereType<String>()) {
        keys.add(item);
      }
    }
    return AiComplianceConsentAuditLog(
      id: (row['id']?.toString() ?? '').trim(),
      submissionId: (row['submission_id']?.toString() ?? '').trim(),
      userId: (row['user_id']?.toString() ?? '').trim(),
      acceptedRuleKeys: keys,
      consentedAt: DateTime.tryParse(row['consented_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String submissionId;
  final String userId;
  final List<String> acceptedRuleKeys;
  final DateTime consentedAt;
}

/// 動的コンプライアンス画面のロードスナップショット (#2664).
@immutable
class AiComplianceDashboardData {
  const AiComplianceDashboardData({
    required this.isAdmin,
    required this.rules,
    required this.submissions,
    required this.auditLogs,
  });

  final bool isAdmin;
  final List<AiComplianceRule> rules;
  final List<AiCommercialAssetSubmission> submissions;
  final List<AiComplianceConsentAuditLog> auditLogs;
}

/// 同意提出時のバリデーション入力 (#2664).
@immutable
class SubmitCommercialComplianceInput {
  const SubmitCommercialComplianceInput({
    required this.assetTitle,
    required this.aiProvider,
    required this.planTier,
    required this.commercialLicenseVerified,
    required this.copyrightNonSimilarityConfirmed,
    required this.acceptedRuleIds,
  });

  final String assetTitle;
  final ComplianceAiProvider aiProvider;
  final GenerationPlanTier planTier;
  final bool commercialLicenseVerified;
  final bool copyrightNonSimilarityConfirmed;
  final Set<String> acceptedRuleIds;

  String? validateAgainstRules(final List<AiComplianceRule> rules) {
    if (assetTitle.trim().isEmpty) {
      return '公開・アップロードする AI 素材タイトルを入力してください。';
    }
    if (!planTier.isCommercialAllowed) {
      return 'Free プランで生成された素材は商用公開できません (生成後課金での遡及適用も不可)。';
    }
    if (!commercialLicenseVerified) {
      return '商用ライセンス保有確認にチェックを入れてください。';
    }
    if (!copyrightNonSimilarityConfirmed) {
      return '著作権侵害 (依拠性・類似性) 非該当確認にチェックを入れてください。';
    }
    final List<AiComplianceRule> requiredApplicable = rules
        .where(
          (final AiComplianceRule r) => r.appliesTo(aiProvider) && r.isRequired,
        )
        .toList();
    for (final AiComplianceRule rule in requiredApplicable) {
      if (!acceptedRuleIds.contains(rule.id)) {
        return '必須チェック項目「${rule.title}」への同意が必要です。';
      }
    }
    return null;
  }
}

/// 管理者によるチェック項目動的追加・更新入力 (#2664).
@immutable
class UpsertComplianceRuleInput {
  const UpsertComplianceRuleInput({
    required this.ruleKey,
    required this.aiProvider,
    required this.title,
    required this.disclaimerBody,
    this.isRequired = true,
    this.isActive = true,
    this.sortOrder = 50,
    this.termsVersion = '2026-11',
  });

  final String ruleKey;
  final ComplianceAiProvider aiProvider;
  final String title;
  final String disclaimerBody;
  final bool isRequired;
  final bool isActive;
  final int sortOrder;
  final String termsVersion;

  String? validate() {
    final String key = ruleKey.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,80}$').hasMatch(key)) {
      return 'ルールキーは 3〜80 文字の半角小文字英数字・アンダースコアにしてください。';
    }
    if (title.trim().isEmpty || disclaimerBody.trim().isEmpty) {
      return 'タイトルおよび免責事項本文は必須です。';
    }
    return null;
  }
}

/// AI 商用・著作権コンプライアンス管理画面のイミュータブル状態 (#2664).
@immutable
class AiCommercialComplianceState {
  const AiCommercialComplianceState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isAdmin = false,
    this.errorMessage,
    this.lastClearedSubmissionId,
    this.selectedProvider = ComplianceAiProvider.elevenlabs,
    this.selectedPlanTier = GenerationPlanTier.paid,
    this.commercialLicenseVerified = false,
    this.copyrightNonSimilarityConfirmed = false,
    this.acceptedRuleIds = const <String>{},
    this.rules = const <AiComplianceRule>[],
    this.submissions = const <AiCommercialAssetSubmission>[],
    this.auditLogs = const <AiComplianceConsentAuditLog>[],
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isAdmin;
  final String? errorMessage;
  final String? lastClearedSubmissionId;
  final ComplianceAiProvider selectedProvider;
  final GenerationPlanTier selectedPlanTier;
  final bool commercialLicenseVerified;
  final bool copyrightNonSimilarityConfirmed;
  final Set<String> acceptedRuleIds;
  final List<AiComplianceRule> rules;
  final List<AiCommercialAssetSubmission> submissions;
  final List<AiComplianceConsentAuditLog> auditLogs;

  List<AiComplianceRule> get applicableRules => rules
      .where((final AiComplianceRule r) => r.appliesTo(selectedProvider))
      .toList();

  bool get allRequiredAccepted {
    final List<AiComplianceRule> reqRules = applicableRules
        .where((final AiComplianceRule r) => r.isRequired)
        .toList();
    return reqRules
        .every((final AiComplianceRule r) => acceptedRuleIds.contains(r.id));
  }

  bool get isReadyToSubmit =>
      selectedPlanTier.isCommercialAllowed &&
      commercialLicenseVerified &&
      copyrightNonSimilarityConfirmed &&
      allRequiredAccepted;

  AiCommercialComplianceState copyWith({
    final bool? isLoading,
    final bool? isSubmitting,
    final bool? isAdmin,
    final String? errorMessage,
    final bool clearError = false,
    final String? lastClearedSubmissionId,
    final ComplianceAiProvider? selectedProvider,
    final GenerationPlanTier? selectedPlanTier,
    final bool? commercialLicenseVerified,
    final bool? copyrightNonSimilarityConfirmed,
    final Set<String>? acceptedRuleIds,
    final List<AiComplianceRule>? rules,
    final List<AiCommercialAssetSubmission>? submissions,
    final List<AiComplianceConsentAuditLog>? auditLogs,
  }) {
    return AiCommercialComplianceState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isAdmin: isAdmin ?? this.isAdmin,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastClearedSubmissionId:
          lastClearedSubmissionId ?? this.lastClearedSubmissionId,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedPlanTier: selectedPlanTier ?? this.selectedPlanTier,
      commercialLicenseVerified:
          commercialLicenseVerified ?? this.commercialLicenseVerified,
      copyrightNonSimilarityConfirmed: copyrightNonSimilarityConfirmed ??
          this.copyrightNonSimilarityConfirmed,
      acceptedRuleIds: acceptedRuleIds ?? this.acceptedRuleIds,
      rules: rules ?? this.rules,
      submissions: submissions ?? this.submissions,
      auditLogs: auditLogs ?? this.auditLogs,
    );
  }
}
