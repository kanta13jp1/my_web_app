# Google Play Data Safety Input

Issue: [#1495](https://github.com/kanta13jp1/my_web_app/issues/1495)
Source policy: [`assets/legal/privacy_policy.md`](../assets/legal/privacy_policy.md)
Last updated: 2026-05-07

This file is a copy-ready reference for the Google Play Console Data Safety form. It mirrors the public privacy policy and should be reviewed before store submission.

## Data Collected

| Play category | Examples in this app | Collection purpose | Shared with third parties |
|---------------|----------------------|--------------------|---------------------------|
| Personal info: name | Google OAuth display name | Account identification, WBS owner display | Yes, service providers only |
| Personal info: email address | Google OAuth email address | Authentication, account support | Yes, service providers only |
| User-generated content | Blog posts, WBS tasks, meal logs, horse-racing notes, comments | Core app functionality | Yes, infrastructure and AI processors when needed |
| App activity | Access time, screen transitions, operation logs | Security, abuse prevention, product improvement | Yes, hosting/analytics infrastructure only |
| Device or other IDs | Browser/device metadata, screen size, OS/browser type | Responsive behavior, diagnostics | Yes, hosting/diagnostic infrastructure only |
| Diagnostics | Crash/error data when crash reporting is active | Reliability and debugging | Yes, diagnostic infrastructure only |

## Data Not Collected

| Play category | Store answer |
|---------------|--------------|
| Location | Not collected |
| Contacts | Not collected |
| Photos and videos | Not collected for Phase 0 mobile release |
| Audio files | Not collected for Phase 0 mobile release |
| Calendar | Not collected |
| Health and fitness | Not collected as platform permission data for Phase 0 |
| Financial info | Not collected; the app does not process payments in Phase 0 |

## Security Practices

| Question | Answer |
|----------|--------|
| Is data encrypted in transit? | Yes. HTTPS/TLS is required. |
| Can users request deletion? | Yes. Users can request deletion through the GitHub issue support channel with `privacy/delete-request`; in-app deletion is Phase 1. |
| Is data shared for advertising? | No. Advertising cookies and third-party profiling sales are not used. |
| Is tracking used? | No. Tracking for third-party advertising is not used. |
| Is collection optional? | Core account and content data is required for authenticated app functionality. Optional analytics cookies are not introduced in Phase 0. |

## Third-Party Processing Notes

- Supabase: database, authentication, Edge Functions, storage.
- Google Firebase / Google Cloud: web hosting, access logs, Cloud Functions.
- Google OAuth: display name, email address, profile image URL.
- Anthropic / OpenAI / Google DeepMind or similar LLM providers: AI response generation for user-provided text when AI features are used.
- GitHub: support issue intake when users voluntarily submit support or deletion requests.
