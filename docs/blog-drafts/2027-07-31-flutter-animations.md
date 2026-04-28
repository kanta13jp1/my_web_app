---
title: "Flutter アニメーション入門 — AnimationController / Tween / Hero を使いこなす"
tags: flutter,AI,個人開発,buildinpublic
published: true
---

# Flutter アニメーション入門 — AnimationController / Tween / Hero を使いこなす

Flutter のアニメーションは仕組みを理解すれば怖くない。3つのパターンを覚えれば、大抵の UI に対応できる。

## アニメーションの基本概念

```
AnimationController: タイムラインを管理 (0.0 〜 1.0)
Tween:              値の補間 (開始値 → 終了値)
Animation:          Controller + Tween の合成
```

```dart
// 基本セット
class _MyWidgetState extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

`SingleTickerProviderStateMixin` が `vsync` を提供する。複数アニメーション同時の場合は `TickerProviderStateMixin`。

## パターン1: フェードイン

```dart
// FadeTransition: opacity アニメーション
FadeTransition(
  opacity: _animation,
  child: const Text('Hello, Flutter!'),
)

// 実行
ElevatedButton(
  onPressed: () => _controller.forward(),
  child: const Text('表示'),
)
```

## パターン2: スライドイン

```dart
// SlideTransition: 位置アニメーション
late final Animation<Offset> _slideAnimation;

@override
void initState() {
  super.initState();
  _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  _slideAnimation = Tween<Offset>(
    begin: const Offset(0, 1),  // 下から
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));
}

// Widget
SlideTransition(
  position: _slideAnimation,
  child: Container(
    padding: const EdgeInsets.all(16),
    color: Colors.blue,
    child: const Text('スライドイン'),
  ),
)
```

## パターン3: Hero アニメーション (画面遷移)

```dart
// 一覧ページ
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DetailPage()),
  ),
  child: Hero(
    tag: 'hero-image',  // 同じタグで繋がる
    child: Image.asset('assets/card.jpg', width: 100),
  ),
)

// 詳細ページ
Hero(
  tag: 'hero-image',  // 同じタグ
  child: Image.asset('assets/card.jpg'),
)
```

Flutter が自動で遷移アニメーションを生成する。

## AnimatedContainer: 宣言的アニメーション

`AnimationController` 不要。状態変化を自動でアニメーション:

```dart
// 状態
bool _isExpanded = false;

// Widget
GestureDetector(
  onTap: () => setState(() => _isExpanded = !_isExpanded),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    width: _isExpanded ? 200 : 100,
    height: _isExpanded ? 200 : 100,
    color: _isExpanded ? Colors.blue : Colors.grey,
    child: const Center(child: Text('タップ')),
  ),
)
```

## TweenAnimationBuilder: カスタム値アニメーション

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: _progress),  // _progress が変わると再アニメーション
  duration: const Duration(milliseconds: 500),
  builder: (context, value, child) {
    return LinearProgressIndicator(value: value);
  },
)
```

## まとめ: 選び方

```
シンプルな状態変化 → AnimatedContainer (宣言的・最速)
カスタム値アニメーション → TweenAnimationBuilder
細かい制御が必要 → AnimationController + Tween
画面遷移をアニメーション → Hero
```

「AnimatedContainer で始めて、足りなくなったら Controller に移行」が個人開発での正解。過度な作り込みより、シンプルで確実な実装を選ぶ。
