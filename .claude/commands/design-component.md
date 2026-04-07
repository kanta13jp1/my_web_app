---
description: Generate a new Flutter widget following the project design system (note-style)
---

Generate a new Flutter widget following the 自分株式会社 design system.

$ARGUMENTS

Before generating, read:
- `/DESIGN.md` — note.com design system reference
- `docs/DESIGN.md` — project-specific tokens
- `docs/DESIGN_TOOLING_SETUP.md` — workflow for Figma MCP / AIDesigner MCP
- `lib/services/theme_service.dart` — ThemeData setup

If this is more than a tiny local tweak:
- use `figma` MCP to inspect the nearest existing source design when available
- use `aidesigner` MCP to generate 2-3 directions before locking the Flutter implementation

Apply these rules:
1. Colors: use `const Color(0xFF08131A)` for text, `withValues(alpha:)` for opacity variants
2. Typography: `Theme.of(context).textTheme.*` — never hardcode font sizes unless necessary
3. Spacing: use multiples of 8px (8, 16, 24, 32, 48)
4. Cards: `BorderRadius.circular(12)`, note-spec BoxShadow
5. Dark mode: wrap color decisions with `Theme.of(context).brightness == Brightness.dark ? ... : ...` or use colorScheme
6. Touch targets: min 44px for all interactive elements
7. No dummy/hardcoded data — connect to Supabase via Edge Functions

After generating, run `flutter analyze` in your mind and confirm 0 linter errors before outputting.
