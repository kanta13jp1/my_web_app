import 'package:flutter/material.dart';

import '../models/ai_suggested_action.dart';
import '../services/ai_suggested_action_monitor_service.dart';
import 'ai_suggested_action_bar.dart';

class AiSuggestedActionAuditDashboard extends StatefulWidget {
  const AiSuggestedActionAuditDashboard({
    super.key,
    this.service = const AiSuggestedActionMonitorService(),
    this.initialEvents,
  });

  final AiSuggestedActionMonitorService service;
  final List<AiSuggestedActionEvent>? initialEvents;

  @override
  State<AiSuggestedActionAuditDashboard> createState() =>
      _AiSuggestedActionAuditDashboardState();
}

class _AiSuggestedActionAuditDashboardState
    extends State<AiSuggestedActionAuditDashboard> {
  final TextEditingController _searchController = TextEditingController();
  List<AiSuggestedActionEvent> _events = const <AiSuggestedActionEvent>[];
  bool _loading = true;
  String _query = '';
  AiSuggestedActionType? _selectedType;
  bool _onlyFlaggedDeception = false;

  static final List<AiSuggestedAction> _sandboxActions = <AiSuggestedAction>[
    const AiSuggestedAction(
      id: 'sandbox_narrative',
      type: AiSuggestedActionType.narrativeChoice,
      rawActionType: 'narrative_choice',
      label: '別ルートで状況を打開する',
      promptText: '代替案としてリスクを抑えた手順を選びます',
      contextExcerpt: 'ユーザー: 期限までに安全に進められる選択肢を教えて',
    ),
    const AiSuggestedAction(
      id: 'sandbox_scene',
      type: AiSuggestedActionType.sceneTransition,
      rawActionType: 'scene_transition',
      label: 'レビュー段階へシーン移行',
      sceneTitle: '検証・振り返りフェーズ',
      sceneDescription: '入力内容の確認と次アクション選定へ切り替えます',
      contextExcerpt: 'アシスタント: ここまでの整理が終わりました',
    ),
    const AiSuggestedAction(
      id: 'sandbox_generic',
      type: AiSuggestedActionType.genericNarrativeChoice,
      rawActionType: 'generic_narrative_choice',
      label: '補足の意図をテキストで伝える',
      promptText: '優先度を下げて段階的に進める案でお願いします',
      contextExcerpt: 'ユーザー: 固定メニュー以外の返答がしたい',
    ),
    const AiSuggestedAction(
      id: 'sandbox_invite_normal',
      type: AiSuggestedActionType.invite,
      rawActionType: 'invite',
      label: 'チームメンバーを招待する',
      contextExcerpt: 'ユーザー: 担当者を追加したい',
    ),
    const AiSuggestedAction(
      id: 'sandbox_invite_deception',
      type: AiSuggestedActionType.invite,
      rawActionType: 'invite',
      label: 'お金を呼び込む決済ページを開く',
      promptText: '決済を完了して利益を増やす',
      contextExcerpt: 'ユーザー: 収益化を進めるための次の手を教えて',
    ),
    AiSuggestedAction.fromJson(
      const <String, dynamic>{
        'id': 'sandbox_unknown_wire',
        'action_type': 'experimental_freeform_hack',
        'label': '未知のツール実行テスト',
        'context_excerpt': 'AIがスキーマ外のアクション名を生成したケース',
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provided = widget.initialEvents;
    if (provided != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _events = List<AiSuggestedActionEvent>.from(provided)
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        _loading = false;
      });
      return;
    }

    final loaded = await widget.service.loadEvents();
    if (!mounted) {
      return;
    }
    setState(() {
      _events = loaded;
      _loading = false;
    });
  }

  Future<void> _onSandboxActionHandled(
    AiSuggestedActionExecutionResult result,
  ) async {
    final recorded = result.recordedEvent;
    if (widget.initialEvents != null && recorded != null) {
      setState(() {
        _events = <AiSuggestedActionEvent>[recorded, ..._events];
      });
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final summaries = widget.service.buildTypeSummaries(_events);
    final filteredEvents = widget.service.filterEvents(
      _events,
      query: _query,
      typeFilter: _selectedType,
      onlyFlaggedDeception: _onlyFlaggedDeception,
    );
    final totalEvents = _events.length;
    final flaggedCount = _events.where((e) => e.flaggedDeception).length;
    final flaggedPercent =
        totalEvents == 0 ? 0.0 : (flaggedCount / totalEvents) * 100.0;
    final impressionCount =
        _events.where((e) => e.eventKind == 'impression').length;
    final clickCount = _events.where((e) => e.eventKind == 'click').length;
    final ctrPercent =
        impressionCount == 0 ? 0.0 : (clickCount / impressionCount) * 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKpiSummary(
          totalEvents: totalEvents,
          flaggedCount: flaggedCount,
          flaggedPercent: flaggedPercent,
          ctrPercent: ctrPercent,
        ),
        const SizedBox(height: 16),
        _buildSandboxCard(),
        const SizedBox(height: 16),
        _buildTypeSummariesCard(
          summaries: summaries,
          totalEvents: totalEvents,
        ),
        const SizedBox(height: 16),
        _buildEventLogCard(
          filteredEvents: filteredEvents,
        ),
      ],
    );
  }

  Widget _buildKpiSummary({
    required int totalEvents,
    required int flaggedCount,
    required double flaggedPercent,
    required double ctrPercent,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiTile(
          tileKey: const Key('ai_action_audit_total_events'),
          label: '記録イベント数',
          value: '$totalEvents 件',
          accent: const Color(0xFF4F46E5),
        ),
        _KpiTile(
          tileKey: const Key('ai_action_audit_flagged_count'),
          label: '意図外使用の疑い',
          value: '$flaggedCount 件 (${flaggedPercent.toStringAsFixed(1)}%)',
          accent: flaggedCount > 0
              ? const Color(0xFFD97706)
              : const Color(0xFF047857),
        ),
        _KpiTile(
          tileKey: const Key('ai_action_audit_ctr'),
          label: '全体クリック率 (CTR)',
          value: '${ctrPercent.toStringAsFixed(1)}%',
          accent: const Color(0xFF0284C7),
        ),
      ],
    );
  }

  Widget _buildSandboxCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '汎用UIアクション・意図逸脱耐性プレビュー',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'narrative_choice / scene_transition / generic_narrative_choice、および誤マッピング・未定義アクションの安全フォールバック挙動を確認できます。押下すると監査ログが記録されます。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            AiSuggestedActionBar(
              actions: _sandboxActions,
              monitorService: widget.service,
              recordImpressions: false,
              onActionHandled: _onSandboxActionHandled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSummariesCard({
    required List<AiActionTypeAuditSummary> summaries,
    required int totalEvents,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'アクション種別別の使用頻度と意図外使用率',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            if (summaries.isEmpty)
              Text(
                'まだ集計対象のアクションイベントがありません。上のプレビューを押すか会話画面で提案が生成されると種別別の頻度が可視化されます。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              )
            else
              for (final item in summaries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TypeSummaryRow(
                    summary: item,
                    totalEvents: totalEvents,
                    selected: _selectedType == item.actionType,
                    onTap: () {
                      setState(() {
                        _selectedType = _selectedType == item.actionType
                            ? null
                            : item.actionType;
                      });
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventLogCard({
    required List<AiSuggestedActionEvent> filteredEvents,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ラベル × アクション種別 × 会話文脈ペア一覧',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('ai_action_audit_search_input'),
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'ラベル・アクション種別・直前の会話文脈を検索',
                hintText: '例: invite / お金 / シーン移行 / 収益化',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  key: const Key('ai_action_audit_deception_only_chip'),
                  selected: _onlyFlaggedDeception,
                  label: const Text('意図外使用の疑いのみ'),
                  onSelected: (value) {
                    setState(() {
                      _onlyFlaggedDeception = value;
                    });
                  },
                ),
                ChoiceChip(
                  selected: _selectedType == null,
                  label: const Text('全種別'),
                  onSelected: (_) {
                    setState(() {
                      _selectedType = null;
                    });
                  },
                ),
                for (final type in AiSuggestedActionType.values)
                  ChoiceChip(
                    key: Key('ai_action_audit_type_chip_${type.wireValue}'),
                    selected: _selectedType == type,
                    label: Text(type.wireValue),
                    onSelected: (_) {
                      setState(() {
                        _selectedType = _selectedType == type ? null : type;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '一致するアクションペアはありません。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (var i = 0; i < filteredEvents.length; i++)
                _EventPairTile(
                  key: Key('ai_action_audit_event_$i'),
                  event: filteredEvents[i],
                ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.tileKey,
    required this.label,
    required this.value,
    required this.accent,
  });

  final Key tileKey;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: tileKey,
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSummaryRow extends StatelessWidget {
  const _TypeSummaryRow({
    required this.summary,
    required this.totalEvents,
    required this.selected,
    required this.onTap,
  });

  final AiActionTypeAuditSummary summary;
  final int totalEvents;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final share = totalEvents == 0 ? 0.0 : summary.totalEvents / totalEvents;
    final unexpectedPct = (summary.unexpectedUseRate * 100).toStringAsFixed(1);
    final sharePct = (share * 100).toStringAsFixed(1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${summary.actionType.displayName} (${summary.actionType.wireValue})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${summary.totalEvents}件 ($sharePct%) / 意図外疑い: $unexpectedPct%',
                  style: TextStyle(
                    fontSize: 12,
                    color: summary.deceptionCount > 0
                        ? const Color(0xFFB45309)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  summary.deceptionCount > 0
                      ? const Color(0xFFD97706)
                      : const Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventPairTile extends StatelessWidget {
  const _EventPairTile({
    super.key,
    required this.event,
  });

  final AiSuggestedActionEvent event;

  @override
  Widget build(BuildContext context) {
    final isFlagged = event.flaggedDeception;
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor =
        isFlagged ? const Color(0xFFB45309) : const Color(0xFF047857);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFlagged
            ? const Color(0xFFFEF3C7).withAlpha(110)
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isFlagged ? const Color(0xFFF59E0B) : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFlagged
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 16,
                color: badgeColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ラベル: 「${event.label}」',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  '${event.rawActionType} · ${event.eventKind}',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          if (event.contextExcerpt.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '直前の会話文脈: ${event.contextExcerpt}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          if (event.deceptionReason case final reason?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '警戒理由: $reason',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
