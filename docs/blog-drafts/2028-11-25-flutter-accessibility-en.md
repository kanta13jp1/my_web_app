---
title: "Flutter Accessibility — Semantics, Screen Readers, and WCAG Compliance"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Accessibility — Semantics, Screen Readers, and WCAG Compliance

Accessibility is foundational to user experience. Here's how to use Flutter's Semantics widget to support screen readers, high contrast mode, and WCAG standards.

## Semantics Widget Basics

```dart
// Add screen reader label to a button
Semantics(
  label: 'Submit button',
  hint: 'Submits the form',
  button: true,
  child: ElevatedButton(
    onPressed: _submit,
    child: const Text('Submit'),
  ),
)

// Alt text for images
Semantics(
  label: 'User avatar image',
  image: true,
  child: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
)

// Exclude decorative elements from TalkBack/VoiceOver
ExcludeSemantics(
  child: Icon(Icons.star, color: Colors.amber),
)
```

## Custom Actions (Swipe Gestures)

```dart
Semantics(
  customSemanticsActions: {
    CustomSemanticsAction(label: 'Delete'): () => _deleteItem(item.id),
    CustomSemanticsAction(label: 'Archive'): () => _archiveItem(item.id),
  },
  child: ListTile(title: Text(item.title)),
)
```

## Contrast Ratio Check

```dart
// WCAG AA: 4.5:1+ (normal text) / 3:1+ (large text)
// Provide high contrast theme in MaterialApp
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  ),
  highContrastTheme: ThemeData(
    colorScheme: const ColorScheme.highContrast(),
  ),
  home: const MyHomePage(),
)
```

## Accessibility Testing

```dart
testWidgets('Submit button has correct semantics', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: MyForm()));

  final semantics = tester.getSemantics(find.text('Submit'));
  expect(semantics.label, contains('Submit'));
  expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
  semantics.dispose();
});
```

## Summary

```
Semantics        → label/hint/button/image flags for screen readers
ExcludeSemantics → remove decorative elements from focus order
HighContrast     → highContrastTheme auto-adapts to OS setting
Testing          → tester.getSemantics() enables unit-level a11y tests
```

Accessibility is cheapest when designed in from the start — retrofitting costs 3-5x more than building it correctly initially.
