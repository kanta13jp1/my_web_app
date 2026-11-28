import 'package:flutter/material.dart';

import '../application/ai_compliance_controller.dart';
import '../domain/ai_compliance_models.dart';

/// Pure presentation view for AI model compliance & security verification.
class AiComplianceView extends StatelessWidget {
  const AiComplianceView({
    super.key,
    required this.state,
    required this.humanConfirmed,
    required this.providerKeyController,
    required this.modelIdController,
    required this.providerNameController,
    required this.termsUrlController,
    required this.reviewNotesController,
    required this.reviewerController,
    required this.approvalNoteController,
    required this.onRefresh,
    required this.onSeedDefaults,
    required this.onFilterChanged,
    required this.onSelectRecord,
    required this.onToggleChecklist,
    required this.onToggleHumanConfirmed,
    required this.onApproveSelected,
    required this.onTestInvokeGuard,
    required this.onSubmitReview,
  });

  final AiComplianceState state;
  final bool humanConfirmed;
  final TextEditingController providerKeyController;
  final TextEditingController modelIdController;
  final TextEditingController providerNameController;
  final TextEditingController termsUrlController;
  final TextEditingController reviewNotesController;
  final TextEditingController reviewerController;
  final TextEditingController approvalNoteController;
  final VoidCallback onRefresh;
  final VoidCallback onSeedDefaults;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSelectRecord;
  final ValueChanged<ComplianceChecklistState> onToggleChecklist;
  final ValueChanged<bool?> onToggleHumanConfirmed;
  final VoidCallback onApproveSelected;
  final VoidCallback onTestInvokeGuard;
  final VoidCallback onSubmitReview;

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = state.selectedRecord;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderCard(
            colors: colors,
            isBusy: state.isLoading || state.isSubmitting,
            onRefresh: onRefresh,
            onSeedDefaults: onSeedDefaults,
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _NoticeBanner(
              key: const ValueKey<String>('ai_compliance_error_banner'),
              icon: Icons.error_outline,
              title: 'エラー',
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
            ),
            const SizedBox(height: 12),
          ],
          if (state.noticeMessage != null) ...<Widget>[
            _NoticeBanner(
              key: const ValueKey<String>('ai_compliance_notice_banner'),
              icon: Icons.info_outline,
              title: '更新通知',
              message: state.noticeMessage!,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          _SummaryRow(colors: colors, summary: state.summary),
          const SizedBox(height: 12),
          _FilterBar(
            state: state,
            onFilterChanged: onFilterChanged,
          ),
          const SizedBox(height: 12),
          _CandidateListCard(
            colors: colors,
            records: state.records,
            selectedId: selected?.id,
            isLoading: state.isLoading,
            onSelectRecord: onSelectRecord,
            onSeedDefaults: onSeedDefaults,
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: 12),
            _DetailChecklistCard(
              colors: colors,
              record: selected,
              humanConfirmed: humanConfirmed,
              guardResult: state.lastGuardResult,
              isSubmitting: state.isSubmitting,
              reviewerController: reviewerController,
              approvalNoteController: approvalNoteController,
              onToggleChecklist: onToggleChecklist,
              onToggleHumanConfirmed: onToggleHumanConfirmed,
              onApproveSelected: onApproveSelected,
              onTestInvokeGuard: onTestInvokeGuard,
            ),
          ],
          const SizedBox(height: 12),
          _SubmitReviewCard(
            colors: colors,
            isSubmitting: state.isSubmitting,
            providerKeyController: providerKeyController,
            modelIdController: modelIdController,
            providerNameController: providerNameController,
            termsUrlController: termsUrlController,
            reviewNotesController: reviewNotesController,
            onSubmitReview: onSubmitReview,
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.colors,
    required this.isBusy,
    required this.onRefresh,
    required this.onSeedDefaults,
  });

  final ColorScheme colors;
  final bool isBusy;
  final VoidCallback onRefresh;
  final VoidCallback onSeedDefaults;

