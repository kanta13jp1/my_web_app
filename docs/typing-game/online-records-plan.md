# Typing records: prepared, not released

Base: `642937041e97901629efdad52c08a6ada55dee13` (English UI + IME fixes),
including the unmerged practice evolution PR #5992. English translates the UI;
all players still type the same 36 Japanese prompts in romaji.

## Behavior

Prompt exposure survives retries and mode changes while this screen is open.
Unseen prompts precede the least recently displayed prompts, with randomized ties.
A focused one-word practice intentionally repeats its only eligible word.
This history is in memory, not shared with the leaderboard and not retained on reload.

The online controls are disabled by default (`TYPING_ONLINE_RECORDS=false`).
An injected store allows isolated UI tests. No RPC runs on opening the game,
finishing a run, viewing results, or opening the records panel. A player must
choose private save, history load, leaderboard load or a publication action.
Saving never publishes. Publication has a separate alias/consent dialog;
withdrawal keeps private history and deletion removes both the run and its entry.
Unchanged retries use the same random run ID. Failed requests never say saved.
Account changes hide loaded data and invalidate in-flight responses.

The Supabase adapter calls `typing_game_records`; it is wired into the page
behind the rollout flag. The SQL draft is executable in a disposable PostgreSQL
fixture, but is deliberately outside `supabase/migrations`.

The server derives the owner from auth, rejects anonymous accounts, validates
JSON shape and bounds, computes `correct * 10 + words * 50`, rejects changed
payloads under an existing owner/run ID and serializes mutations per owner.
Private tables have RLS and no direct client grants. The public RPC is an
invoker wrapper; the narrowly scoped implementation has an empty search path
in an unexposed private schema. Rankings contain only chosen aliases and stats,
one best eligible 60-second challenge per account, at most 20 entries.
Practice and partial challenges cannot enter that board. Existing account names,
emails, metadata and auth UUIDs never become public aliases.

These are **self-reported results**. Server arithmetic and bounds do not prove
typing occurred, establish a trustworthy timer, prevent bots or verify a human.
No verified competitive claim is appropriate without server sessions/events.
No new analytics, keyboard telemetry, or external AI transmission is added.

## Working baseline and approval boundaries

The owner requested production deployment on 2026-11-05. The working baseline
is authenticated participants, a dedicated alias, explicit per-record
publication, a 90-day display window and at most 100 private history records.
This supersedes the previous stop-before-deploy scope for typing only. It does
not authorize new external AI disclosure or applying new production DB grants.

- Audience: authenticated participants only is a draft, not an approved choice.
  Anonymous public reading would require a separate review of RPC access and UI text.
- Alias: dedicated 3–24 ASCII characters is a conservative draft. Decide whether
  to support Japanese/Unicode, uniqueness and moderation/reporting before release.
- Public visibility is 90 days from the run timestamp. Private history has no
  time-based expiry. At 100 retained records, new saves are rejected; no old
  private record is automatically pruned. Deliberate owner deletion removes the
  run and its publication. Account deletion cascades into this feature's tables.
  Expired publications are hidden by a read filter, without deleting stored
  entries on access or by a scheduled task. Daily submission counters survive
  private-record deletion and are not purged by maintenance.
- Rate limits: 5 seconds between new saves, 100/day UTC, proposed not approved.
- Anti-cheat: choose between a casual self-reported board and a separately
  designed verified leaderboard. Current code implements only the former.

## Release boundaries

Production rollout is requested, subject to the following action-time approvals.
Review the policy decisions and SQL, generate a migration through Supabase CLI,
test on an isolated Supabase stack with real auth/RPC, verify non-destructive visibility expiry, and
obtain explicit human DB/security review before applying it. Enable the client
flag only after that reviewed rollout. The flag alone is not a security boundary;
the server grants and owner checks are the authorization boundary.

Reconcile #5992 before a new PR; do not duplicate its practice/catalog work or
release unrelated current main changes. The initial release workflow hardcodes
the original game PR and cannot be reused for this change without reviewed updates.
New diffs require separate permission before external AI review/PR creation.

## Validation and limits

Cloud validation tests prompt continuity, immutable reports, real RPC adapter
serialization with mock HTTP, opt-in UI/privacy and disposable PostgreSQL auth,
storage, reload, deduplication, authorization, publication and deletion.
Mock HTTP tests are not a real Supabase deployment. PostgreSQL auth fixtures
cannot prove PostgREST/JWT integration, anonymous-claim configuration, Supabase
advisors or production readiness. Real mobile OS IME, Safari and assistive
technology testing remain outstanding from the preserved input work.

The additional `test/integration/typing_records_supabase_test.dart` exercises
real GoTrue sessions and PostgREST on a disposable localhost-only Supabase stack.
It is explicitly skipped in ordinary tests lacking that stack. Its dedicated
cloud job must execute it (not skip it). Expiry changes visibility only. The test
checks that private history AND the expired public entry remain stored after
owner reads and ranking reads. There is no purge function or cron setup in this
proposal. No real-user account, production key or production DB is used by tests.

## Exact proposed permissions and non-destructive expiry (NOT APPLIED)

- Create only `typing_private.runs`, `typing_private.entries`, and
  `typing_private.budgets`. All have RLS. Revoke direct access from PUBLIC,
  anon, authenticated and service_role. Existing tables/policies are unchanged.
  The database administrator owns the new objects.
- Grant authenticated schema USAGE and EXECUTE on the public invoker RPC and
  private definer implementation. Both reject missing/anonymous identities.
  Owner identity is derived from `auth.uid()`, never from client parameters.
  The public-schema service_role default EXECUTE grant is explicitly revoked
  on the new RPC. No service-role key goes to the app.
- The 90-day rule is a query predicate on the original run timestamp. It hides
  old entries from the ranking and prevents re-publication outside that window.
  It does NOT delete the public entry, alias, private record or counters.
- No cron job, purge function, scheduled DELETE, extension enablement or global
  timezone change is included. Earlier proposed daily 03:17 UTC maintenance and
  earlier private-history deletion drafts are withdrawn, not approved or applied.
- Private history has no time-based expiry. At 100 records, new saves fail;
  old records are never silently pruned. Exact retries of an existing run still
  succeed, even when the history is full.
- A player may deliberately withdraw one public entry while keeping private
  history, or delete one private record and its associated entry. The UI asks
  for action-time confirmation, describes scope and lack of undo/recovery
  guarantee, and rechecks account identity after the dialog. The server enforces
  ownership on every action. Deleting an account cascades into these three
  feature-owned tables. No other account or record is affected.
- A future permanent cleanup proposal, if desired, requires its own exact SQL,
  affected-data description and fresh informed action-time approval.

Read-only production preflight on 2026-11-05 confirmed PostgreSQL 17,
pg_cron 1.6.4, cron timezone GMT, no typing_private schema and no matching job.
Those reads changed no rows, permissions or schedules. Cron is not used here.
