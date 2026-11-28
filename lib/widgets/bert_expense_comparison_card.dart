import 'package:flutter/material.dart';
import '../services/bert_expense_comparison_service.dart';

/// BERT 支出分類（合成サンプル・読み取り専用）の保存済み比較結果を表示するパネル。
///
/// 実家計データの送信・自動記帳・モック数値の捏造は行わず、
/// 失敗・未計測・未校正スコア・モデル来歴を正直に表示する。
class BertExpenseComparisonCard extends StatefulWidget {
  const BertExpenseComparisonCard({
    super.key,
    this.records,
    this.loadRecords,
    this.service = const BertExpenseComparisonService(),
    this.errorMessage,
    this.isLoading = false,
    this.onRetry,
  });

  final List<BertSyntheticSampleRecord>? records;
  final Future<List<BertSyntheticSampleRecord>> Function()? loadRecords;
  final BertExpenseComparisonService service;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  State<BertExpenseComparisonCard> createState() =>
      _BertExpenseComparisonCardState();
}

class _BertExpenseComparisonCardState extends State<BertExpenseComparisonCard> {
  List<BertSyntheticSampleRecord>? _loadedRecords;
  String? _loadError;
  bool _isLoading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.records == null && widget.loadRecords != null) {
      _fetchRecords();
    }
  }

  @override
  void didUpdateWidget(covariant BertExpenseComparisonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records == null &&
        widget.loadRecords != null &&
        widget.loadRecords != oldWidget.loadRecords) {
      _fetchRecords();
    }
  }

  Future<void> _fetchRecords() async {
    final loader = widget.loadRecords;
    if (loader == null) {
      return;
    }
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final result = await loader();
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loadedRecords = List<BertSyntheticSampleRecord>.unmodifiable(result);
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  void _handleRetry() {
    if (widget.onRetry != null) {
      widget.onRetry!();
      return;
    }
    _fetchRecords();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveLoading = widget.isLoading || _isLoading;
    final effectiveError = widget.errorMessage ?? _loadError;
    final effectiveRecords =
        widget.records ?? _loadedRecords ?? const <BertSyntheticSampleRecord>[];
    final canRetry = widget.onRetry != null || widget.loadRecords != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, colorScheme),
            const SizedBox(height: 12),
            if (effectiveLoading)
              _buildLoadingState(theme)
            else if (effectiveError != null && effectiveError.trim().isNotEmpty)
              _buildErrorState(theme, colorScheme, effectiveError, canRetry)
            else if (effectiveRecords.isEmpty)
              _buildEmptyState(theme, colorScheme, canRetry)
            else
              _buildLoadedContent(theme, colorScheme, effectiveRecords),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.science_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'BERT 支出分類 合成サンプル比較（読み取り専用）',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _StatusChip(
              label: '合成サンプル専用',
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
            _StatusChip(
              label: '実家計データ送信なし・自動記帳なし',
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '保存済みの合成サンプル比較結果を読み込み中...',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
    ColorScheme colorScheme,
    String errorText,
    bool canRetry,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '比較結果の取得に失敗しました（成功扱いにはしません）',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            errorText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
          if (canRetry) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _handleRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    ColorScheme colorScheme,
    bool canRetry,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '保存済みの合成サンプル比較結果はまだありません（未計測）',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '推論結果が未保存のため、候補・スコア・推論時間は表示しません。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (canRetry) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _handleRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadedContent(
    ThemeData theme,
    ColorScheme colorScheme,
    List<BertSyntheticSampleRecord> records,
  ) {
    final summary = widget.service.summarize(records);
    final provenances = _collectUniqueProvenances(records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummarySection(theme, colorScheme, summary),
        const SizedBox(height: 12),
        _buildProvenanceSection(theme, colorScheme, provenances),
        const SizedBox(height: 12),
        for (var i = 0; i < records.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _RecordTile(
            record: records[i],
            validation: widget.service.validateRecord(records[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildSummarySection(
    ThemeData theme,
    ColorScheme colorScheme,
    BertComparisonSummary summary,
  ) {
    final meanCpuText = summary.meanCpuInferenceMs == null
        ? '未計測'
        : '${summary.meanCpuInferenceMs!.toStringAsFixed(1)} ms';
    final meanHttpText = summary.meanHttpRoundTripMs == null
        ? '未計測'
        : '${summary.meanHttpRoundTripMs!.toStringAsFixed(1)} ms';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusChip(
                label: '合計 ${summary.totalCount}件',
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurface,
              ),
              _StatusChip(
                label: '検証済 ${summary.verifiedCount}',
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
              _StatusChip(
                label: '失敗 ${summary.failedCount}',
                backgroundColor: summary.failedCount > 0
                    ? colorScheme.errorContainer
                    : colorScheme.surfaceContainerHighest,
                foregroundColor: summary.failedCount > 0
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSurfaceVariant,
              ),
              _StatusChip(
                label: '未計測 ${summary.notMeasuredCount}',
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
              ),
              _StatusChip(
                label: summary.allValid ? '契約検証 OK' : '契約検証エラーあり',
                backgroundColor: summary.allValid
                    ? colorScheme.tertiaryContainer
                    : colorScheme.errorContainer,
                foregroundColor: summary.allValid
                    ? colorScheme.onTertiaryContainer
                    : colorScheme.onErrorContainer,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ルール一致: ${summary.ruleModelAgreementCount} / ${summary.verifiedCount}件'
            '  |  平均CPU推論: $meanCpuText'
            '  |  平均HTTP: $meanHttpText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceSection(
    ThemeData theme,
    ColorScheme colorScheme,
    List<BertModelProvenance> provenances,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'モデル来歴（固定SHA・推論ランタイム）',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final p in provenances) ...[
            Text(
              'ID: ${p.modelId.isEmpty ? '未設定' : p.modelId} / '
              'rev: ${p.weightRevision.isEmpty ? '未設定' : p.weightRevision} / '
              'runtime: ${p.runtimeKind.isEmpty ? '未設定' : p.runtimeKind}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'SHA: ${p.pinnedSha.isEmpty ? '未設定' : p.pinnedSha}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<BertModelProvenance> _collectUniqueProvenances(
    List<BertSyntheticSampleRecord> records,
  ) {
    final seen = <String>{};
    final result = <BertModelProvenance>[];
    for (final r in records) {
      final p = r.provenance;
      final key =
          '${p.modelId}|${p.weightRevision}|${p.pinnedSha}|${p.runtimeKind}';
      if (seen.add(key)) {
        result.add(p);
      }
    }
    return result;
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.validation,
  });

  final BertSyntheticSampleRecord record;
  final BertValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ruleLabel =
        BertExpenseCategories.labels[record.ruleCandidateCategory] ??
            record.ruleCandidateCategory;
    final modelCategory = record.modelCandidateCategory;
    final modelLabel = modelCategory == null
        ? '未取得'
        : (BertExpenseCategories.labels[modelCategory] ?? modelCategory);
    final topScore = record.topUncalibratedScore;
    final topScoreText = topScore == null
        ? '未計測'
        : '${(topScore * 100).toStringAsFixed(1)}%（未校正）';
    final cpuText = record.cpuInferenceMs == null
        ? '未計測'
        : '${record.cpuInferenceMs!.toStringAsFixed(1)} ms';
    final httpText = record.httpRoundTripMs == null
        ? '未計測'
        : '${record.httpRoundTripMs!.toStringAsFixed(1)} ms';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  record.sampleId.isEmpty ? '(ID未設定)' : record.sampleId,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(colorScheme, record.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            record.syntheticMemo,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'ルール候補: $ruleLabel',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'モデル候補: $modelLabel / スコア: $topScoreText',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'CPU推論: $cpuText / HTTP往復: $httpText / 反復: ${record.iterations}回',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (record.status == BertMeasurementStatus.failed) ...[
            const SizedBox(height: 6),
            Text(
              '失敗詳細: ${record.errorCode ?? 'unknown'}'
              '${(record.errorMessage ?? '').trim().isNotEmpty ? ' (${record.errorMessage})' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (!validation.isValid) ...[
            const SizedBox(height: 6),
            Text(
              '契約検証エラー: ${validation.errors.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          if (record.uncalibratedScores.isNotEmpty) ...[
            const SizedBox(height: 6),
            _UncalibratedScoreList(scores: record.uncalibratedScores),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    ColorScheme colorScheme,
    BertMeasurementStatus status,
  ) {
    switch (status) {
      case BertMeasurementStatus.verified:
        return _StatusChip(
          label: '検証済',
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
        );
      case BertMeasurementStatus.failed:
        return _StatusChip(
          label: '失敗',
          backgroundColor: colorScheme.errorContainer,
          foregroundColor: colorScheme.onErrorContainer,
        );
      case BertMeasurementStatus.notMeasured:
        return _StatusChip(
          label: '未計測',
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
        );
    }
  }
}

class _UncalibratedScoreList extends StatelessWidget {
  const _UncalibratedScoreList({required this.scores});

  final Map<String, double> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
        title: Text(
          '12カテゴリ未校正スコア内訳 (${entries.length}件)',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      BertExpenseCategories.labels[entry.key] ?? entry.key,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(entry.value * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
