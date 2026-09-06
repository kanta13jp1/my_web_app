# Design Accessibility Audit

Issue: #1281
Owner: Claude Code #1 for design judgment, Codex #1 for implementation and CI

## Purpose

Every new or materially revised UI surface must be reviewed with Anthropic's
Design plugin before the Pull Request is ready for review. The review covers:

- design-level WCAG 2.1 AA risks;
- checkout, payment, authentication, and form error-state microcopy;
- the remediation applied before the final plugin re-review; and
- durable evidence in the Pull Request description.

The official Design plugin describes accessibility audits and UX writing as
supported workflows, including WCAG 2.1 AA audits and checkout error-state
microcopy review:

- https://claude.com/plugins/design
- https://www.w3.org/TR/WCAG21/

The plugin review is a design critique, not a substitute for deterministic
checks. Flutter semantics tests, keyboard testing, contrast measurement,
browser evidence, and assistive-technology checks remain required where they
apply.

## Trigger

Run this flow when a PR adds or materially changes a user-visible Flutter UI
file, including a user-visible removal. The CI gate recognizes UI paths under `lib/ui/`, `lib/widgets/`,
`lib/pages/`, `lib/screens/`, and `lib/components/`, while excluding data,
domain, model, service, repository, and view-model directories. It also catches
UI files elsewhere under `lib/` when their names end in `_component.dart`,
`_dialog.dart`, `_page.dart`, `_screen.dart`, `_sheet.dart`, `_view.dart`, or
`_widget.dart`, plus app shell, route/navigation, feature, and development UI
paths.

A checkout/form microcopy review is mandatory when an affected path or declared
scope contains a checkout, payment, purchase, form, authentication, login,
signup, registration, or contact surface marker. The PR must also classify the
surface; generic route or shell filenames cannot silently declare a checkout
surface as unrelated UI.

## Audit Procedure

1. Capture the surface in each relevant state and viewport.
   - desktop and mobile where the layout is responsive;
   - normal, loading, empty, validation-error, request-error, and recovery
     states where available;
   - focus, disabled, selected, and expanded states for interactive controls.
2. Open the Anthropic-verified Design plugin and attach the screenshots or
   mockups. Include enough surrounding context to understand hierarchy and the
   task the user is trying to complete.
3. Run the accessibility prompt below. Ask the plugin to separate design-level
   findings from implementation checks that require the running application.
4. If the surface contains checkout or form errors, run the microcopy prompt.
5. Remediate every unresolved blocker, critical, or high-severity finding.
6. Re-run the plugin review against the remediated state. A pass means no
   unresolved WCAG 2.1 AA blocker, critical, or high-severity finding remains.
7. Perform the deterministic checks listed below and paste the PR evidence
   block into the PR description.

### Accessibility prompt

```text
Audit these desktop/mobile UI states for WCAG 2.1 AA design risks. Review
contrast, text resizing and reflow, focus visibility and order, keyboard-only
operation, labels and instructions, error identification, status messages,
touch targets, motion, and color-independent meaning. Separate findings that
are visible in the supplied design from implementation checks that require the
running Flutter app. For each finding provide severity, affected element,
WCAG criterion, user impact, and a concrete remediation. End with unresolved
blocker/critical/high findings and an explicit pass/fail recommendation.
```

### Error microcopy prompt

```text
Review every checkout/form error state shown here. Rewrite unclear copy so it
states what happened, what the user can do next, and whether their data or
payment is safe. Keep the tone calm and specific. Do not blame the user, claim
success before confirmation, expose internal errors, or create urgency. Check
that the error is programmatically associable with the affected field and that
the recovery action is named. Return before/after copy and any unresolved risk.
```

## Deterministic Verification

Record the checks that apply to the changed surface:

- measured contrast meets WCAG 2.1 AA for text and essential UI graphics;
- keyboard-only traversal has visible focus and a logical order;
- controls expose a name, role, value/state, and at least a 44x44 target;
- text scaling and narrow/mobile layouts do not clip or obscure actions;
- errors identify the affected input, preserve safe user input, and provide a
  recovery action;
- async errors/status changes are announced without moving focus unexpectedly;
- reduced-motion behavior and non-color status indicators are present;
- targeted widget/semantics tests and the UI QA evidence are updated.

Visual/browser QA and assistive-technology QA are separate gates. Automated
Semantics tests do not prove NVDA, VoiceOver, or TalkBack behavior. Record the
AT/browser/OS result, or a specific not-run reason and release follow-up owner.
`docs/ACCESSIBILITY_QA_CHECKLIST.md` demonstrates the repository's existing
AT/manual-evidence boundary for specific surfaces; adapt that evidence pattern
to the changed surface. Use `docs/CODEX_UI_QA_PLAYBOOK.md` for browser evidence.

## Pull Request Evidence Contract

Copy this block into the PR description. Do not use placeholders. Plugin output
may be attached as a PR comment, repository artifact, or stable review link.
The evidence must let a reviewer inspect what was reviewed; a bare statement
such as "ran the plugin" is insufficient.

```markdown
## Design Accessibility Audit

- Scope: routes=<routes>; components=<components>; states=<states>; viewports=<viewports>
- Surface-Type: <checkout-form — reason | other — reason>
- Design-Plugin-Status: pass
- Design-Plugin-Reviewed-At: <YYYY-MM-DD>
- Design-Plugin-Evidence: <HTTPS URL, PR comment #, artifact:name, or repository evidence file>
- WCAG-2.1-AA-Findings: result=pass; unresolved-high=0; <summary/remaining risks>
- Remediation: resolved=<count>; <what changed after review, or why none was required>
- Deterministic-Evidence: tests=<result>; keyboard-contrast=<result>; AT=<result or not-run owner/follow-up>
- Error-Microcopy-Review: reviewed — <before/after summary and recovery behavior>
```

For a UI surface that has no checkout/form error state, use:

```text
Error-Microcopy-Review: not-applicable — <specific reason, at least one sentence>
```

`not-applicable` is not accepted for checkout/form-related UI paths. If the
Design plugin is unavailable, the audit is blocked; a different tool or an
unchecked PR box is not evidence that this Issue's acceptance condition passed.

## CI Boundary

`scripts/check_design_accessibility_audit.py` checks whether a UI change needs
this contract and whether the required PR fields contain non-placeholder
evidence. It cannot determine whether the plugin actually ran or whether a
design truly conforms to WCAG. The human reviewer remains responsible for
opening the evidence, confirming its review date/scope/states match the code,
and checking that the final plugin report—not a superseded first pass—was linked.
