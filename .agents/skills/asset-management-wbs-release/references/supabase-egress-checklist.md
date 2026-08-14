# Supabase Egress Checklist

Use this checklist for every asset-management query, sync, evidence upload, or Storage delivery change. Record applicable decisions in the Issue or PR.

## Database Queries

- Select only columns used by the current view. Avoid `select('*')`, especially on rows containing long text or `jsonb` payloads.
- Fetch summaries for list views and load detail payloads only when the user opens the detail view.
- Paginate growing tables with a stable order and `.range()` or cursor/keyset pagination. Do not fetch an unbounded history or audit log.
- Request exact counts only when the UI needs them; exact counts can add database work and response bytes.
- Filter by authenticated `user_id`, `month_key`, status, and other indexed keys before transfer. Keep RLS enabled as defense in depth.
- Avoid returning full rows from inserts and updates. Request only required identifiers or no representation when the SDK permits it.
- Do not store screenshots or base64 image data in database columns. Store private Storage object metadata and verification results instead.
- Prefer small normalized metadata columns for list/filter operations. Load large `payload` JSON only for sync or detail operations.

## Fetch And Cache Behavior

- Reuse the existing repository/local cache before issuing a network request.
- Define freshness and invalidation rules. Invalidate only affected user/month/resource keys after a write.
- Deduplicate concurrent identical reads and prevent rebuilds from starting repeated fetches.
- Keep SharedPreferences/local state usable when Supabase is disabled, offline, or fails.
- For manual sync, preview before write and stop non-destructively on unresolved local/remote conflicts.
- Measure request count and transferred bytes during desktop reload, narrow viewport reload, manual sync, and evidence review.

## Storage Uploads

- Use private buckets with user-scoped paths and RLS policies. Never publish financial evidence by default.
- Enforce file count, MIME allowlist, and maximum byte size in both UI validation and Storage policy/configuration.
- Decode the image before acceptance and enforce safe dimensions. Reject malformed content even when the extension looks valid.
- Downscale or compress screenshots before upload when OCR and human review remain legible. Preserve the original only when an audit requirement needs it.
- Derive object names from stable IDs plus a content hash or version. Do not overwrite a cached URL with different bytes.
- Persist object path, byte size, MIME type, hash, created time, and verification state. Do not persist long-lived signed URLs.
- Delete replaced or obsolete evidence only through an explicit, user-scoped lifecycle action with an audit record.

## Storage Downloads

- List only metadata needed for the current account and page; paginate evidence histories.
- Lazy-load previews. Download the original only when the user or verification service opens it.
- Use short-lived signed URLs appropriate to the review flow. Do not regenerate them on every widget rebuild.
- Set a long `Cache-Control` lifetime only for immutable, content-versioned objects. Use shorter caching for mutable or sensitive delivery paths.
- Avoid embedding large base64 images in AI requests. Prefer a server-side, time-limited object fetch when the provider and threat model support it.
- Do not repeatedly send the same evidence to AI. Cache the verification result by object hash plus verifier/model/prompt version.

## Image Transformations And CDN

- Treat Supabase Image Transformations and paid CDN features as a cost gate, not an automatic optimization.
- Confirm project plan, regional availability, pricing, and transformation limits before enabling them.
- Keep the default path functional without paid transformations.
- If enabled, request bounded dimensions and quality, use stable transformation parameters, and measure cache-hit behavior.

## AI Verification Of Evidence

- OCR or vision output is advisory. Store extracted rate, confidence, evidence hash, model/provider version, and review time.
- Require human confirmation before an AI-extracted annual rate changes a financial calculation.
- Do not expose service-role keys or provider API keys to Flutter/Web clients; call providers through the approved server boundary.
- Use a deterministic Japanese system instruction for user-facing summaries. Preserve deterministic Dart amounts and safe fallback text when the provider fails or requires payment.
- Redact unrelated account numbers, names, and transaction details before sending evidence when possible.

## Proof Before Merge

Capture a before/after sample for the changed flow:

- Network request count.
- Response rows and selected columns.
- Transferred bytes and repeated-fetch count.
- Storage object bytes and preview/original download behavior.
- Cache behavior on reload.
- Failure behavior for offline, unauthorized, expired URL, oversized upload, unsupported MIME, and provider failure.
- Evidence that RLS prevents cross-user reads and writes.

If the optimization cannot be measured locally, document the staging metric or dashboard query that will prove it after deployment.
