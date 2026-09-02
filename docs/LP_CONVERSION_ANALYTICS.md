# LP Conversion Analytics

The landing page keeps Supabase as the source of truth for experiment events,
LP views, and completed registrations. `LandingConversionAnalytics` mirrors the
same anonymous experiment event to PostHog when a production token is present.

## Production Configuration

Add `POSTHOG_PROJECT_TOKEN` as a GitHub Actions repository secret. Optionally
set the `POSTHOG_HOST` repository variable for EU Cloud or self-hosting. The
default host is `https://us.i.posthog.com`.

```bash
flutter build web \
  --dart-define=POSTHOG_PROJECT_TOKEN=phc_xxx \
  --dart-define=POSTHOG_HOST=https://us.i.posthog.com
```

An absent token, blocked script, or PostHog outage makes the adapter a no-op.
It does not block the LP, authentication, or Supabase measurement.

## Event Model

PostHog receives one event, `landing_conversion_stage`. Its generated fields
are `hypothesis_id`, `variant`, and `stage`, parsed from the validated existing
`lp_exp_hXX_{control|treatment}_{stage}` event key. Supported stages are owned
by `LandingConversionExperimentService`.

Only these optional properties can pass through the adapter:

- `path`
- `viewport`
- `utm_source`
- `utm_medium`
- `utm_campaign`
- `referral_present`

Email, visitor UUID, user ID, prompt text, proposed tasks, and arbitrary
properties are never sent. Autocapture, automatic page views, page leaves,
session replay, surveys, lifecycle capture, push capture, feature-flag events,
and person profiles are disabled. The app never calls `identify`.

## Analysis

Build funnels with the same hypothesis and variant filters. Use
`signup_complete` as the outcome, segment mobile and desktop separately, and
confirm the result against Supabase before selecting a winning treatment.
