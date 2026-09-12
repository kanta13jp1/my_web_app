---
description: Runs a design and accessibility review of the current Flutter file
---

Review the currently open or specified Flutter file for design compliance against the project design system.

Before reviewing, also read:
- `docs/DESIGN_TOOLING_SETUP.md`
- `docs/DESIGN_ACCESSIBILITY_AUDIT.md`
- `docs/DESIGN.md`
- `lib/services/theme_service.dart`
- the nearest existing Figma source through `figma` MCP when it exists

`docs/DESIGN.md` is the source of truth. Figma and AIDesigner outputs are
references and must be reconciled to it before implementation.

For a new or materially revised UI surface, run the Anthropic-verified Design
plugin review before declaring the design ready:

1. Attach desktop/mobile screenshots plus normal, loading, empty, error, and
   recovery states that apply.
2. Run the WCAG 2.1 AA prompt from `docs/DESIGN_ACCESSIBILITY_AUDIT.md`.
3. For checkout, payment, authentication, or form errors, run the error
   microcopy prompt from that runbook.
4. Fix every blocker, critical, and high finding, then re-run the plugin review.
5. Return the completed `## Design Accessibility Audit` PR evidence block.

If the Design plugin is unavailable, report the audit as blocked. Do not treat
Figma/AIDesigner review or an unchecked checklist as equivalent evidence.

Check the following in order:

1. **Colors**: Use the surface, text, and semantic colors defined by
   `docs/DESIGN.md` and mapped by `theme_service.dart`. Use
   `withValues(alpha: x)` rather than `withOpacity()`.

2. **Typography**: `letterSpacing` must only appear on headline styles (headlineLarge, headlineMedium). Body text must NOT have letterSpacing. Check that height values match: body ≥ 1.6, headings ≥ 1.4.

3. **Touch targets**: All `InkWell`, `GestureDetector`, `IconButton`, `TextButton` must have min 44×44px interactive area.

4. **Cards**: Border radius, border, surface, and shadow must match the current
   project card tokens in `docs/DESIGN.md`.

5. **Dark mode**: All hardcoded colors must have a dark mode equivalent. Prefer `Theme.of(context).colorScheme.*`.

6. **Content width**: Long-form text containers must have `maxWidth: 620` or less.

Report findings as a checklist with ✅ (pass) / ⚠️ (warning) / ❌ (fail), then
list specific fixes. Separate design-level plugin findings from implementation
checks that require the running Flutter app. Do not claim WCAG conformance from
the plugin review alone.
