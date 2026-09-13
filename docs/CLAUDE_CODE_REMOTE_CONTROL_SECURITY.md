# Claude Code Remote Control security decision

Last reviewed: 2026-09-03 JST

Owner: repository owner + organization security/legal owner

Status: **not approved or enabled by this repository**

## Executive summary

Remote Control can expose a local Claude Code session to the same user's
Claude web or mobile account without opening an inbound port. Execution and
filesystem access remain local, but Anthropic stores the synchronized session
transcript, responses, and tool activity while the connection is active.

The repository must not turn Remote Control on for a user or organization.
An organization Owner may enable it only after confirming the data-retention
and contract requirements below. Zero Data Retention organizations cannot use
Remote Control, and Anthropic's current BAA documentation does not cover it.

## Security findings

### RC-01 — High — Enabling before compliance review can violate policy

The previous session check treated a missing auto-connect setting as a task to
enable it. That is not a safe default: Remote Control stores synchronized
session content with Anthropic and is unavailable to Zero Data Retention
organizations. For regulated data, the organization must also confirm whether
its applicable contract covers the feature.

Remediation: `scripts/codex_session_check.py` now reports
`owner-security-review-required` and never treats local detection as approval.

### RC-02 — High — The official setting was not detected

The official user or managed setting is `remoteControlAtStartup`. The previous
heuristic looked for words such as `enable` or `all sessions`, so it could miss
an enabled official setting and produce a false-negative audit.

Remediation: the exact official setting is detected and covered by a regression
test. A checked-in project setting can disable auto-connect, but cannot enable
it for every developer.

### RC-03 — Medium — Local inspection cannot prove organization eligibility

Repository files cannot prove the Team/Enterprise Owner toggle, OAuth account,
data-retention agreement, Trusted Devices state, or successful connection from
a second device. They also cannot prove that a previously running session was
protected after Trusted Devices was enabled.

Remediation: keep the live enablement and second-device test as an explicit
human review gate. Record only pass/fail evidence; do not store account tokens,
session URLs, QR codes, device credentials, or screenshots containing them.

## Required decision checklist

The organization Owner and security/legal owner must record all answers before
enabling Remote Control:

- [ ] The account uses an eligible Pro, Max, Team, or Enterprise subscription
  and signs in through `claude.ai` OAuth; API keys are not used.
- [ ] The organization is not subject to Zero Data Retention for this workflow.
- [ ] The applicable data-retention terms and contract/BAA coverage are
  acceptable for repository prompts, responses, and tool activity.
- [ ] The local session cannot access production service-role credentials,
  customer exports, PHI, payment data, or unrelated personal files.
- [ ] Team/Enterprise: an Owner enabled the admin toggle at
  `https://claude.ai/admin-settings/claude-code`.
- [ ] Team/Enterprise: Require Trusted Devices is enabled where supported, all
  intended devices are enrolled, and lost-device/sign-out-everywhere recovery
  has been tested.
- [ ] Organization privacy controls such as `DO_NOT_TRACK` or
  `DISABLE_TELEMETRY` are not removed merely to make Remote Control work.
- [ ] Custom endpoints, Bedrock, Google Cloud's Agent Platform, Microsoft
  Foundry, and non-Anthropic gateways are not in use for the test session.
- [ ] A bounded test confirms connection, disconnect, device revocation, and
  session termination without exposing a secret or changing production state.

Any unchecked item means **do not enable**.

## Bounded verification procedure

1. Run `python scripts/codex_session_check.py --json`. Review blocker names;
   environment values are intentionally redacted.
2. Use a clean test repository containing no secrets or customer data.
3. Run `claude`, then `/login`, and complete the eligible `claude.ai` OAuth
   flow. Do not paste or persist tokens in repository files.
4. Team/Enterprise only: have an Owner enable Remote Control and Require Trusted
   Devices. Start a new session after the Trusted Devices change because the
   control is not retroactive.
5. Start one session with `/remote-control`; do not enable all-session
   auto-connect yet.
6. Connect from one enrolled device, verify the expected account and workspace,
   disconnect, revoke the device, and confirm that steering no longer works.
7. Record reviewer names, date, policy decision, and pass/fail only. If approved,
   the user or managed administrator may separately decide whether
   `remoteControlAtStartup` should be enabled.

## Fail-closed conditions

Do not enable, and disable an active session, when any of these apply:

- Zero Data Retention is required, BAA/contract coverage is required but not
  satisfied, or the retention decision is unknown.
- The session can read a production secret or high-risk regulated data.
- The connecting device is shared, lost, unenrolled, or cannot use the required
  recent sign-in/passkey step-up.
- The account, organization, or workspace shown remotely is unexpected.
- A custom API endpoint or enterprise cloud provider is required.
- A privacy/telemetry control would need to be removed without its owner's
  explicit approval.

## Official evidence

- [Remote Control requirements, data flow, settings, and Trusted Devices](https://code.claude.com/docs/en/remote-control)
- [Anthropic BAA feature coverage](https://support.claude.com/en/articles/8114513-business-associate-agreements-baa-for-commercial-customers)
- [Claude release notes](https://support.claude.com/en/articles/12138966-release-notes)

These are external product terms and can change. Recheck them before every new
organization approval or material policy change.
