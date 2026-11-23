import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/competitor_discovery_log_service.dart';

class CompetitiveIntelNotebook {
  const CompetitiveIntelNotebook({
    required this.shortId,
    required this.title,
    required this.route,
    required this.issueNumber,
    required this.sourcePolicy,
    required this.evidence,
    required this.primarySourceRequired,
  });

  final String shortId;
  final String title;
  final String route;
  final int issueNumber;
  final String sourcePolicy;
  final String evidence;
  final bool primarySourceRequired;
}

@visibleForTesting
const competitiveIntelNotebookQueue = <CompetitiveIntelNotebook>[
  CompetitiveIntelNotebook(
    shortId: '0829f536',
    title:
        'Google I/O 2026: Strategic Defense and Competitive Analysis Briefing',
    route: 'competitive-intel',
    issueNumber: 1660,
    sourcePolicy: 'routing_only',
    evidence: 'docs/STRATEGIC_INTELLIGENCE_2026Q2.md section 3',
    primarySourceRequired: true,
  ),
  CompetitiveIntelNotebook(
    shortId: 'f167dcc3',
    title: 'Competitive AI Intelligence Report: The Multi-Agent Convergence',
    route: 'competitive-intel',
    issueNumber: 1660,
    sourcePolicy: 'routing_only',
    evidence: 'docs/STRATEGIC_INTELLIGENCE_2026Q2.md section 1',
    primarySourceRequired: true,
  ),
  CompetitiveIntelNotebook(
    shortId: 'c60da02b',
    title:
        'Strategic Intelligence Scoreboard: May 2026 Competitive Analysis Summary',
    route: 'competitive-intel',
    issueNumber: 1660,
    sourcePolicy: 'routing_only',
    evidence: 'docs/STRATEGIC_INTELLIGENCE_2026Q2.md sections 1-3',
    primarySourceRequired: true,
  ),
  CompetitiveIntelNotebook(
    shortId: 'd83954af',
    title: 'Competitor Discovery Report: April 2026 Status Update',
    route: 'competitive-intel',
    issueNumber: 1660,
    sourcePolicy: 'routing_only',
    evidence: 'docs/notebooklm-intake/latest-report.md',
    primarySourceRequired: true,
  ),
  CompetitiveIntelNotebook(
    shortId: '17cd45cd',
    title:
        'Competitive Intelligence Report: 2026 AI Infrastructure and Marketplace Trends',
    route: 'competitive-intel',
    issueNumber: 1660,
    sourcePolicy: 'routing_only',
    evidence: 'docs/STRATEGIC_INTELLIGENCE_2026Q2.md section 2',
    primarySourceRequired: true,
  ),
];

/// 管理者ダッシュボード用: 競合サイト可用性モニタリングカード。
/// get-competitor-monitoring Edge Function からデータを取得して表示。
class CompetitorMonitoringCard extends StatefulWidget {
  const CompetitorMonitoringCard({
    super.key,
    this.discoveryLogService,
    this.initialDiscoveryLogs,
  });

  final CompetitorDiscoveryLogService? discoveryLogService;
  final List<CompetitorDiscoveryLogEntry>? initialDiscoveryLogs;

  @override
  State<CompetitorMonitoringCard> createState() =>
      _CompetitorMonitoringCardState();
}

