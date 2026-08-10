# Kokumin election intelligence

The election dashboard uses one versioned contract for local, House of
Representatives, and House of Councillors data. Only the local collector is
active today; the two national modes are registered without invented targets.

## Data flow

1. `kokumin-election-intelligence-update.yml` downloads the party's official
   local-election PDF every six hours.
2. `scripts/update_kokumin_local_endorsements.py` extracts endorsement counts,
   checks the 現/元/新 totals, applies parser-collapse and large-drop gates, and
   generates both `assets/data/kokumin_local_endorsements.json` and the Flutter
   offline fallback `lib/data/dpj_official_endorsements.dart` from the same
   canonical snapshot.
3. `local-election-snapshot-queue.yml` invokes the Edge Function every six
   hours. The function loads the generated endorsement asset and
   `kokumin_election_modes.json`, then re-fetches each official goal source and
   verifies its configured evidence terms.
4. Complete snapshots are content-addressed and stored in history. Goal,
   achievement, endorsement, member, candidate, and schedule changes create
   separate human-approval post candidates; nothing is auto-published.
5. Flutter reads the same `electionIntelligence` payload. The official
   endorsement repository resolves live values or the generated fallback as a
   single source of truth; a `ChangeNotifier` ViewModel exposes that snapshot
   to the dashboard, while sharing and metadata use the same repository.

If a required asset or official goal source cannot be fetched or validated,
the public endpoint may return its last-known fallback, but persistence is
blocked so a transient outage cannot create a false zero or removal diff.

## Local verification

```powershell
python -m pip install -r scripts/requirements-election-intelligence.txt
python test/scripts/update_kokumin_local_endorsements_test.py
python scripts/update_kokumin_local_endorsements.py
deno test supabase/functions/local-election-intelligence/election_mode_test.ts supabase/functions/local-election-intelligence/snapshot_history_test.ts
flutter test test/models/election_intelligence_test.dart test/services/local_election_reality_service_test.dart test/services/local_election_share_service_test.dart
```

## Activating a future mode

Do not change a national mode from `registered` to `active` until all of the
following exist:

- an official candidate/result collector for that mode;
- at least one official source contract for every displayed numeric target;
- collection-quality gates that preserve the last valid snapshot on failure;
- canonical history and diff tests for its goals, candidates, and results;
- Flutter rendering and sharing tests for the mode.

After those checks, set the mode's `availability` to `active` in
`assets/data/kokumin_election_modes.json`. The UI already renders all
registered modes and only enables active ones.
