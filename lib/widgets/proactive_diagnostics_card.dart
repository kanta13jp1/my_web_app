import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProactiveDiagnosticsCard extends StatefulWidget {
  const ProactiveDiagnosticsCard({super.key});

  @override
  State<ProactiveDiagnosticsCard> createState() =>
      _ProactiveDiagnosticsCardState();
}

class _ProactiveDiagnosticsCardState extends State<ProactiveDiagnosticsCard> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw Exception('Not authenticated');
    }
    final response = await Supabase.instance.client.functions.invoke(
      'core-hub',
      body: {'action': 'system.proactive_diagnostics'},
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid proactive diagnostics response');
    }
    return Map<String, dynamic>.from(data);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _DiagnosticsLoading();
            }
            if (snapshot.hasError) {
              return _DiagnosticsError(
                message: snapshot.error.toString(),
                onRefresh: _refresh,
              );
            }
            return _DiagnosticsBody(
              data: snapshot.data ?? const <String, dynamic>{},
              onRefresh: _refresh,
            );
          },
        ),
      ),
    );
  }
}

class _DiagnosticsBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;

  const _DiagnosticsBody({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final score = (data['score'] as num?)?.toInt() ?? 0;
    final status = (data['status'] ?? 'unknown').toString();
    final checkedAt =
        DateTime.tryParse((data['checked_at'] ?? '').toString())?.toLocal();
    final aiReview = _asMap(data['ai_review']);
    final stats = _asMap(data['stats']);
    final findings = _asMapList(data['findings']);
    final primaryColor = _statusColor(status, score);
    final checkedAtLabel =
        checkedAt == null ? '未取得' : DateFormat('M/d HH:mm').format(checkedAt);
    final nextActions = _asStringList(aiReview['next_actions']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(Icons.health_and_safety_outlined, color: primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AIプロアクティブ診断',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'WBS・Issue・Actions・Supabaseのズレを先回りで検知します',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            _DiagnosticsIconAction(
              tooltip: '再診断',
              icon: Icons.refresh,
              onTap: onRefresh,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricChip(
              label: '診断スコア',
              value: '$score',
              color: primaryColor,
            ),
            _MetricChip(
              label: '未完了WBS',
              value: '${_intStat(stats, 'open_wbs_tasks')}',
              color: const Color(0xFF2563EB),
            ),
            _MetricChip(
              label: '期限超過',
              value: '${_intStat(stats, 'overdue_wbs_tasks')}',
              color: const Color(0xFFDC2626),
            ),
            _MetricChip(
              label: 'Actions失敗',
              value: '${_intStat(stats, 'latest_action_errors')}',
              color: const Color(0xFFF97316),
            ),
            _MetricChip(
              label: '確認',
              value: checkedAtLabel,
              color: const Color(0xFF64748B),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
        const SizedBox(height: 14),
        if ((aiReview['summary'] ?? '').toString().trim().isNotEmpty)
          _AiReviewBox(aiReview: aiReview, nextActions: nextActions),
        if (findings.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '検出事項',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...findings.take(4).map((finding) => _FindingTile(finding: finding)),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DiagnosticsActionButton(
              icon: Icons.timeline_outlined,
              label: 'WBSを見る',
              onTap: () => Navigator.pushNamed(context, '/project-gantt'),
            ),
            _DiagnosticsActionButton(
              icon: Icons.assignment_ind_outlined,
              label: 'ユーザータスク',
              onTap: () => Navigator.pushNamed(context, '/wbs-user-tasks'),
            ),
          ],
        ),
      ],
    );
  }

  static Color _statusColor(String status, int score) {
    if (status == 'risk' || score < 70) return const Color(0xFFDC2626);
    if (status == 'degraded' || score < 90) return const Color(0xFFF97316);
    return const Color(0xFF0F766E);
  }

  static int _intStat(Map<String, dynamic> stats, String key) =>
      (stats[key] as num?)?.toInt() ?? 0;

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class _AiReviewBox extends StatelessWidget {
  final Map<String, dynamic> aiReview;
  final List<String> nextActions;

  const _AiReviewBox({required this.aiReview, required this.nextActions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 6),
              Text(
                'AIレビュー',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF3730A3),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (aiReview['summary'] ?? '').toString(),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
          ),
          if ((aiReview['root_cause'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '原因仮説: ${aiReview['root_cause']}',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
            ),
          ],
          if (nextActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...nextActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '・$action',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  final Map<String, dynamic> finding;

  const _FindingTile({required this.finding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity = (finding['severity'] ?? 'info').toString();
    final color = switch (severity) {
      'critical' => const Color(0xFFDC2626),
      'warning' => const Color(0xFFF97316),
      _ => const Color(0xFF2563EB),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (finding['title'] ?? '').toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  (finding['next_action'] ?? '').toString(),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DiagnosticsLoading extends StatelessWidget {
  const _DiagnosticsLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 132,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DiagnosticsError extends StatelessWidget {
  final String message;
  final VoidCallback onRefresh;

  const _DiagnosticsError({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.health_and_safety_outlined,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Text(
              'AIプロアクティブ診断',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            _DiagnosticsIconAction(
              tooltip: '再診断',
              icon: Icons.refresh,
              onTap: onRefresh,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFFDC2626),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DiagnosticsActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
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

class _DiagnosticsIconAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _DiagnosticsIconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox.square(
              dimension: 40,
              child: Center(
                child: Icon(icon, size: 22, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
