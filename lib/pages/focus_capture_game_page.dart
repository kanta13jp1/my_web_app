import 'dart:math';

import 'package:flutter/material.dart';

class FocusCaptureGamePage extends StatefulWidget {
  const FocusCaptureGamePage({super.key});

  @override
  State<FocusCaptureGamePage> createState() => _FocusCaptureGamePageState();
}

class _FocusCaptureGamePageState extends State<FocusCaptureGamePage>
    with SingleTickerProviderStateMixin {
  static const List<_CaptureTarget> _targets = <_CaptureTarget>[
    _CaptureTarget(
      name: 'モチルン',
      focusPower: 214,
      difficulty: 0.06,
      color: Color(0xFF74C69D),
      accent: Color(0xFFFFD166),
    ),
    _CaptureTarget(
      name: 'ヒラメリーフ',
      focusPower: 286,
      difficulty: 0.1,
      color: Color(0xFF60A5FA),
      accent: Color(0xFFA7F3D0),
    ),
    _CaptureTarget(
      name: 'コツコツン',
      focusPower: 342,
      difficulty: 0.15,
      color: Color(0xFFF97316),
      accent: Color(0xFFFDE68A),
    ),
    _CaptureTarget(
      name: 'スタミナイト',
      focusPower: 408,
      difficulty: 0.2,
      color: Color(0xFF8B5CF6),
      accent: Color(0xFF93C5FD),
    ),
  ];

  final Random _random = Random();
  late final AnimationController _throwController;

  Animation<Offset>? _flight;
  Offset? _dragPosition;
  int _targetIndex = 0;
  int _balls = 5;
  int _captures = 0;
  int _streak = 0;
  double _lastChance = 0.72;
  String _message = '低いハードルを1つ捕まえる。';

  _CaptureTarget get _target => _targets[_targetIndex];

  @override
  void initState() {
    super.initState();
    _throwController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _throwController.dispose();
    super.dispose();
  }

  void _resetRun() {
    _throwController.stop();
    setState(() {
      _flight = null;
      _dragPosition = null;
      _balls = 5;
      _captures = 0;
      _streak = 0;
      _lastChance = 0.72;
      _message = '低いハードルを1つ捕まえる。';
    });
  }

  void _nextTarget() {
    _targetIndex = (_targetIndex + 1) % _targets.length;
  }

  Offset _targetCenter(Size size) =>
      Offset(size.width * 0.5, size.height * 0.42);

  Offset _restPosition(Size size) => Offset(size.width * 0.5, size.height - 72);

  Offset _clampToStage(Offset position, Size size) {
    return Offset(
      position.dx.clamp(34.0, size.width - 34.0).toDouble(),
      position.dy.clamp(34.0, size.height - 34.0).toDouble(),
    );
  }

  Offset _ballPosition(Size size) {
    final flight = _flight;
    if (flight != null && _throwController.isAnimating) {
      return flight.value;
    }
    return _dragPosition ?? _restPosition(size);
  }

  void _throw(Size size) {
    if (_balls <= 0 || _throwController.isAnimating) {
      return;
    }

    final release = _clampToStage(_dragPosition ?? _restPosition(size), size);
    final targetCenter = _targetCenter(size);
    final distance = (release - targetCenter).distance;
    final reach = max(160.0, size.shortestSide * 0.44);
    final accuracy = (1 - distance / reach).clamp(0.0, 1.0).toDouble();
    final chance = (0.18 + accuracy * 0.82 - _target.difficulty)
        .clamp(0.05, 0.96)
        .toDouble();
    final captured = accuracy >= 0.76 || _random.nextDouble() < chance;

    _flight = Tween<Offset>(begin: release, end: targetCenter).animate(
      CurvedAnimation(parent: _throwController, curve: Curves.easeOutCubic),
    );

    setState(() {
      _dragPosition = null;
      _lastChance = chance;
      _message = captured ? 'いい軌道。' : '少し浅い。';
    });

    _throwController.forward(from: 0).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _balls -= 1;
        _flight = null;
        if (captured) {
          _captures += 1;
          _streak += 1;
          _message = '${_target.name} を捕獲。集中力 +${18 + _streak * 2}';
          _nextTarget();
          if (_balls < 5) {
            _balls += 1;
          }
        } else {
          _streak = 0;
          _message = '逃げられた。次の1投に集中。';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1727),
      appBar: AppBar(
        title: const Text('フォーカス捕獲ゲーム'),
        actions: <Widget>[
          IconButton(
            tooltip: 'リセット',
            onPressed: _resetRun,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0B1727), Color(0xFF102A43)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final availableHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 720.0;
              final stageHeight =
                  min(620.0, max(340.0, availableHeight * 0.74));
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: stageHeight,
                          child: _buildStage(),
                        ),
                        const SizedBox(height: 14),
                        _buildControlStrip(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final targetCenter = _targetCenter(size);
          final ballPosition = _ballPosition(size);
          final canThrow = _balls > 0 && !_throwController.isAnimating;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: canThrow
                ? (DragStartDetails details) => setState(
                      () => _dragPosition = _clampToStage(
                        details.localPosition,
                        size,
                      ),
                    )
                : null,
            onPanUpdate: canThrow
                ? (DragUpdateDetails details) => setState(
                      () => _dragPosition = _clampToStage(
                        details.localPosition,
                        size,
                      ),
                    )
                : null,
            onPanEnd: canThrow ? (_) => _throw(size) : null,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const CustomPaint(painter: _FieldPainter()),
                Positioned(
                  top: 18,
                  left: 18,
                  child: _HudBadge(
                    icon: Icons.auto_awesome,
                    label: _target.name,
                    value: 'FP ${_target.focusPower}',
                  ),
                ),
                Positioned(
                  top: 18,
                  right: 18,
                  child: _HudBadge(
                    icon: Icons.trip_origin,
                    label: 'ORB',
                    value: '$_balls',
                  ),
                ),
                Positioned(
                  left: targetCenter.dx - 64,
                  top: targetCenter.dy - 70,
                  child: _TargetCreature(target: _target),
                ),
                Positioned(
                  left: ballPosition.dx - 29,
                  top: ballPosition.dy - 29,
                  child: FocusOrb(enabled: _balls > 0),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: _StatusPanel(
                    message: _balls == 0 ? 'ORB切れ。リセットで再開。' : _message,
                    chance: _lastChance,
                    captures: _captures,
                    streak: _streak,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlStrip() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _MetricChip(label: '捕獲', value: '$_captures'),
                  _MetricChip(label: '連続', value: '$_streak'),
                  _MetricChip(
                    label: '成功率',
                    value: '${(_lastChance * 100).round()}%',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _resetRun,
              icon: const Icon(Icons.replay),
              label: const Text('再挑戦'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureTarget {
  const _CaptureTarget({
    required this.name,
    required this.focusPower,
    required this.difficulty,
    required this.color,
    required this.accent,
  });

  final String name;
  final int focusPower;
  final double difficulty;
  final Color color;
  final Color accent;
}

class _FieldPainter extends CustomPainter {
  const _FieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF7DD3FC), Color(0xFFE0F2FE)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.72);
    for (final cloud in <Offset>[
      Offset(size.width * 0.18, size.height * 0.18),
      Offset(size.width * 0.72, size.height * 0.14),
      Offset(size.width * 0.86, size.height * 0.28),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: cloud, width: 92, height: 24),
        cloudPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: cloud.translate(28, -8),
          width: 72,
          height: 26,
        ),
        cloudPaint,
      );
    }

    final hillPaint = Paint()..color = const Color(0xFF86EFAC);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.24, size.height * 0.72),
        width: size.width * 0.76,
        height: size.height * 0.62,
      ),
      hillPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.78, size.height * 0.74),
        width: size.width * 0.82,
        height: size.height * 0.58,
      ),
      Paint()..color = const Color(0xFFBBF7D0),
    );

    final grass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF65A30D), Color(0xFF166534)],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.58, size.width, size.height),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.58, size.width, size.height * 0.42),
      grass,
    );

    final fence = Paint()
      ..color = const Color(0xFF7C4A21)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final fenceY = size.height * 0.58;
    canvas.drawLine(Offset(0, fenceY), Offset(size.width, fenceY), fence);
    canvas.drawLine(
      Offset(0, fenceY + 28),
      Offset(size.width, fenceY + 28),
      fence..strokeWidth = 4,
    );
    for (var x = 24.0; x < size.width; x += 76) {
      canvas.drawLine(Offset(x, fenceY - 20), Offset(x, fenceY + 48), fence);
    }

    final flowerPaint = Paint()..color = const Color(0xFFFFF7AD);
    for (var i = 0; i < 42; i += 1) {
      final x = (i * 47) % max(size.width, 1);
      final y = size.height * 0.68 + (i % 7) * 19;
      canvas.drawCircle(Offset(x.toDouble(), y), 2.2, flowerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TargetCreature extends StatelessWidget {
  const _TargetCreature({required this.target});

  final _CaptureTarget target;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            bottom: 8,
            child: Container(
              width: 84,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 22,
            child: _Leaf(color: target.accent, turns: -0.2),
          ),
          Positioned(
            top: 12,
            right: 24,
            child: _Leaf(color: target.accent, turns: 0.2),
          ),
          Container(
            width: 88,
            height: 78,
            decoration: BoxDecoration(
              color: target.color,
              borderRadius: BorderRadius.circular(38),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 20,
                  top: 26,
                  child: _Eye(color: target.accent),
                ),
                Positioned(
                  right: 20,
                  top: 26,
                  child: _Eye(color: target.accent),
                ),
                Positioned(
                  left: 34,
                  top: 48,
                  child: Container(
                    width: 20,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf({required this.color, required this.turns});

  final Color color;
  final double turns;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: pi * turns,
      child: Container(
        width: 32,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(28),
          ),
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class FocusOrb extends StatelessWidget {
  const FocusOrb({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF22D3EE),
              Color(0xFF2563EB),
              Color(0xFFFFD166),
            ],
          ),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.center_focus_strong, color: Colors.white),
      ),
    );
  }
}

class _HudBadge extends StatelessWidget {
  const _HudBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.message,
    required this.chance,
    required this.captures,
    required this.streak,
  });

  final String message;
  final double chance;
  final int captures;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _TinyStat(label: '率', value: '${(chance * 100).round()}%'),
            const SizedBox(width: 8),
            _TinyStat(label: '捕獲', value: '$captures'),
            const SizedBox(width: 8),
            _TinyStat(label: '連続', value: '$streak'),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
