---
description: Run the full design workflow with Figma MCP, AIDesigner MCP, Design Skills, and docs/DESIGN.md
---

Use the project's full UI workflow instead of generating design directly from model intuition.

$ARGUMENTS

Always do the following:

1. Read `docs/DESIGN_TOOLING_SETUP.md`
2. Read `docs/DESIGN.md`
3. If an existing source design exists, inspect it with `figma` MCP
4. If the task needs exploration, generate or refine options with `aidesigner` MCP
5. Reconcile every proposal against `lib/services/theme_service.dart`
6. Produce the final Flutter implementation or review comments only after the above

Rules:
- `docs/DESIGN.md` is the final authority
- Figma MCP is for fidelity
- AIDesigner MCP is for speed and variation
- Always think in desktop and mobile together for new screens
- Avoid generic SaaS UI and keep alignment with existing project tone
