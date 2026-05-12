---
title: "Flutter CustomPaint 完全ガイド — Canvas API・アニメーション・Fragment Shaderの実践パターン"
emoji: "🎨"
type: "tech"
topics: ["flutter", "dart", "ui", "animation"]
published: true
---

# Flutter CustomPaint 完全ガイド — Canvas API・アニメーション・Fragment Shaderの実践パターン

Flutter の標準ウィジェットでは実現できない複雑な描画が必要になったとき、`CustomPaint` がその答えになります。本記事では Canvas API の基礎から Fragment Shader との組み合わせまで、実務で使えるパターンを網羅します。

## CustomPaint の基本構造

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

## Bezier 曲線で滑らかな折れ線を描く

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

## AnimatedCustomPainter — アニメーションとの連携

`CustomPainter` に `Listenable` を渡すことで、アニメーションコントローラーが更新されるたびに自動的に再描画します。

```dart
class RippleEffect extends StatefulWidget {
  const RippleEffect({super.key});

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RipplePainter(animation: _controller),
      size: const Size(200, 200),
    );
  }
}

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

## Fragment Shader で GPU描画

Flutter 3.7 以降、GLSL Fragment Shader が利用できます。

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
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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
// pubspec.yaml に追加
// flutter:
//   shaders:
//     - shaders/gradient_noise.frag

class ShaderWidget extends StatefulWidget {
  const ShaderWidget({super.key});

  @override
  State<ShaderWidget> createState() => _ShaderWidgetState();
}

class _ShaderWidgetState extends State<ShaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await FragmentProgram.fromAsset('shaders/gradient_noise.frag');
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: ShaderPainter(
            shader: _shader!,
            time: _controller.value * 10,
          ),
          size: const Size(double.infinity, 300),
        );
      },
    );
  }
}

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
  bool shouldRepaint(ShaderPainter oldDelegate) => oldDelegate.time != time;
}
```

## パフォーマンス最適化

### shouldRepaint を必ず実装する

```dart
@override
bool shouldRepaint(WaveChartPainter oldDelegate) {
  // データが変わっていなければ再描画しない
  return oldDelegate.data != data ||
         oldDelegate.color != color;
}
```

### RepaintBoundary でスコープを限定する

```dart
RepaintBoundary(
  child: CustomPaint(
    painter: HeavyPainter(),
    // この領域だけが再描画される
  ),
)
```

### ImageFilter と saveLayer のコスト

`canvas.saveLayer()` はオフスクリーンバッファを生成するため高コストです。ブラーやシャドウは `ImageFiltered` ウィジェットで代替できないか先に検討します。

## 自分株式会社での活用例

- **成長グラフ**: KPI ダッシュボードの折れ線グラフを `CustomPaint` で実装 (ライブラリ依存ゼロ)
- **競馬結果可視化**: PS#6 の odds/confidence スコアを棒グラフで可視化
- **AI大学進捗バー**: 学習完了率を Bezier 曲線ベースのプログレスバーで表示

## まとめ

| ユースケース | 手段 |
|---|---|
| 静的な図形・グラフ | `CustomPaint` + `CustomPainter` |
| アニメーション連動 | `repaint: animationController` |
| GPU シェーダー効果 | Fragment Shader + `CustomPaint` |
| 重い描画の分離 | `RepaintBoundary` |

Canvas API をマスターすると、標準ウィジェットの制約から解放されます。Fragment Shader との組み合わせで、Web や Native を問わず GPU の能力を直接活かした滑らかなビジュアルが実現できます。
