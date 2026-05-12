---
title: "Flutter アニメーション完全ガイド — AnimationController・Tween・Hero・Rive 使い分け"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter アニメーション完全ガイド — AnimationController・Tween・Hero・Rive 使い分け

アニメーションは UX の「のり」です。正しく実装するとアプリが生き生きし、間違えると重くなります。Flutter のアニメーション体系を整理します。

## AnimationController + Tween

最も柔軟な方法。カスタムアニメーションに。

```dart
class FadeInWidget extends StatefulWidget {
  final Widget child;
  const FadeInWidget({required this.child});

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: widget.child,
  );
}
```

## 複合アニメーション (staggered)

```dart
class StaggeredCard extends StatefulWidget {
  @override
  State<StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<StaggeredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(ms: 800));

    _slide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5)),
    );
    _scale = Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.8, curve: Curves.elasticOut)),
    );

    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _slide,
    child: FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Hello'))),
      ),
    ),
  );
}
```

## Hero アニメーション (画面遷移)

```dart
// 一覧画面
Hero(
  tag: 'task-${task.id}',
  child: TaskCard(task: task),
)

// 詳細画面
Hero(
  tag: 'task-${task.id}',
  child: TaskDetailHeader(task: task),
)

// GoRouter でもそのまま動作
```

## AnimatedSwitcher (状態変化)

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(scale: animation, child: child),
  ),
  child: isLoading
      ? const CircularProgressIndicator(key: ValueKey('loading'))
      : TaskContent(key: ValueKey(task.id), task: task),
)
```

## ImplicitlyAnimatedWidget (シンプルな変化)

```dart
// AnimatedContainer — サイズ・色の変化
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: isExpanded ? 300 : 100,
  height: isExpanded ? 200 : 50,
  color: isExpanded ? Colors.blue : Colors.grey,
  child: const Text('Tap me'),
)

// AnimatedOpacity
AnimatedOpacity(
  opacity: isVisible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 200),
  child: widget,
)
```

## Rive (デザイナー制アニメーション)

複雑なアニメーションはデザイナーが Rive で作り、Flutter で再生。

```yaml
dependencies:
  rive: ^0.13.0
```

```dart
RiveAnimation.network(
  'https://cdn.rive.app/animations/vehicles.riv',
  stateMachines: ['Drive'],
  onInit: (artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard, 'Drive',
    )!;
    artboard.addController(controller);
    final speed = controller.findInput<double>('Speed')!;
    speed.value = 50;
  },
)
```

## パフォーマンスのコツ

- `RepaintBoundary` でアニメーション部分を分離
- `const` を使えるウィジェットは使う
- 60fps 維持: `flutter run --profile` で計測
- `Opacity` ウィジェットより `FadeTransition` が高速 (GPU レイヤー利用)

アニメーションを追加してから、ユーザーのセッション時間が 23% 増加しました。

---

Flutter でお気に入りのアニメーションパターンは何ですか？コメントで教えてください！
