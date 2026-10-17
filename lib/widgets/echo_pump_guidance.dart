import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';
import '../services/echo_pump_audio.dart';

const _mint = Color(0xFF9BE0CF);

/// Progress is derived from the actual rules, never a separate saved checklist.
class EchoPumpProgress extends StatelessWidget {
  const EchoPumpProgress({super.key, required this.game});

  final EchoPumpGame game;

  @override
  Widget build(BuildContext context) {
    final completed = [
      game.hasFuse || game.repaired,
      game.repaired,
      game.sealed,
      game.drained,
      game.escaped,
    ];
    final current = completed.indexOf(false);
    const labels = ['回収', '修理', '封鎖', '排水', '脱出'];
    const icons = [
      Icons.electrical_services,
      Icons.build_outlined,
      Icons.lock_outline,
      Icons.water_drop_outlined,
      Icons.exit_to_app,
    ];
    final route = switch (current) {
      0 => (Icons.bolt, 'B系統', Icons.electrical_services, '工具庫'),
      1 => (Icons.electrical_services, 'ヒューズ', Icons.build_outlined, 'ポンプ室'),
      2 => (
          Icons.notifications_active_outlined,
          'C系統・点検槽',
          Icons.lock_outline,
          'ポンプ室'
        ),
      3 => (Icons.bolt, 'C系統', Icons.water_drop_outlined, 'ポンプ室'),
      _ => (Icons.home_outlined, '管理室', Icons.exit_to_app, '出口'),
    };
    return Semantics(
      container: true,
      label: '探索の進行',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 500 ? 3 : 5;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(route.$1, color: _mint),
                      Text(route.$2),
                      const Icon(Icons.arrow_forward, size: 18),
                      Icon(route.$3, color: _mint),
                      Text(route.$4),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < labels.length; i++)
                Semantics(
                  label:
                      '${labels[i]}：${completed[i] ? '完了' : i == current ? '次の目標' : '未完了'}',
                  child: ExcludeSemantics(
                    child: Container(
                      key: Key('echo-goal-$i'),
                      width: width,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: completed[i]
                            ? const Color(0xFF234F48)
                            : const Color(0xFF14272C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: i == current ? _mint : Colors.white12,
                          width: i == current ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            completed[i] ? Icons.check_circle : icons[i],
                            color: completed[i] || i == current
                                ? _mint
                                : Colors.white38,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(labels[i], textAlign: TextAlign.center),
                          Text(
                            completed[i]
                                ? '完了'
                                : i == current
                                    ? 'NEXT'
                                    : '—',
                            style: TextStyle(
                              color: i == current ? _mint : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One bounded response per action; reduced-motion users see the settled state.
class EchoPumpActionVisual extends StatelessWidget {
  const EchoPumpActionVisual({
    super.key,
    required this.revision,
    required this.cue,
    required this.from,
    required this.to,
    required this.message,
    required this.blocked,
  });

  final int revision;
  final EchoPumpCue? cue;
  final PumpRoom from;
  final PumpRoom to;
  final String message;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final danger =
        cue == EchoPumpCue.damage || cue == EchoPumpCue.fail || blocked;
    final color = danger ? const Color(0xFFFFB49B) : _mint;
    final (icon, title) = blocked
        ? (Icons.info_outline, '操作を確認')
        : switch (cue) {
            EchoPumpCue.step => (
                Icons.directions_walk,
                '${from.label} → ${to.label}'
              ),
            EchoPumpCue.power => (Icons.bolt, '電源切替'),
            EchoPumpCue.collect => (Icons.electrical_services, 'ヒューズ回収'),
            EchoPumpCue.repair => (Icons.build_outlined, '修理完了'),
            EchoPumpCue.seal => (Icons.lock_outline, '隔壁閉鎖'),
            EchoPumpCue.drain => (Icons.water_drop, '排水完了'),
            EchoPumpCue.damage => (Icons.heart_broken, '接触・体力低下'),
            EchoPumpCue.escape => (Icons.wb_twilight, '外へ到達'),
            EchoPumpCue.fail => (Icons.warning_amber, '探索失敗'),
            EchoPumpCue.start => (Icons.explore_outlined, '探索開始'),
            null => (Icons.hearing, '耳を澄ます'),
          };
    return Semantics(
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('echo-action-visual'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF14272C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(revision),
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 800),
                builder: (context, progress, child) => SizedBox(
                  height: 72,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ActionPainter(
                      cue: cue,
                      progress: progress,
                      color: color,
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * Curves.easeOut.transform(progress),
                        child: Icon(icon, size: 40, color: color),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              if (blocked) Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPainter extends CustomPainter {
  const _ActionPainter({
    required this.cue,
    required this.progress,
    required this.color,
  });
  final EchoPumpCue? cue;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25 + 0.35 * progress);
    if (cue == EchoPumpCue.step) {
      for (var i = 0; i < 6; i++) {
        if (progress < (i + 1) / 7) continue;
        final x = size.width * (i + 1) / 7;
        // Leave the central walk icon unobscured.
        if ((x - size.width / 2).abs() < 28) continue;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, i.isEven ? 25 : 48),
            width: 10,
            height: 18,
          ),
          paint,
        );
      }
    } else if (cue == EchoPumpCue.drain) {
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 4) {
        final y = 20 + progress * 42 + math.sin(x / 20 + progress * 8) * 4;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, paint);
    } else if (cue == EchoPumpCue.seal) {
      final width = size.width * 0.35 * progress;
      canvas.drawRect(Rect.fromLTWH(0, 8, width, 56), paint);
      canvas.drawRect(Rect.fromLTWH(size.width - width, 8, width, 56), paint);
    } else {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(size.width / 2, 36), 24 + 10 * progress, paint);
      for (var i = 0; i < 3; i++) {
        final width = math.min(size.width * 0.18, 64.0) * progress;
        canvas.drawLine(
          Offset(8, 20 + i * 16),
          Offset(8 + width, 20 + i * 16),
          paint,
        );
        canvas.drawLine(
          Offset(size.width - 8 - width, 20 + i * 16),
          Offset(size.width - 8, 20 + i * 16),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ActionPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.cue != cue ||
      oldDelegate.color != color;
}
