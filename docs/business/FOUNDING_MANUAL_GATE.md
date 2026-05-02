# Founding Manual Gate

Status: in progress
Owner: User and Claude Code for decisions, Codex #6 for deterministic handoff, GitHub Actions for proof.
GitHub issue: `#1662`
Related GA gate: `#1640`, PR `#1661`
Harness notebook: `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`
Target review date: `2026-05-05`

This page is the single handoff surface for founding, legal, tax, banking, and
financing decisions that block the MVP/GA readiness gate. Codex can prepare
checklists, consistency checks, and evidence routing. Codex must not invent or approve
legal entity data, advisor contracts, registration filings, bank account
decisions, or financing materials.

## Manual Decision Register

| WBS task | Deadline | Decision owner | Required evidence | Downstream route |
| --- | --- | --- | --- | --- |
| `108a24dc-abee-4bec-90f4-56c8b558f616` Trade name and head-office address | `2026-06-15` | User / advisor | Final trade name, final registered address, advisor confirmation, source document date | Update `#1633`, `#1330`, and `#1640` |
| `0fa38c4f-0d9e-43e3-8ca0-2643c8888e28` Legal/tax advisor engagement | `2026-06-30` | User | At least two quotes or explicit single-source rationale, selected advisor, scope and fee notes | Comment on `#1662`; link in `#1640` |
| `5e34304e-7731-4aa2-9ba0-c8ff9654ccd8` Incorporation filing | `2026-09-30` | User / judicial scrivener | Filing date, registry proof, articles version, seal/certificate checklist | Update GA readiness proof in `#1640` |
| `282c7660-933f-4a55-a004-638da077c416` Three-year P/L plan | `2026-08-31` | User / Claude Code | Approved P/L assumptions, pricing mode, cost model, risk notes | Feed pricing task and investor materials |
| `c1436a87-8248-40b6-b8fa-4f4c3502889f` Corporate bank account | `2026-10-15` | User | Bank selected, application status, KYC evidence checklist, rejection/retry notes | Feed Paddle/legal SSOT and finance docs |
| `f9c7fd37-f2c5-494a-9438-9bba424218d1` Seed investor list | `2026-10-31` | User / Claude Code | Target list, outreach constraints, exclusion list, source of each contact | Feed pitch deck and CRM tasks |
| `69d5bbad-84ba-4fa6-89c0-b7375a6c75cf` Pitch Deck v1.0 | `2026-10-31` | User / Claude Code | Approved deck, version, reviewer notes, claims source register | Feed fundraising readiness tasks |

## Existing Source Notes

- `docs/research/2026-04-25_legal_entity_decision.md`
- `docs/research/2026-04-25_trade_name_head_office_decision.md`
- `docs/research/2026-04-25_professional_advisor_selection_checklist.md`
- `docs/user-tasks-snapshot.md`
- `docs/roadmaps/BUSINESS_OPERATIONS_PLAN.md`

These notes are inputs, not final approvals. If a final decision differs from
any note above, the GitHub issue comment must say which note was superseded and
why.

## Release Interaction

Do not mark the MVP/GA gate complete until these conditions are true:

- Legal entity name and public operator name have one source of truth.
- Paddle account entity, terms, privacy, support contact, and public site match
  the same entity data.
- Business address and bank-account evidence are real external decisions, not
  generated text.
- Pricing mode is explicit: free-only MVP, paid beta, or paid GA.
- Any financing claims in a deck or public page have an approved source
  register.

Related issues:

- `#1640` MVP scope freeze and GA readiness gate.
- `#1662` manual founding/legal/tax/banking gate.
- `#1633` legal entity single source of truth and Paddle audit.
- `#1330` operator name and Paddle registered account mismatch.
- `#1185` AI officer business plan generation for corporate bank account prep.

## Session Routing Rules

Codex sessions should do this:

- Prepare or update deterministic checklists, docs, CI checks, and issue links.
- Report missing evidence without filling it in.
- Keep WBS rows linked to GitHub Issues or issue comments.
- Use NotebookLM as background memory only; official records, advisor outputs,
  repository docs, and GitHub Issues remain the proof.

Claude Code should do this:

- Resolve ambiguous product, pricing, legal, and business-policy decisions.
- Review whether the manual evidence is sufficient for GA readiness.
- Decide when PR `#1661` can leave draft status.

User/advisors should do this:

- Select the final trade name and address.
- Retain legal and tax advisors.
- Approve incorporation, bank, pricing, and financing decisions.
- Provide evidence that can be linked back to `#1662`.

## Evidence Comment Template

Use this exact shape in `#1662` or a linked issue when a manual step advances:

```md
Manual gate evidence update:

- WBS task:
- Decision:
- Evidence source:
- Evidence date:
- Reviewer / advisor:
- Downstream issues updated:
- Remaining risk:
```

## Automation Route

- `scripts/check_founding_manual_gate.py` validates this page has the required
  anchors and manual-decision warnings.
- `.github/workflows/founding-manual-gate.yml` runs the check on pull requests
  and manual dispatch.
- `#1607` can persist the manual gate as a Codex `/goal` once Codex CLI is
  available locally.
- `#1559` should route future Claude Code or Codex tool changes into this gate
  only when they reduce manual evidence drift or improve proof collection.
