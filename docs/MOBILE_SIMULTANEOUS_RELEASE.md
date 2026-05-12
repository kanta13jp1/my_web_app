# iOS / Android Simultaneous Release Runbook

Issue: https://github.com/kanta13jp1/my_web_app/issues/1495

## Scope

Codex #1 owns the deterministic build and release automation in the current
two-instance flow. Any older multi-Codex ownership notes are absorbed into
Codex #1. Claude Code keeps store policy, product gates, review conditions, and
final go/no-go ownership.

## Current App Metadata

| Item | Value |
| --- | --- |
| App display name | 自分株式会社 |
| Android applicationId / namespace | `jp.kanta13.jibun` |
| iOS bundle identifier | `jp.kanta13.jibun` |
| Flutter build workflow | `.github/workflows/mobile-release-build.yml` |
| Distribution readiness gate | `.github/workflows/mobile-distribution-readiness.yml` |
| Native CI entrypoint | `lib/main_mobile.dart` |
| Metadata gate | `python scripts/check_mobile_release_readiness.py` |
| Distribution gate | `python scripts/check_mobile_distribution_readiness.py` |

Do not upload to either store until the bundle identifiers are confirmed as the
final public identifiers. Changing them after a first store upload is painful or
impossible.

## GitHub Actions

Manual build:

```powershell
gh workflow run mobile-release-build.yml `
  -f platform=all `
  -f build_name=1.0.0 `
  -f build_number=1 `
  -f publish_release=false
```

Android-only build while iOS native route split is pending:

```powershell
gh workflow run mobile-release-build.yml `
  -f platform=android `
  -f build_name=1.0.0 `
  -f build_number=1 `
  -f publish_release=false
```

Release build:

```powershell
git tag mobile-v1.0.0
git push origin mobile-v1.0.0
```

Distribution readiness report:

```powershell
gh workflow run mobile-distribution-readiness.yml `
  -f platform=all `
  -f require_distribution_secrets=false
```

Strict pre-distribution gate after secrets are configured:

```powershell
gh workflow run mobile-distribution-readiness.yml `
  -f platform=all `
  -f require_distribution_secrets=true
```

The non-strict gate is allowed to warn when signing/store secrets are missing.
The strict gate fails on missing secrets and should be green before Play
Internal testing or TestFlight upload. The workflow writes a
`mobile-distribution-readiness-report` artifact with only boolean secret
presence, never secret values.

Artifacts:

- Android AAB: `jibun-android-release.aab`
- iOS simulator CI app bundle zip: `jibun-ios-runner-simulator-debug.zip`

The first native build intentionally uses `lib/main_mobile.dart` instead of the
full Flutter Web entrypoint. This keeps `package:web`, JS interop, OGP sharing,
and browser-only dashboards out of the Android/iOS route graph while the full
web app remains unchanged. Move features into the native shell only after their
imports are conditional or platform-neutral.

The Android artifact is Play-upload ready only when the Android signing secrets
are configured. Without those secrets, the workflow deliberately falls back to a
debug-signed release artifact for build verification only. The iOS artifact is
a simulator debug build that proves the Flutter/Xcode build path without Apple
Developer credentials. A TestFlight-ready IPA still needs Apple Developer team,
provisioning profile, certificate, and App Store Connect API key.

## Required Secrets Before Store Distribution

Android / Google Play:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

iOS / TestFlight:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8`
- `IOS_SIGNING_CERTIFICATE_BASE64`
- `IOS_SIGNING_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- Or a Fastlane Match equivalent documented in the same strict gate report

## Release Checklist

- [ ] Confirm final Android applicationId and iOS bundle identifier.
- [ ] Confirm app display name, icon, splash, screenshots, and store category.
- [ ] Run `python scripts/check_mobile_release_readiness.py`.
- [ ] Run `python scripts/check_mobile_distribution_readiness.py --platform all`.
- [ ] Run Android AAB workflow and keep the artifact.
- [ ] Run iOS simulator CI workflow and keep the artifact.
- [ ] Run `mobile-distribution-readiness.yml` with `require_distribution_secrets=true`.
- [ ] Configure Android signing and Google Play internal testing upload.
- [ ] Configure iOS signing and TestFlight upload.
- [ ] Verify Supabase redirect URLs, Google login, deep links, and notification permissions.
- [ ] Create a shared release note for both platforms.
- [ ] Gate release on both platforms passing the same product smoke checklist.

## Known Blockers / Handoff

- Local Windows validation cannot run Android builds until `ANDROID_HOME` points
  to an installed Android SDK.
- The iOS workflow currently creates a simulator debug artifact so CI can prove
  the Flutter/Xcode build without Apple signing material. TestFlight upload
  needs Apple signing material and should be wired after the developer account
  values are confirmed.
- If the full `lib/main.dart` mobile build fails in GitHub Actions because of
  web-only imports, route the code split to Codex #1. Codex #1 should keep the
  workflow green by adding a mobile-safe target only after Claude Code confirms
  the product surface for the first app release.
- Web-only features parked for the first mobile artifact: browser OGP sharing,
  desktop cleanup, rich web dashboards, audio/media JS interop tools, and pages
  that directly import `package:web` or `dart:js_interop`.

## Automation Follow-up

The session-start AI tooling watch on 2026-05-01 still points new Codex and
Claude Code changes into `codex-runtime`, `hooks`, `integration`,
`quality-cost`, and `schedule`. For mobile release work, the nearest automation
hooks are:

- scheduled mobile build smoke after metadata/signing is stable,
- strict distribution readiness report after signing/store secrets are present,
- automatic issue update when `mobile-release-build.yml` fails,
- release-tag workflow that publishes both platform artifacts from one tag,
- mobile UAT task generation for the dedicated mobile instance.
