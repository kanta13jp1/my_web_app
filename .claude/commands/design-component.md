---
description: Generate a Flutter widget using docs/DESIGN.md as the single source of truth
---

Generate a Flutter widget for 自分株式会社.

$ARGUMENTS

1. Read `docs/DESIGN.md` and the nearest existing widget or screen.
2. Read `docs/DESIGN_TOOLING_SETUP.md` only when Figma or AIDesigner is needed.
3. Inspect existing Figma for fidelity; use AIDesigner for alternatives, not as a token authority.
4. Reuse `ThemeService`, `Theme.of(context)`, and shared widgets before adding local constants.
5. Cover desktop and mobile constraints, interaction states, accessibility, and real data boundaries defined by the feature.
6. Reconcile the result against the implementation and review checklists in `docs/DESIGN.md`.
7. Run `dart format`, `flutter analyze`, and targeted tests.

Do not restate or invent design token values in this command. Update `docs/DESIGN.md` first when a new canonical value is required.
