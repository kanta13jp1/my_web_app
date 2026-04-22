import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/kgi_csf_kpi.dart';
import '../models/local_election_plan.dart';
import 'kgi_csf_kpi_panel.dart';

class ElectionJapanMap extends StatefulWidget {
  final List<LocalElectionPrefecturePlan> prefectures;

  const ElectionJapanMap({
    super.key,
    required this.prefectures,
  });

  @override
  State<ElectionJapanMap> createState() => _ElectionJapanMapState();
}

class _ElectionJapanMapState extends State<ElectionJapanMap> {
  int _selectedIndex = 12; // Tokyo by default.

  @override
  void initState() {
    super.initState();
    _selectedIndex = _firstPriorityIndex();
  }

  @override
  void didUpdateWidget(covariant ElectionJapanMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.prefectures.length) {
      _selectedIndex = _firstPriorityIndex();
    }
  }

  int _firstPriorityIndex() {
    if (widget.prefectures.isEmpty) {
      return 0;
    }
    var index = 0;
    var score = -1;
    for (var i = 0; i < widget.prefectures.length; i++) {
      final item = widget.prefectures[i];
      final currentScore = item.additionalSeatTarget * 3 +
          item.newCandidateTarget * 2 +
          item.closeRaceSupportRounds;
      if (currentScore > score) {
        score = currentScore;
        index = i;
      }
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.prefectures.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final totalAdditional = widget.prefectures.fold<int>(
      0,
      (sum, item) => sum + item.additionalSeatTarget,
    );
    final totalNew = widget.prefectures.fold<int>(
      0,
      (sum, item) => sum + item.newCandidateTarget,
    );
    final totalFocus = widget.prefectures.fold<int>(
      0,
      (sum, item) => sum + item.focusMunicipalityCount,
    );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: Color(0xFF0369A1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '全国KPIマップ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '都道府県別の純増・新人擁立・公認期限を地図で俯瞰',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            KgiCsfKpiPanel(
              plan: KgiCsfKpiPlan(
                domain: '全国県連KPI',
                kgi: '47県連の純増計画を700人達成へ接続する',
                actualLabel: '純増$totalAdditional / 新人$totalNew',
                targetLabel: '700人必達',
                metrics: <KgiCsfKpiMetric>[
                  KgiCsfKpiMetric.number(
                    csf: '候補者擁立',
                    kpi: '新人擁立目標',
                    actual: totalNew,
                    target: totalAdditional,
                    unit: '人',
                  ),
                  KgiCsfKpiMetric.number(
                    csf: '重点自治体攻略',
                    kpi: '重点自治体数',
                    actual: totalFocus,
                    target: widget.prefectures.length * 2,
                    unit: '件',
                  ),
                  KgiCsfKpiMetric.number(
                    csf: '県連配分',
                    kpi: '純増配分',
                    actual: totalAdditional,
                    target: 360,
                    unit: '人',
                  ),
                ],
              ),
              accentColor: const Color(0xFF0369A1),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: '純増配分',
                  value: totalAdditional.toString(),
                  color: const Color(0xFF2563EB),
                ),
                _MetricChip(
                  label: '新人擁立',
                  value: totalNew.toString(),
                  color: const Color(0xFF7C3AED),
                ),
                _MetricChip(
                  label: '重点自治体',
                  value: totalFocus.toString(),
                  color: const Color(0xFF0F766E),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final map = _buildMap(context);
                final detail = _buildDetailPanel(context);
                if (!wide) {
                  return Column(
                    children: [
                      map,
                      const SizedBox(height: 16),
                      detail,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: map),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: detail),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final maxLoad = widget.prefectures.fold<int>(
      1,
      (max, item) => math.max(
        max,
        item.additionalSeatTarget + item.newCandidateTarget,
      ),
    );
    final safeIndex = math.min(_selectedIndex, widget.prefectures.length - 1);
    final selectedPlan = widget.prefectures[safeIndex];
    final selectedTile = _tileForIndex(safeIndex, selectedPlan);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        const horizontalPadding = 16.0;
        const headerHeight = 44.0;
        final mapAvailableWidth = math.max(
          120.0,
          availableWidth - horizontalPadding * 2,
        );
        final cell = math.min(34.0, math.max(12.0, mapAvailableWidth / 10.4));
        final width = cell * _mapColumns;
        final height = cell * _mapRows;
        final surfaceWidth = width + horizontalPadding * 2;
        final surfaceHeight = height + horizontalPadding * 2 + headerHeight;

        return Center(
          child: SizedBox(
            width: surfaceWidth,
            height: surfaceHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _JapanMapSurfacePainter(
                      outlineColor:
                          Theme.of(context).colorScheme.outlineVariant,
                      oceanColor: const Color(0xFFEFF6FF),
                      gridColor: const Color(0xFF93C5FD),
                    ),
                  ),
                ),
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  top: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '日本地図UI',
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SelectedMapBadge(
                        label: '${selectedTile.shortName} 選択中',
                        value:
                            '純増${selectedPlan.additionalSeatTarget} / 新人${selectedPlan.newCandidateTarget}',
                      ),
                    ],
                  ),
                ),
                for (final label in _regionLabels)
                  Positioned(
                    left: horizontalPadding + label.col * cell,
                    top: headerHeight + label.row * cell,
                    child: _RegionMapLabel(label: label.label),
                  ),
                Positioned(
                  left: horizontalPadding,
                  top: headerHeight,
                  width: width,
                  height: height,
                  child: Stack(
                    children: [
                      for (final tile in _japanTiles)
                        _buildPrefectureTile(
                          context: context,
                          tile: tile,
                          cell: cell,
                          maxLoad: maxLoad,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrefectureTile({
    required BuildContext context,
    required _JapanTile tile,
    required double cell,
    required int maxLoad,
  }) {
    final plan = tile.index < widget.prefectures.length
        ? widget.prefectures[tile.index]
        : null;
    final selected = tile.index == _selectedIndex;
    final total =
        plan == null ? 0 : plan.additionalSeatTarget + plan.newCandidateTarget;
    final color = _tileColor(context, plan, maxLoad);
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : const Color(0xFF111827);
    final borderColor = selected
        ? const Color(0xFF111827)
        : (plan?.endorsementConfirmed == true
            ? const Color(0xFF16A34A)
            : Colors.white.withValues(alpha: 0.90));

    return Positioned(
      left: tile.col * cell,
      top: tile.row * cell,
      width: cell * tile.width - 3,
      height: cell - 3,
      child: Tooltip(
        message: plan == null
            ? tile.name
            : '${tile.name}: 純増${plan.additionalSeatTarget} / 新人${plan.newCandidateTarget} / 期限${formatMonthKey(plan.endorsementDeadlineMonth)}',
        child: Semantics(
          button: true,
          selected: selected,
          label: plan == null
              ? tile.name
              : '${tile.name} 純増${plan.additionalSeatTarget} 新人${plan.newCandidateTarget}',
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: plan == null
                  ? null
                  : () => setState(() => _selectedIndex = tile.index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tile.shortName,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (plan != null)
                        Text(
                          total.toString(),
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(BuildContext context) {
    final theme = Theme.of(context);
    final safeIndex = math.min(_selectedIndex, widget.prefectures.length - 1);
    final plan = widget.prefectures[safeIndex];
    final tile = _tileForIndex(safeIndex, plan);
    final now = DateTime.now();
    final overdue = plan.isEndorsementOverdue(now);
    final dueSoon = plan.isEndorsementDueSoon(now);
    final statusColor = plan.endorsementConfirmed
        ? const Color(0xFF16A34A)
        : overdue
            ? const Color(0xFFDC2626)
            : dueSoon
                ? const Color(0xFFF59E0B)
                : const Color(0xFF2563EB);
    final statusLabel = plan.endorsementConfirmed
        ? '公認確認済み'
        : overdue
            ? '期限超過'
            : dueSoon
                ? '60日以内'
                : '進行管理中';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${tile.name} KPI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPriorityMeter(context, plan),
          const SizedBox(height: 12),
          _buildDetailRows(
            context,
            entries: [
              MapEntry('現職人数', '${plan.currentMembers}'),
              if (plan.cdpLocalMembers > 0)
                MapEntry('立憲地方議員', '${plan.cdpLocalMembers}'),
              MapEntry('純増目標', '${plan.additionalSeatTarget}'),
              MapEntry('新人擁立', '${plan.newCandidateTarget}'),
              MapEntry('予定選挙', '${plan.scheduledElectionCount}件'),
              MapEntry('現職維持', '${plan.incumbentRetentionTarget}'),
              MapEntry('重点自治体', '${plan.focusMunicipalityCount}'),
              MapEntry('接戦支援', '${plan.closeRaceSupportRounds}回'),
              MapEntry('公認期限', formatMonthKey(plan.endorsementDeadlineMonth)),
            ],
          ),
          if (plan.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              plan.notes,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
            ),
          ],
        ],
      ),
    );
  }

  _JapanTile _tileForIndex(int index, LocalElectionPrefecturePlan plan) {
    return _japanTiles.firstWhere(
      (item) => item.index == index,
      orElse: () => _JapanTile(
        index: index,
        name: plan.prefecture,
        shortName: plan.prefecture,
        row: 0,
        col: 0,
      ),
    );
  }

  Widget _buildPriorityMeter(
    BuildContext context,
    LocalElectionPrefecturePlan plan,
  ) {
    final score = plan.additionalSeatTarget +
        plan.newCandidateTarget +
        plan.closeRaceSupportRounds;
    final ratio = (score / 72).clamp(0.0, 1.0).toDouble();
    final color = ratio >= 0.72
        ? const Color(0xFFDC2626)
        : ratio >= 0.48
            ? const Color(0xFFF59E0B)
            : const Color(0xFF2563EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '重点度',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
              ),
            ),
            Text(
              '$score pt',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 9,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRows(
    BuildContext context, {
    required List<MapEntry<String, String>> entries,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in entries)
          Container(
            width: 112,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(color: Color(0xFFBFDBFE), label: '低負荷'),
        _LegendItem(color: Color(0xFF2563EB), label: '高負荷'),
        _LegendItem(color: Color(0xFF16A34A), label: '公認確認済み'),
        _LegendItem(color: Color(0xFFF59E0B), label: '期限接近'),
        _LegendItem(color: Color(0xFFDC2626), label: '期限超過'),
      ],
    );
  }

  Color _tileColor(
    BuildContext context,
    LocalElectionPrefecturePlan? plan,
    int maxLoad,
  ) {
    if (plan == null) {
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
    final now = DateTime.now();
    if (plan.isEndorsementOverdue(now)) {
      return const Color(0xFFFCA5A5);
    }
    if (plan.isEndorsementDueSoon(now)) {
      return const Color(0xFFFCD34D);
    }
    final total = plan.additionalSeatTarget + plan.newCandidateTarget;
    final ratio = (total / maxLoad).clamp(0.0, 1.0);
    final base = plan.endorsementConfirmed
        ? const Color(0xFF16A34A)
        : const Color(0xFF2563EB);
    final tint = plan.endorsementConfirmed
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFDBEAFE);
    return Color.lerp(tint, base, 0.22 + ratio * 0.68) ?? base;
  }
}

class _SelectedMapBadge extends StatelessWidget {
  final String label;
  final String value;

  const _SelectedMapBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionMapLabel extends StatelessWidget {
  final String label;

  const _RegionMapLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _JapanMapSurfacePainter extends CustomPainter {
  final Color outlineColor;
  final Color oceanColor;
  final Color gridColor;

  const _JapanMapSurfacePainter({
    required this.outlineColor,
    required this.oceanColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final backgroundPaint = Paint()..color = oceanColor;
    canvas.drawRRect(rrect, backgroundPaint);

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var x = 24.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 26.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final coastlinePaint = Paint()
      ..color = const Color(0xFFBFDBFE).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(14, size.width * 0.045);

    final mainIsland = Path()
      ..moveTo(size.width * 0.78, size.height * 0.18)
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.30,
        size.width * 0.78,
        size.height * 0.43,
        size.width * 0.70,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.66,
        size.width * 0.42,
        size.height * 0.61,
        size.width * 0.32,
        size.height * 0.70,
      )
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.79,
        size.width * 0.15,
        size.height * 0.86,
        size.width * 0.10,
        size.height * 0.92,
      );
    canvas.drawPath(mainIsland, coastlinePaint);

    final hokkaido = Path()
      ..moveTo(size.width * 0.72, size.height * 0.09)
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.04,
        size.width * 0.90,
        size.height * 0.07,
        size.width * 0.92,
        size.height * 0.15,
      );
    canvas.drawPath(hokkaido, coastlinePaint);

    final shikokuKyushu = Path()
      ..moveTo(size.width * 0.17, size.height * 0.72)
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.75,
        size.width * 0.28,
        size.height * 0.83,
        size.width * 0.20,
        size.height * 0.91,
      );
    canvas.drawPath(shikokuKyushu, coastlinePaint);

    final borderPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _JapanMapSurfacePainter oldDelegate) {
    return outlineColor != oldDelegate.outlineColor ||
        oceanColor != oldDelegate.oceanColor ||
        gridColor != oldDelegate.gridColor;
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _JapanTile {
  final int index;
  final String name;
  final String shortName;
  final int row;
  final int col;
  final int width;

  const _JapanTile({
    required this.index,
    required this.name,
    required this.shortName,
    required this.row,
    required this.col,
    this.width = 1,
  });
}

class _RegionLabel {
  final String label;
  final double row;
  final double col;

  const _RegionLabel(this.label, this.row, this.col);
}

const int _mapColumns = 10;
const int _mapRows = 15;

const List<_RegionLabel> _regionLabels = <_RegionLabel>[
  _RegionLabel('北海道', 1.15, 7.05),
  _RegionLabel('東北', 2.65, 7.10),
  _RegionLabel('関東', 6.75, 6.85),
  _RegionLabel('中部', 5.25, 4.80),
  _RegionLabel('近畿', 7.00, 2.85),
  _RegionLabel('中国', 6.55, 0.20),
  _RegionLabel('四国', 9.70, 1.35),
  _RegionLabel('九州', 11.55, 2.15),
];

const List<_JapanTile> _japanTiles = <_JapanTile>[
  _JapanTile(index: 0, name: '北海道', shortName: '北海道', row: 0, col: 8, width: 2),
  _JapanTile(index: 1, name: '青森県', shortName: '青森', row: 2, col: 8),
  _JapanTile(index: 2, name: '岩手県', shortName: '岩手', row: 3, col: 9),
  _JapanTile(index: 3, name: '宮城県', shortName: '宮城', row: 4, col: 9),
  _JapanTile(index: 4, name: '秋田県', shortName: '秋田', row: 3, col: 8),
  _JapanTile(index: 5, name: '山形県', shortName: '山形', row: 4, col: 8),
  _JapanTile(index: 6, name: '福島県', shortName: '福島', row: 5, col: 8),
  _JapanTile(index: 7, name: '茨城県', shortName: '茨城', row: 6, col: 9),
  _JapanTile(index: 8, name: '栃木県', shortName: '栃木', row: 6, col: 8),
  _JapanTile(index: 9, name: '群馬県', shortName: '群馬', row: 6, col: 7),
  _JapanTile(index: 10, name: '埼玉県', shortName: '埼玉', row: 7, col: 8),
  _JapanTile(index: 11, name: '千葉県', shortName: '千葉', row: 8, col: 9),
  _JapanTile(index: 12, name: '東京都', shortName: '東京', row: 8, col: 8),
  _JapanTile(index: 13, name: '神奈川県', shortName: '神奈川', row: 9, col: 8),
  _JapanTile(index: 14, name: '新潟県', shortName: '新潟', row: 5, col: 7),
  _JapanTile(index: 15, name: '富山県', shortName: '富山', row: 6, col: 6),
  _JapanTile(index: 16, name: '石川県', shortName: '石川', row: 6, col: 5),
  _JapanTile(index: 17, name: '福井県', shortName: '福井', row: 7, col: 5),
  _JapanTile(index: 18, name: '山梨県', shortName: '山梨', row: 8, col: 7),
  _JapanTile(index: 19, name: '長野県', shortName: '長野', row: 7, col: 7),
  _JapanTile(index: 20, name: '岐阜県', shortName: '岐阜', row: 8, col: 6),
  _JapanTile(index: 21, name: '静岡県', shortName: '静岡', row: 9, col: 7),
  _JapanTile(index: 22, name: '愛知県', shortName: '愛知', row: 9, col: 6),
  _JapanTile(index: 23, name: '三重県', shortName: '三重', row: 10, col: 5),
  _JapanTile(index: 24, name: '滋賀県', shortName: '滋賀', row: 8, col: 4),
  _JapanTile(index: 25, name: '京都府', shortName: '京都', row: 8, col: 3),
  _JapanTile(index: 26, name: '大阪府', shortName: '大阪', row: 9, col: 3),
  _JapanTile(index: 27, name: '兵庫県', shortName: '兵庫', row: 8, col: 2),
  _JapanTile(index: 28, name: '奈良県', shortName: '奈良', row: 9, col: 4),
  _JapanTile(index: 29, name: '和歌山県', shortName: '和歌山', row: 10, col: 4),
  _JapanTile(index: 30, name: '鳥取県', shortName: '鳥取', row: 7, col: 1),
  _JapanTile(index: 31, name: '島根県', shortName: '島根', row: 7, col: 0),
  _JapanTile(index: 32, name: '岡山県', shortName: '岡山', row: 8, col: 1),
  _JapanTile(index: 33, name: '広島県', shortName: '広島', row: 8, col: 0),
  _JapanTile(index: 34, name: '山口県', shortName: '山口', row: 9, col: 0),
  _JapanTile(index: 35, name: '徳島県', shortName: '徳島', row: 10, col: 3),
  _JapanTile(index: 36, name: '香川県', shortName: '香川', row: 10, col: 2),
  _JapanTile(index: 37, name: '愛媛県', shortName: '愛媛', row: 10, col: 1),
  _JapanTile(index: 38, name: '高知県', shortName: '高知', row: 11, col: 2),
  _JapanTile(index: 39, name: '福岡県', shortName: '福岡', row: 10, col: 0),
  _JapanTile(index: 40, name: '佐賀県', shortName: '佐賀', row: 11, col: 0),
  _JapanTile(index: 41, name: '長崎県', shortName: '長崎', row: 12, col: 0),
  _JapanTile(index: 42, name: '熊本県', shortName: '熊本', row: 12, col: 1),
  _JapanTile(index: 43, name: '大分県', shortName: '大分', row: 11, col: 1),
  _JapanTile(index: 44, name: '宮崎県', shortName: '宮崎', row: 13, col: 2),
  _JapanTile(index: 45, name: '鹿児島県', shortName: '鹿児島', row: 13, col: 1),
  _JapanTile(index: 46, name: '沖縄県', shortName: '沖縄', row: 14, col: 0),
];