class _CompetitorMonitoringCardState extends State<CompetitorMonitoringCard> {
  bool _loading = false;
  bool _checking = false;
  String? _error;
  List<Map<String, dynamic>> _competitors = [];
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _runCheck() async {
    if (widget.initialDiscoveryLogs != null) {
      return;
    }
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _checking = false);
      return;
    }
    setState(() => _checking = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'admin-hub',
        body: {'action': 'competitor.check'},
      );
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
    await _load();
  }

  Future<void> _load() async {
    if (widget.initialDiscoveryLogs != null) {
      setState(() => _loading = false);
      return;
    }
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'admin-hub',
        body: {'action': 'monitoring.get'},
        queryParameters: {'days': '7'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final raw = data['competitors'];
        final rawSummary = data['summary'];
        setState(() {
          _competitors = raw is List
              ? List<Map<String, dynamic>>.from(
                  raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                )
              : [];
          _summary = rawSummary is Map<String, dynamic> ? rawSummary : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '競合モニタリング取得失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final availPct = summary != null
        ? (summary['availabilityPct'] as num?)?.toStringAsFixed(1)
        : null;
    final total = summary?['total'] as int?;
    final available = summary?['available'] as int?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart, color: Color(0xFF3D5AFE)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '競合サイト可用性モニタリング',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _load,
                    tooltip: '再読み込み',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _SummaryChip(
                    label: '可用率',
                    value: '$availPct%',
                    color: _availColor(double.tryParse(availPct ?? '0') ?? 0),
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: '正常',
                    value: '$available / $total',
                    color: Colors.green,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _buildCompetitiveIntelQueue(),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, height: 1.5),
              )
            else if (_loading && _competitors.isEmpty)
              const SizedBox(height: 40)
            else if (_competitors.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'データがありません。',
                    style: TextStyle(color: Color(0xFFB0B0B0), height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _checking ? null : _runCheck,
                    icon: _checking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow, size: 16),
                    label: Text(
                      _checking ? 'チェック中...' : '今すぐチェック',
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3D5AFE),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              )
            else
              ..._competitors.map(_buildRow),
            const SizedBox(height: 16),
            CompetitorDiscoveryLogsPanel(
              service: widget.discoveryLogService,
              initialLogs: widget.initialDiscoveryLogs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitiveIntelQueue() {
    final textTheme = Theme.of(context).textTheme;
    const accent = Color(0xFF3D5AFE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.policy, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'NotebookLM competitive intake',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const _SourcePolicyChip(label: '#1660', color: accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Routing metadata only. Verify with primary or official sources before scoring, copy, or WBS priority changes.',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFFB0B0B0),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          for (final notebook in competitiveIntelNotebookQueue)
            _buildCompetitiveIntelNotebookRow(notebook),
        ],
      ),
    );
  }

  Widget _buildCompetitiveIntelNotebookRow(
    final CompetitiveIntelNotebook notebook,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              notebook.shortId,
              style: textTheme.labelSmall?.copyWith(
                color: const Color(0xFFB8C4FF),
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notebook.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${notebook.route} / ${notebook.sourcePolicy} / ${notebook.evidence}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFB0B0B0),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> c) {
    final name = c['competitor']?.toString() ?? c['url']?.toString() ?? '?';
    final isUp = c['is_available'] as bool? ?? false;
    final ms = (c['response_ms'] as num?)?.toInt();
    final checkedAt = c['checked_at']?.toString();
    final timeStr = checkedAt != null
        ? checkedAt.substring(0, 16).replaceFirst('T', ' ')
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isUp ? Icons.check_circle : Icons.cancel,
            color: isUp ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, height: 1.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ms != null)
            Text(
              '${ms}ms',
              style: TextStyle(
                fontSize: 12,
                color: ms > 2000
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFB0B0B0),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _availColor(double pct) {
    if (pct >= 90) return Colors.green;
    if (pct >= 70) return const Color(0xFFFF6B35);
    return Colors.red;
  }
}

class _SourcePolicyChip extends StatelessWidget {
  const _SourcePolicyChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, height: 1.5),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 競合発掘ワークフロー (`competitor-discovery.yml`) の検索・応答・0件アラートログ閲覧パネル (#2696)。
class CompetitorDiscoveryLogsPanel extends StatefulWidget {
  const CompetitorDiscoveryLogsPanel({
    super.key,
    this.service,
    this.initialLogs,
  });

  final CompetitorDiscoveryLogService? service;
  final List<CompetitorDiscoveryLogEntry>? initialLogs;

  @override
  State<CompetitorDiscoveryLogsPanel> createState() =>
      _CompetitorDiscoveryLogsPanelState();
}

class _CompetitorDiscoveryLogsPanelState
    extends State<CompetitorDiscoveryLogsPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final CompetitorDiscoveryLogService _service =
      widget.service ?? const CompetitorDiscoveryLogService();

  bool _loading = false;
  bool _onlyZeroAlerts = false;
  String? _error;
  List<CompetitorDiscoveryLogEntry> _logs =
      const <CompetitorDiscoveryLogEntry>[];

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialLogs;
    if (seeded != null) {
      _logs = seeded;
    } else if (widget.service != null) {
      _loadLogs();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    if (widget.initialLogs != null && widget.service == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fetched = await _service.fetchLogs();
      if (mounted) {
        setState(() => _logs = fetched);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '発掘ログ読込エラー: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = CompetitorDiscoveryLogService.filterLogs(
      _logs,
      query: _searchCtrl.text,
      onlyZeroResultAlerts: _onlyZeroAlerts,
    );

    return Container(
      key: const ValueKey<String>('competitor_discovery_logs_panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.manage_search, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '競合発掘ログ・0件アラート履歴',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                key:
                    const ValueKey<String>('competitor_discovery_refresh_logs'),
                onPressed: _loading ? null : _loadLogs,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: '発掘ログを再読み込み',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('competitor_discovery_log_search'),
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'ログ検索（週・カテゴリ・エラー・クエリ）',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FilterChip(
                  key: const ValueKey<String>(
                    'competitor_discovery_zero_alert_filter',
                  ),
                  label: const Text('0件アラートのみ'),
                  selected: _onlyZeroAlerts,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (value) =>
                      setState(() => _onlyZeroAlerts = value),
                ),
              ),
              Text(
                '表示件数: ${filtered.length}件',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 13, height: 1.4),
            )
          else if (filtered.isEmpty)
            Text(
              '条件に一致する発掘ログはありません。',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            )
          else
            for (final entry in filtered) _DiscoveryLogTile(entry: entry),
        ],
      ),
    );
  }
}

class _DiscoveryLogTile extends StatelessWidget {
  const _DiscoveryLogTile({required this.entry});

  final CompetitorDiscoveryLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey<String>('competitor_discovery_log_item_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'Week ${entry.discoveryWeek}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (entry.zeroResultAlertTriggered)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '0件アラート',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '候補 ${entry.totalCandidates} / 追加 ${entry.stagedCount} / エラー ${entry.errorCount}',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: <Widget>[
          if (entry.alertSummary != null &&
              entry.alertSummary!.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.alertSummary!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.error,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (entry.errorLogs.isNotEmpty) ...<Widget>[
            for (final err in entry.errorLogs)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'エラー: $err',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
          for (final q in entry.queries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'カテゴリ ${q.category} (HTTP ${q.httpStatus ?? '-'} / 候補 ${q.candidateCount}): ${q.promptPreview}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
