import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/self_devin_control_tower_service.dart';

class SelfDevinControlTowerCard extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  final SelfDevinControlTowerSnapshot? snapshotOverride;

  const SelfDevinControlTowerCard({
    super.key,
    this.supabaseClient,
    this.snapshotOverride,
  });

  @override
  State<SelfDevinControlTowerCard> createState() =>
      _SelfDevinControlTowerCardState();
}

class _SelfDevinControlTowerCardState extends State<SelfDevinControlTowerCard> {
  final SelfDevinControlTowerService _service =
      const SelfDevinControlTowerService();

  bool _loading = true;
  String? _error;
  SelfDevinControlTowerSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    if (widget.snapshotOverride != null) {
      _snapshot = widget.snapshotOverride;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _service.load(
        supabaseClient: widget.supabaseClient,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.hub, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Self Devin control tower',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Feature request -> WBS -> 4 lanes -> CI self-heal',
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.snapshotOverride == null)
                  IconButton(
                    onPressed: _loading ? null : _load,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildErrorState(textTheme)
            else if (_snapshot != null)
              _buildSnapshot(context, _snapshot!, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFB91C1C).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFB91C1C).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        _error ?? 'Unknown error',
        style: textTheme.bodySmall?.copyWith(
          color: const Color(0xFFB91C1C),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSnapshot(
    BuildContext context,
    SelfDevinControlTowerSnapshot snapshot,
    TextTheme textTheme,
  ) {
    final readinessPct = (snapshot.readiness * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildMetricChip(
              label: 'Readiness',
              value: '$readinessPct%',
              color: const Color(0xFF0F766E),
            ),
            _buildMetricChip(
              label: 'Healthy loops',
              value: '${snapshot.healthyLoopCount}/${snapshot.totalLoopCount}',
              color: const Color(0xFF2563EB),
            ),
            _buildMetricChip(
              label: 'Open FR',
              value: '${snapshot.openFeatureRequestCount}',
              color: const Color(0xFFFF6B35),
            ),
            _buildMetricChip(
              label: 'Blocked',
              value: '${snapshot.blockedTaskCount}',
              color: const Color(0xFFDC2626),
            ),
            _buildMetricChip(
              label: 'Active lanes',
              value: '${snapshot.activeLaneCount}/4',
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: snapshot.readiness,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Automation loops', textTheme),
        const SizedBox(height: 8),
        ...snapshot.loops.map(_buildLoopTile),
        const SizedBox(height: 16),
        _buildSectionTitle('4 lanes', textTheme),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final cardWidth = constraints.maxWidth > 860
                ? (constraints.maxWidth - 24) / 4
                : constraints.maxWidth > 620
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: snapshot.lanes
                  .map(
                    (SelfDevinLaneSnapshot lane) => SizedBox(
                      width: cardWidth,
                      child: _buildLaneTile(lane, textTheme),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Next move', textTheme),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                snapshot.nextActionTitle,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                snapshot.nextActionDetail,
                style: textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoopTile(SelfDevinLoopSnapshot loop) {
    final color = _loopStatusColor(loop.status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  loop.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _loopStatusLabel(loop.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${loop.cadenceLabel} | ${_formatDateTime(loop.lastRunAt)}',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loop.detail,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaneTile(
    SelfDevinLaneSnapshot lane,
    TextTheme textTheme,
  ) {
    final color = _laneColor(lane);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  lane.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                lane.healthLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLaneMetricRow('Active', '${lane.activeTasks}', textTheme),
          _buildLaneMetricRow('Blocked', '${lane.blockedTasks}', textTheme),
          _buildLaneMetricRow('Overdue', '${lane.overdueTasks}', textTheme),
          _buildLaneMetricRow(
            'Open FR',
            '${lane.featureRequestTasks}',
            textTheme,
          ),
          _buildLaneMetricRow(
            'Avg progress',
            '${lane.averageProgress}%',
            textTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildLaneMetricRow(
    String label,
    String value,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, TextTheme textTheme) {
    return Text(
      text,
      style: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Color _loopStatusColor(String status) {
    switch (status) {
      case 'healthy':
        return const Color(0xFF0F766E);
      case 'running':
        return const Color(0xFF2563EB);
      case 'error':
        return const Color(0xFFDC2626);
      case 'configured':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _loopStatusLabel(String status) {
    switch (status) {
      case 'healthy':
        return 'Healthy';
      case 'running':
        return 'Running';
      case 'error':
        return 'Error';
      case 'configured':
        return 'Configured';
      default:
        return 'Watch';
    }
  }

  Color _laneColor(SelfDevinLaneSnapshot lane) {
    if (lane.blockedTasks > 0 || lane.overdueTasks > 0) {
      return const Color(0xFFDC2626);
    }
    if (lane.staleTasks > 0) {
      return const Color(0xFFF59E0B);
    }
    if (lane.activeTasks == 0) {
      return const Color(0xFF64748B);
    }
    return const Color(0xFF0F766E);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'No run yet';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
