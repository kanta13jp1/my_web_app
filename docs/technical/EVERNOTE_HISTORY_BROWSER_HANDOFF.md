# Note history browser: paused implementation proposal

Parent: PR #5125, application base 4a57c8a54aefc2d2cc842c6affa5ea529657f957.
Branch: codex/evernote-history-browser-20260912.

This is a preserved, UNVALIDATED work-in-progress. The user requested source
export inventory assistance during implementation, so this commit does not
start CI or claim any release gate passed. No production change or personal
data is included.

## Proposed behavior

- Owner-scoped metadata-only keyset pages, with timestamp precision and UUID
  tie breaking; nullable legacy saved_at values remain reachable.
- Load only the selected body. Page imported attachment metadata too.
- Read-only selectable Markdown preview, avoiding automatic remote image/link
  requests. Display source tags, attachment metadata and verification status.
- Keep native title/body restoration, but fail closed when its pre-restore
  snapshot cannot be saved.
- Do not route imported Evernote versions through the legacy title/body-only
  restore path: it does not restore all attachment/tag evidence safely.

## Verification still required

New repository/controller/widget tests and editor backup-failure/success tests
are proposed. Run the existing Evernote cloud workflow on the exact branch SHA,
apply its reviewed formatter patch, then rerun after any changes. No local
Flutter/Dart, browser, dependency installation, ENEX parsing, or media processing
is permitted under the active resource gate.

Known review items: responsive large-text coverage, private history session
changes, authenticated RLS behavior, and rendered Design/accessibility review.
The parent passing CI does not validate this child revision.

## Remaining full-history work

Implement and verify transactional restore of title, content, tags and
attachment manifests with a pre-change snapshot, source lock enforcement,
concurrent-edit detection, and idempotent retries. Preserve archives and
migration evidence. Native attachment snapshot coverage, periodic snapshots,
history recovery export, and shared-history permission semantics also remain
unproven. This proposal is not complete Evernote parity.

## Source inventory handoff

A metadata-only search of the known export location and standard accessible
download/document/desktop locations found no additional exports beyond the
already known first batch. The all-notebook export inventory is still unknown.
Exact local paths and personal source names stay out of GitHub.

No merge, deployment, source deletion, subscription action, or personal-data
import is authorized until full migration verification and required reviews
are complete.
