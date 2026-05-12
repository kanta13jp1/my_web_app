---
title: "Flutter アニメーション深化 — AnimationController / Tween / Hero"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter アニメーション深化 — AnimationController / Tween / Hero

「アニメーションを付けたいけど難しそう」は最初だけ。3つの仕組みを理解すれば自在に動かせる。

## アニメーションの3つの仕組み

```
AnimationController → 0.0〜1.0 の「時間」を管理
Tween              → 値の範囲を定義 (0.0→1.0 を 0px→200px に変換)
AnimatedBuilder    → アニメーション値が変わるたびに Widget を再ビルド
```

## 基本: AnimationController + Tween

```dart
class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,  // vsync でフレームレートと同期
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();  // 再生開始
  }

  @override
  void dispose() {
    _controller.dispose();  // 必ず解放
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: child,
      ),
      child: widget.child,  // child は再ビルドしない最適化
    );
  }
}
```

## Staggered Animation: 複数要素を時差で動かす

```dart
class _StaggeredCardState extends State<StaggeredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _opacity;
  late final Animation<Offset> _slideY;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Interval で開始・終了タイミングをずらす
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _slideY = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );
    _scale = Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: SlideTransition(
          position: _slideY,
          child: ScaleTransition(scale: _scale, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}
```

## Hero Animation: 画面遷移時の共有アニメーション

```dart
// リスト画面
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetailPage(item: item)),
  ),
  child: Hero(
    tag: 'item-image-${item.id}',  // ユニークなタグ
    child: Image.network(item.imageUrl, width: 80, height: 80),
  ),
)

// 詳細画面 (同じ tag を使う)
Hero(
  tag: 'item-image-${item.id}',
  child: Image.network(item.imageUrl, width: double.infinity),
)
```

## ImplicitlyAnimatedWidget: 最も簡単な方法

```dart
// AnimatedContainer: プロパティ変更時に自動アニメーション
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: _isExpanded ? 300 : 100,
  height: _isExpanded ? 200 : 100,
  color: _isExpanded ? Colors.blue : Colors.grey,
  child: const Center(child: Text('タップで展開')),
)

// AnimatedOpacity
AnimatedOpacity(
  duration: const Duration(milliseconds: 300),
  opacity: _isVisible ? 1.0 : 0.0,
  child: widget.child,
)
```

## まとめ

```
AnimationController + Tween
  → 完全コントロール (繰り返し/逆再生/停止)
Staggered Animation
  → 複数要素の時差アニメーション (Interval で制御)
Hero Animation
  → 画面遷移時の自然なアニメーション (tag を合わせるだけ)
ImplicitlyAnimatedWidget
  → 最も簡単 (AnimatedContainer/AnimatedOpacity)
```

ほとんどのアニメーションは `AnimatedContainer` で実現できる。細かい制御が必要になったら `AnimationController` に移行する。

