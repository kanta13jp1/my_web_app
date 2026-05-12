---
title: "Flutter CustomPaint Deep Dive — Canvas API, Animations & Fragment Shaders"
published: true
tags: flutter, dart, animation, webdev
canonical_url: null
---

# Flutter CustomPaint Deep Dive — Canvas API, Animations & Fragment Shaders

When Flutter's standard widgets can't achieve the visual effect you need, `CustomPaint` unlocks the full power of the Canvas API — and with Fragment Shaders, you can push rendering directly to the GPU.

## The CustomPaint / CustomPainter contract

```dart
class WaveChart extends StatelessWidget {
  final List<double> data;
  const WaveChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WaveChartPainter(data: data),
      size: const Size(double.infinity, 200),
    );
  }
}

class WaveChartPainter extends CustomPainter {
  final List<double> data;
  WaveChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = (1 - data[i]) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveChartPainter oldDelegate) =>
      oldDelegate.data != data;
}
```

## Smooth curves with cubic Bezier paths

```dart
void _drawSmoothLine(Canvas canvas, List<Offset> points, Paint paint) {
  if (points.length < 2) return;

  final path = Path()..moveTo(points[0].dx, points[0].dy);

  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[i];
    final p1 = points[i + 1];
    final controlX = (p0.dx + p1.dx) / 2;
    path.cubicTo(
      controlX, p0.dy,
      controlX, p1.dy,
      p1.dx, p1.dy,
    );
  }

  canvas.drawPath(path, paint);
}
```

## AnimatedCustomPainter — hooking into AnimationController

Pass the controller as the `repaint` argument so Flutter repaints automatically on every tick — no `setState` needed.

```dart
class RipplePainter extends CustomPainter {
  final Animation<double> animation;

  RipplePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (var i = 0; i < 3; i++) {
      final progress = (animation.value + i / 3) % 1.0;
      final radius = maxRadius * progress;
      final opacity = 1.0 - progress;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF6366F1).withOpacity(opacity * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) => false;
}
```

## Fragment Shaders — move rendering to the GPU

Since Flutter 3.7, GLSL fragment shaders are a first-class citizen.

```glsl
// shaders/gradient_noise.frag
#include <flutter/runtime_effect.glsl>

uniform float iTime;
uniform vec2 iResolution;
out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1,0)), f.x),
    mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x),
    f.y
  );
}

void main() {
  vec2 uv = FlutterFragCoord().xy / iResolution;
  float n = noise(uv * 5.0 + iTime * 0.3);
  vec3 color = mix(
    vec3(0.388, 0.400, 0.945),
    vec3(0.667, 0.471, 0.945),
    n
  );
  fragColor = vec4(color, 1.0);
}
```

```dart
class ShaderPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;

  ShaderPainter({required this.shader, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, time)
      ..setFloat(1, size.width)
      ..setFloat(2, size.height);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(ShaderPainter old) => old.time != time;
}
```

## Performance checklist

| Concern | Solution |
|---|---|
| Unnecessary repaints | `shouldRepaint` returning false when data unchanged |
| Wide repaint scope | Wrap in `RepaintBoundary` |
| `saveLayer` cost | Replace blur/shadow with `ImageFiltered` widget |
| Shader compile stall | Warm up with `ShaderWarmUp` in `main()` |

## Real-world usage at Jibun K.K.

- **KPI dashboard line charts** — implemented with `CustomPaint` to avoid library dependencies
- **Odds/confidence bars** — PS#6 horse racing confidence scores rendered as custom progress indicators
- **AI University progress arcs** — learning completion displayed as animated Bezier arcs

## When to reach for CustomPaint

Use it when you need pixel-level control that standard widgets can't provide. Fragment Shaders are the next step when you need GPU-accelerated effects like noise, gradients, or real-time distortion — and they work identically on web, iOS, Android, and desktop.
