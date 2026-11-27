# Comparison Evidence & CTA Telemetry Spec (`#4725`)

## 1. Evidence Citation & Filtering

- Every comparison claim is parsed through
  `CompetitorClaimEvidence.tryFromJson`, which requires:
  - Non-empty `competitor_id`, `claim_key`, valid `claim_type`, and `claim_text`.
  - Valid HTTP/HTTPS `source_url` with a non-empty host.
  - Valid `verified_at` timestamp (`YYYY-MM-DD`).
- Claims missing a valid source URL or verified date are filtered out (`null`)
  and never displayed as unverified claims (`ComparisonEvidenceSection` renders
  `comparison-evidence-unavailable` when unavailable).

## 2. CTA Touch Measurement & Missing-Data Handling

- `ComparisonPage` records arrival via `touchRecorder(competitorKey)` (default:
  `GrowthAcquisitionService.recordComparisonTouch`).
- `ComparisonCtaPanel` accepts `onPrimaryCtaTap` and `onSecondaryCtaTap`
  callbacks, wired by `ComparisonPage` to record
  `'<competitorKey>:primary_cta'` and `'<competitorKey>:secondary_cta'`.
- Telemetry callbacks execute fail-open (`unawaited(...catchError((_) {}))`) so
  missing network/telemetry never blocks navigation to `/` or `/import`.
