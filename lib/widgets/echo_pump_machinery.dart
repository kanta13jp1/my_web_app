import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'echo_pump_inventory.dart';

const _mint = Color(0xFF9BE0CF);
const _amber = Color(0xFFFFC785);

/// A view of committed game facts. Animation never advances the game clock.
class EchoPumpMachinery extends ImplicitlyAnimatedWidget {
  const EchoPumpMachinery({
    super.key,
    required this.repaired,
    required this.sealed,
    required this.drained,
    required this.powered,
    super.duration = const Duration(milliseconds: 1100),
  }) : super(curve: Curves.easeInOutCubic);

  final bool repaired;
  final bool sealed;
  final bool drained;
  final bool powered;

  @override
  AnimatedWidgetBaseState<EchoPumpMachinery> createState() => _MachineryState();
}

class _MachineryState extends AnimatedWidgetBaseState<EchoPumpMachinery> {
  Tween<double>? _fuse;
  Tween<double>? _gate;
  Tween<double>? _water;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _fuse = visitor(
      _fuse,
      widget.repaired ? 1.0 : 0.0,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
    _gate = visitor(
      _gate,
      widget.sealed ? 1.0 : 0.0,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
    _water = visitor(
      _water,
      widget.drained ? 1.0 : 0.0,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final fuse =
        still ? (widget.repaired ? 1.0 : 0.0) : _fuse!.evaluate(animation);
    final gate =
        still ? (widget.sealed ? 1.0 : 0.0) : _gate!.evaluate(animation);
    final water =
        still ? (widget.drained ? 1.0 : 0.0) : _water!.evaluate(animation);
    final label = '設備断面：ヒューズ${widget.repaired ? '装着済み' : '未装着'}、'
        '隔壁${widget.sealed ? '閉鎖' : '開放'}、'
        '水位${widget.drained ? '低下・排水完了' : '高・冠水中'}、'
        'C系統${widget.powered ? '通電' : '停止'}';
    return Semantics(
      key: const Key('echo-machinery'),
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _status(
                  Icons.electrical_services,
                  widget.repaired ? '装着済み' : 'ヒューズ待ち',
                  widget.repaired,
                ),
                _status(
                  widget.sealed ? Icons.lock : Icons.lock_open,
                  widget.sealed ? '隔壁閉鎖' : '隔壁開放',
                  widget.sealed,
                ),
                _status(
                  Icons.water_drop_outlined,
                  widget.drained ? '排水完了' : '冠水中',
                  widget.drained,
                ),
              ],
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              child: AspectRatio(
                aspectRatio: 2,
                child: FittedBox(
                  child: SizedBox(
                    width: 600,
                    height: 300,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            key: const Key('echo-machinery-drawing'),
                            painter: _MachineryPainter(
                              fuse,
                              gate,
                              water,
                              widget.powered,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 19 + 18 * (1 - fuse),
                          top: 23 - 18 * (1 - fuse),
                          width: 156,
                          height: 110,
                          child: Opacity(
                            opacity: fuse,
                            child: EchoPumpFuseArt(present: widget.repaired),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(IconData icon, String text, bool complete) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: complete ? _mint : _amber),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: complete ? _mint : _amber)),
        ],
      );
}

/// Original schematic: fuse bay → motor → isolation gate → flooded outlet.
class _MachineryPainter extends CustomPainter {
  const _MachineryPainter(this.fuse, this.gate, this.water, this.powered);
  final double fuse;
  final double gate;
  final double water;
  final bool powered;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    void line(Offset a, Offset b, Color color, [double width = 3]) {
      canvas.drawLine(
        a,
        b,
        ink
          ..color = color
          ..strokeWidth = width,
      );
    }

    void box(Rect rect, Color fill, Color border, [double radius = 8]) {
      final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(shape, Paint()..color = fill);
      canvas.drawRRect(
        shape,
        ink
          ..color = border
          ..strokeWidth = 2,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFF0B191F),
    );
    for (double x = 20; x < 600; x += 20) {
      line(Offset(x, 0), Offset(x, 300), const Color(0xFF14292F), 1);
    }
    for (double y = 20; y < 300; y += 20) {
      line(Offset(0, y), Offset(600, y), const Color(0xFF14292F), 1);
    }
    box(
      const Rect.fromLTWH(18, 22, 160, 122),
      const Color(0xFF20353A),
      fuse > .5 ? _mint : _amber,
    );
    box(
      const Rect.fromLTWH(36, 52, 124, 48),
      const Color(0xFF0B191F),
      const Color(0xFF647C7F),
    );
    for (final x in [40.0, 150.0]) {
      line(Offset(x, 58), Offset(x, 94), _amber, 8);
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(48 + i * 25, 124),
        4,
        Paint()..color = fuse > .5 ? _mint : _amber,
      );
    }
    final live = fuse > .5 && powered;
    final cable = Path()
      ..moveTo(98, 145)
      ..lineTo(98, 204)
      ..lineTo(232, 204);
    canvas.drawPath(
      cable,
      ink
        ..color = live ? _mint : const Color(0xFF506568)
        ..strokeWidth = 5,
    );
    box(
      const Rect.fromLTWH(206, 106, 128, 146),
      const Color(0xFF263A40),
      const Color(0xFF688A8D),
    );
    canvas.drawCircle(
      const Offset(270, 172),
      44,
      Paint()..color = const Color(0xFF0B191F),
    );
    canvas.save();
    canvas.translate(270, 172);
    canvas.rotate(water * math.pi * 4);
    for (var i = 0; i < 4; i++) {
      canvas.rotate(math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-7, 6, 14, 30),
          const Radius.circular(5),
        ),
        Paint()..color = live ? _mint : const Color(0xFF688A8D),
      );
    }
    canvas.restore();
    canvas.drawCircle(const Offset(270, 172), 9, Paint()..color = _amber);
    for (var i = 0; i < 4; i++) {
      line(
        Offset(226, 224 + i * 6),
        Offset(314, 224 + i * 6),
        const Color(0xFF0B191F),
        2,
      );
    }
    line(
      const Offset(334, 172),
      const Offset(405, 172),
      const Color(0xFF506568),
      20,
    );
    if (water > 0 && water < 1) {
      line(
        Offset(340 + water * 44, 172),
        Offset(356 + water * 44, 172),
        _mint,
        6,
      );
    }
    box(
      const Rect.fromLTWH(416, 32, 164, 236),
      const Color(0xFF112A34),
      const Color(0xFF688A8D),
    );
    final level = 98 + water * 146;
    final wave = Path()..moveTo(420, level);
    for (double x = 420; x <= 576; x += 4) {
      wave.lineTo(
        x,
        level + math.sin((x - 420) / 16 + water * 12) * 3 * (1 - water),
      );
    }
    wave
      ..lineTo(576, 264)
      ..lineTo(420, 264)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0xFF24788C));
    for (var i = 0; i < 7; i++) {
      line(
        Offset(550, 64 + i * 27),
        Offset(569, 64 + i * 27),
        const Color(0xFFB0CFCD),
        2,
      );
    }
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(374, 40, 36, 224));
    final top = 44 - 218 * (1 - gate);
    box(
      Rect.fromLTWH(378, top, 28, 218),
      const Color(0xFF657A80),
      gate > .5 ? _mint : _amber,
      2,
    );
    for (var i = 0; i < 11; i++) {
      line(
        Offset(381, top + 12 + i * 19),
        Offset(403, top + 12 + i * 19),
        const Color(0xFF20353A),
        3,
      );
    }
    canvas.restore();
    line(
      const Offset(370, 40),
      const Offset(370, 266),
      const Color(0xFF92AEAF),
      3,
    );
    line(
      const Offset(412, 40),
      const Offset(412, 266),
      const Color(0xFF92AEAF),
      3,
    );
    for (double x = 28; x < 590; x += 22) {
      line(Offset(x, 286), Offset(x + 10, 276), const Color(0xFF52696A), 3);
    }
  }

  @override
  bool shouldRepaint(_MachineryPainter old) =>
      fuse != old.fuse ||
      gate != old.gate ||
      water != old.water ||
      powered != old.powered;
}
