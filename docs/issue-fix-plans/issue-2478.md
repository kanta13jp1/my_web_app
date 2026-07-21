# Issue #2478: Daily anomaly scan cron

## Scope

- Run at 03:00 JST every day when `DAILY_ANOMALY_SCAN_ENABLED=true`.
- Discover eligible users through Supabase Auth Admin.
- Invoke `asset.anomaly.detect.scheduled` once per eligible user.
- Retry transient failures and notify configured Slack/Discord webhooks.
- Keep AI explanations controlled by the existing Edge Function flag.

## Safety decisions

- The scheduled action requires an exact service-role bearer token and a valid
  user UUID. The existing user-authenticated action remains unchanged.
- Deleted, currently banned, anonymous, and malformed Auth users are skipped.
- Scheduled execution is OFF by default. Manual all-user execution requires an
  explicit confirmation input; a single-user manual run does not.
- Reports expose hashed user references instead of raw user UUIDs.

## Validation

- `python scripts/daily_anomaly_scan_test.py`
- `deno fmt --check supabase/functions/ai-hub/anomaly_detection.ts supabase/functions/ai-hub/anomaly_detection_test.ts supabase/functions/ai-hub/index.ts`
- `deno test supabase/functions/ai-hub/anomaly_detection_test.ts`
- GitHub Actions workflow syntax and repository quality gates

## Rollout

1. Merge and deploy `ai-hub` with the scheduled action.
2. Manually scan one test user with `user_id` and verify the artifact.
3. Manually scan all users with `confirm_all_users=true`.
4. Set repository variable `DAILY_ANOMALY_SCAN_ENABLED=true`.
