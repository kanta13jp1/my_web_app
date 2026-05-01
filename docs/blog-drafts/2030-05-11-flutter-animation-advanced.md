---
title: "Flutter アニメーション 完全ガイド — AnimationController・カスタムTween・物理シミュレーション"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter アニメーション 完全ガイド — AnimationController・カスタムTween・物理シミュレーション

Flutter のアニメーションシステムは「暗黙的」と「明示的」の2層構造になっています。`AnimatedContainer` で済む場面と、`AnimationController` を直接操る場面を正しく使い分けることで、表現力と保守性を両立できます。

## 暗黙的アニメーション: AnimatedWidget 系

```dart
// AnimatedContainer: 値が変わると自動でアニメーション
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

`AnimatedSwitcher`・`AnimatedOpacity`・`AnimatedPadding` など20種超の既製品を優先する。カスタムが必要になってから `AnimationController` に進む。

## 明示的アニメーション: AnimationController

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
      vsync: this,
    );
    // CurvedAnimation でイージングを分離
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void dispose() {
    _ctrl.dispose(); // 必須: リークを防ぐ
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

`SingleTickerProviderStateMixin` は1つ、複数なら `TickerProviderStateMixin`。

## カスタム Tween

```dart
// ColorTween はデフォルトでも使えるが、HSL補間にしたい場合
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

// 使用例
final colorAnim = HslColorTween(begin: Colors.blue, end: Colors.pink)
    .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
```

## Interval でシーケンスを作る

```dart
// 1つのControllerで3要素を時差起動
_fade = Tween<double>(begin: 0, end: 1).animate(
  CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4)),
);
_slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
  CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.7)),
);
_scale = Tween<double>(begin: 0.8, end: 1.0).animate(
  CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.elasticOut)),
);
```

`Interval` の begin/end は 0.0〜1.0 で全体 duration の割合を示す。

## 物理シミュレーション: SpringSimulation

```dart
class SpringCard extends StatefulWidget { ... }

class _SpringCardState extends State<SpringCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

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
  ...
}
```

`SpringSimulation` は velocity (第4引数) を引き継げるため、ドラッグ速度をそのままバネ運動に接続できる。

## CustomPainter でアニメーション描画

```dart
class WavePainter extends CustomPainter {
  final double phase;
  WavePainter(this.phase) : super();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height / 2);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          30 * sin((x / size.width * 2 * pi) + phase);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.indigo.withOpacity(0.4));
  }

  @override
  bool shouldRepaint(WavePainter old) => old.phase != phase;
}

// RepaintBoundary でコスト隔離
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

## Hero アニメーション

```dart
// 遷移元
Hero(
  tag: 'product-${product.id}',
  child: Image.network(product.imageUrl),
)

// 遷移先: 同じ tag を使うだけ
Hero(
  tag: 'product-${product.id}',
  flightShuttleBuilder: (_, anim, direction, from, to) {
    return FadeTransition(opacity: anim, child: to);
  },
  child: Image.network(product.imageUrl, fit: BoxFit.cover),
)
```

`flightShuttleBuilder` でフライト中のウィジェットを差し替え可能。

## パフォーマンスチェックリスト

| 項目 | NG | OK |
|------|----|----|
| ビルド頻度 | setState でツリー全体再構築 | `AnimatedBuilder` / `AnimationController.addListener` |
| 重い子ウィジェット | アニメーション範囲内に巨大ツリー | `RepaintBoundary` で隔離 |
| 画像アニメーション | 毎フレーム decode | `precacheImage` + キャッシュ済みを再利用 |
| Opacity | `Opacity(opacity: ...)` | `FadeTransition` (raster cache 維持) |

`flutter run --profile` + DevTools の **Frame Chart** で jank を特定してから最適化する。

## まとめ

1. **まず暗黙的アニメーション** — `AnimatedContainer` 系で済むか確認
2. **カスタムが必要** → `AnimationController` + `Tween` + `Interval`
3. **触感が必要** → `SpringSimulation` で物理ベースに
4. **描画が必要** → `CustomPainter` + `RepaintBoundary`
5. **画面遷移** → `Hero` で文脈継続

アニメーションは「動く」だけでなく「なぜ動くか」をユーザーに伝えるUIの語彙。適切な Curve と Duration がUXを決める。
