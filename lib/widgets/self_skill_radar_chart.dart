import 'dart:math';

import 'package:flutter/material.dart';

import '../models/self_skill_asset.dart';

/// スキル資産バランスをレーダーチャート（3軸未満時は水平バー）で可視化する (#1392 / #2770)。
class SelfSkillRadarChart extends StatelessWidget {
  const SelfSkillRadarChart({
    super.key,
    required this.axes,
    this.size = 230,
  });

  final List<SelfSkillRadarAxisPoint> axes;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (axes.isEmpty) {
      return Container(
        key: const Key('self_skill_radar_empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Text(
          '保有スキルを登録すると、レーダーチャートまたは習熟度バーで資産バランスを可視化します。',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    if (axes.length < 3) {
      return Container(
        key: const Key('self_skill_radar_bars_fallback'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'スキル習熟度バー（3軸以上の登録でレーダーチャートを表示）',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final axis in axes) ...[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      axis.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    'Lv ${axis.value.toStringAsFixed(1)} / ${axis.maxValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: axis.normalized,
                minHeight: 7,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
    }

    final summaryText =
        axes.map((a) => '${a.label} ${a.value.toStringAsFixed(1)}').join('、');

    return Semantics(
      label: 'スキル資産レーダーチャート: $summaryText',
      child: Center(
        child: SizedBox(
          key: const Key('self_skill_radar_canvas_box'),
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SelfSkillRadarPainter(
              axes: axes,
              labelColor: Theme.of(context).colorScheme.onSurface,
              gridColor: Theme.of(context).dividerColor,
              accentColor: const Color(0xFF0F766E),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelfSkillRadarPainter extends CustomPainter {
  const _SelfSkillRadarPainter({
    required this.axes,
    required this.labelColor,
    required this.gridColor,
    required this.accentColor,
  });

  final List<SelfSkillRadarAxisPoint> axes;
  final Color labelColor;
  final Color gridColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n < 3) {
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.31;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 5段階の同心多角形グリッドを描画する。
    for (var ring = 1; ring <= 5; ring++) {
      final ringRadius = radius * (ring / 5.0);
      final ringPath = Path();
      for (var i = 0; i < n; i++) {
        final angle = -pi / 2 + (2 * pi * i / n);
        final pt = Offset(
          center.dx + ringRadius * cos(angle),
          center.dy + ringRadius * sin(angle),
        );
        if (i == 0) {
          ringPath.moveTo(pt.dx, pt.dy);
        } else {
          ringPath.lineTo(pt.dx, pt.dy);
        }
      }
      ringPath.close();
      canvas.drawPath(ringPath, gridPaint);
    }

    // 軸線とラベルを描画する。
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + (2 * pi * i / n);
      final endPt = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, endPt, gridPaint);

      final labelDist = radius + 24;
      final labelCenter = Offset(
        center.dx + labelDist * cos(angle),
        center.dy + labelDist * sin(angle),
      );
      final painter = TextPainter(
        text: TextSpan(
          text: '${axes[i].label}\n(${axes[i].value.toStringAsFixed(1)})',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 74);
      painter.paint(
        canvas,
        Offset(
          labelCenter.dx - painter.width / 2,
          labelCenter.dy - painter.height / 2,
        ),
      );
    }

    // 実データの多角形と頂点ドットを描画する。
    final dataPath = Path();
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + (2 * pi * i / n);
      final r = radius * axes[i].normalized;
      final pt = Offset(
        center.dx + r * cos(angle),
        center.dy + r * sin(angle),
      );
      points.add(pt);
      if (i == 0) {
        dataPath.moveTo(pt.dx, pt.dy);
      } else {
        dataPath.lineTo(pt.dx, pt.dy);
      }
    }
    dataPath.close();

    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);
    for (final pt in points) {
      canvas.drawCircle(pt, 3.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelfSkillRadarPainter oldDelegate) {
    return oldDelegate.axes != axes ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}
