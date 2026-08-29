# AI University evidence and content reliability operations

Issue #4738 adds two independent, backward-compatible contracts.

## Course evidence

`ai_university_content` may now carry these nullable fields:

- `target_audience`
- `observable_learning_outcome`
- `assessment_verification_method`
- `evidence_source_url`
- `evidence_verified_at`

Legacy rows remain valid with all five values `NULL`. New evidence must be
complete and attributed: the database accepts either all five fields or none.
No migration backfill invents evidence for existing content.

The repository-external course-review exporter must select the five base fields
and all five evidence fields. The installed canonical exporter now emits
schema version 2 with the complete projection and an `evidence_complete`
all-or-none flag. Its focused tests and a production public-API export passed on
2026-08-29. Because that exporter is distributed outside this repository, other
installed environments must adopt the same projection independently.

`scripts/ai_university_export_contract.py` is the executable v1 integration
contract. It accepts a raw JSON array or the external exporter's schema-version-2
catalog envelope; either form contains rows with all ten base and evidence
keys. Legacy rows are valid only when all five evidence values are
`NULL`; evidence is otherwise complete, nonblank, HTTPS-attributed, and carries
a timezone-aware verification timestamp. The database length limits are also
enforced. This validates transport and completeness, not whether the prose is
true.

The exporter repository should add this repository's validator to its fixture
or integration test after expanding its projection:

```powershell
python scripts/ai_university_export_contract.py course-export.json `
  --output-json export-contract.json `
  --output-md export-contract.md
```

The scheduled source-audit job runs the same contract against its read-only
catalog projection. There is no legacy projection fallback now that migration
`20260824135127` is deployed: a projection or contract failure is visible while
the content-update job remains separate, and successful checks publish a
contract artifact.

## Official-source audit

`scripts/ai_university_source_audit.py` reads active catalog rows from a JSON
export, performs public GET requests only, and records the UTC check timestamp,
HTTP status, ETag, Last-Modified, SHA-256 body digest, change signals, evidence
completeness, and explicit recheck reasons. It never writes to Supabase or
calls a model/provider generation API.

The scheduled update downloads the preceding audit artifact as its baseline,
uses a transient catalog export, and uploads the sanitized JSON/Markdown audit
for 30 days. The audit report never contains course title or content; title is
present only in the transient input required by the exporter contract check.

This automation never writes course evidence. The selected 01.AI/Yi model-list
row (`22befb67-6147-4a4b-999c-ee1ad6fa9615`) was remediated separately by
PR #4983 and migration `20260829093000`, with its evidence verified against
`https://platform.01.ai/docs` on 2026-08-29. A read-only production public-API
export on that date found 1,079 active rows, 534 reviewable courses, three
evidence-complete courses, and 531 legacy all-NULL courses. The selected 01.AI
row was evidence-complete. This is a point-in-time operations snapshot, not a
requirement to infer evidence for the remaining legacy rows.

## Anonymous reliability events

The client can insert only the fixed events `content_fetch_failed`,
`fallback_shown`, `retry_requested`, `retry_succeeded`, and `retry_failed`, with
the fixed surface `ai_university_content`. There are no user, session, URL,
exception, location, IP, content, or free-form columns, and clients have no
read permission. Analytics failures are intentionally no-op.

Because anonymous inserts can be spammed, these counts are directional
operational signals rather than billing-grade truth. Monitor volume and add an
edge rate limit or aggregate RPC before using them for automated decisions.

`scripts/ai_university_reliability_metrics.py` now provides the reproducible
measurement layer. The scheduled source-audit runner also exports the last 30 days of the
five allowlisted event names, detects a truncated PostgREST range, and publishes
counts plus these descriptive ratios without starting an additional runner:

- fallbacks per content-fetch failure;
- retry successes divided by terminal retry outcomes;
- terminal retry outcomes per retry request.

Zero denominators render as `n/a`. Ratios can exceed 100% because events are
anonymous, uncorrelated counters and may be duplicated or spammed. Every report
therefore sets `threshold_evaluation.status` to `not_configured` and forbids an
automated decision. Choosing a minimum sample size, alert window, target
audience, failure/retry/fallback thresholds, and dashboard owner remains a
product/operations decision after representative production usage exists.
