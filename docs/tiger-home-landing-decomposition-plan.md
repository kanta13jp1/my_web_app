# Home and landing page decomposition plan

Tracking: Refs #4744. This addresses only the staged decomposition plan finding.
The parent Issue remains open for demand, conversion, retention, economics,
portfolio evidence, comparative outcomes, and data handling review.

## Baseline and first boundary

The review's historical line counts are not current measurements. Before each
extraction, record the exact main SHA, page line count, existing tests and route
count in the PR. Do not present code reduction as evidence of customer value.
Home currently combines calendar range calculation, cashflow loading, task
loading, month selection and day rendering. Start with calendar date/range
calculation: it has a smaller observable boundary than an entire page rewrite.

## Sequence and acceptance gates

1. Extract calendar date/range calculation into a pure module. Preserve month
   boundaries, leap days, week alignment and the existing clock/timezone
   convention. Cloud unit tests compare old and new outputs for these cases.
2. Extract calendar display widgets with immutable input and callbacks. Keep
   selection and loading ownership in Home until behavior is equivalent.
   Cloud widget tests cover selected date, empty/error/loading states, month
   navigation and accessibility labels. Do not add new network requests.
3. Extract calendar data composition behind the existing loading contract.
   Preserve user scoping, ordering, totals and error handling. Prove request
   counts and resulting day data are unchanged with deterministic fixtures.
4. Apply the same pattern to the next independent Home section, then Landing:
   pure calculations, display widgets, and finally data orchestration. Choose
   one section per PR after inspecting its dependencies and existing coverage.

Each PR records moved responsibilities, the exact pushed SHA, cloud CI results,
behavior checks and remaining coupling. Keep PRs independently revertible.
If a boundary cannot fit the authorized bounded edit limit, split the work
before editing; do not raise the limit implicitly. No schema, RLS, billing,
authentication, legal text or public route change belongs in an extraction.

## Portfolio decisions remain evidence dependent

Do not hide or delete routes based on source size. For any future consolidation,
collect anonymous reach, first-value, D7/D30 retention and paid contribution
with numerator, denominator and observation period. Define the selected
segment, minimum usable sample, observation window and decision owner before
interpreting the measurements. Missing or small samples mean insufficient
evidence, rather than zero value. Route retirement needs an explicit decision
and migration path for current users.

## Completion and re-review

Publishing this plan completes neither the extractions nor the quality loop.
After each extraction merges and deployment is verified, re-review the original
finding against the recorded boundary and behavior gates. Store the PR, merge
SHA, cloud run and re-review result in the parent Issue's evidence chain.
Only measured portfolio decisions and verified staged extractions can close
the full maintenance-cost finding; the other Issue findings remain separate.
