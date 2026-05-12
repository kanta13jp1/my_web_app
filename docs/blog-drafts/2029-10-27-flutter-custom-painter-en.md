---
title: "Flutter CustomPainter Guide — Drawing Custom UI With the Canvas API"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter CustomPainter Guide — Drawing Custom UI With the Canvas API

When Flutter's built-in widgets can't express your design vision, `CustomPainter` gives you direct access to the Skia/Impeller canvas. This guide walks through everything from basic shapes to animated charts with real, production-ready code.

---

## The Two Methods You Must Implement

Every `CustomPainter` subclass requires exactly two methods.

```dart
class CirclePainter extends CustomPainter {
  final Color color;
  final double radius;

  const CirclePainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      Paint()..color = color,
    );
  }

  // Return true only when something visual has actually changed.
  @override
  bool shouldRepaint(CirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
```

Returning `true` unconditionally from `shouldRepaint` forces a repaint every frame — a common performance mistake.

---

## Wiring Up CustomPaint

```dart
class CanvasDemo extends StatelessWidget {
  const CanvasDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Explicit size — omit to fill parent constraints
      size: const Size(200, 200),
      painter: CirclePainter(
        color: Colors.deepPurple,
        radius: 80,
      ),
      // child is painted between painter and foregroundPainter
      child: const Center(child: Text('Hello Canvas')),
    );
  }
}
```

---

## Core Canvas API

### Rectangles

```dart
void paint(Canvas canvas, Size size) {
  final fillPaint = Paint()
    ..color = Colors.blueAccent.withOpacity(0.2)
    ..style = PaintingStyle.fill;

  final borderPaint = Paint()
    ..color = Colors.blueAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round;

  final rect = Rect.fromLTRB(16, 16, size.width - 16, size.height - 16);
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

  canvas.drawRRect(rrect, fillPaint);
  canvas.drawRRect(rrect, borderPaint);
}
```

### Paths for Free-Form Shapes

```dart
void _drawHexagon(Canvas canvas, Offset center, double r) {
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = (pi / 3) * i - pi / 6;
    final x = center.dx + r * cos(angle);
    final y = center.dy + r * sin(angle);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  path.close();

  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill,
  );
}
```

### Arcs

`drawArc` takes a bounding rect, start angle (radians, 0 = right), sweep angle, and a `useCenter` flag.

```dart
void _drawArc(Canvas canvas, Size size) {
  canvas.drawArc(
    Rect.fromLTWH(20, 20, size.width - 40, size.height - 40),
    -pi / 2,        // start at top
    pi * 1.5,       // 270 degrees
    false,          // don't connect to center
    Paint()
      ..color = Colors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round,
  );
}
```

---

## Drawing Text on Canvas

```dart
void _drawCenteredText(Canvas canvas, Size size, String text) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: size.width);

  tp.paint(
    canvas,
    Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    ),
  );
}
```

---

## Practical Example 1: Animated Progress Ring

```dart
class RingPainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color trackColor;
  final Color ringColor;
  final double thickness;

  const RingPainter({
    required this.progress,
    this.trackColor = const Color(0xFFEEEEEE),
    this.ringColor = const Color(0xFF6200EA),
    this.thickness = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.shortestSide - thickness) / 2;
    final bounds = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, basePaint..color = trackColor);
    canvas.drawArc(
      bounds,
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      basePaint..color = ringColor,
    );
  }

  @override
  bool shouldRepaint(RingPainter old) => old.progress != progress;
}

// Animated wrapper
class AnimatedRing extends StatefulWidget {
  final double progress;
  final Duration duration;

  const AnimatedRing({
    super.key,
    required this.progress,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<AnimatedRing> createState() => _AnimatedRingState();
}

class _AnimatedRingState extends State<AnimatedRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.duration, vsync: this);
    _anim = Tween<double>(begin: 0, end: widget.progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedRing old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(begin: _anim.value, end: widget.progress)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          size: const Size(140, 140),
          painter: RingPainter(progress: _anim.value),
        ),
      );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
```

---

## Practical Example 2: Bar Chart

```dart
class BarChartPainter extends CustomPainter {
  final List<({String label, double value})> data;
  final Color barColor;
  final double maxValue;

  const BarChartPainter({
    required this.data,
    this.barColor = const Color(0xFF6200EA),
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const gutterBottom = 24.0;
    const gap = 8.0;
    final chartHeight = size.height - gutterBottom;
    final barWidth = (size.width - gap * (data.length + 1)) / data.length;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final fraction = (data[i].value / maxValue).clamp(0.0, 1.0);
      final barH = chartHeight * fraction;
      final left = gap * (i + 1) + barWidth * i;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, chartHeight - barH, barWidth, barH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        barPaint,
      );

      // Label below bar
      final tp = TextPainter(
        text: TextSpan(
          text: data[i].label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(left + (barWidth - tp.width) / 2, chartHeight + 4),
      );
    }
  }

  @override
  bool shouldRepaint(BarChartPainter old) =>
      old.data.length != data.length || old.maxValue != maxValue;
}
```

---

## Performance Tips

### Use RepaintBoundary

Wrap the `CustomPaint` in a `RepaintBoundary` so changes inside don't invalidate the surrounding widget tree.

```dart
RepaintBoundary(
  child: CustomPaint(
    painter: BarChartPainter(data: _data, maxValue: 100),
    size: const Size(300, 200),
  ),
),
```

### Leverage `isComplex` and `willChange`

```dart
CustomPaint(
  isComplex: true,   // hint to engine to cache the raster
  willChange: false, // set true only during active animation
  painter: myPainter,
)
```

### Avoid Allocations Inside `paint`

```dart
// Bad — allocates Paint on every frame
void paint(Canvas canvas, Size size) {
  canvas.drawCircle(center, r, Paint()..color = Colors.red);
}

// Good — reuse from field
class MyPainter extends CustomPainter {
  final _paint = Paint()..color = Colors.red;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(center, r, _paint);
  }
}
```

---

## Summary

| Task | Canvas method |
|------|--------------|
| Solid / stroked rectangle | `drawRect` / `drawRRect` |
| Circle | `drawCircle` |
| Arc / donut segment | `drawArc` |
| Free-form polygon | `drawPath` + `Path` |
| Text | `TextPainter.paint` |
| Image | `drawImage` / `drawImageRect` |
| Gradient fill | `Paint()..shader = gradient.createShader(...)` |

Once you understand the Canvas API, virtually any data visualization or decorative element becomes achievable without third-party packages.

---

What's the most complex custom painter you've shipped in production? I'd love to hear about your approach in the comments!
