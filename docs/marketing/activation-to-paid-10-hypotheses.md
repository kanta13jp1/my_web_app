# Activation to Paid: 10 Hypotheses

## Goal

Move a newly registered user from an immediate first result to an optional
100 JPY supporter payment or a Pro checkout without putting payment before
value. The bank-payout goal remains open until Stripe records a real payment
and the linked bank account shows a payout of at least 1 JPY.

## Funnel

1. `onboarding_view`
2. `intent_selected`
3. `first_action_started`
4. `first_action_completed`
5. `onboarding_completed`
6. `value_recap_view`
7. `billing_view`
8. `supporter_checkout` or `pro_checkout`
9. `checkout_return`

Each event keeps the bounded key
`activation_exp_<hypothesis>_<variant>_<stage>`. The existing daily
`app_analytics.source_details` counter remains as an operational signal, while
`activation_experiment_events` records each authenticated, non-anonymous
user/arm/stage at most once for experiment decisions. The raw ledger is denied
to browser roles; only the service-role aggregate
`activation_experiment_arm_stats` is used by reports. It stores no email, IP
address, user agent, prompt, challenge, or other user-supplied content.

Assignments persist in SharedPreferences. QA can force an arm with:

```text
?activation_hypothesis=a10&activation_variant=treatment
```

## Hypotheses

| ID | Hypothesis | Control | Treatment | Primary metric |
| --- | --- | --- | --- | --- |
| A01 | A concrete 60-second result reduces uncertainty. | Generic setup headline | "Choose today's one action in 60 seconds" | onboarding completion rate |
| A02 | Purpose selection makes the product feel relevant. | Default work path | Work, learning, or money choice | first-action start rate |
| A03 | One short challenge field is enough to begin. | Challenge may be skipped | One challenge is requested | first-action start rate |
| A04 | Examples remove blank-page hesitation. | No examples | Intent-specific example chips | first-action start rate |
| A05 | A personalized first action demonstrates value. | Generic action | Action generated from the user's challenge | first-action completion rate |
| A06 | Optional display name reduces form abandonment. | Display name required | Display name optional, email local part fallback | onboarding completion rate |
| A07 | A visible three-stage path feels finite. | Minimal progress context | Purpose, first action, start progress | onboarding completion rate |
| A08 | Saving the first action as a real task increases confidence. | No persistence promise or task creation | Save the first action in today's Home task list and show account-only storage trust copy | onboarding completion rate |
| A09 | Payment should appear only after value. | Paid choice can appear without recap framing | Free continuation first; paid choices after saved result | billing-view rate |
| A10 | Value-framed choices outperform plan jargon. | Generic supporter/Pro labels | Free, one-time 100 JPY, and Pro explained by outcome and renewal behavior | checkout-start rate |

The experiment is leave-one-out: a control assignment disables only its own
hypothesis while all other improvements remain enabled. This prevents a user
from receiving a deliberately poor ten-control experience and isolates one
decision at a time.

## Implementation evidence

- `ActivationRevenueExperimentService` defines all 20 arms, stable assignment,
  bounded event keys, and QA overrides.
- `OnboardingPage` implements the three-stage first-value flow and delays paid
  choices until the value recap. A08 persists the proposed first action as an
  idempotent `daily_todos` item so the Home calendar can resume it.
- `SubscriptionBillingPage` presents Japanese value-based Free, 100 JPY, Pro,
  and Team choices and records checkout intent.
- `record_activation_experiment_event` deduplicates every signed-in user,
  hypothesis, variant, and stage. Anonymous sessions cannot write this ledger.
- `activation_experiment_report.py` validates all 20 arms, calculates Wilson
  95% intervals and relative lift, and emits aggregate-only JSON and Markdown.
- `activation-experiment-report.yml` runs the decision report daily and on
  demand with the service-role key kept out of pull-request workflows.
- `schedule-hub` creates the supporter item as "AI仕事OS 初期サポーター" with
  one-time/no-renewal value copy in Stripe Checkout.
- Widget tests cover a 390 px viewport, the complete first-value flow, A03
  control/treatment behavior, billing return states, and onboarding entry.
- Unit tests cover all 10 hypotheses, both variants, stable assignment, QA
  override, and every funnel-event key.

## Validation gate

Automated tests prove implementation, not market impact. Do not declare a
hypothesis won until both arms have at least 100 unique onboarding views and
20 users in the primary-metric denominator. A01-A09 also require 20 total
primary successes; A10 requires 5 total supporter-or-Pro checkout starts.
Prefer an arm only when the primary metric differs by at least 20% and its
Wilson 95% interval is fully separated from the other arm. Impossible funnels
such as more unique checkout starters than billing viewers are reported as
`invalid_funnel_data`, never as a winner.

## Revenue completion gate

The technical funnel is ready when a live Stripe Checkout opens and its
webhook records the payment. The session goal is complete only after all three
external facts are verified:

1. A non-owner user registers and completes first value.
2. A real 100 JPY or subscription payment succeeds in Stripe live mode.
3. Stripe pays out and the linked bank account shows at least 1 JPY received.
