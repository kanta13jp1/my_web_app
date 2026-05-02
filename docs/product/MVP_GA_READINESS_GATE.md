# MVP Scope Freeze and GA Readiness Gate

Status: in progress
Owner: Claude Code for product judgment, Codex #6 for scoped implementation, GitHub Actions for proof.
WBS task: `77f54e9c-06ed-4ad2-bb96-b779e32ed5d1`
GitHub issue: `#1640`
Harness notebook: `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`
Target freeze date: `2026-05-31`

This document turns the PS6 WBS product tasks into a single release gate. It
does not decide legal, pricing, or launch strategy by itself. It records the
decisions that must be made, the checks that prove them, and the owners that
must unblock them.

## Scope Freeze

### Must Ship

- CEO dashboard entry points for daily decision review, WBS visibility, and user task follow-up.
- AI officer flows that are already represented in the product surface and have server-side safety checks.
- WBS and GitHub Issue synchronization for product, launch, and user/manual tasks.
- Paddle/legal readiness visibility through existing legal compliance and subscription surfaces.
- Public web build that can pass the existing CI, public E2E, and deployment smoke gates.

### Explicitly Out of MVP

- Full incorporation workflow, tax filing, bank account creation, and advisor contracting.
- Production SAML/AppStream SSO rollout.
- Authenticated WorkOS/AuthKit MCP bearer-token production closure for every external tool.
- Final seed fundraising package, investor outreach, and Series A materials.
- Any feature that needs manual legal, tax, banking, or payment-provider approval before safe operation.

### Do Not Release If

- `flutter analyze` or `flutter test` is red on the release branch.
- Edge Function smoke, public E2E, or production deploy checks are red.
- Paddle legal entity data is inconsistent with the public site, terms, or account setup.
- A high-risk AI/officer tool path can send, delete, purchase, or externally share without a CEO approval gate.
- WBS tasks linked to MVP/GA gates are stale, blocked without a recovery plan, or missing GitHub Issue links.

## Pricing And Legal Dependencies

Pricing plan v1.0 is blocked until these inputs are final:

- Final legal entity name, headquarters address, and support contact.
- Paddle account entity, product description, refund policy, and checkout sandbox proof.
- Public terms/privacy pages that match the Paddle entity exactly.
- A decision on whether MVP is free-only, paid beta, or paid GA.

Related issues:

- `#1330` Paddle public operator name and registered account mismatch.
- `#1633` Single source of truth and automated Paddle legal entity audit.
- `#1286` Branch protection and release governance.

## Deterministic Checks

The MVP/GA gate is not complete until all applicable checks are green:

```powershell
flutter analyze
flutter test
python scripts/check_mvp_ga_readiness.py
python scripts/check_mobile_release_readiness.py
python scripts/codex_session_check.py
```

External proof still required:

- Public E2E stability smoke.
- Edge Function smoke for critical hubs.
- Paddle/legal readiness review.
- WBS sync proof for `#1640` and related product tasks.

## Ownership

| Lane | Owner | Completion proof |
| --- | --- | --- |
| Product scope and release policy | Claude Code | This document is accepted or amended in `#1640`. |
| Scoped repo changes | Codex #6 or assigned Codex lane | PR links, deterministic command output, and WBS updates. |
| CI and scheduled proof | GitHub Actions / Codex #2 | Green workflow run and failure issue routing. |
| Manual/legal/business tasks | User / Claude Code | Explicit decision comment or external evidence. |

## Current Blockers

- BLOCKER: Legal entity data is not yet a single source of truth for Paddle and public pages.
- BLOCKER: Codex CLI is unavailable on the local PowerShell PATH, so `/goal` persistence must use Issue/WBS fallback.
- BLOCKER: WorkOS/AuthKit bearer-token smoke for tools-hub MCP remains external-credential blocked.
- BLOCKER: Business/legal/finance WBS items require user or advisor action.

## Automation Route

- `scripts/check_mvp_ga_readiness.py` validates this document's required anchors.
- `.github/workflows/mvp-ga-readiness.yml` runs the check on pull requests and manual dispatch.
- `#1607` should persist this gate as a Codex `/goal` candidate when Codex CLI 0.128+ is available.
- `#1559` should connect future AI Tool Watch findings to this gate when they affect release automation.
