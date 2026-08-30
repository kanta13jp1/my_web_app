# Video artifact loop contract

## Tables

| Table | Purpose | Browser access |
|---|---|---|
| `video_generation_jobs` | Paid job, status, output path, and improvement lineage | Owner select only |
| `video_artifacts` | Durable immutable original plus commercialization readiness | Owner select only |
| `video_artifact_reviews` | Append-only owner evaluation and suggested next prompt | Owner select only |
| `video_artifact_events` | Append-only capture, review, improvement, and product evidence | Owner select only |
| `video_improvement_authorizations` | Expiry, credit/iteration ceilings, confirmations, and remaining recurring authority | Owner select only |

Artifact, review, and event mutations use service-role RPCs behind the
authenticated Edge Function. Never expose the service role to Flutter or the
GPU worker container.

## Core transitions

```text
succeeded job
  -> captured / review_required / review_required / sale_candidate

review keep|improve + both checks clear
  -> productizing / allowed / cleared / sale_candidate

review reject OR any blocked clearance
  -> blocked / ... / ... / blocked

separate product workflow with explicit approval
  -> draft_product -> listed
```

The four values after an arrow are:
`lifecycle_stage / rights_status / privacy_status / commerce_status`.

## Lineage

For an improved generation:

- `video_generation_jobs.parent_artifact_id` identifies the reviewed source.
- `video_generation_jobs.applied_review_id` identifies the exact feedback.
- `video_generation_jobs.authorization_id` identifies the bounded envelope
  consumed for an authorized child job.
- The resulting `video_artifacts.parent_artifact_id` carries the relationship
  into the new immutable artifact.
- `video_artifact_events` records `improvement_applied` with the child job ID.

The review action never reserves credits. Manual create uses the normal
reservation path. The authorization form uses
`video_authorize_and_reserve_improvement`, which creates the envelope and first
linked job atomically; later iterations use
`video_reserve_authorized_improvement` for an exact unconsumed review in the
same artifact lineage.

## Output provenance

The GPU worker computes SHA-256 and the local file size after validating the
MP4. The worker Edge Function compares the reported size with private Storage
metadata before completion, then enriches the artifact. The original trigger
allows initially missing size/digest to be filled once, but prevents later
changes.
