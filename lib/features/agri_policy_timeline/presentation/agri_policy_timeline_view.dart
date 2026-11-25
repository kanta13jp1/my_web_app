import 'package:flutter/material.dart';

import '../application/agri_policy_controller.dart';
import '../domain/agri_policy_models.dart';

/// Pure presentation view for agricultural policy reform timeline & KG (#2755).
class AgriPolicyTimelineView extends StatelessWidget {
  const AgriPolicyTimelineView({
    super.key,
    required this.state,
    required this.searchController,
    required this.dateController,
    required this.titleController,
    required this.summaryController,
    required this.tagsController,
    required this.nodesController,
    required this.sourceController,
    required this.notesController,
    required this.selectedNewFactStatus,
    required this.onRetryLoad,
    required this.onSearch,
    required this.onClearSearch,
    required this.onSelectTag,
    required this.onSelectPhase,
    required this.onSelectNewFactStatus,
    required this.onCreateEvent,
    required this.onEditFactCheck,
  });

  final AgriPolicyTimelineState state;
  final TextEditingController searchController;
  final TextEditingController dateController;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController tagsController;
  final TextEditingController nodesController;
  final TextEditingController sourceController;
  final TextEditingController notesController;
  final FactCheckStatus selectedNewFactStatus;
  final VoidCallback onRetryLoad;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onSelectTag;
  final ValueChanged<AgriPolicyPhase?> onSelectPhase;
  final ValueChanged<FactCheckStatus> onSelectNewFactStatus;
  final VoidCallback onCreateEvent;
  final ValueChanged<AgriPolicyEvent> onEditFactCheck;

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderCard(
            colors: colors,
            eventCount: state.events.length,
            totalCount: state.totalCount,
            isLoading: state.isLoading,
            onRefresh: onRetryLoad,
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _StatusBanner(
              key: const ValueKey<String>('agri_policy_error_banner'),
              icon: Icons.error_outline,
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              actionLabel: '再試行',
              actionKey: const ValueKey<String>('agri_policy_retry_button'),
              onAction: state.isLoading ? null : onRetryLoad,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _StatusBanner(
              key: const ValueKey<String>('agri_policy_notice_banner'),
              icon: Icons.check_circle_outline,
              message: state.statusNotice!,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          _FilterControlCard(
            colors: colors,
            state: state,
            searchController: searchController,
            onSearch: onSearch,
            onClearSearch: onClearSearch,
            onSelectTag: onSelectTag,
            onSelectPhase: onSelectPhase,
          ),
          const SizedBox(height: 12),
          _TimelineSectionCard(
            colors: colors,
            state: state,
            onEditFactCheck: onEditFactCheck,
          ),
          const SizedBox(height: 12),
          _KnowledgeEdgesCard(
            colors: colors,
            events: state.events,
            edges: state.knowledgeEdges,
          ),
          const SizedBox(height: 12),
          _CreatePolicyEventCard(
            colors: colors,
            isSubmitting: state.isSubmitting,
            dateController: dateController,
            titleController: titleController,
            summaryController: summaryController,
            tagsController: tagsController,
            nodesController: nodesController,
            sourceController: sourceController,
            notesController: notesController,
            selectedFactStatus: selectedNewFactStatus,
            onSelectFactStatus: onSelectNewFactStatus,
            onCreateEvent: onCreateEvent,
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.colors,
    required this.eventCount,
    required this.totalCount,
    required this.isLoading,
    required this.onRefresh,
  });

  final ColorScheme colors;
  final int eventCount;
  final int totalCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(final BuildContext context) {
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
                Icon(Icons.timeline, color: colors.primary),
                Text(
                  '農政改革タイムライン & ナレッジグラフ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                _MetaPill(
                  key: const ValueKey<String>('agri_policy_count_badge'),
                  label: '$eventCount / $totalCount 件',
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('更新'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '2018年（減反廃止）から2027年（令和9年）度改革までの政策変遷と、'
              '直接支払い・マルキン制度・一次出典メタデータを中立的に整理します。',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterControlCard extends StatelessWidget {
  const _FilterControlCard({
    required this.colors,
    required this.state,
    required this.searchController,
    required this.onSearch,
    required this.onClearSearch,
    required this.onSelectTag,
    required this.onSelectPhase,
  });

  final ColorScheme colors;
  final AgriPolicyTimelineState state;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onSelectTag;
  final ValueChanged<AgriPolicyPhase?> onSelectPhase;

  @override
  Widget build(final BuildContext context) {
    final allTags = <String>{
      ...kDefaultAgriKeywordTags,
      ...state.availableTags,
    }.toList(growable: false);

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'キーワード検索・タグ・期間フィルタ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('agri_policy_search_input'),
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'キーワード検索 (例: 減反廃止 / 直接支払い / マルキン制度)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (final String _) {
                if (!state.isLoading) onSearch();
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ElevatedButton.icon(
                  key: const ValueKey<String>('agri_policy_search_button'),
                  onPressed: state.isLoading ? null : onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('検索実行'),
                ),
                TextButton(
                  key:
                      const ValueKey<String>('agri_policy_clear_search_button'),
                  onPressed: state.isLoading ? null : onClearSearch,
                  child: const Text('条件をクリア'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'タグで絞り込み',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  key: const ValueKey<String>('agri_policy_tag_all'),
                  onPressed: state.isLoading ? null : () => onSelectTag(null),
                  style: state.selectedTag == null
                      ? OutlinedButton.styleFrom(
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                        )
                      : null,
                  child: const Text('すべて'),
                ),
                ...allTags.map(
                  (final String tag) => OutlinedButton(
                    key: ValueKey<String>('agri_policy_tag_$tag'),
                    onPressed: state.isLoading ? null : () => onSelectTag(tag),
                    style: state.selectedTag == tag
                        ? OutlinedButton.styleFrom(
                            backgroundColor: colors.primaryContainer,
                            foregroundColor: colors.onPrimaryContainer,
                          )
                        : null,
                    child: Text(tag),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '改革フェーズ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  key: const ValueKey<String>('agri_policy_phase_all'),
                  onPressed: state.isLoading ? null : () => onSelectPhase(null),
                  style: state.selectedPhase == null
                      ? OutlinedButton.styleFrom(
                          backgroundColor: colors.secondaryContainer,
                          foregroundColor: colors.onSecondaryContainer,
                        )
                      : null,
                  child: const Text('全期間'),
                ),
                ...AgriPolicyPhase.values.map(
                  (final AgriPolicyPhase phase) => OutlinedButton(
                    key: ValueKey<String>(
                      'agri_policy_phase_${phase.wireValue}',
                    ),
                    onPressed:
                        state.isLoading ? null : () => onSelectPhase(phase),
                    style: state.selectedPhase == phase
                        ? OutlinedButton.styleFrom(
                            backgroundColor: colors.secondaryContainer,
                            foregroundColor: colors.onSecondaryContainer,
                          )
                        : null,
                    child: Text(phase.labelJa),
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

class _TimelineSectionCard extends StatelessWidget {
  const _TimelineSectionCard({
    required this.colors,
    required this.state,
    required this.onEditFactCheck,
  });

  final ColorScheme colors;
  final AgriPolicyTimelineState state;
  final ValueChanged<AgriPolicyEvent> onEditFactCheck;

  @override
  Widget build(final BuildContext context) {
    return Card(
      key: const ValueKey<String>('agri_policy_timeline_list'),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '政策変遷タイムライン (${state.events.length} 件)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (state.isLoading && state.events.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (state.events.isEmpty)
              Text(
                '一致する政策イベントはありません。検索条件を変更するか新規登録してください。',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              ...List<Widget>.generate(
                state.events.length,
                (final int index) => _TimelineEventRow(
                  colors: colors,
                  event: state.events[index],
                  isLast: index == state.events.length - 1,
                  onEditFactCheck: onEditFactCheck,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({
    required this.colors,
    required this.event,
    required this.isLast,
    required this.onEditFactCheck,
  });

  final ColorScheme colors;
  final AgriPolicyEvent event;
  final bool isLast;
  final ValueChanged<AgriPolicyEvent> onEditFactCheck;

  @override
  Widget build(final BuildContext context) {
    final factBg = switch (event.factCheckStatus) {
      FactCheckStatus.verified => colors.tertiaryContainer,
      FactCheckStatus.needsReview => colors.secondaryContainer,
      FactCheckStatus.disputed => colors.errorContainer,
      FactCheckStatus.unverified => colors.surfaceContainerHighest,
    };
    final factFg = switch (event.factCheckStatus) {
      FactCheckStatus.verified => colors.onTertiaryContainer,
      FactCheckStatus.needsReview => colors.onSecondaryContainer,
      FactCheckStatus.disputed => colors.onErrorContainer,
      FactCheckStatus.unverified => colors.onSurface,
    };

    return Padding(
      key: ValueKey<String>('agri_policy_event_card_${event.id}'),
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Column(
              children: <Widget>[
                Icon(
                  event.phase == AgriPolicyPhase.planned
                      ? Icons.schedule
                      : Icons.flag_circle,
                  color: colors.primary,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 72,
                    color: colors.outlineVariant,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _MetaPill(
                        label: '${event.eventDate} (${event.fiscalYear}年度)',
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                      ),
                      _MetaPill(
                        label: event.phase.labelJa,
                        backgroundColor: colors.secondaryContainer,
                        foregroundColor: colors.onSecondaryContainer,
                      ),
                      _MetaPill(
                        key: ValueKey<String>(
                          'agri_policy_fact_badge_${event.id}',
                        ),
                        label: '事実確認: ${event.factCheckStatus.labelJa}',
                        backgroundColor: factBg,
                        foregroundColor: factFg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  if (event.summary.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      event.summary,
                      style: TextStyle(color: colors.onSurface),
                    ),
                  ],
                  if (event.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: event.tags
                          .map(
                            (final String tag) => _MetaPill(
                              label: '#$tag',
                              backgroundColor: colors.surfaceContainerHighest,
                              foregroundColor: colors.onSurface,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (event.relatedNodes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '関連 KG ノード: ${event.relatedNodes.join(" / ")}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                  if (event.sourceCitation.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '一次出典・根拠: ${event.sourceCitation}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                  if (event.policyImpactNotes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '影響・検証メモ: ${event.policyImpactNotes}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: ValueKey<String>('agri_policy_edit_fact_${event.id}'),
                    onPressed: () => onEditFactCheck(event),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('事実確認メタデータを編集'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeEdgesCard extends StatelessWidget {
  const _KnowledgeEdgesCard({
    required this.colors,
    required this.events,
    required this.edges,
  });

  final ColorScheme colors;
  final List<AgriPolicyEvent> events;
  final List<AgriKnowledgeEdge> edges;

  @override
  Widget build(final BuildContext context) {
    final byId = <String, AgriPolicyEvent>{
      for (final event in events) event.id: event,
    };

    return Card(
      key: const ValueKey<String>('agri_policy_kg_card'),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '政策ナレッジグラフ関連リンク (${edges.length} 本)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (edges.isEmpty)
              Text(
                '共通タグ・共通ノードを持つイベントペアはありません。',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              ...edges.map((final AgriKnowledgeEdge edge) {
                final fromTitle =
                    byId[edge.fromEventId]?.title ?? edge.fromEventId;
                final toTitle = byId[edge.toEventId]?.title ?? edge.toEventId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$fromTitle <-> $toTitle '
                    '[共通ノード: ${edge.sharedTerms.join(", ")}]',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CreatePolicyEventCard extends StatelessWidget {
  const _CreatePolicyEventCard({
    required this.colors,
    required this.isSubmitting,
    required this.dateController,
    required this.titleController,
    required this.summaryController,
    required this.tagsController,
    required this.nodesController,
    required this.sourceController,
    required this.notesController,
    required this.selectedFactStatus,
    required this.onSelectFactStatus,
    required this.onCreateEvent,
  });

  final ColorScheme colors;
  final bool isSubmitting;
  final TextEditingController dateController;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController tagsController;
  final TextEditingController nodesController;
  final TextEditingController sourceController;
  final TextEditingController notesController;
  final FactCheckStatus selectedFactStatus;
  final ValueChanged<FactCheckStatus> onSelectFactStatus;
  final VoidCallback onCreateEvent;

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
              '新規政策イベント・事実確認記録の追加',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('agri_policy_create_date_input'),
              controller: dateController,
              decoration: const InputDecoration(
                labelText: '日付 (YYYY-MM-DD)',
                hintText: '2026-06-01',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('agri_policy_create_title_input'),
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '政策イベント名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('agri_policy_create_summary_input'),
              controller: summaryController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '概要',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('agri_policy_create_tags_input'),
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: 'キーワードタグ (カンマ区切り)',
                hintText: '減反廃止, 直接支払い, 備蓄米',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('agri_policy_create_nodes_input'),
              controller: nodesController,
              decoration: const InputDecoration(
                labelText: '関連 KG ノード (カンマ区切り)',
                hintText: '農林水産省, 需要に応じた生産',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('agri_policy_create_source_input'),
              controller: sourceController,
              decoration: const InputDecoration(
                labelText: '一次出典・参照資料',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('agri_policy_create_notes_input'),
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '中立的影響分析・事実確認メモ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FactCheckStatus.values
                  .map(
                    (final FactCheckStatus status) => OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => onSelectFactStatus(status),
                      style: selectedFactStatus == status
                          ? OutlinedButton.styleFrom(
                              backgroundColor: colors.tertiaryContainer,
                              foregroundColor: colors.onTertiaryContainer,
                            )
                          : null,
                      child: Text(status.labelJa),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey<String>('agri_policy_create_button'),
              onPressed: isSubmitting ? null : onCreateEvent,
              icon: const Icon(Icons.add_chart),
              label: Text(isSubmitting ? '登録中...' : '政策イベントを記録'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    super.key,
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final IconData icon;
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Icon(icon, color: foregroundColor),
          Text(
            message,
            style: TextStyle(color: foregroundColor),
          ),
          if (actionLabel != null && onAction != null)
            ElevatedButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
