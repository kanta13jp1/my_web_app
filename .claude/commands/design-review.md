---
description: Runs a design review of the current Flutter file against DESIGN.md (note design system)
---

Review the currently open or specified Flutter file for design compliance against the project design system.

Before reviewing, also read:
- `docs/DESIGN_TOOLING_SETUP.md`
- `docs/DESIGN.md`
- the nearest existing Figma source through `figma` MCP when it exists

Check the following in order:

1. **Colors**: All colors must use `Color(0xFF08131A)` family (not `Colors.black`) for text. Use `withValues(alpha: x)` not `withOpacity()`. Brand color `Color(0xFF5AC8B8)` must not be used for body text.

2. **Typography**: `letterSpacing` must only appear on headline styles (headlineLarge, headlineMedium). Body text must NOT have letterSpacing. Check that height values match: body ≥ 1.6, headings ≥ 1.4.

3. **Touch targets**: All `InkWell`, `GestureDetector`, `IconButton`, `TextButton` must have min 44×44px interactive area.

4. **Cards**: Border radius must be 12px. Border color `Color(0xFF08131A).withValues(alpha: 0.14)`. Shadow must match note elevation-1 spec.

5. **Dark mode**: All hardcoded colors must have a dark mode equivalent. Prefer `Theme.of(context).colorScheme.*`.

6. **Content width**: Long-form text containers must have `maxWidth: 620` or less.

Read `/DESIGN.md` and `docs/DESIGN.md` for the full spec. When useful, compare the current implementation against Figma MCP and propose an AIDesigner exploration path for unclear areas. Report findings as a checklist with ✅ (pass) / ⚠️ (warning) / ❌ (fail), then list specific fixes needed.
