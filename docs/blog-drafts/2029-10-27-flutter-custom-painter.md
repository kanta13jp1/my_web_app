---
title: "Flutter CustomPainter 完全ガイド — Canvas API でカスタム描画を極める"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter CustomPainter 完全ガイド — Canvas API でカスタム描画を極める

Flutter の標準ウィジェットでは実現できない UI を作りたいとき、`CustomPainter` が答えになります。本記事では Canvas API の基礎から、アニメーションと組み合わせた実践的な描画まで体系的に解説します。

---

## CustomPainter の基礎

`CustomPainter` は `paint` と `shouldRepaint` の 2 メソッドを実装するだけで使えます。

```dart
class SimplePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const SimplePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(SimplePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
```

`shouldRepaint` でプロパティが変わったときだけ再描画するよう制御することが、パフォーマンスの第一歩です。

---

## CustomPaint ウィジェットへの組み込み

```dart
class MyCanvas extends StatelessWidget {
  const MyCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(300, 200),
      painter: SimplePainter(
        color: Colors.indigo,
        strokeWidth: 2.0,
      ),
    );
  }
}
```

`size` を省略すると親の制約に従います。`foregroundPainter` を使うと子ウィジェットの前面に描画できます。

---

## Canvas API — 基本図形

### drawRect / drawRRect

```dart
void paint(Canvas canvas, Size size) {
  final fillPaint = Paint()
    ..color = Colors.blue.withOpacity(0.3)
    ..style = PaintingStyle.fill;

  final strokePaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  // 角丸長方形
  final rrect = RRect.fromRectAndRadius(
    Rect.fromLTWH(20, 20, size.width - 40, 60),
    const Radius.circular(12),
  );
  canvas.drawRRect(rrect, fillPaint);
  canvas.drawRRect(rrect, strokePaint);
}
```

### drawCircle / drawOval

```dart
canvas.drawCircle(
  Offset(size.width / 2, size.height / 2),
  40,
  Paint()..color = Colors.orange,
);

canvas.drawOval(
  Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 120,
    height: 60,
  ),
  Paint()..color = Colors.green.withOpacity(0.5),
);
```

### drawPath — 自由曲線

```dart
void _drawWave(Canvas canvas, Size size) {
  final path = Path()..moveTo(0, size.height / 2);

  for (double x = 0; x < size.width; x++) {
    final y = size.height / 2 + 20 * sin((x / size.width) * 2 * pi);
    path.lineTo(x, y);
  }

  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
}
```

---

## テキスト描画

`TextPainter` を使うとテキストを Canvas 上に描画できます。

```dart
void _drawLabel(Canvas canvas, Offset offset, String text) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(minWidth: 0, maxWidth: double.infinity);

  textPainter.paint(
    canvas,
    offset - Offset(textPainter.width / 2, textPainter.height / 2),
  );
}
```

---

## 実践例 1: プログレスリング

```dart
class ProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 〜 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const ProgressRingPainter({
    required this.progress,
    this.trackColor = const Color(0xFFE0E0E0),
    this.progressColor = const Color(0xFF6200EA),
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // トラック
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // プログレス弧
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(ProgressRingPainter old) => old.progress != progress;
}
```

---

## 実践例 2: バーチャート

```dart
class BarChartPainter extends CustomPainter {
  final List<double> values; // 正規化済み (0.0〜1.0)
  final List<Color> colors;
  final double barSpacing;

  const BarChartPainter({
    required this.values,
    required this.colors,
    this.barSpacing = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final barWidth = (size.width - barSpacing * (values.length + 1)) / values.length;

    for (int i = 0; i < values.length; i++) {
      final barHeight = size.height * values[i];
      final left = barSpacing * (i + 1) + barWidth * i;
      final top = size.height - barHeight;

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      canvas.drawRRect(
        rrect,
        Paint()..color = colors[i % colors.length],
      );
    }
  }

  @override
  bool shouldRepaint(BarChartPainter old) =>
      old.values.length != values.length ||
      !_listEquals(old.values, values);

  bool _listEquals(List<double> a, List<double> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
```

---

## AnimationController との連携

```dart
class AnimatedProgressRing extends StatefulWidget {
  final double targetProgress;
  const AnimatedProgressRing({super.key, required this.targetProgress});

  @override
  State<AnimatedProgressRing> createState() => _AnimatedProgressRingState();
}

class _AnimatedProgressRingState extends State<AnimatedProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.targetProgress)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetProgress != widget.targetProgress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.targetProgress,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => CustomPaint(
        size: const Size(120, 120),
        painter: ProgressRingPainter(progress: _animation.value),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## RepaintBoundary によるパフォーマンス最適化

`CustomPainter` を含むウィジェットツリーが大きい場合、`RepaintBoundary` で描画レイヤーを分離するとフレームレートが改善します。

```dart
RepaintBoundary(
  child: CustomPaint(
    painter: ProgressRingPainter(progress: 0.75),
    size: const Size(120, 120),
  ),
),
```

`isComplex: true` と `willChange: true` フラグも状況に応じて使い分けます。

```dart
CustomPaint(
  isComplex: true,   // キャッシュを積極活用
  willChange: false, // アニメーション中は false に
  painter: MyHeavyPainter(),
)
```

---

## shouldRepaint の正しい書き方

```dart
// NG: 常に true だと毎フレーム再描画
@override
bool shouldRepaint(_) => true;

// OK: 関係するプロパティだけ比較
@override
bool shouldRepaint(ProgressRingPainter old) =>
    old.progress != progress ||
    old.progressColor != progressColor ||
    old.strokeWidth != strokeWidth;
```

---

## まとめ

| 用途 | API |
|------|-----|
| 塗りつぶし図形 | `drawRect` / `drawCircle` / `drawRRect` |
| 自由曲線 | `drawPath` + `Path` |
| テキスト | `TextPainter` |
| 弧・扇形 | `drawArc` |
| 画像 | `drawImage` / `drawImageRect` |

CustomPainter をマスターすれば、デザインの自由度が一気に広がります。パフォーマンスが心配なときは `RepaintBoundary` と `shouldRepaint` の最適化を忘れずに。

---

あなたが CustomPainter で実装した中で一番難しかった描画はどんなものでしたか？コメントで教えてください！
