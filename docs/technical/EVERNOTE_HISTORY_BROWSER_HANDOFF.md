# Note history browser: implementation proposal

Parent: PR #5125, application base 4a57c8a54aefc2d2cc842c6affa5ea529657f957.
Branch: codex/evernote-history-browser-20260912.

Implementation and tests are under cloud validation, not released. No production
change or personal data is included. The initial WIP was preserved while the
user requested source-export inventory assistance; validation resumed afterward.

## Implemented proposal

- Owner-scoped metadata-only keyset pages, with database timestamp precision and
  UUID tie breaking; nullable legacy saved_at values remain reachable.
- Load only the selected body. Page imported attachment metadata too and lazily
  build attachment rows, rather than expanding every row into widgets at once.
- Read-only selectable Markdown preview avoids automatic remote image/link
  requests. Source tags, attachment metadata and verification status are shown.
- Native title/body restoration aborts when its pre-restore snapshot fails or
  when local text/account state changes while awaiting that snapshot. A modal
  cancellation notice cannot be delayed behind unrelated queued snackbars.
- Imported Evernote versions cannot use the legacy title/body-only restore path:
  it does not restore all attachment/tag evidence safely.

## Validation evidence and remaining gates

- [Initial validation](https://github.com/kanta13jp1/my_web_app/actions/runs/34672652834):
  strict test-code lint findings; disposable PostgreSQL contracts passed.
- [Revision 107f483](https://github.com/kanta13jp1/my_web_app/actions/runs/34672944157):
  zero analyzer issues, 178 tests passed and 9 failed. All seven history sheet
  tests passed, including 31st-version access, retries, read-only source preview,
  320/1280 widths and 2x text. One cloud formatter change remained.
- The eight HTTP-fixture failures were traced to postgrest 2.7.1 dereferencing
  response.request in its response parser. Mock responses now retain the
  originating request. Subsequent runs passed those HTTP tests (186/187 total).
- [Cancellation diagnostic](https://github.com/kanta13jp1/my_web_app/actions/runs/34673644913)
  confirmed that the pre-restore snapshot completed and the draft was preserved,
  but its cancellation snackbar was queued behind an earlier attachment error.
  The result is now a dialog. The regression explicitly displays an unrelated
  long-duration snackbar and still requires an immediate cancellation dialog,
  unchanged draft and no historical-body update.
- The corrected revision must pass the exact-SHA cloud workflow before approval.
  PR evidence records the newest run; prior parent checks do not validate this
  child revision.

No local Flutter/Dart, browser, dependency installation, ENEX parsing or media
processing is permitted under the active resource gate. Review still requires
authenticated RLS/import flows, rendered Design/accessibility evidence and human
acknowledgement. No schema or RLS policy is changed in this child branch.

## Remaining full-history work

Implement and verify transactional restore of title, content, tags and
attachment manifests with a pre-change snapshot, source lock enforcement,
concurrent-edit detection and idempotent retries. Serialize in-flight autosaves
and restores; the local draft-change guard is not a database transaction or
cross-device conflict guarantee. Preserve archives and migration evidence.
Native attachment snapshot coverage, periodic snapshots, history recovery
export and shared-history permission semantics remain unproven. This proposal
does not establish complete Evernote parity.

## Source inventory handoff

A metadata-only search of the known export location and standard accessible
download/document/desktop locations found no additional exports beyond the
already known first batch. The all-notebook export inventory is still unknown.
Exact local paths and personal source names stay out of GitHub.

No merge, deployment, source deletion, subscription action or personal-data
import is authorized until full migration verification and required reviews
are complete.
