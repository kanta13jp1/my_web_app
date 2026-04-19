---
title: "Completing a 300-File Flutter DESIGN Token Migration — Eliminating Every Material Color Constant"
tags: Flutter,UI,buildinpublic,ClaudeCode,webdev
published: false
---

# Completing a 300-File Flutter DESIGN Token Migration

## The Goal

Replace every `Colors.orange`, `Colors.indigo`, `Colors.white` and similar Material color constants with explicit HEX design tokens that match our `docs/DESIGN.md` Orange+Indigo dark theme.

## Before and After

```dart
// ❌ Before: Material brand colors
Container(
  color: Colors.orange,
  child: Text('Title', style: TextStyle(color: Colors.white)),
)

// ✅ After: HEX design tokens
Container(
  color: const Color(0xFFFF6B35),  // orange primary
  child: Text('Title', style: TextStyle(color: const Color(0xFFF1F5F9))),
)
```

## Scale

| Metric | Value |
|--------|-------|
| Files touched | 300+ |
| Compliance at start | 60% |
| Compliance at end | **100%** |
| Sessions to complete | 8 (VSCode#94–#109) |

## The Three Hard Cases

### Case 1: `Colors.grey.shade700` — shade variants

```dart
// ❌ After replacement, this is invalid syntax
color: const Color(0xFFB0B0B0).shade700,  // → compiler error

// ✅ Fix: use PdfColors (pdf package) or fixed HEX
color: PdfColors.grey700,           // inside pdf package code
color: const Color(0xFF616161),     // regular Dart
```

`.shadeXXX` only exists on `MaterialColor`, not on `Color`. The linter won't catch this before CI does. Check for shade suffixes after any bulk replacement.

### Case 2: `Colors.white` and `Colors.black`

```dart
// ❌ Direct substitution can look wrong in context
const Color(0xFFFFFFFF)  // technically correct but often too bright

// ✅ Use slate-scale equivalents from DESIGN.md
const Color(0xFFF1F5F9)  // slate-100 for text white
const Color(0xFF0F172A)  // slate-900 for text black
```

Pure white/black rarely matches a dark theme. The slate scale gives contextually appropriate values.

### Case 3: `Colors.transparent` — leave it alone

```dart
// Both are identical — keep the readable one
Colors.transparent == const Color(0x00000000)
```

`Colors.transparent` communicates intent clearly. No reason to replace it.

## Automation with Claude Code

```bash
# 1. Count violations before starting
grep -r "Colors\." lib/ --include="*.dart" | wc -l

# 2. Python batch replacement per color
python3 -c "
import re, pathlib
for f in pathlib.Path('lib').rglob('*.dart'):
    src = f.read_text()
    src = re.sub(r'Colors\.orange(?!Accent)', 'const Color(0xFFFF6B35)', src)
    f.write_text(src)
"

# 3. Always validate in order
dart format lib/ --set-exit-if-changed
flutter analyze lib/
```

Do 20–30 files per session. Push only when `flutter analyze` reports 0 errors.

## Verification

```bash
# Confirm completion: should print 0
grep -r "Colors\.orange\|Colors\.indigo\|Colors\.amber\|Colors\.blue" lib/ \
  --include="*.dart" | grep -v "//\|test" | wc -l
```

## Lessons

1. **Batch size matters**: 20–30 files per commit. All-at-once creates an undebuggable mess of errors.
2. **shade suffix trap**: Always grep for `.shade` after bulk replacement.
3. **`dart format` before `flutter analyze`**: Format changes can mask or introduce analyze errors.
4. **`Colors.transparent` exception**: Some "constants" are fine to keep.

At 300+ files, this took 8 sessions of ~30 minutes each. The end result: a codebase where every color value traces back to a named token in `DESIGN.md`.

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #UI #buildinpublic #ClaudeCode
