---
title: "Flutter CI Broke With 2288 Errors — How dart fix --apply Saved Us"
tags: Flutter,Dart,CI/CD,buildinpublic,webdev
published: true
---

# Flutter CI Broke With 2288 Errors — How `dart fix --apply` Saved Us

## What Happened

One morning, `deploy-prod.yml` started failing:

```
error • Use 'const' with the constructor to improve performance
lib/pages/landing_page.dart:12:15 • prefer_const_constructors
... (2287 more errors)
```

2,288 errors. A 200-page Flutter Web app went from green to red overnight.

The cause: one line in `analysis_options.yaml`.

```yaml
# Before:
prefer_const_constructors: warning

# The commit that broke everything:
prefer_const_constructors: error
```

One severity upgrade. 2,288 CI failures.

## The Fix

### Step 1: Immediate rollback — warning not error

```yaml
# analysis_options.yaml
linter:
  rules:
    prefer_const_constructors: warning  # downgrade back
```

This unblocks CI, but 2,288 warnings remain as a time bomb. Anyone upgrading to `error` again will re-trigger the same failure. We needed a real fix.

### Step 2: Batch-fix with dart fix --apply

```bash
dart fix --apply lib/
```

Output:

```
pages/landing_page.dart
  prefer_const_constructors - 47 fixes
pages/home_page.dart
  prefer_const_constructors - 89 fixes
...
2276 fixes made in 181 files.
```

181 files. 2,276 automatic fixes. One command.

### Step 3: dart format (mandatory)

```bash
dart format lib/ --set-exit-if-changed
```

`dart fix` inserts `const` keywords that can change line lengths and break formatting. CI's `Check formatting` step will fail if you skip this.

### Step 4: Verify with flutter analyze

```bash
flutter analyze lib/
# → No issues found! (ran in 23.9s)
```

### Step 5: Commit and push

```bash
git add lib/ analysis_options.yaml
git commit -m "fix: prefer_const → warning + dart fix 2276 fixes in 181 files"
git push origin main
```

## Bonus: require_trailing_commas Was Also Broken

The same CI run had 36 `require_trailing_commas` errors too. Same fix:

```bash
dart fix --apply lib/
# → require_trailing_commas - 36 fixes in 12 files
```

**One command handles multiple lint rules simultaneously.**

## Gotcha #1: dart fix Can Break Things Too

`dart fix --apply` isn't always safe:

```dart
// ❌ What dart fix incorrectly generated:
color: const Color(0xFF9E9E9E)[400]  // Color has no [] operator

// ✅ Correct:
color: const Color(0xFFBDBDBD)  // use the actual hex value
```

This happened because an older `dart fix` run had transformed `Colors.grey[400]` → `Color(0xFFB0B0B0)[400]` — partially correct but leaving a `[]` subscript that `Color` doesn't support. Always verify with `flutter analyze` after running `dart fix`.

## Gotcha #2: PdfColor Got Mangled

The `pdf` package uses `PdfColor`, not Flutter's `Color`. The substitution produced invalid syntax:

```dart
// ❌ dart fix's broken output:
color: PdfColor(0xFFB0B0B0)700,  // completely invalid

// ✅ Correct PdfColors API:
color: PdfColors.grey700,
```

`PdfColor` and `Color` have different APIs. Use `PdfColors.grey700`, `PdfColors.grey300` etc. for the pdf package.

## Summary

| Step | Command | Effect |
|------|---------|--------|
| Emergency stop | Edit `analysis_options.yaml` | CI unblocked immediately |
| Batch fix | `dart fix --apply lib/` | Thousands of fixes in one shot |
| Format | `dart format lib/` | Passes `Check formatting` in CI |
| Verify | `flutter analyze lib/` | Confirm 0 errors |

**The rule**: always run `dart fix --apply` *before* upgrading a lint rule to `error`. Upgrading severity and fixing violations in the same commit is the recipe for CI carnage.

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Dart #CI/CD #buildinpublic #devops
