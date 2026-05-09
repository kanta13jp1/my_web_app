# External API Retry Policy

Codex #1 implements this policy for WBS #1308.

## Scope

External calls from Supabase Edge Functions should use
`supabase/functions/_shared/external_fetch.ts` when the target is an external
API such as Qiita, dev.to, Notion, RSS sources, or an internal hub reached over
HTTP.

## Behavior

- Timeout: default 30 seconds per attempt.
- Retry: default 3 retries, for 4 total attempts.
- Backoff: exponential delay starting at 500 ms.
- Retryable failures: timeout, network failure, HTTP 408, 429, 500, 502, 503,
  and 504.
- Non-retryable 4xx responses are returned to the caller without retry.
- On retry exhaustion, the helper logs a JSON `ERROR` event with timestamp,
  target API, status, attempts, error type, and optional trace id.

## User Message

Callers should return this message for temporary external failures:

`一時的な通信エラーが発生しました。時間をおいて再度お試しください。`

`schedule-hub` now maps exhausted external failures to HTTP 503 with
`user_message` and per-platform result payloads for blog publishing flows.

## 2-Instance Operating Rule

- Codex Windows owns implementation, Edge Function hardening, GitHub Actions,
  and tests.
- Claude Code Windows owns design/spec/UI planning tasks and keeps WBS routing
  current.
- New external integrations should first add the shared retry wrapper, then
  wire target-specific behavior in the owning hub.
