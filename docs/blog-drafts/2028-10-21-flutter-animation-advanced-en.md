---
title: "Flutter Advanced Animation — Hero, Staggered, and CustomPainter for Rich UIs"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Advanced Animation — Hero, Staggered, and CustomPainter for Rich UIs

Three advanced animation patterns with full implementation code.

## Hero Animation (Screen Transitions)

```dart
// List screen
GridView.builder(
  itemBuilder: (context, index) {
    final item = items[index];
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => DetailPage(item: item))),
      child: Hero(
        tag: 'item-${item.id}', // unique tag
        child: Image.network(item.imageUrl, fit: BoxFit.cover),
      ),
    );
  },
)

// Detail screen
Hero(
  tag: 'item-${widget.item.id}', // same tag
  child: Image.network(widget.item.imageUrl),
)
```

## Staggered Animation (Sequential Reveal)

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

## CustomPainter (Custom Drawing Animation)

```dart
class CircleProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
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
      -pi / 2,            // start at 12 o'clock
      2 * pi * progress,  // draw progress amount
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircleProgressPainter old) => old.progress != progress;
}

// Usage
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

## Summary

```
Hero            → shared element transition between screens (linked by tag)
Staggered       → Interval staggers each element's entrance
CustomPainter   → shouldRepaint prevents unnecessary redraws
Performance     → always dispose AnimationController
```

Animation exists to help the eye follow elements — meaning over spectacle.
