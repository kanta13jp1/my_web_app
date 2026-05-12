---
title: "Flutter Animation Deep Dive — AnimationController, Custom Tweens, and Physics Simulations"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter Animation Deep Dive — AnimationController, Custom Tweens, and Physics Simulations

Flutter's animation system divides into two layers: *implicit* (value-driven, automatic) and *explicit* (controller-driven, precise). Knowing when to use each — and how to compose them — separates polished apps from janky ones.

## Implicit Animations: Let the Framework Drive

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 400),
  curve: Curves.easeOutCubic,
  width: _expanded ? 300 : 100,
  height: _expanded ? 200 : 60,
  decoration: BoxDecoration(
    color: _expanded ? Colors.indigo : Colors.indigo.shade200,
    borderRadius: BorderRadius.circular(_expanded ? 16 : 8),
  ),
  child: const Center(child: Text('Tap me')),
)
```

Flutter ships 20+ animated widgets (`AnimatedSwitcher`, `AnimatedOpacity`, `AnimatedPadding`, …). Prefer them. Reach for `AnimationController` only when implicit widgets can't express what you need.

## Explicit Animations: AnimationController

```dart
class _FadeSlideState extends State<FadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this, // prevents off-screen rendering
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void dispose() {
    _ctrl.dispose(); // critical: prevents ticker leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}
```

Use `SingleTickerProviderStateMixin` for one controller; `TickerProviderStateMixin` for multiple.

## Custom Tweens

```dart
// HSL color interpolation (smoother hue transitions than RGB lerp)
class HslColorTween extends Tween<Color> {
  HslColorTween({required super.begin, required super.end});

  @override
  Color lerp(double t) {
    final b = HSLColor.fromColor(begin!);
    final e = HSLColor.fromColor(end!);
    return HSLColor.fromAHSL(
      lerpDouble(b.alpha, e.alpha, t)!,
      lerpDouble(b.hue, e.hue, t)!,
      lerpDouble(b.saturation, e.saturation, t)!,
      lerpDouble(b.lightness, e.lightness, t)!,
    ).toColor();
  }
}

final colorAnim = HslColorTween(begin: Colors.blue, end: Colors.pink)
    .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
```

Override `lerp` to control how values interpolate between begin and end.

## Sequencing with Interval

```dart
// One controller, three elements with staggered timing
_fade = Tween<double>(begin: 0, end: 1).animate(
  CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4)),
);
_slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
  CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.7)),
);
_scale = Tween<double>(begin: 0.8, end: 1.0).animate(
  CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
  ),
);
```

`Interval` values (0.0–1.0) map to fractions of the controller's total duration.

## Physics-Based Animations: SpringSimulation

```dart
void _onTap() {
  final spring = SpringDescription(mass: 1, stiffness: 200, damping: 15);
  final sim = SpringSimulation(spring, _ctrl.value, 1.0, 0);
  _ctrl.animateWith(sim);
}

void _onRelease() {
  final spring = SpringDescription(mass: 1, stiffness: 200, damping: 15);
  final sim = SpringSimulation(spring, _ctrl.value, 0.0, 0);
  _ctrl.animateWith(sim);
}
```

Pass the current drag velocity as the fourth argument to `SpringSimulation` to create seamless hand-off from gesture to physics.

## AnimatedBuilder + CustomPainter

```dart
class WavePainter extends CustomPainter {
  final double phase;
  WavePainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height / 2);
    for (double x = 0; x <= size.width; x++) {
      path.lineTo(x, size.height / 2 + 30 * sin(x / size.width * 2 * pi + phase));
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.indigo.withOpacity(0.4));
  }

  @override
  bool shouldRepaint(WavePainter old) => old.phase != phase;
}

// Isolate repaint cost with RepaintBoundary
AnimatedBuilder(
  animation: _ctrl,
  builder: (_, __) => RepaintBoundary(
    child: CustomPaint(
      painter: WavePainter(_ctrl.value * 2 * pi),
      size: const Size(double.infinity, 120),
    ),
  ),
)
```

## Hero Animations

```dart
// Source route
Hero(
  tag: 'product-${product.id}',
  child: Image.network(product.imageUrl),
)

// Destination route — same tag is enough
Hero(
  tag: 'product-${product.id}',
  flightShuttleBuilder: (_, anim, direction, from, to) =>
      FadeTransition(opacity: anim, child: to),
  child: Image.network(product.imageUrl, fit: BoxFit.cover),
)
```

`flightShuttleBuilder` lets you control exactly what renders during the shared-element flight.

## Performance Checklist

| Issue | Avoid | Use Instead |
|-------|-------|-------------|
| Rebuilding whole tree | `setState` inside animation | `AnimatedBuilder` |
| Heavy subtree in animation scope | Large widgets that repaint every frame | `RepaintBoundary` |
| Image decode per frame | Uncached network images | `precacheImage` |
| Opacity blending | `Opacity(opacity: val)` | `FadeTransition` (preserves raster cache) |

Profile with `flutter run --profile` and DevTools **Frame Chart** before optimizing.

## Summary

1. **Start implicit** — `AnimatedContainer` and friends cover most cases
2. **Go explicit** when you need precise timing → `AnimationController` + `Tween` + `Interval`
3. **Add feel** → `SpringSimulation` for physics-based touch response
4. **Custom visuals** → `CustomPainter` + `RepaintBoundary`
5. **Screen transitions** → `Hero` for continuity

Animation is UI vocabulary — it explains *why* something changed, not just *that* it changed. Get the curve and duration right, and everything else follows.
