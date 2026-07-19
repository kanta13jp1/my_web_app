# LP acquisition validation - 2026-07-19

## Goal

Move one unknown visitor through the complete funnel:

`X impression -> LP visit -> no-signup trial -> Magic Link signup -> first saved action -> 100 JPY supporter or Pro checkout -> Stripe payout -> bank deposit`

The session goal remains open until a real external-user payment is paid out to the bank account. Test sessions, anonymous Supabase users, and Stripe Checkout creation do not count as completion.

## Production baseline

The anonymous production aggregate was checked before this change.

- LP experiment view events are present.
- Only one `funnel_trial_run` was observed in the recent period.
- No `funnel_magic_link_send` was observed.
- All recent `auth.users` rows were anonymous sessions; non-anonymous registrations were zero.
- The supporter checkout event observed on 2026-07-19 was internal QA and is excluded from revenue evidence.

The largest verified drop is therefore `LP view -> trial`, followed by `trial -> signup submit`.

## Ten hypotheses

| ID | Hypothesis | Treatment | Primary metric | Technical verification | Live conclusion |
| --- | --- | --- | --- | --- | --- |
| H01 | An outcome-first promise increases hero engagement. | Lead with the concrete result: AI chooses the next action in one minute. | `hero_cta / view` | Automated widget test | Pending sample |
| H02 | Choosing work, learning, or money increases trial starts. | Show an intent selector and one-click example. | `trial / view` | Automated widget test | Pending sample |
| H03 | Experiencing value before signup increases conversion. | Put the actual AI trial inside the first viewport; control keeps auth before trial. | `signup_submit / trial` | Automated position and control tests | Refined after baseline showed almost no trials |
| H04 | A one-field Magic Link removes signup friction. | Show email and Magic Link directly below the generated result; control keeps password-first flow. | `signup_submit / trial` | Automated Magic Link and control tests | Refined after zero Magic Link sends |
| H05 | Risk reversal increases CTA use. | Show free core, no card, and stop-anytime assurances. | `hero_cta / view` | Automated widget test | Pending sample |
| H06 | Concrete input-output-continuity proof increases trials. | Show the three-step product proof before conversion. | `trial / view` | Automated widget test | Pending sample |
| H07 | Real social proof near conversion increases signup. | Place real aggregate usage proof before auth. | `signup_submit / view` | Automated position test | Pending sample; never fabricate proof |
| H08 | Privacy assurance increases completed signup. | Explain email privacy, Stripe handling, and data controls. | `signup_complete / signup_submit` | Automated widget test | Pending sample |
| H09 | A mobile sticky CTA prevents lost opportunities. | Show a stable CTA below 720 px. | Mobile `signup_submit / view` | 390 px widget test | Pending sample |
| H10 | Explaining saved continuity increases desire to register. | State that the suggestion, history, and next action remain available tomorrow. | `save_cta / trial` | Automated result-state test | Pending sample |

## Experiment rules

- A visitor is stably assigned to one of 20 arms: ten hypotheses times control/treatment.
- The assigned hypothesis changes only its own mechanism; the other nine treatments remain enabled.
- URL overrides are reserved for QA: `lp_hypothesis=h03&lp_variant=control`.
- Events use `lp_exp_{hypothesis}_{variant}_{stage}`.
- Supported stages are `view`, `hero_cta`, `intent`, `trial`, `save_cta`, `signup_submit`, `signup_complete`, and `sticky_cta`.
- Do not declare a winner from implementation tests. Require at least 100 unique views per arm and at least 10 signup submits across both variants before evaluating direction.

## Acquisition and revenue attribution

- Any `utm_source=x&utm_campaign=first_user_growth` visit records `touch_x_first_user_growth`.
- Profile traffic remains separately identified as `touch_profile`.
- Signup submit records `signup_submit_x_first_user_growth` when that touchpoint is latest.
- The latest X touchpoint survives the signup redirect and is added to supporter and Pro checkout metadata.
- A unique `utm_content` must be used for each human-approved X creative. Do not publish near-duplicate posts or automate replies/DMs.

## Release gate

- [x] All ten hypotheses remain technically testable.
- [x] H03 actual trial is in the hero treatment.
- [x] H04 inline Magic Link is directly below the result.
- [x] H03 and H04 controls preserve the prior flow.
- [x] X attribution survives to supporter/Pro checkout.
- [x] Targeted widget/service tests pass.
- [x] Static analysis passes.
- [ ] Production deployment completed.
- [ ] One unknown visitor starts a trial.
- [ ] One non-anonymous user completes signup.
- [ ] That user completes a first saved action.
- [ ] One real external-user payment succeeds.
- [ ] Stripe payout is marked paid.
- [ ] Bank deposit of at least 1 JPY is verified.

