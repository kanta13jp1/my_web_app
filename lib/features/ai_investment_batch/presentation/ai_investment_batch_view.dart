import 'package:flutter/material.dart';

import '../application/ai_investment_controller.dart';
import '../domain/ai_investment_models.dart';

/// Pure presentation UI for 2026Q2 AI investment trends admin review (#2761).
class AiInvestmentBatchView extends StatelessWidget {
  const AiInvestmentBatchView({
    super.key,
    required this.state,
    required this.searchController,
    required this.verificationNoteController,
    required this.rawPayloadController,
    required this.ingestSourceController,
    required this.onRefresh,
    required this.onSearchSubmit,
    required this.onFilterChanged,
    required this.onSelectRecord,
    required this.onSeedDefaults,
    required this.onVerifyDecision,
    required this.onInsertSamplePayload,
    required this.onIngestSubmit,
  });

  final AiInvestmentState state;
  final TextEditingController searchController;
  final TextEditingController verificationNoteController;
  final TextEditingController rawPayloadController;
  final TextEditingController ingestSourceController;
  final VoidCallback onRefresh;
  final VoidCallback onSearchSubmit;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSelectRecord;
  final VoidCallback onSeedDefaults;
  final ValueChanged<InvestmentVerificationStatus> onVerifyDecision;
  final VoidCallback onInsertSamplePayload;
  final VoidCallback onIngestSubmit;

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
            _NoticeCard(
              key: const ValueKey<String>('ai_investment_error_banner'),
              icon: Icons.error_outline,
              title: 'エラー',
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
            ),
            const SizedBox(height: 12),
          ],
          if (state.noticeMessage != null) ...<Widget>[
            _NoticeCard(
              key: const ValueKey<String>('ai_investment_notice_banner'),
              icon: Icons.info_outline,
              title: 'ステータス更新',
              message: state.noticeMessage!,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          _SummaryCard(
            colors: colors,
            summary: state.summary,
          ),
          const SizedBox(height: 12),
          _FilterCard(
            colors: colors,
            state: state,
            searchController: searchController,
            onSearchSubmit: onSearchSubmit,
            onFilterChanged: onFilterChanged,
          ),
          const SizedBox(height: 12),
          _RecordListCard(
            colors: colors,
            records: state.records,
            selectedId: selected?.id,
            isLoading: state.isLoading,
            onSelectRecord: onSelectRecord,
            onSeedDefaults: onSeedDefaults,
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: 12),
            _RecordDetailCard(
              colors: colors,
              record: selected,
              noteController: verificationNoteController,
              isSubmitting: state.isSubmitting,
              onVerifyDecision: onVerifyDecision,
            ),
          ],
          const SizedBox(height: 12),
          _IngestCard(
            colors: colors,
            rawPayloadController: rawPayloadController,
            ingestSourceController: ingestSourceController,
            isSubmitting: state.isSubmitting,
            onInsertSamplePayload: onInsertSamplePayload,
            onIngestSubmit: onIngestSubmit,
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
              '2026Q2 AI企業投資動向モニター',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '新規に収集・正規化された投資・資金調達レコードは、誤情報防止のため初期状態「要検証」で Supabase (RLS) に保存されます。',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('ai_investment_refresh_btn'),
                  onPressed: isBusy ? null : onRefresh,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('再読込'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey<String>('ai_investment_seed_btn'),
                  onPressed: isBusy ? null : onSeedDefaults,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('テンプレート読込'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
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
                  Text(
                    message,
                    style: TextStyle(color: foregroundColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.colors,
    required this.summary,
  });

  final ColorScheme colors;
  final AiInvestmentSummary summary;

  @override
  Widget build(final BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _KpiTile(
          key: const ValueKey<String>('ai_investment_kpi_total'),
          label: '総件数',
          value: '${summary.total}',
          backgroundColor: colors.surfaceContainerHigh,
          foregroundColor: colors.onSurface,
        ),
        _KpiTile(
          key: const ValueKey<String>('ai_investment_kpi_needs_verification'),
          label: '要検証',
          value: '${summary.needsVerification}',
          backgroundColor: colors.tertiaryContainer,
          foregroundColor: colors.onTertiaryContainer,
        ),
        _KpiTile(
          key: const ValueKey<String>('ai_investment_kpi_verified'),
          label: '確認済み',
          value: '${summary.verified}',
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
        ),
        _KpiTile(
          key: const ValueKey<String>('ai_investment_kpi_rejected'),
          label: '却下',
          value: '${summary.rejected}',
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.onErrorContainer,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
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
      constraints: const BoxConstraints(minWidth: 132),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.colors,
    required this.state,
    required this.searchController,
    required this.onSearchSubmit,
    required this.onFilterChanged,
  });

  final ColorScheme colors;
  final AiInvestmentState state;
  final TextEditingController searchController;
  final VoidCallback onSearchSubmit;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(final BuildContext context) {
    const filters = <MapEntry<String, String>>[
      MapEntry<String, String>('all', 'すべて'),
      MapEntry<String, String>('needs_verification', '要検証のみ'),
      MapEntry<String, String>('verified', '確認済みのみ'),
      MapEntry<String, String>('rejected', '却下のみ'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('ai_investment_search_field'),
              controller: searchController,
              decoration: const InputDecoration(
                labelText: '企業名・出典・概要で検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onSearchSubmit(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  key: const ValueKey<String>('ai_investment_search_btn'),
                  onPressed: state.isLoading ? null : onSearchSubmit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  child: const Text('検索'),
                ),
                for (final item in filters)
                  if (state.statusFilter == item.key)
                    FilledButton(
                      key: ValueKey<String>(
                        'ai_investment_filter_${item.key}',
                      ),
                      onPressed: state.isLoading
                          ? null
                          : () => onFilterChanged(item.key),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 48),
                      ),
                      child: Text(item.value),
                    )
                  else
                    OutlinedButton(
                      key: ValueKey<String>(
                        'ai_investment_filter_${item.key}',
                      ),
                      onPressed: state.isLoading
                          ? null
                          : () => onFilterChanged(item.key),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 48),
                      ),
                      child: Text(item.value),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordListCard extends StatelessWidget {
  const _RecordListCard({
    required this.colors,
    required this.records,
    required this.selectedId,
    required this.isLoading,
    required this.onSelectRecord,
    required this.onSeedDefaults,
  });

  final ColorScheme colors;
  final List<AiInvestmentRecord> records;
  final String? selectedId;
  final bool isLoading;
  final ValueChanged<String> onSelectRecord;
  final VoidCallback onSeedDefaults;

  @override
  Widget build(final BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey<String>('ai_investment_list_card'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '収集済み AI 企業投資動向一覧 (${records.length}件)',
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
                    '表示対象の投資動向データがありません。上のボタンからテンプレート初期項目を読み込むか、下の取込フォームからデータを取り込んでください。',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    key: const ValueKey<String>('ai_investment_empty_seed_btn'),
                    onPressed: onSeedDefaults,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    child: const Text('初期項目を登録'),
                  ),
                ],
              )
            else
              Column(
                children: <Widget>[
                  for (final record in records)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RecordRow(
                        colors: colors,
                        record: record,
                        isSelected: record.id == selectedId,
                        onTap: () => onSelectRecord(record.id),
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

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.colors,
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  final ColorScheme colors;
  final AiInvestmentRecord record;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final statusColors = _statusColors(colors, record.verificationStatus);
    return Material(
      color:
          isSelected ? colors.secondaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: ValueKey<String>('ai_investment_row_${record.id}'),
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
                        record.companyName,
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
                        color: statusColors.$1,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          record.verificationLabel,
                          style: TextStyle(
                            color: statusColors.$2,
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
                  '${record.quarter} ・ ${record.roundStage} ・ ${record.amountDisplay}',
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

class _RecordDetailCard extends StatelessWidget {
  const _RecordDetailCard({
    required this.colors,
    required this.record,
    required this.noteController,
    required this.isSubmitting,
    required this.onVerifyDecision,
  });

  final ColorScheme colors;
  final AiInvestmentRecord record;
  final TextEditingController noteController;
  final bool isSubmitting;
  final ValueChanged<InvestmentVerificationStatus> onVerifyDecision;

  @override
  Widget build(final BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColors = _statusColors(colors, record.verificationStatus);
    final investorsText =
        record.investors.isEmpty ? '未記載' : record.investors.join(', ');

    return Card(
      key: const ValueKey<String>('ai_investment_detail_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '詳細・検証ワークベンチ: ${record.companyName}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColors.$1,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      record.verificationLabel,
                      style: TextStyle(
                        color: statusColors.$2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (record.isSampleTemplate) ...<Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'これはテンプレート初期項目です。実運用前に一次情報・公式発表URLを確認してください。',
                    style: TextStyle(color: colors.onTertiaryContainer),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _DetailRow(
              label: '四半期 / ステージ',
              value: '${record.quarter} / ${record.roundStage}',
            ),
            _DetailRow(label: '金額表示', value: record.amountDisplay),
            _DetailRow(label: '領域カテゴリ', value: record.targetProviderCategory),
            _DetailRow(label: '情報ソース', value: record.sourceName),
            _DetailRow(
              label: '出典URL',
              value: record.sourceUrl.isEmpty ? '未設定（要確認）' : record.sourceUrl,
            ),
            _DetailRow(
              label: '公開日時',
              value: record.announcedAt.isEmpty ? '未設定' : record.announcedAt,
            ),
            _DetailRow(label: '投資家', value: investorsText),
            _DetailRow(label: '重複防止キー', value: record.dedupKey),
            _DetailRow(
              label: '検証状態',
              value: record.requiresManualVerification
                  ? '${record.verificationLabel}（手動承認待ち）'
                  : '${record.verificationLabel} (${record.verifiedAt ?? ''})',
            ),
            if (record.verificationNote.isNotEmpty)
              _DetailRow(label: '検証メモ', value: record.verificationNote),
            const SizedBox(height: 8),
            Text(
              '概要',
              style:
                  textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(record.summary.isEmpty ? '（概要なし）' : record.summary),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('ai_investment_verify_note_field'),
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '一次情報確認メモ（任意）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const ValueKey<String>(
                    'ai_investment_verify_approve_btn',
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () => onVerifyDecision(
                            InvestmentVerificationStatus.verified,
                          ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('確認済みにする'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>(
                    'ai_investment_verify_reject_btn',
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () => onVerifyDecision(
                            InvestmentVerificationStatus.rejected,
                          ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('却下する'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>(
                    'ai_investment_verify_reset_btn',
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () => onVerifyDecision(
                            InvestmentVerificationStatus.needsVerification,
                          ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  icon: const Icon(Icons.hourglass_top),
                  label: const Text('要検証に戻す'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(final BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngestCard extends StatelessWidget {
  const _IngestCard({
    required this.colors,
    required this.rawPayloadController,
    required this.ingestSourceController,
    required this.isSubmitting,
    required this.onInsertSamplePayload,
    required this.onIngestSubmit,
  });

  final ColorScheme colors;
  final TextEditingController rawPayloadController;
  final TextEditingController ingestSourceController;
  final bool isSubmitting;
  final VoidCallback onInsertSamplePayload;
  final VoidCallback onIngestSubmit;

  @override
  Widget build(final BuildContext context) {
    return Card(
      key: const ValueKey<String>('ai_investment_ingest_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '手動フィード / 収集JSON・RSS 正規化取込',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'GitHub Actions 収集JSONやニュースRSS/Atomを正規化して取り込みます。全件「要検証」フラグが強制付与されます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('ai_investment_ingest_source_field'),
              controller: ingestSourceController,
              decoration: const InputDecoration(
                labelText: '出典ソース名（任意）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('ai_investment_ingest_payload_field'),
              controller: rawPayloadController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'JSON配列 / オブジェクト または RSS/Atom XML',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  key: const ValueKey<String>(
                    'ai_investment_insert_sample_btn',
                  ),
                  onPressed: isSubmitting ? null : onInsertSamplePayload,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  child: const Text('サンプル挿入'),
                ),
                FilledButton.icon(
                  key:
                      const ValueKey<String>('ai_investment_ingest_submit_btn'),
                  onPressed: isSubmitting ? null : onIngestSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('正規化して取込'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

(Color, Color) _statusColors(
  final ColorScheme colors,
  final InvestmentVerificationStatus status,
) {
  switch (status) {
    case InvestmentVerificationStatus.verified:
      return (colors.primaryContainer, colors.onPrimaryContainer);
    case InvestmentVerificationStatus.rejected:
      return (colors.errorContainer, colors.onErrorContainer);
    case InvestmentVerificationStatus.needsVerification:
      return (colors.tertiaryContainer, colors.onTertiaryContainer);
  }
}