  @override
  Widget build(final BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '新規AIモデル コンプライアンス・セキュリティ検証',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '法的権利や利用規約の自動判断は行いません。「承認済」かつ人間の最終承認者記録が確定するまでAPI呼び出しはシステムレベルでブロックされます。',
                  style: TextStyle(color: colors.onTertiaryContainer),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('ai_compliance_refresh_btn'),
                  onPressed: isBusy ? null : onRefresh,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('再読込'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey<String>('ai_compliance_seed_btn'),
                  onPressed: isBusy ? null : onSeedDefaults,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('評価候補を読込'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: foregroundColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: TextStyle(color: foregroundColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.colors,
    required this.summary,
  });

  final ColorScheme colors;
  final AiComplianceSummary summary;

  @override
  Widget build(final BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _KpiBadge(
          key: const ValueKey<String>('ai_compliance_kpi_total'),
          label: '総件数',
          value: '${summary.total}',
          backgroundColor: colors.surfaceContainerHigh,
          foregroundColor: colors.onSurface,
        ),
        _KpiBadge(
          key: const ValueKey<String>('ai_compliance_kpi_unverified'),
          label: '未検証',
          value: '${summary.unverified}',
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.onErrorContainer,
        ),
        _KpiBadge(
          key: const ValueKey<String>('ai_compliance_kpi_in_review'),
          label: '検証中',
          value: '${summary.inReview}',
          backgroundColor: colors.tertiaryContainer,
          foregroundColor: colors.onTertiaryContainer,
        ),
        _KpiBadge(
          key: const ValueKey<String>('ai_compliance_kpi_approved'),
          label: '承認済',
          value: '${summary.approved}',
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
        ),
      ],
    );
  }
}

class _KpiBadge extends StatelessWidget {
  const _KpiBadge({
    super.key,
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(final BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.state,
    required this.onFilterChanged,
  });

  final AiComplianceState state;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(final BuildContext context) {
    const filters = <MapEntry<String, String>>[
      MapEntry<String, String>('all', 'すべて'),
      MapEntry<String, String>('unverified', '未検証'),
      MapEntry<String, String>('in_review', '検証中'),
      MapEntry<String, String>('approved', '承認済'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final f in filters)
          if (state.statusFilter == f.key)
            FilledButton(
              key: ValueKey<String>('ai_compliance_filter_${f.key}'),
              onPressed: state.isLoading ? null : () => onFilterChanged(f.key),
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 48),
              ),
              child: Text(f.value),
            )
          else
            OutlinedButton(
              key: ValueKey<String>('ai_compliance_filter_${f.key}'),
              onPressed: state.isLoading ? null : () => onFilterChanged(f.key),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 48),
              ),
              child: Text(f.value),
            ),
      ],
    );
  }
}

class _CandidateListCard extends StatelessWidget {
  const _CandidateListCard({
    required this.colors,
    required this.records,
    required this.selectedId,
    required this.isLoading,
    required this.onSelectRecord,
    required this.onSeedDefaults,
  });

  final ColorScheme colors;
  final List<AiComplianceRecord> records;
  final String? selectedId;
  final bool isLoading;
  final ValueChanged<String> onSelectRecord;
  final VoidCallback onSeedDefaults;

