# Codex UI QA Playbook

Issue: #1646  
Owner lane: Codex #1 in the Windows app  
Fleet rule: use only Claude Code #1 and Codex #1. Do not route this work to old Codex #2/#3 lanes.

## Purpose

Codex UI work must leave reviewable browser evidence, not only code diffs. This
playbook turns in-app browser checks, Playwright visual evidence, console-error
review, and image-generation provenance into a repeatable PR contract.

Claude Code #1 owns product/design judgment when a visual decision changes the
direction of the product. Codex #1 owns implementation, local browser
verification, screenshots, and CI evidence.

## UI PR Checklist

Use this for any PR that changes `lib/`, `web/`, route behavior, visual assets,
or user-visible copy.

1. List the changed routes or surfaces in the PR body.
2. Fill the Minimal E2E Gate section in `.github/PULL_REQUEST_TEMPLATE.md`.
3. Fill the Visual E2E Evidence section in `.github/PULL_REQUEST_TEMPLATE.md`.
4. For new or materially revised UI, complete
   `docs/DESIGN_ACCESSIBILITY_AUDIT.md` and its PR evidence section.
5. Run targeted static checks for the touched stack.
6. Capture browser evidence with Codex in-app browser, Playwright, or both.
7. Record console/page errors, request failures, and HTTP 5xx findings.
8. Attach or link screenshots, Playwright artifacts, or the exact reason the PR is documentation-only.
9. If generated imagery is used, record the prompt, intended use, rights statement, and asset path.

## Minimal Browser Evidence

For user-facing UI changes, the minimum automated evidence is:

- desktop viewport: `chromium` project, 1440 x 1000
- mobile viewport: `mobile-chrome` project, Pixel 5 profile
- screenshot: one stable screenshot per route and viewport
- motion sanity: three low-FPS frames per route
- browser issues: console errors, page errors, request failures, and HTTP 5xx responses
- animation settling: `document.getAnimations({ subtree: true })` wait path or a documented fallback

The current automation lives in:

- `test/e2e/visual_evidence.spec.ts`
- `test/e2e/public_smoke.spec.ts`
- `.github/workflows/minimal-e2e-gate.yml`
- `scripts/summarize_playwright_results.mjs`

Run locally against production:

```bash
npm run e2e:visual -- --project=chromium --project=mobile-chrome --workers=1
```

Run locally against a dev server:

```bash
E2E_BASE_URL=http://127.0.0.1:3000 npm run e2e:visual -- --project=chromium --project=mobile-chrome --workers=1
```

If the UI route requires auth, seed data, or secrets unavailable in local
browser automation, document the exception in the PR body and still include a
Codex in-app browser or manual browser note for the reachable part of the flow.

## Codex In-App Browser

Use the Codex in-app browser when the PR changes layout, interaction,
responsive behavior, or visible media.

Record the route, viewport, and observation in the PR body:

```text
Codex browser evidence:
- route: /example
- viewport: desktop 1440x1000, mobile Pixel 5 equivalent
- console/page errors: none observed
- screenshots/artifacts: <link or artifact name>
```

The browser note is not a replacement for Playwright when the route is public
and automatable. It is the extra human-in-the-loop check for framing,
readability, interaction, and whether the result feels like the intended product.

## Image Generation Policy

Use generated bitmap images only when a raster asset is the correct artifact:

- OGP cards, blog/social thumbnails, hero backgrounds, concept mockups, texture
  studies, or illustrative product-state drafts
- transparent-background cutouts or visual variants where the prompt and source
  references can be recorded
- temporary design exploration that is linked to a PR comment, docs note, or WBS task

Prefer code, existing assets, SVG, or screenshots when the output should be
deterministic:

- app icons, logos, brand marks, buttons, badges, diagrams, charts, and
  product UI primitives
- screenshots used as evidence of the actual product state
- branded/product/place/person imagery that must depict the real subject
- legal, financial, medical, or compliance visuals where fidelity matters

Every generated image used in a PR must include:

- prompt or source reference
- intended use
- asset path or artifact link
- rights statement: generated/owned/licensed, no third-party logo or trademark
  claim unless explicitly permitted
- verification note when it depicts a product, person, place, or branded object

Generated imagery must not be used to imply an unverified real product state.
If the image is only illustrative, label it as illustrative in the PR or docs.

## Reviewable Output

A UI/prototyping PR is complete when reviewers can answer these questions from
the PR body and artifacts:

- What changed for the user?
- Which route and viewport were checked?
- Were console/page/request failures reviewed?
- What screenshots or Playwright artifacts prove the state?
- Did generated imagery enter the product, and if so, where is its provenance?
- Is the change connected to the relevant Issue or WBS task?

