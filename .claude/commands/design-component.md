---
description: Generate a new Flutter widget following the project design system
---

Generate a new Flutter widget following the 自分株式会社 design system.

$ARGUMENTS

Before generating, read:
- `docs/DESIGN.md` — project-specific tokens and source of truth
- `docs/DESIGN_TOOLING_SETUP.md` — workflow for Figma MCP / AIDesigner MCP
- `docs/DESIGN_ACCESSIBILITY_AUDIT.md` — Design plugin audit and PR evidence
- `lib/services/theme_service.dart` — ThemeData setup
- `/DESIGN.md` — secondary design reference only

If this is more than a tiny local tweak:
- use `figma` MCP to inspect the nearest existing source design when available
- use `aidesigner` MCP to generate 2-3 directions before locking the Flutter implementation
- reconcile every direction to `docs/DESIGN.md` before implementation

Apply these rules:
1. Colors: use the tokens in `docs/DESIGN.md` / `theme_service.dart`, and
   `withValues(alpha:)` for opacity variants
2. Typography: `Theme.of(context).textTheme.*` — never hardcode font sizes unless necessary
3. Spacing: use multiples of 8px (8, 16, 24, 32, 48)
4. Cards: use the project card tokens and `BorderRadius.circular(12)`
5. Dark mode: wrap color decisions with `Theme.of(context).brightness == Brightness.dark ? ... : ...` or use colorScheme
6. Touch targets: min 44px for all interactive elements
7. No dummy/hardcoded data — connect to Supabase via Edge Functions

After generating, run targeted tests and the real `flutter analyze` command.
Report their exact results; if either cannot run, report the blocker and do not
claim the widget is ready. Complete the Design plugin audit and PR evidence
block before review.
