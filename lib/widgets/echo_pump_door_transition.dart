import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';

/// A finite presentation of an already committed move. No game mutation here.
class EchoPumpDoorTransition extends StatefulWidget {
  const EchoPumpDoorTransition({
    super.key,
    required this.from,
    required this.to,
    required this.onFinished,
  });

  final PumpRoom from;
  final PumpRoom to;
  final VoidCallback onFinished;

  @override
  State<EchoPumpDoorTransition> createState() => _DoorTransitionState();
}

class _DoorTransitionState extends State<EchoPumpDoorTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish();
      });
    } else {
      _controller.forward();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _controller.stop();
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Material(
          key: const Key('echo-door-transition'),
          color: const Color(0xFF050A0D),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '移動中：${widget.from.label} → ${widget.to.label}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF9BE0CF), fontSize: 18,),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final t = _controller.value;
                          final opening = t < .34
                              ? Curves.easeInOut
                                  .transform((t / .34).clamp(0.0, 1.0))
                              : t < .58
                                  ? 1.0
                                  : 1 -
                                      Curves.easeInOut.transform(
                                          ((t - .58) / .32).clamp(0.0, 1.0),);
                          final blackout = t < .34
                              ? 0.0
                              : t < .48
                                  ? (t - .34) / .14
                                  : t < .58
                                      ? 1.0
                                      : (1 - (t - .58) / .14).clamp(0.0, 1.0);
                          return Opacity(
                            opacity:
                                t < .9 ? 1 : ((1 - t) / .1).clamp(0.0, 1.0),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Center(
                                  child: AspectRatio(
                                    aspectRatio: .8,
                                    child: LayoutBuilder(
                                      builder: (context, bounds) => Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CustomPaint(
                                              painter: _DoorPainter(opening,
                                                  frame: true,),),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: bounds.maxWidth * .17,
                                              vertical: bounds.maxHeight * .08,
                                            ),
                                            child: Transform(
                                              alignment: Alignment.centerLeft,
                                              transform: Matrix4.identity()
                                                ..setEntry(3, 2, .0015)
                                                ..rotateY(
                                                    -opening * math.pi * .45,),
                                              child: CustomPaint(
                                                  painter:
                                                      _DoorPainter(opening),),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Opacity(
                                  opacity: blackout,
                                  child: const ColoredBox(color: Colors.black),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    key: const Key('echo-door-skip'),
                    onPressed: _finish,
                    icon: const Icon(Icons.skip_next, color: Color(0xFF9BE0CF)),
                    label: const Text('演出をスキップ',
                        style: TextStyle(color: Color(0xFF9BE0CF)),),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Original industrial steel door; no external image or runtime dependency.
class _DoorPainter extends CustomPainter {
  const _DoorPainter(this.opening, {this.frame = false});
  final double opening;
  final bool frame;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (frame) {
      canvas.drawRect(Rect.fromLTWH(w * .14, h * .05, w * .72, h * .9),
          Paint()..color = const Color(0xFF41545A),);
      canvas.drawRect(Rect.fromLTWH(w * .17, h * .08, w * .66, h * .84),
          Paint()..color = const Color(0xFF010405),);
      final light = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF24454E).withValues(alpha: opening * .65),
            Colors.transparent
          ,],
        ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, light);
      for (var i = 0; i < 9; i++) {
        canvas.drawLine(
            Offset(w * (.18 + i * .075), h * .96),
            Offset(w * (.21 + i * .075), h * .94),
            Paint()
              ..color = const Color(0xFFB49460)
              ..strokeWidth = h * .01,);
      }
      return;
    }
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF30464E), Color(0xFF1A2B32), Color(0xFF40575D)],
          ).createShader(Offset.zero & size),);
    final edge = Paint()
      ..color = const Color(0xFF6C878C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(Rect.fromLTWH(w * .06, h * .04, w * .88, h * .92), edge);
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(
          Offset(w * .23, h * (.18 + i * .035)),
          Offset(w * .77, h * (.18 + i * .035)),
          Paint()
            ..color = const Color(0xFF0D1C22)
            ..strokeWidth = h * .014,);
    }
    for (final y in [.1, .88]) {
      for (final x in [.12, .88]) {
        canvas.drawCircle(Offset(w * x, h * y), w * .015,
            Paint()..color = const Color(0xFF9BB4B4),);
      }
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .76, h * .52, w * .12, h * .025),
            Radius.circular(w * .01),),
        Paint()..color = const Color(0xFFB6CBC9),);
    canvas.drawRect(Rect.fromLTWH(w * .36, h * .73, w * .28, h * .055),
        Paint()..color = const Color(0xFF9BE0CF),);
    canvas.drawCircle(Offset(w * .5, h * .758), h * .014,
        Paint()..color = const Color(0xFF1B383B),);
  }

  @override
  bool shouldRepaint(_DoorPainter old) =>
      opening != old.opening || frame != old.frame;
}
