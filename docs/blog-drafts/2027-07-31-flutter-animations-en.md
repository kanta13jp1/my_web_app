---
title: "Flutter Animations: AnimationController, Tween, and Hero Explained"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Animations: AnimationController, Tween, and Hero Explained

Flutter animations become simple once you understand the mental model. Three patterns cover 90% of what you'll ever need.

## The Core Concepts

```
AnimationController: manages the timeline (0.0 → 1.0)
Tween:              interpolates values (start → end)
Animation:          the combination of both
```

```dart
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

`SingleTickerProviderStateMixin` provides `vsync`. Use `TickerProviderStateMixin` for multiple simultaneous animations.

## Pattern 1: Fade In

```dart
FadeTransition(
  opacity: _animation,
  child: const Text('Hello, Flutter!'),
)

ElevatedButton(
  onPressed: () => _controller.forward(),
  child: const Text('Show'),
)
```

## Pattern 2: Slide In

```dart
late final Animation<Offset> _slideAnimation;

@override
void initState() {
  super.initState();
  _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  _slideAnimation = Tween<Offset>(
    begin: const Offset(0, 1),  // slide from bottom
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));
}

SlideTransition(
  position: _slideAnimation,
  child: Container(
    padding: const EdgeInsets.all(16),
    color: Colors.blue,
    child: const Text('Slide In'),
  ),
)
```

## Pattern 3: Hero Animation (Screen Transitions)

```dart
// List page
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DetailPage()),
  ),
  child: Hero(
    tag: 'hero-image',
    child: Image.asset('assets/card.jpg', width: 100),
  ),
)

// Detail page
Hero(
  tag: 'hero-image',  // same tag connects them
  child: Image.asset('assets/card.jpg'),
)
```

Flutter generates the transition automatically.

## AnimatedContainer: Declarative Animations

No `AnimationController` needed. State changes animate automatically:

```dart
bool _isExpanded = false;

GestureDetector(
  onTap: () => setState(() => _isExpanded = !_isExpanded),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    width: _isExpanded ? 200 : 100,
    height: _isExpanded ? 200 : 100,
    color: _isExpanded ? Colors.blue : Colors.grey,
    child: const Center(child: Text('Tap me')),
  ),
)
```

## TweenAnimationBuilder: Custom Value Animations

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: _progress),
  duration: const Duration(milliseconds: 500),
  builder: (context, value, child) {
    return LinearProgressIndicator(value: value);
  },
)
```

When `_progress` changes, the widget re-animates automatically.

## Choosing the Right Tool

```
Simple state change → AnimatedContainer (declarative, fastest)
Custom value animation → TweenAnimationBuilder
Fine-grained control → AnimationController + Tween
Screen transition → Hero
```

Start with `AnimatedContainer`. Graduate to `AnimationController` only when you need control that declarative APIs can't provide. Keep it simple — smooth animations improve UX without costing development time.
