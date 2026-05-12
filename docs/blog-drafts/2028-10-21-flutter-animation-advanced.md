---
title: "Flutter アニメーション応用 — Hero・Staggered・CustomPainter でリッチ UI"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter アニメーション応用 — Hero・Staggered・CustomPainter でリッチ UI

3 つの高度なアニメーションパターンを実装コード付きで解説する。

## Hero アニメーション (画面遷移)

```dart
// 一覧画面
GridView.builder(
  itemBuilder: (context, index) {
    final item = items[index];
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => DetailPage(item: item))),
      child: Hero(
        tag: 'item-${item.id}', // 一意なタグ
        child: Image.network(item.imageUrl, fit: BoxFit.cover),
      ),
    );
  },
)

// 詳細画面
Hero(
  tag: 'item-${widget.item.id}', // 同じタグ
  child: Image.network(widget.item.imageUrl),
)
```

## Staggered アニメーション (順次表示)

```dart
class StaggeredList extends StatefulWidget { ... }

class _StaggeredListState extends State<StaggeredList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (i) {
        final start = i * 0.1;
        final end = (start + 0.4).clamp(0.0, 1.0);
        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: ItemCard(item: items[i]),
          ),
        );
      }),
    );
  }
}
```

## CustomPainter (カスタム描画アニメーション)

```dart
class CircleProgressPainter extends CustomPainter {
  final double progress; // 0.0 〜 1.0
  final Color color;

  const CircleProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 4),
      -pi / 2,             // 12時から開始
      2 * pi * progress,   // 進捗分だけ描画
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircleProgressPainter old) => old.progress != progress;
}

// 使用
AnimatedBuilder(
  animation: _controller,
  builder: (_, __) => CustomPaint(
    painter: CircleProgressPainter(
      progress: _controller.value,
      color: Colors.blue,
    ),
    size: const Size(100, 100),
  ),
)
```

## まとめ

```
Hero            → 画面間の要素共有アニメーション (tag で紐付け)
Staggered       → Interval で各要素に時差をつけて順次表示
CustomPainter   → shouldRepaint で不要な再描画を防ぐ
パフォーマンス   → AnimationController は dispose 必須
```

アニメーションは「要素を目で追いやすくする」ためのもの。派手さより意味を持たせる。
