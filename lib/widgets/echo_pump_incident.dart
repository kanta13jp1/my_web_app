import 'package:flutter/material.dart';

/// An original, three-shot equipment incident. It never changes game turns.
class EchoPumpIncident extends StatefulWidget {
  const EchoPumpIncident({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<EchoPumpIncident> createState() => _EchoPumpIncidentState();
}

class _EchoPumpIncidentState extends State<EchoPumpIncident>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  bool _finished = false;
  bool _paused = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _clock =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: 9),
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        });
    if (_foreground) _clock.forward();
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    _clock.stop();
    widget.onFinished();
  }

  void _togglePause() {
    if (_finished) return;
    setState(() => _paused = !_paused);
    if (_paused || !_foreground) {
      _clock.stop();
    } else {
      _clock.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _clock.stop();
    } else if (!_paused && !_finished) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final scene = (_clock.value * 3).floor().clamp(0, 2);
        const headings = ['警告灯', '廊下の影', '音の行き先'];
        const captions = ['予備灯だけが、揺れている。', '機械が軋むと、廊下の影が振り向いた。', '音は、誘導にもなる。'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text('設備異常 ${scene + 1} / 3'),
                  TextButton(
                    key: const Key('echo-incident-skip'),
                    onPressed: _finish,
                    child: const Text('スキップして探索へ'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Semantics(
                label: headings[scene],
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scale: reduced ? 1 : 1 + _clock.value * 0.04,
                        child: Image.asset(
                          'assets/echo_pump/opening_background.png',
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, error, stack) =>
                              const ColoredBox(color: Color(0xFF10282E)),
                        ),
                      ),
                      const ColoredBox(color: Color(0xA6081318)),
                      ExcludeSemantics(
                        child: CustomPaint(
                          key: ValueKey('echo-incident-shot-$scene'),
                          painter: _IncidentPanel(
                            scene,
                            reduced ? 0 : _clock.value,
                          ),
                        ),
                      ),
                      if (scene == 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Opacity(
                            opacity: 0.65,
                            child: Image.asset(
                              'assets/echo_pump/character_stalker.png',
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                              errorBuilder: (_, error, stack) => const Icon(
                                Icons.visibility_outlined,
                                color: Color(0xFF9BE0CF),
                                size: 90,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Flexible(
              flex: 0,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      headings[scene],
                      style: const TextStyle(color: Color(0xFF9BE0CF)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      captions[scene],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            LinearProgressIndicator(value: _clock.value),
            TextButton.icon(
              onPressed: _togglePause,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              label: Text(_paused ? '演出を再開' : '演出を一時停止'),
            ),
          ],
        );
      },
    );
  }
}

class _IncidentPanel extends CustomPainter {
  const _IncidentPanel(this.scene, this.progress);
  final int scene;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final scale = size.shortestSide * 0.24;
    final paint = Paint()
      ..color = scene == 0 ? const Color(0xFFFFB49B) : const Color(0xFF9BE0CF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: scale * 3, height: scale * 2),
        const Radius.circular(16),
      ),
      paint,
    );
    if (scene == 0) {
      canvas.drawCircle(center, scale * (0.35 + progress * 0.1), paint);
      canvas.drawLine(
        center - Offset(0, scale * 0.2),
        center + Offset(0, scale * 0.05),
        paint,
      );
      canvas.drawCircle(center + Offset(0, scale * 0.2), 2, paint);
    } else {
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: scale * (0.25 + i * 0.25)),
          -0.8,
          1.6,
          false,
          paint,
        );
      }
      canvas.drawLine(center - Offset(scale, 0), center, paint);
    }
  }

  @override
  bool shouldRepaint(_IncidentPanel oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.progress != progress;
}
