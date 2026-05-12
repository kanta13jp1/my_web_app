---
title: "Flutter Accessibility: Semantics, Screen Readers, and WCAG"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Accessibility: Semantics, Screen Readers, and WCAG

Accessibility isn't a special feature — it's a quality standard.

## Semantics: Feeding Screen Readers

```dart
// Bad: icon button with no meaning for screen readers
IconButton(
  icon: const Icon(Icons.favorite),
  onPressed: () => _toggleFavorite(),
);

// Good: tooltip becomes the semantic label automatically
IconButton(
  icon: const Icon(Icons.favorite),
  onPressed: () => _toggleFavorite(),
  tooltip: 'Add to favorites',
);

// Custom widgets need explicit Semantics
Semantics(
  label: 'Progress: 75%',
  value: '75',
  child: LinearProgressIndicator(value: 0.75),
);

// Decorative images should be excluded
Image.asset(
  'assets/decorative_banner.png',
  excludeFromSemantics: true,
);
```

## Focus Management

```dart
class _LoginFormState extends State<LoginForm> {
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          focusNode: _emailFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: const InputDecoration(label: Text('Email')),
        ),
        TextField(
          focusNode: _passwordFocus,
          textInputAction: TextInputAction.done,
          obscureText: true,
          decoration: const InputDecoration(label: Text('Password')),
        ),
      ],
    );
  }
}
```

## Color Contrast: WCAG AA Compliance

```dart
// WCAG AA: normal text ≥ 4.5:1 / large text ≥ 3:1

// Bad: insufficient contrast
Text(
  'Helper text',
  style: TextStyle(color: Color(0xFFAAAAAA)),  // ~2.3:1 on white
);

// Good: passes AA
Text(
  'Helper text',
  style: TextStyle(color: Color(0xFF767676)),  // 4.54:1 on white
);

// React to high-contrast system setting
final features = MediaQuery.of(context).accessibilityFeatures;
if (features.highContrast) {
  // apply high-contrast theme
}
```

## Touch Targets: Minimum 48×48 dp

```dart
// Bad: too small to tap reliably
InkWell(
  onTap: () {},
  child: const Icon(Icons.close, size: 16),
);

// Good: ensure minimum tap area with SizedBox
SizedBox(
  width: 48,
  height: 48,
  child: InkWell(
    onTap: () {},
    child: const Center(
      child: Icon(Icons.close, size: 16),
    ),
  ),
);
```

## Testing Accessibility

```bash
flutter test --tags accessibility
# DevTools > Accessibility tab — inspect the Semantics tree
```

```dart
testWidgets('login button has semantic label', (tester) async {
  await tester.pumpWidget(const MyApp());
  expect(
    tester.getSemantics(find.byType(ElevatedButton)),
    matchesSemantics(label: 'Login', isButton: true),
  );
});
```

## Summary

```
Semantics     → label/value to define what screen readers announce
Focus         → FocusNode + textInputAction for correct Tab order
Contrast      → 4.5:1 normal / 3:1 large text (WCAG AA)
Touch targets → minimum 48×48 dp (Material Design spec)
```

Nothing beats testing with VoiceOver (iOS) or TalkBack (Android) on a real device.
