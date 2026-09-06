# Google OAuth scope audit

Last reviewed: 2026-09-05 (JST)

Repository snapshot: `cec131dd5ea38735a453675d3bf5f5e4eecd06f6`

Tracking issue: [#4164](https://github.com/kanta13jp1/my_web_app/issues/4164)

## Result

The production Supabase Google authorization redirect requests exactly
`email profile`. The Flutter application adds no OAuth scopes, offline access,
or product API permissions. No Gmail, Google Calendar, Google Drive, or other
sensitive/restricted Google API scope was found in the runtime path.

No repository or live-request scope should be removed in this change. The
Google Cloud console is not represented as infrastructure as code, so its
configured Data Access list still requires an account-owner review. This audit
must not be treated as proof that the console is correctly configured.

## Current scope inventory

| Scope in the live request | Current technical use | Decision |
| --- | --- | --- |
| `email` | Supabase identifies and links the Google-authenticated account and exposes the verified account email as `User.email`, which is used by the current authentication and account flows. | Retain. This is the minimum identifier used by the Google sign-in flow. |
| `profile` | Google supplies the standard identity profile. The current MUSUBI profile bootstrap reads `full_name` from Supabase user metadata to seed the user's display name. Google bundles the name and picture claims in this standard scope; the application does not request a narrower Google name-only scope. | Retain while automatic display-name bootstrap is a current feature. Reassess if that bootstrap is removed. |

The live authorization URL did **not** contain `openid`. Google Cloud may still
show `openid` in the consent-screen Data Access configuration, as recommended
by Supabase for Google sign-in; console configuration and scopes present in an
individual authorization request are recorded separately in this audit.

## Repository evidence

Two runtime call sites initiate Google OAuth:

- `lib/services/landing_page_adapter.dart` for normal sign-in.
- `lib/services/account_lifecycle_service.dart` for account-deletion
  reauthentication.

Both call `signInWithOAuth(OAuthProvider.google, redirectTo: ...)`. Neither
passes `scopes` nor Google-specific `queryParams`. The repository also has:

- no direct `google_sign_in` or `googleapis` dependency in `pubspec.yaml`;
- no runtime read of a Google `providerToken` or provider refresh token;
- no `access_type=offline` or `prompt=consent` request in the runtime path; and
- no `[auth.external.google]` block in `supabase/config.toml`.

The last point means production Google-provider settings are dashboard-managed
and can drift from the repository.

### Calendar stub is not an OAuth grant

`enterprise-hub` currently returns the placeholder path
`/oauth/google-calendar` for `calendar.connect_url`, while
`GoogleCalendarSyncPage` discards that response and only displays a snackbar.
`calendar.sync` returns a scheduled message with zero synced records. There is
no Google Calendar authorization request, token persistence, or Calendar API
call behind this stub, so Calendar scopes are not part of the current OAuth
inventory. A future implementation must complete a new least-privilege review
before adding any Calendar scope.

Blog drafts, generated test mocks, Gemini API-key calls, and internal MCP scope
strings are not runtime Google user-data OAuth grants and were excluded from
the inventory.

## Production redirect observation

At 2026-09-05 19:08 JST, a redirect-disabled `GET` was sent to the public
Supabase authorize endpoint for each application callback below. No Google
credentials were submitted and no consent was granted.

| Application callback | HTTP result | Google request scope | Offline or forced consent |
| --- | --- | --- | --- |
| `https://my-web-app-b67f4.web.app/` | `302` to `accounts.google.com` | `email profile` | `access_type` absent; `prompt` absent |
| `https://my-web-app-b67f4.web.app/account-deletion` | `302` to `accounts.google.com` | `email profile` | `access_type` absent; `prompt` absent |

Reproduction method:

1. Request `https://smmkxxavexumewbfaqpy.supabase.co/auth/v1/authorize`
   with `provider=google` and one URL-encoded `redirect_to` value above.
2. Disable automatic redirects.
3. Confirm status `302`, destination host `accounts.google.com`, and inspect
   only `scope`, `access_type`, and `prompt` in the `Location` query.
4. Do not copy the OAuth client ID or the complete redirect URL into logs.

This observation proves the public request produced by the current Supabase
configuration at that time. It does not prove what additional scopes may be
listed but unused in Google Cloud.

## Google Cloud owner checklist

An owner of the production OAuth client must complete this section before the
tracking issue can be closed:

- [ ] Open **Google Auth Platform > Data Access** for the OAuth client used by
  production Supabase.
- [ ] Capture a timestamped, redacted screenshot or export of the current
  configured scope list. Do not expose the client secret.
- [ ] Confirm the list contains only the identity scopes documented by
  Supabase: `openid`, `.../auth/userinfo.email`, and
  `.../auth/userinfo.profile`.
- [ ] Remove every Gmail, Calendar, Drive, or other unused/future scope if any
  is present. Do not retain permissions "for future use."
- [ ] Save the configuration, then repeat the redirect observation for both
  callbacks and confirm it remains `email profile` with no offline access.
- [ ] In a credentialed production smoke test, verify normal Google sign-in
  and account-deletion reauthentication without unexpected re-consent.
- [ ] Attach the redacted evidence and result to issue #4164 for human security
  review.

If removing an unexpected console scope breaks a current flow, restore only
the previously recorded configuration needed to recover service, record the
exact failing flow, and open a security review before retaining that scope.

## Policy basis

- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)
  requires requesting only permissions critical to current features and not
  requesting access for possible future use.
- [Google OAuth 2.0 policy compliance](https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance)
  requires the narrowest scopes and accurate disclosure of their use.
- [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)
  distinguishes basic identity claims from additional Google product scopes.
- [Supabase Google Auth](https://supabase.com/docs/guides/auth/social-login/auth-google)
  documents `openid`, `userinfo.email`, and `userinfo.profile` as the Google
  consent-screen Data Access configuration for this sign-in integration.
