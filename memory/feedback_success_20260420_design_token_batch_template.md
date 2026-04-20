---
name: DESIGN token batch-replacement template
description: Reusable 4-step pipeline (Python map + dart format + dart fix + flutter analyze) with full shade color map for replacing Material brand colors with DESIGN.md hex tokens
type: feedback
---

DESIGN token batch-replacement template (VSCode版 Batch 11-16 proven, 43 files / ~490 violations).

**Why:** `lib/pages/*.dart` had 600+ Material brand-color usages (Colors.red/green/orange plus shade variants). Regex-only replacement kept tripping over shades and required many per-batch fixups. Locking in the full shade map + pipeline avoids the fix-and-repeat loop.

**How to apply:** Each batch = 5-6 files from `lib/pages/`, ranked by violation density. Run:

1. Python replace (full shade map below)
2. `dart format <files>`
3. `for f in ...; do dart fix --apply lib/pages/$f.dart; done` (per-file — multi-file unsupported)
4. `flutter analyze <files>` — usually clean; residual shades on hex Color need manual hex
5. git add + commit + `git pull --rebase origin main` + `git push origin HEAD:main` (bypass PR rule)

**Full shade map (Python dict form):**

```python
green_shades = {'50':'0xFFE8F5E9','100':'0xFFC8E6C9','200':'0xFFA5D6A7','300':'0xFF81C784',
                '400':'0xFF66BB6A','600':'0xFF43A047','700':'0xFF388E3C','800':'0xFF2E7D32'}
red_shades   = {'50':'0xFFFFEBEE','100':'0xFFFFCDD2','200':'0xFFEF9A9A','300':'0xFFE57373',
                '400':'0xFFEF5350','700':'0xFFC62828','800':'0xFFC62828','900':'0xFFB71C1C'}
orange_shades= {'50':'0xFFFFF3E0','100':'0xFFFFE0B2','200':'0xFFFFCC80','300':'0xFFFFB74D',
                '700':'0xFFE65100'}
# Bare forms:
# Colors.redAccent / Colors.red → Color(0xFFE53935)
# Colors.green → Color(0xFF4CAF50)
# Colors.orange → Color(0xFFFF6B35)
# Regex lookahead (?![\w\[]) to exclude Colors.greenAccent etc.
```

**Gotchas caught by this pipeline:**
- `Colors.X.withValues(...)` — regex matches; runtime call works on Color class. OK.
- `const Color(0xFFE53935).shade900` — remaining after Python (lingering from prior passes); grep `shade\d+` after replace, manual hex fix.
- Alert-helper pattern `final color = isError ? Colors.red : Colors.green` + downstream `.shade50/200/700` — refactor to three pre-computed `bg`/`border`/`fg` vars BEFORE Python pass (see discord_notification / line_notification_page precedent).
- `dart fix --apply` takes single file only; loop required.
- `require_trailing_commas` + `undefined_getter` come up in ~20% of batches → grep `shade\d+` and manual Edit.

**Commit message template:**
```
style: DESIGN tokens — N pages Colors.red/green/orange → hex (VSCode版 Batch N)

- file1, file2, file3, ...
- <new shade variant introduced this batch, if any>
- K prefer_const_constructors auto-fixed via `dart fix --apply`
```

Throughput: ~5-6 files per 5-7 min batch including flutter analyze cost (~60-90s).
