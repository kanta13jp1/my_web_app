---
title: "How I Applied Design Tokens Across 200 Flutter Pages in One Commit"
tags: Flutter,webdev,UI,buildinpublic,Dart
published: true
---

# How I Applied Design Tokens Across 200 Flutter Pages in One Commit

## The Problem

My solo SaaS project [Jibun Kabushiki Kaisha](https://my-web-app-b67f4.web.app/) has ~200 Flutter Web pages. Over time, color usage became inconsistent:

```dart
// Page A
color: Colors.grey,

// Page B  
color: Color(0xFF9E9E9E),

// Page C
color: Colors.grey[600],
```

The design system (`docs/DESIGN.md`) mandates `Color(0xFFB0B0B0)` for grey. Manual fixes across 200 pages aren't feasible. Here's how I automated it.

## Solution: grep + Python batch replace + flutter analyze

### Step 1: Find all violations

```bash
grep -rn "Colors\.grey\b" lib/ --include="*.dart" | wc -l
# → 312 occurrences across 73 files
```

### Step 2: Python batch replace (safer than sed)

```python
import os, re

target_dir = "lib/"
replacements = [
    (r'\bColors\.grey\b(?!\[)', 'const Color(0xFFB0B0B0)'),
    (r'\bColors\.grey\[700\]', 'const Color(0xFF616161)'),
    (r'\bColors\.grey\[600\]', 'const Color(0xFF757575)'),
    (r'\bColors\.grey\[400\]', 'const Color(0xFFBDBDBD)'),
    (r'\bColors\.grey\[200\]', 'const Color(0xFFEEEEEE)'),
]

for root, dirs, files in os.walk(target_dir):
    for file in files:
        if not file.endswith('.dart'): continue
        path = os.path.join(root, file)
        content = open(path, 'r', encoding='utf-8').read()
        new_content = content
        for pattern, replacement in replacements:
            new_content = re.sub(pattern, replacement, new_content)
        if new_content != content:
            open(path, 'w', encoding='utf-8').write(new_content)
            print(f"Updated: {path}")
```

### Step 3: Format and validate

```bash
dart format lib/ --set-exit-if-changed
flutter analyze lib/
# → No issues found!
```

### Step 4: Commit

```bash
git add lib/
git commit -m "style: design token batch replace — Colors.grey→Color(0xFFB0B0B0) 43 pages"
```

## The Gotcha: Partial Name Matches

`Colors.white12` and `Colors.white38` are valid Flutter constants. A naive `\bColors\.white\b` pattern breaks them:

```python
# ❌ This matches "white" inside "white12"
r'\bColors\.white\b'

# ✅ Negative lookahead excludes digit suffixes
r'\bColors\.white\b(?!\d)'
```

We learned this the hard way — 13 files had `Colors.white12` → `Color(0x1FFFFFFF)` wrongly substituted, causing 13 CI failures that needed manual fixes.

## Results

| Metric | Before | After |
|--------|--------|-------|
| Design token compliance | ~65% | ~95% |
| Hardcoded colors | 312 | 12 |
| CI lint errors | 0 | 0 |
| Pages fixed | - | 43 in 1 commit |

## Key Lessons

1. **Always end with `flutter analyze` 0 errors** — the linter will revert partial fixes on next run
2. **Use strict regex boundaries** — partial matches cause cascading fix commits
3. **`dart format` is mandatory** — CI's `Check formatting` step will catch any missed formatting

The batch approach turns what would be a week of manual work into a 10-minute script. The only investment is getting the regex right the first time.

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Dart #buildinpublic #designsystem
