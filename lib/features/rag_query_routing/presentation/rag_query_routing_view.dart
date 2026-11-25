import 'package:flutter/material.dart';

import '../application/rag_query_routing_controller.dart';
import '../domain/rag_query_routing_models.dart';

/// Pure presentation view for Pleias query-report routing & clarification (#2754).
class RagQueryRoutingView extends StatelessWidget {
  const RagQueryRoutingView({
    super.key,
    required this.state,
    required this.queryController,
    required this.queryReportController,
    required this.onToggleAutoReport,
    required this.onApplyPreset,
    required this.onSubmit,
    required this.onOpenClarifyDialog,
  });

  final RagQueryRoutingState state;
  final TextEditingController queryController;
  final TextEditingController queryReportController;
  final ValueChanged<bool> onToggleAutoReport;
  final ValueChanged<QueryReportTokenPreset> onApplyPreset;
  final VoidCallback onSubmit;
  final ValueChanged<QueryRouteDecision> onOpenClarifyDialog;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final outcome = state.outcome;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderCard(
            colors: colors,
            decision: outcome?.decision,
            isLoading: state.isLoading,
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _NoticeBanner(
              key: const ValueKey<String>('rag_routing_error_banner'),
              icon: Icons.error_outline,
              title: '実行エラー',
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              actionLabel: '再試行',
              actionKey: const ValueKey<String>('rag_routing_retry_button'),
              onAction: state.isLoading ? null : onSubmit,
            ),
            const SizedBox(height: 12),
          ],
          _QueryInputCard(
            colors: colors,
            state: state,
            queryController: queryController,
            queryReportController: queryReportController,
            onToggleAutoReport: onToggleAutoReport,
            onApplyPreset: onApplyPreset,
            onSubmit: onSubmit,
          ),
          if (outcome != null) ...<Widget>[
            const SizedBox(height: 12),
            _DecisionSummaryCard(
              colors: colors,
              outcome: outcome,
              onOpenClarifyDialog: onOpenClarifyDialog,
            ),
            if (!outcome.clarificationRequired) ...<Widget>[
              const SizedBox(height: 12),
              _SearchResultsCard(
                colors: colors,
                outcome: outcome,
              ),
            ],
          ],
          if (state.history.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _RoutingHistoryCard(
              colors: colors,
              history: state.history,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.colors,
    required this.decision,
    required this.isLoading,
  });

