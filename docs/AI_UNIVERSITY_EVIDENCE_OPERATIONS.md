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

The external course-review exporter currently selects only
`id,provider,title,source_url,is_active`. It must be updated separately before
the review skill can consume the five new fields. The repository audit accepts
and preserves those fields now, providing the intended integration contract.

## Official-source audit

`scripts/ai_university_source_audit.py` reads active catalog rows from a JSON
export, performs public GET requests only, and records the UTC check timestamp,
HTTP status, ETag, Last-Modified, SHA-256 body digest, change signals, evidence
completeness, and explicit recheck reasons. It never writes to Supabase or
calls a model/provider generation API.

The scheduled update downloads the preceding audit artifact as its baseline,
exports only IDs/providers/source URLs and evidence metadata (never course
title or content), and uploads the new JSON/Markdown audit for 30 days. If the
new evidence columns have not reached the database yet, the workflow falls
back to the legacy catalog projection and marks evidence incomplete.

## Anonymous reliability events

The client can insert only the fixed events `content_fetch_failed`,
`fallback_shown`, `retry_requested`, `retry_succeeded`, and `retry_failed`, with
the fixed surface `ai_university_content`. There are no user, session, URL,
exception, location, IP, content, or free-form columns, and clients have no
read permission. Analytics failures are intentionally no-op.

Because anonymous inserts can be spammed, these counts are directional
operational signals rather than billing-grade truth. Monitor volume and add an
edge rate limit or aggregate RPC before using them for automated decisions.
