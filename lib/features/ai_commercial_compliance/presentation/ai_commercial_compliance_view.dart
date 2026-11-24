import 'package:flutter/material.dart';

import '../domain/ai_commercial_compliance_models.dart';

/// AI 生成素材の商用利用ライセンス・著作権コンプライアンス View (#2664).
class AiCommercialComplianceView extends StatelessWidget {
  const AiCommercialComplianceView({
    required this.state,
    required this.assetTitleController,
    required this.adminRuleKeyController,
    required this.adminRuleTitleController,
    required this.adminRuleBodyController,
    required this.onRefresh,
    required this.onProviderChanged,
    required this.onPlanTierChanged,
    required this.onCommercialVerifiedChanged,
    required this.onCopyrightConfirmedChanged,
    required this.onToggleRule,
    required this.onOpenWizardDialog,
    required this.onSubmit,
    required this.onAdminSaveRule,
    super.key,
  });

  final AiCommercialComplianceState state;
  final TextEditingController assetTitleController;
  final TextEditingController adminRuleKeyController;
  final TextEditingController adminRuleTitleController;
  final TextEditingController adminRuleBodyController;
  final Future<void> Function() onRefresh;
  final ValueChanged<ComplianceAiProvider> onProviderChanged;
  final ValueChanged<GenerationPlanTier> onPlanTierChanged;
  final ValueChanged<bool> onCommercialVerifiedChanged;
  final ValueChanged<bool> onCopyrightConfirmedChanged;
  final void Function(String ruleId, bool accepted) onToggleRule;
  final Future<void> Function() onOpenWizardDialog;
  final Future<bool> Function() onSubmit;
  final Future<bool> Function() onAdminSaveRule;