  final ColorScheme colors;
  final QueryRouteDecision? decision;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final badgeText = isLoading
        ? '判定・検索中...'
        : decision == null
            ? '待機中'
            : decision!.state.labelJa;
    final badgeBg = decision == null
        ? colors.secondaryContainer
        : decision!.requiresClarification
            ? colors.errorContainer
            : decision!.usedReformulatedQuery
                ? colors.primaryContainer
                : colors.tertiaryContainer;
    final badgeFg = decision == null
        ? colors.onSecondaryContainer
        : decision!.requiresClarification
            ? colors.onErrorContainer
            : decision!.usedReformulatedQuery
                ? colors.onPrimaryContainer
                : colors.onTertiaryContainer;

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Icon(Icons.alt_route, color: colors.primary),
                Text(
                  'クエリレポート自動再定式化 & ルーティング',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                DecoratedBox(
                  key: const ValueKey<String>('rag_routing_state_badge'),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '<|query_report_start|> 等の意図解析タグから '
              'trivial / reformulated / unclear を判定し、自動再検索または質問明確化ダイアログへ分岐します。',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueryInputCard extends StatelessWidget {
  const _QueryInputCard({
    required this.colors,
    required this.state,
    required this.queryController,
    required this.queryReportController,
    required this.onToggleAutoReport,
    required this.onApplyPreset,
    required this.onSubmit,
  });

  final ColorScheme colors;
  final RagQueryRoutingState state;
  final TextEditingController queryController;
  final TextEditingController queryReportController;
  final ValueChanged<bool> onToggleAutoReport;
  final ValueChanged<QueryReportTokenPreset> onApplyPreset;
  final VoidCallback onSubmit;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '1. 検索クエリとレポートタグ入力',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('rag_routing_query_input'),
              controller: queryController,
              decoration: const InputDecoration(
                labelText: '検索クエリ',
                hintText: '例: Pleias / あれを調べて',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (final String _) {
                if (!state.isLoading) {
                  onSubmit();
                }
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: defaultQueryReportPresets
                  .map(
                    (final QueryReportTokenPreset preset) => OutlinedButton(
                      key: ValueKey<String>(
                        'rag_routing_preset_${preset.id}',
                      ),
                      onPressed:
                          state.isLoading ? null : () => onApplyPreset(preset),
                      child: Text(preset.label),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey<String>('rag_routing_auto_report_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                'レポート未入力時にバックエンドで意図解析を実行',
                style: TextStyle(color: colors.onSurface),
              ),
              subtitle: Text(
                'タグ欄が空の場合に auto_report=true で状態を推定します',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              value: state.autoReport,
              onChanged: state.isLoading ? null : onToggleAutoReport,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('rag_routing_report_input'),
              controller: queryReportController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'モデル出力クエリレポート (任意)',
                hintText: '<|query_report_start|><|state|>reformulated...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey<String>('rag_routing_submit_button'),
              onPressed: state.isLoading ? null : onSubmit,
              icon: state.isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.manage_search),
              label: Text(
                state.isLoading ? 'ルーティング解析中...' : '解析して検索実行',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionSummaryCard extends StatelessWidget {
  const _DecisionSummaryCard({
    required this.colors,
    required this.outcome,
    required this.onOpenClarifyDialog,
  });

  final ColorScheme colors;
  final QueryRouteOutcome outcome;
  final ValueChanged<QueryRouteDecision> onOpenClarifyDialog;

  @override
  Widget build(final BuildContext context) {
    final decision = outcome.decision;

    return Card(
      key: const ValueKey<String>('rag_routing_decision_card'),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '2. ルーティング判定結果',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoPill(
                  label: '状態: ${decision.state.wireValue}',
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                ),
                _InfoPill(
                  label: '分岐: ${decision.action.labelJa}',
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                ),
                _InfoPill(
                  label: '解析元: ${decision.reportSource}',
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                ),
              ],
            ),
            if (decision.usedReformulatedQuery) ...<Widget>[
              const SizedBox(height: 12),
              _NoticeBanner(
                key: const ValueKey<String>('rag_routing_reformulated_banner'),
                icon: Icons.auto_fix_high,
                title: '自動再定式化クエリで再検索しました',
                message: '元のクエリ: ${decision.originalQuery}\n'
                    '再検索クエリ: ${decision.searchQuery}',
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
              ),
            ],
            if (outcome.clarificationRequired) ...<Widget>[
              const SizedBox(height: 12),
              _NoticeBanner(
                key: const ValueKey<String>('rag_routing_halted_banner'),
                icon: Icons.pause_circle_outline,
                title: '推論・検索プロセスを中断しました (明確化が必要)',
                message: decision.feedback ?? '検索対象を明確にするため質問を修正してください。',
                backgroundColor: colors.errorContainer,
                foregroundColor: colors.onErrorContainer,
                actionLabel: '質問を修正する',
                actionKey: const ValueKey<String>(
                  'rag_routing_reopen_clarify_button',
                ),
                onAction: () => onOpenClarifyDialog(decision),
              ),
            ] else if (decision.feedback != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '判定理由: ${decision.feedback!}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.colors,
    required this.outcome,
  });

  final ColorScheme colors;
  final QueryRouteOutcome outcome;

  @override
  Widget build(final BuildContext context) {
    return Card(
      key: const ValueKey<String>('rag_routing_results_card'),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '3. 検索結果 (${outcome.results.length} 件)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '検索クエリ: ${outcome.decision.searchQuery} '
              '(BM25: ${outcome.bm25Candidates} / Vector: ${outcome.vectorCandidates})',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (outcome.results.isEmpty)
              Text(
                '該当するメモリドキュメントは見つかりませんでした。',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              ...outcome.results.map(
                (final QueryRouteSearchHit hit) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hit.displayTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hit.filePath} ・ スコア ${hit.score.toStringAsFixed(3)} '
                        '(${hit.matchReason})',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      if (hit.snippet != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          hit.snippet!,
                          style: TextStyle(color: colors.onSurface),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoutingHistoryCard extends StatelessWidget {
  const _RoutingHistoryCard({
    required this.colors,
    required this.history,
  });

  final ColorScheme colors;
  final List<QueryRouteDecision> history;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'ルーティング履歴 (${history.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...history.map(
              (final QueryRouteDecision item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '[${item.state.wireValue}] ${item.originalQuery} -> '
                  '${item.requiresClarification ? '中断・再入力要求' : item.searchQuery}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(final BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
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
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Icon(icon, color: foregroundColor),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(color: foregroundColor),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 8),
            ElevatedButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
