---
title: "Flutter Animation Deep Dive: AnimationController, Tween, and Hero"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Animation Deep Dive: AnimationController, Tween, and Hero

Animations feel complex at first. Understand three building blocks and you can animate anything.

## The Three Building Blocks

```
AnimationController → manages "time" from 0.0 to 1.0
Tween              → maps a range of values (0.0→1.0 becomes 0px→200px)
AnimatedBuilder    → rebuilds the widget whenever the animation value changes
```

## Basic: AnimationController + Tween

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
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose(); // always dispose
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
      child: widget.child, // child subtree rebuilt only once
    );
  }
}
```

## Staggered Animation: Offset Multiple Elements in Time

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

    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _slideY = Tween(
      begin: const Offset(0, 0.3), end: Offset.zero,
    ).animate(
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

## Hero Animation: Shared Element Transitions

```dart
// List screen
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetailPage(item: item)),
  ),
  child: Hero(
    tag: 'item-image-${item.id}', // must be unique
    child: Image.network(item.imageUrl, width: 80, height: 80),
  ),
)

// Detail screen (same tag)
Hero(
  tag: 'item-image-${item.id}',
  child: Image.network(item.imageUrl, width: double.infinity),
)
```

## ImplicitlyAnimatedWidgets: The Easiest Path

```dart
// AnimatedContainer: auto-animates on property change
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: _isExpanded ? 300 : 100,
  height: _isExpanded ? 200 : 100,
  color: _isExpanded ? Colors.blue : Colors.grey,
  child: const Center(child: Text('Tap to expand')),
)

// AnimatedOpacity
AnimatedOpacity(
  duration: const Duration(milliseconds: 300),
  opacity: _isVisible ? 1.0 : 0.0,
  child: widget.child,
)
```

## Summary

```
AnimationController + Tween → full control (repeat, reverse, pause)
Staggered Animation         → time-offset multiple elements (Interval)
Hero Animation              → seamless screen transitions (match the tag)
ImplicitlyAnimatedWidgets   → simplest approach (AnimatedContainer etc.)
```

Most animations can be handled by `AnimatedContainer`. Move to `AnimationController` only when you need finer control.