  @override
  Widget build(final BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey<String>('ai_compliance_list_card'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '新規モデル・プロバイダー検証キュー (${records.length}件)',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (isLoading && records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (records.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '検証対象のAIモデルがありません。評価候補を読み込むか下のフォームから新規検証リクエストを起票してください。',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    key: const ValueKey<String>('ai_compliance_empty_seed_btn'),
                    onPressed: onSeedDefaults,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    child: const Text('候補を登録'),
                  ),
                ],
              )
            else
              Column(
                children: <Widget>[
                  for (final rec in records)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CandidateRow(
                        colors: colors,
                        record: rec,
                        isSelected: rec.id == selectedId,
                        onTap: () => onSelectRecord(rec.id),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.colors,
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  final ColorScheme colors;
  final AiComplianceRecord record;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final badgeColors = _statusColors(colors, record.status);
    return Material(
      color:
          isSelected ? colors.secondaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: ValueKey<String>('ai_compliance_row_${record.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${record.providerName} (${record.modelId})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isSelected
                                  ? colors.onSecondaryContainer
                                  : colors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: badgeColors.$1,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          record.statusLabel,
                          style: TextStyle(
                            color: badgeColors.$2,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'チェック ${record.checklist.completedCount}/4 ・ APIガード: ${record.invokeAllowed ? '許可済' : 'ブロック中 (${record.invokeGuardCode})'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colors.onSecondaryContainer
                            : colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailChecklistCard extends StatelessWidget {
  const _DetailChecklistCard({
    required this.colors,
    required this.record,
    required this.humanConfirmed,
    required this.guardResult,
    required this.isSubmitting,
    required this.reviewerController,
    required this.approvalNoteController,
    required this.onToggleChecklist,
    required this.onToggleHumanConfirmed,
    required this.onApproveSelected,
    required this.onTestInvokeGuard,
  });

  final ColorScheme colors;
  final AiComplianceRecord record;
  final bool humanConfirmed;
  final AiComplianceGuardResult? guardResult;
  final bool isSubmitting;
  final TextEditingController reviewerController;
  final TextEditingController approvalNoteController;
  final ValueChanged<ComplianceChecklistState> onToggleChecklist;
  final ValueChanged<bool?> onToggleHumanConfirmed;
  final VoidCallback onApproveSelected;
  final VoidCallback onTestInvokeGuard;

  @override
  Widget build(final BuildContext context) {
    final checklist = record.checklist;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey<String>('ai_compliance_detail_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'セキュリティ基準・利用規約チェックリスト: ${record.providerName}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ステータス: ${record.statusLabel} ・ API呼出状態: ${record.invokeAllowed ? '許可済' : 'ブロック中'}',
              style: textTheme.bodyMedium,
            ),
            if (record.githubIssueNumber != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'GitHub 法務・セキュリティ確認タスク: #${record.githubIssueNumber} (${record.githubIssueUrl ?? ''})',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey<String>('ai_compliance_check_terms'),
              value: checklist.termsReviewed,
              onChanged: isSubmitting
                  ? null
                  : (final bool? v) => onToggleChecklist(
                        checklist.copyWith(termsReviewed: v ?? false),
                      ),
              title: const Text('1. API利用規約・商用利用・学習データ権利の確認'),
            ),
            CheckboxListTile(
              key: const ValueKey<String>('ai_compliance_check_retention'),
              value: checklist.dataRetentionChecked,
              onChanged: isSubmitting
                  ? null
                  : (final bool? v) => onToggleChecklist(
                        checklist.copyWith(dataRetentionChecked: v ?? false),
                      ),
              title: const Text('2. データ保持期間・学習オプトアウト設定の確認'),
            ),
            CheckboxListTile(
              key: const ValueKey<String>('ai_compliance_check_pii'),
              value: checklist.piiLeakageChecked,
              onChanged: isSubmitting
                  ? null
                  : (final bool? v) => onToggleChecklist(
                        checklist.copyWith(piiLeakageChecked: v ?? false),
                      ),
              title: const Text('3. 個人情報・機密情報漏洩リスク対策の確認'),
            ),
            CheckboxListTile(
              key: const ValueKey<String>('ai_compliance_check_security'),
              value: checklist.securityControlsVerified,
              onChanged: isSubmitting
                  ? null
                  : (final bool? v) => onToggleChecklist(
                        checklist.copyWith(
                          securityControlsVerified: v ?? false,
                        ),
                      ),
              title: const Text('4. 通信暗号化・認証・監査証跡のセキュリティ確認'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey<String>('ai_compliance_guard_test_btn'),
              onPressed: isSubmitting ? null : onTestInvokeGuard,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 48),
              ),
              icon: const Icon(Icons.shield_outlined),
              label: const Text('APIガード検証'),
            ),
            if (guardResult != null) ...<Widget>[
              const SizedBox(height: 10),
              DecoratedBox(
                key: const ValueKey<String>('ai_compliance_guard_banner'),
                decoration: BoxDecoration(
                  color: guardResult!.allowed
                      ? colors.primaryContainer
                      : colors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '${guardResult!.code}: ${guardResult!.reason}',
                    style: TextStyle(
                      color: guardResult!.allowed
                          ? colors.onPrimaryContainer
                          : colors.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const Divider(height: 24),
            Text(
              '人間の担当者による最終承認（必須）',
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai_compliance_reviewer_field'),
              controller: reviewerController,
              decoration: const InputDecoration(
                labelText: '承認担当者名（法務・セキュリティ担当）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai_compliance_approval_note_field'),
              controller: approvalNoteController,
              decoration: const InputDecoration(
                labelText: '最終承認メモ（任意）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey<String>(
                'ai_compliance_human_confirm_checkbox',
              ),
              value: humanConfirmed,
              onChanged: isSubmitting ? null : onToggleHumanConfirmed,
              title: const Text('法的判断の自動判定は行わず、人間の担当者として確認済みであることを確定する'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey<String>('ai_compliance_approve_btn'),
              onPressed: isSubmitting ? null : onApproveSelected,
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 48),
              ),
              icon: const Icon(Icons.verified_user),
              label: const Text('承認済みに確定'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitReviewCard extends StatelessWidget {
  const _SubmitReviewCard({
    required this.colors,
    required this.isSubmitting,
    required this.providerKeyController,
    required this.modelIdController,
    required this.providerNameController,
    required this.termsUrlController,
    required this.reviewNotesController,
    required this.onSubmitReview,
  });

  final ColorScheme colors;
  final bool isSubmitting;
  final TextEditingController providerKeyController;
  final TextEditingController modelIdController;
  final TextEditingController providerNameController;
  final TextEditingController termsUrlController;
  final TextEditingController reviewNotesController;
  final VoidCallback onSubmitReview;

  @override
  Widget build(final BuildContext context) {
    return Card(
      key: const ValueKey<String>('ai_compliance_submit_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '新規AIモデル導入 検証リクエスト起票',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '新規リクエストは「検証中」として登録され、GitHub Issues に法務・セキュリティ確認タスクを起票します。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('ai_compliance_provider_key_field'),
              controller: providerKeyController,
              decoration: const InputDecoration(
                labelText: 'プロバイダーキー（例: new-vendor）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai_compliance_model_id_field'),
              controller: modelIdController,
              decoration: const InputDecoration(
                labelText: 'モデルID（例: q2-frontier-1）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai_compliance_provider_name_field'),
              controller: providerNameController,
              decoration: const InputDecoration(
                labelText: '表示名（例: Q2 New Vendor）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai_compliance_terms_url_field'),
              controller: termsUrlController,
              decoration: const InputDecoration(
                labelText: '利用規約 / DPA URL（https://...）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('ai_compliance_notes_field'),
              controller: reviewNotesController,
              decoration: const InputDecoration(
                labelText: '導入背景・確認メモ（任意）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey<String>('ai_compliance_submit_btn'),
              onPressed: isSubmitting ? null : onSubmitReview,
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 48),
              ),
              icon: const Icon(Icons.assignment_late_outlined),
              label: const Text('検証タスク起票'),
            ),
          ],
        ),
      ),
    );
  }
}

(Color, Color) _statusColors(
  final ColorScheme colors,
  final ComplianceVerificationStatus status,
) {
  switch (status) {
    case ComplianceVerificationStatus.approved:
      return (colors.primaryContainer, colors.onPrimaryContainer);
    case ComplianceVerificationStatus.inReview:
      return (colors.tertiaryContainer, colors.onTertiaryContainer);
    case ComplianceVerificationStatus.unverified:
      return (colors.errorContainer, colors.onErrorContainer);
  }
}
