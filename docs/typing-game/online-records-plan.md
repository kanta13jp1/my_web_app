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
  Expired publications are filtered and removed on owner access or by the
  proposed administrator maintenance job. Daily submission counters survive
  private-record deletion and are not purged by maintenance.
- Rate limits: 5 seconds between new saves, 100/day UTC, proposed not approved.
- Anti-cheat: choose between a casual self-reported board and a separately
  designed verified leaderboard. Current code implements only the former.

## Release boundaries

Production rollout is requested, subject to the following action-time approvals.
Review the policy decisions and SQL, generate a migration through Supabase CLI,
test on an isolated Supabase stack with real auth/RPC, configure expiry, and
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
cloud job must execute it (not skip it). The draft maintenance function has no
client grants and removes only expired publication entries, including for
inactive accounts. It does not delete private runs or counters. Proposed
scheduling is a daily privileged job; installation is still pending review.
No real-user account, production key or production database is used by this test.

## Exact proposed DB privileges and maintenance (NOT APPLIED)

- Create only `typing_private.runs`, `typing_private.entries`, and
  `typing_private.budgets`. All have RLS. Revoke direct table access from PUBLIC,
  anon and authenticated. Existing application tables/policies are not altered.
- Grant authenticated schema USAGE and EXECUTE on the public invoker RPC and
  its private definer implementation. Both entry points reject missing or
  anonymous identities; ownership comes from `auth.uid()`, never a parameter.
- No grant to anon. No client EXECUTE on maintenance. No client service-role
  credential. Rankings return only deliberate aliases and four score fields.
- Run the proposed maintenance job daily at **03:17 UTC (12:17 JST)** as the
  database administrator, only after verifying cron's configured timezone is
  UTC/GMT and that no job of this name exists. Do not change global timezone,
  enable an extension, or replace an existing job automatically.
- Command: `select typing_private.purge_expired_publications();` removes only
  entries whose matching run was created at least 90 days ago. `runs` and
  `budgets` survive. Rank reads already hide expired entries, so delayed cron
  execution cannot extend visibility.
- This physically removes public aliases/entry associations and has no undo
  button. It does not erase private scores. The user may delete a private run
  deliberately (irreversible here), which also removes its public entry.
  Deleting the account removes all three feature-owned tables' rows via FK
  cascades. No backup/PITR recovery guarantee is made.
- To stop future maintenance, the administrator can unschedule this named job.
  Unscheduling does not restore already removed publication entries.

After explicit approval, and only if the above preflight passes:

```sql
select cron.schedule(
  'typing-expired-publications-v1',
  '17 3 * * *',
  'select typing_private.purge_expired_publications();'
);
```

This proposal supersedes the earlier draft that deleted private runs after 90
days or pruned them on save. Neither older behavior was approved or applied.
