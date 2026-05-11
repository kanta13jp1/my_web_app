import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'collapsible_home_section.dart';

class GaReadinessGatePanel extends StatefulWidget {
  const GaReadinessGatePanel({super.key});

  @override
  State<GaReadinessGatePanel> createState() => _GaReadinessGatePanelState();
}

class _GaReadinessGatePanelState extends State<GaReadinessGatePanel> {
  late Future<_GaReadinessSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadSnapshot();
  }

  void _refresh() {
    setState(() {
      _future = _loadSnapshot();
    });
  }

  Future<_GaReadinessSnapshot> _loadSnapshot() async {
    final fallback = _GaReadinessSnapshot.fallback();
    if (Supabase.instance.client.auth.currentUser == null) {
      return fallback.copyWith(sourceNote: 'Sign in to refresh from app-hub.');
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'app-hub',
        body: {'action': 'agent.list_ga_axes'},
      );
      final rawData = response.data;
      if (rawData is! Map) {
        throw const FormatException('Invalid GA readiness response');
      }
      final data = Map<String, dynamic>.from(rawData);
      final rawSnapshot = data['ga_readiness'];
      if (rawSnapshot is! Map) {
        throw const FormatException('Missing GA readiness payload');
      }
      return _GaReadinessSnapshot.fromJson(
        Map<String, dynamic>.from(rawSnapshot),
      );
    } catch (error) {
      return fallback.copyWith(sourceNote: 'Offline snapshot: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleHomeSection(
      key: const Key('home_ga_readiness_gate_panel'),
      storageKey: 'home_section_ga_readiness_gate',
      title: 'GA READINESS GATE',
      icon: Icons.verified_outlined,
      iconColor: const Color(0xFF0D9488),
      initiallyExpanded: false,
      child: FutureBuilder<_GaReadinessSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _GaReadinessSnapshot.fallback();
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          return _GaReadinessGateBody(
            snapshot: data,
            isLoading: isLoading,
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

class _GaReadinessGateBody extends StatelessWidget {
  final _GaReadinessSnapshot snapshot;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _GaReadinessGateBody({
    required this.snapshot,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final progress = snapshot.overallProgress / 100;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _GaReadinessSummary(
                    snapshot: snapshot,
                    progress: progress,
                  ),
                ),
                Tooltip(
                  message: 'Refresh GA readiness',
                  child: IconButton(
                    key: const Key('home_ga_readiness_refresh'),
                    onPressed: isLoading ? null : onRefresh,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 8,
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(
                  snapshot.gaEligible
                      ? const Color(0xFF0D9488)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.axes
                  .map((axis) => _GaReadinessAxisChip(axis: axis))
                  .toList(),
            ),
            if (snapshot.blockers.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...snapshot.blockers
                  .take(3)
                  .map(
                    (blocker) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_clock_outlined,
                            size: 16,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              blocker,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF334155),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    snapshot.sourceNote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/project-gantt'),
                  icon: const Icon(Icons.timeline, size: 16),
                  label: const Text('WBS'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(72, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
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

class _GaReadinessSummary extends StatelessWidget {
  final _GaReadinessSnapshot snapshot;
  final double progress;

  const _GaReadinessSummary({required this.snapshot, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snapshot.gaEligible ? 'GA eligible' : 'GA blocked',
          style: TextStyle(
            color: snapshot.gaEligible
                ? const Color(0xFF0D9488)
                : const Color(0xFFB45309),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${snapshot.greenCount}/${snapshot.axisCount} green - '
          '${snapshot.overallProgress}% ready',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _GaReadinessAxisChip extends StatelessWidget {
  final _GaReadinessAxis axis;

  const _GaReadinessAxisChip({required this.axis});

  @override
  Widget build(BuildContext context) {
    final colors = _axisColors(axis.status);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 156, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.foreground.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Text(
                axis.code,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    axis.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${axis.progress}% - #${axis.issue}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
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

class _AxisColors {
  final Color background;
  final Color border;
  final Color foreground;

  const _AxisColors({
    required this.background,
    required this.border,
    required this.foreground,
  });
}

_AxisColors _axisColors(String status) {
  return switch (status) {
    'green' => const _AxisColors(
      background: Color(0xFFEFFAF5),
      border: Color(0xFF99F6C7),
      foreground: Color(0xFF047857),
    ),
    'amber' => const _AxisColors(
      background: Color(0xFFFFFBEB),
      border: Color(0xFFFDE68A),
      foreground: Color(0xFFB45309),
    ),
    'red' => const _AxisColors(
      background: Color(0xFFFEF2F2),
      border: Color(0xFFFECACA),
      foreground: Color(0xFFB91C1C),
    ),
    _ => const _AxisColors(
      background: Color(0xFFF8FAFC),
      border: Color(0xFFCBD5E1),
      foreground: Color(0xFF475569),
    ),
  };
}

class _GaReadinessSnapshot {
  final bool gaEligible;
  final int axisCount;
  final int greenCount;
  final int blockedCount;
  final int overallProgress;
  final List<String> blockers;
  final List<_GaReadinessAxis> axes;
  final String sourceNote;

  const _GaReadinessSnapshot({
    required this.gaEligible,
    required this.axisCount,
    required this.greenCount,
    required this.blockedCount,
    required this.overallProgress,
    required this.blockers,
    required this.axes,
    this.sourceNote = 'Source: app-hub agent.list_ga_axes',
  });

  factory _GaReadinessSnapshot.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(json['summary'] as Map? ?? {});
    final axes = (json['axes'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (axis) => _GaReadinessAxis.fromJson(Map<String, dynamic>.from(axis)),
        )
        .toList();
    return _GaReadinessSnapshot(
      gaEligible: json['ga_eligible'] == true,
      axisCount: _asInt(summary['axis_count'], axes.length),
      greenCount: _asInt(summary['green_count'], 0),
      blockedCount: _asInt(summary['blocked_count'], 0),
      overallProgress: _asInt(summary['overall_progress'], 0),
      blockers: (summary['blockers'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      axes: axes,
    );
  }

  factory _GaReadinessSnapshot.fallback() {
    const axes = _fallbackAxes;
    return _GaReadinessSnapshot(
      gaEligible: false,
      axisCount: axes.length,
      greenCount: 0,
      blockedCount: axes.where((axis) => axis.status == 'blocked').length,
      overallProgress: 24,
      blockers: axes
          .where((axis) => axis.blocker.isNotEmpty)
          .map((axis) => '${axis.code}. ${axis.title}: ${axis.blocker}')
          .toList(),
      axes: axes,
      sourceNote: 'Fallback snapshot: waiting for app-hub.',
    );
  }

  _GaReadinessSnapshot copyWith({String? sourceNote}) {
    return _GaReadinessSnapshot(
      gaEligible: gaEligible,
      axisCount: axisCount,
      greenCount: greenCount,
      blockedCount: blockedCount,
      overallProgress: overallProgress,
      blockers: blockers,
      axes: axes,
      sourceNote: sourceNote ?? this.sourceNote,
    );
  }
}

class _GaReadinessAxis {
  final String code;
  final String title;
  final String status;
  final int progress;
  final int issue;
  final String blocker;

  const _GaReadinessAxis({
    required this.code,
    required this.title,
    required this.status,
    required this.progress,
    required this.issue,
    this.blocker = '',
  });

  factory _GaReadinessAxis.fromJson(Map<String, dynamic> json) {
    return _GaReadinessAxis(
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? 'blocked').toString(),
      progress: _asInt(json['progress'], 0),
      issue: _asInt(json['issue'], 0),
      blocker: (json['blocker'] ?? '').toString(),
    );
  }
}

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

const _fallbackAxes = [
  _GaReadinessAxis(
    code: 'A',
    title: 'MVP Scope',
    status: 'amber',
    progress: 80,
    issue: 1640,
  ),
  _GaReadinessAxis(
    code: 'B',
    title: 'Pricing v1.0',
    status: 'blocked',
    progress: 20,
    issue: 1640,
    blocker: 'Manual Paddle/legal approval is required.',
  ),
  _GaReadinessAxis(
    code: 'C',
    title: 'Legal Entity',
    status: 'blocked',
    progress: 0,
    issue: 1662,
    blocker: 'Corporate formation is a user/legal decision.',
  ),
  _GaReadinessAxis(
    code: 'D',
    title: 'Banking',
    status: 'blocked',
    progress: 0,
    issue: 1662,
    blocker: 'Bank account setup is user-owned.',
  ),
  _GaReadinessAxis(
    code: 'E',
    title: 'Video Secrets',
    status: 'blocked',
    progress: 20,
    issue: 1724,
    blocker: 'Repository secrets are still user-provided.',
  ),
];
