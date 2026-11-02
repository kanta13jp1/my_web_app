# Supabase API keys and JWT signing-key rotation

This runbook keeps public Flutter configuration separate from server-only
credentials. Never paste a key value or JWT fragment into an Issue, pull
request, Actions summary, screenshot, source file, or command argument.

## Credential boundary

| Value | Exposure | Rule |
| --- | --- | --- |
| Project URL / reference ID | Public identifier | Inject per environment. Do not hardcode it, so isolation and rotation remain reviewable. |
| `sb_publishable_...` | Browser, Flutter, and mobile safe | RLS and application authorization protect data. Store as `SUPABASE_PUBLISHABLE_KEY_{DEV,STAGING,PROD}`. |
| Legacy `anon` JWT | Publishable-key compatibility only | Supported temporarily by the deploy fallback; migrate before Supabase's end-of-2026 deprecation. |
| `sb_secret_...` | Server only | Bypasses RLS. Never pass it to `--dart-define`, a browser, a URL, or a client log. |
| Legacy `service_role` JWT | Server only | Treat like a secret key and migrate each backend consumer. |
| JWT signing key | Auth infrastructure only | Managed separately from API keys; it signs user access tokens. |

Flutter Web embeds every `--dart-define` value in the downloadable bundle.
Only the project URL and a publishable/legacy anon key may enter the Flutter
build. `scripts/validate_flutter_supabase_env.py` blocks secret or service-role
values before build, and `scripts/check_flutter_supabase_config.py` blocks
source-code regressions without printing matched values.

## Rotate or migrate a publishable key

1. Create the replacement publishable key in the Supabase Dashboard.
2. Update only the target GitHub secret:
   `SUPABASE_PUBLISHABLE_KEY_DEV`, then `_STAGING`, then `_PROD`.
3. Deploy in that same order. Confirm Supabase initialization, anonymous RLS,
   sign-in, authenticated RLS, and Edge Function calls after each deployment.
4. Confirm every client uses the new key before disabling the old publishable
   key or legacy anon key.
5. Remove the workflow's `SUPABASE_ANON_KEY_*` fallback after all three primary
   publishable secrets have been deployed and verified.

Use `gh secret list` to verify names and presence only. Do not echo or decode a
stored value.

## Rotate a server secret key

1. Inventory every backend component that uses the affected key. Prefer a
   separate named secret key per component so future rotation has a small
   blast radius.
2. Create a replacement `sb_secret_...` key and update one server component at
   a time (GitHub secret, Supabase secret, or host secret store as applicable).
3. Verify the component with a minimal health/read query and its authorization
   boundary. Do not use a Flutter or browser client for this proof.
4. After every consumer is verified, delete the old key. Deletion is
   irreversible.
5. For a confirmed leak, shorten this sequence and delete the compromised key
   immediately after the replacement reaches critical consumers.

New Edge Function environments expose `SUPABASE_PUBLISHABLE_KEYS` and
`SUPABASE_SECRET_KEYS` as JSON objects. New API keys are not JWTs, so review the
`apikey` header, `verify_jwt` compatibility, and function-level authorization
before replacing a legacy bearer-JWT flow.

## Rotate a JWT signing key

1. Prefer an asymmetric signing key and create it in standby state.
2. Confirm custom JWT verifiers can retrieve and cache the project's JWKS.
3. Rotate so newly issued access tokens use the standby key.
4. Wait longer than the access-token lifetime plus verifier cache margin. For a
   one-hour token lifetime, Supabase's example minimum is 1 hour 15 minutes.
5. Revoke the previous signing key. In an active incident, revoke sooner and
   account for sign-outs and stale custom caches.

Before revoking the legacy JWT secret, migrate or disable legacy anon and
service-role keys. The legacy secret couples their signatures and can otherwise
invalidate clients unexpectedly.

## Evidence and rollback

Record only environment, key name, operator, time, affected components, deploy
run, and pass/fail result. A publishable-key rollback means restoring the prior
GitHub secret and redeploying while that key is still active. A deleted secret
key or revoked signing key cannot be restored; create a new key instead.

Official references:

- <https://supabase.com/docs/guides/api/api-keys>
- <https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys>
- <https://supabase.com/docs/guides/auth/signing-keys>
- <https://supabase.com/docs/guides/troubleshooting/rotating-anon-service-and-jwt-secrets-1Jq6yd>