  @override
  Widget build(final BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderInk =
        isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final Color primaryInk =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color secondaryInk =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final Color accentBg =
        isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
    final Color accentInk =
        isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A);
    final Color errorBg =
        isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
    final Color errorInk =
        isDark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);

    final List<AiComplianceRule> activeRules = state.applicableRules;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'AI 商用ライセンス & 著作権コンプライアンス',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: primaryInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('compliance-refresh-button'),
                tooltip: '最新の規約項目・監査ログを再読込',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                onPressed: state.isLoading ? null : () => onRefresh(),
                icon: Icon(Icons.refresh, color: primaryInk),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ElevenLabs の生成時有料プラン必須要件や Leonardo.Ai 等の著作権（類似性・依拠性）リスクをアップロード・公開前に確認し、不変の同意監査ログを記録します。',
            style: theme.textTheme.bodyMedium?.copyWith(color: secondaryInk),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _ComplianceStatCard(
                label: '適用チェック項目',
                value: '${activeRules.length} 件',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
              _ComplianceStatCard(
                label: '公開承認済み素材',
                value: '${state.submissions.length} 件',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
              _ComplianceStatCard(
                label: '不変同意監査ログ',
                value: '${state.auditLogs.length} 件',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!state.selectedPlanTier.isCommercialAllowed) ...<Widget>[
            DecoratedBox(
              key: const ValueKey<String>('compliance-free-tier-block-banner'),
              decoration: BoxDecoration(
                color: errorBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: errorInk),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'ブロック中: Free プランで生成された素材は商用ライセンスが付与されないため保存・公開できません。生成時点で有効な Paid / Enterprise プランを利用してください。',
                  style: theme.textTheme.bodyMedium?.copyWith(color: errorInk),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.errorMessage != null &&
              state.errorMessage!.isNotEmpty) ...<Widget>[
            DecoratedBox(
              key: const ValueKey<String>('compliance-error-banner'),
              decoration: BoxDecoration(
                color: errorBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: errorInk),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: errorInk),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.lastClearedSubmissionId != null) ...<Widget>[
            DecoratedBox(
              key: const ValueKey<String>('compliance-cleared-banner'),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderInk),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '商用コンプライアンス承認・監査ログ記録完了 (${state.lastClearedSubmissionId})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accentInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderInk),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '1. 素材情報・生成時プラン確認',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: primaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('compliance-asset-title-input'),
                    controller: assetTitleController,
                    decoration: const InputDecoration(
                      labelText: 'AI 生成素材タイトル',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ComplianceAiProvider>(
                    key: const ValueKey<String>('compliance-provider-dropdown'),
                    isExpanded: true,
                    initialValue: state.selectedProvider,
                    decoration: const InputDecoration(
                      labelText: 'AI 生成プロバイダ',
                      border: OutlineInputBorder(),
                    ),
                    items: ComplianceAiProvider.values
                        .map(
                          (final ComplianceAiProvider p) =>
                              DropdownMenuItem<ComplianceAiProvider>(
                            value: p,
                            child: Text(
                              p.labelJa,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (final ComplianceAiProvider? val) {
                      if (val != null) {
                        onProviderChanged(val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<GenerationPlanTier>(
                    key:
                        const ValueKey<String>('compliance-plan-tier-dropdown'),
                    isExpanded: true,
                    initialValue: state.selectedPlanTier,
                    decoration: const InputDecoration(
                      labelText: '生成時点の契約プラン',
                      border: OutlineInputBorder(),
                    ),
                    items: GenerationPlanTier.values
                        .map(
                          (final GenerationPlanTier tier) =>
                              DropdownMenuItem<GenerationPlanTier>(
                            value: tier,
                            child: Text(
                              tier.labelJa,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (final GenerationPlanTier? val) {
                      if (val != null) {
                        onPlanTierChanged(val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '2. 商用ライセンス・著作権チェックリスト (DB 動的管理)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: primaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    key: const ValueKey<String>('compliance-commercial-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '生成時点で有効な商用利用許可プラン (非 Free / 非 Beta) を確認済み',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: primaryInk,
                      ),
                    ),
                    value: state.commercialLicenseVerified,
                    onChanged: onCommercialVerifiedChanged,
                  ),
                  SwitchListTile(
                    key: const ValueKey<String>('compliance-copyright-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '著作権侵害 (依拠性・実質的類似性) および肖像権に問題ないことを確認済み',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: primaryInk,
                      ),
                    ),
                    value: state.copyrightNonSimilarityConfirmed,
                    onChanged: onCopyrightConfirmedChanged,
                  ),
                  for (final AiComplianceRule rule in activeRules)
                    CheckboxListTile(
                      key: ValueKey<String>(
                        'compliance-rule-checkbox-${rule.ruleKey}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: state.acceptedRuleIds.contains(rule.id),
                      onChanged: (final bool? checked) =>
                          onToggleRule(rule.id, checked ?? false),
                      title: Text(
                        rule.isRequired ? '${rule.title} (必須)' : rule.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: primaryInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${rule.disclaimerBody} [規約版: ${rule.termsVersion}]',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryInk,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'compliance-open-wizard-button',
                      ),
                      onPressed: () => onOpenWizardDialog(),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('ウィザードダイアログで確認・同意'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FilledButton.icon(
                      key: const ValueKey<String>('compliance-submit-button'),
                      onPressed: state.isReadyToSubmit && !state.isSubmitting
                          ? () => onSubmit()
                          : null,
                      icon: const Icon(Icons.verified_user),
                      label: Text(
                        state.isSubmitting ? '監査ログへ保存中...' : 'すべての項目に同意して公開保存',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.isAdmin) ...<Widget>[
            const SizedBox(height: 16),
            DecoratedBox(
              key: const ValueKey<String>('compliance-admin-editor'),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderInk),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '管理者設定: 規約チェック項目・免責事項を動的追加/更新',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: primaryInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey<String>('admin-rule-key-input'),
                      controller: adminRuleKeyController,
                      decoration: const InputDecoration(
                        labelText: 'ルールキー (例: elevenlabs_2026_terms)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey<String>('admin-rule-title-input'),
                      controller: adminRuleTitleController,
                      decoration: const InputDecoration(
                        labelText: 'チェック項目タイトル',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey<String>('admin-rule-body-input'),
                      controller: adminRuleBodyController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '免責事項・利用規約の説明文',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton(
                        key: const ValueKey<String>('admin-save-rule-button'),
                        onPressed:
                            state.isSubmitting ? null : () => onAdminSaveRule(),
                        child: const Text('動的チェックルールを保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '不変の同意監査ログ (Append-Only)',
            style: theme.textTheme.titleMedium?.copyWith(
              color: primaryInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (state.auditLogs.isEmpty)
            Text(
              '同意監査ログはまだありません。',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondaryInk),
            )
          else
            for (final AiComplianceConsentAuditLog log
                in state.auditLogs) ...<Widget>[
              DecoratedBox(
                key: ValueKey<String>('compliance-audit-card-${log.id}'),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderInk),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Submission ${log.submissionId} (同意項目 ${log.acceptedRuleKeys.length} 件)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: primaryInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rules: ${log.acceptedRuleKeys.join(', ')} | ${log.consentedAt.toIso8601String()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ComplianceStatCard extends StatelessWidget {
  const _ComplianceStatCard({
    required this.label,
    required this.value,
    required this.cardBg,
    required this.borderInk,
    required this.primaryInk,
    required this.secondaryInk,
  });

  final String label;
  final String value;
  final Color cardBg;
  final Color borderInk;
  final Color primaryInk;
  final Color secondaryInk;

  @override
  Widget build(final BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderInk),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: secondaryInk),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: primaryInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
