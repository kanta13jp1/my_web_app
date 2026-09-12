# Product Hunt / Hacker News launch package

Status: **review-ready, external action blocked**

Issue: #3671

Prepared: 2026-09-03

Proposed launch date: **2026-09-10** (not scheduled; owner approval required)

This package turns the factual product positioning in
[`docs/PRESS_RELEASE_V1.md`](../PRESS_RELEASE_V1.md) into launch-channel
inputs. Current production pricing and URLs take precedence over the older
MVP-era claim that the whole service is free.

No Product Hunt draft, schedule, launch, or Hacker News submission has been
created by automation. Those are external publication actions and require the
owner's approval at action time.

## Verified product facts

- Product/brand name: **自分株式会社**. Do not imply that this is the legal
  entity name unless the owner has separately confirmed that fact.
- Product: a Japanese Web app that brings health, learning, money, notes, and
  AI-assisted reflection into one workspace.
- Positioning: compare with yesterday's self, not other people; AI proposes
  next steps and the user keeps the final decision.
- Public product URL: <https://my-web-app-b67f4.web.app/>
- Public pricing URL:
  <https://my-web-app-b67f4.web.app/subscription-billing>
- Current pricing shown by the product: Free ¥0, one-time Supporter ¥100,
  Pro ¥980/month, Team ¥2,980/month.
- All four tagged landing/pricing URLs below returned HTTP 200 on 2026-09-03.
- Do not publish user-count, outcome, revenue, company, or launch-date claims
  that are not backed by current evidence.

## Measurement links

Use the landing link as the primary product URL. It offers the public journey
and starts the privacy-minimized seven-day attribution that continues through
signup, first action, billing, and supporter checkout.

| Channel | Purpose | URL |
|---|---|---|
| Product Hunt | Primary product link | <https://my-web-app-b67f4.web.app/?lp_intent=trial&utm_source=producthunt&utm_medium=launch&utm_campaign=first_user_growth&utm_content=ph_launch_v1> |
| Product Hunt | Pricing disclosure | <https://my-web-app-b67f4.web.app/subscription-billing?utm_source=producthunt&utm_medium=launch&utm_campaign=first_user_growth&utm_content=ph_launch_v1> |
| Hacker News | Primary Show HN link | <https://my-web-app-b67f4.web.app/?lp_intent=trial&utm_source=hackernews&utm_medium=launch&utm_campaign=first_user_growth&utm_content=hn_show_v1> |
| Hacker News | Pricing disclosure | <https://my-web-app-b67f4.web.app/subscription-billing?utm_source=hackernews&utm_medium=launch&utm_campaign=first_user_growth&utm_content=hn_show_v1> |

The accepted source tokens are `producthunt` and `hackernews`; campaign is
`first_user_growth`. The launch must not proceed until the migration and Edge
Function changes in the #3671 PR have been reviewed, merged, and deployed.

## Product Hunt listing fields

The field set follows Product Hunt's current posting flow. Product Hunt now
requires creating a draft or scheduling a launch rather than using a
"Launch Now" action. Review the live UI before saving because field labels can
change.

### Core fields

| Field | Review value |
|---|---|
| Name | 自分株式会社 |
| Tagline | Run your life like a calm, AI-assisted company |
| Pricing | Paid (with a free plan) |
| Website | Use the Product Hunt primary product link above |
| Topics | Productivity, Artificial Intelligence, Personal Finance |
| Status | Draft only until owner approves scheduling |

### Description (260 characters or fewer)

> A Japanese life-management web app that brings health, learning, money,
> notes, and AI-assisted reflection into one dashboard. Compare with
> yesterday's self—not other people. Start free; paid support and plans are
> optional.

### Maker comment draft — owner review required

> Hello Product Hunt. I built 自分株式会社 around a simple idea: personal
> management should help you decide what to do next without turning life into
> a competition. The app brings health, learning, money, notes, and AI-assisted
> reflection into one place. You can explore the public journey before signing
> up, then continue on the Free plan without entering a card. If you try it,
> I would value specific feedback on what feels clear, what feels crowded, and
> whether the suggested next action is genuinely useful. Paid support and
> plans are optional and shown on the pricing page.

### First comment draft — owner review required

> A useful place to begin is the four-step public journey: scattered inputs,
> one workspace, an AI-proposed priority, and one action to move today. The
> Product Hunt link is tagged only for aggregate funnel measurement; the
> acquisition table stores a random visitor ID and campaign tokens, not email,
> prompt text, IP address, or browser fingerprint. Current pricing is Free ¥0,
> a one-time ¥100 Supporter option, Pro ¥980/month, and Team ¥2,980/month.

### Thumbnail and gallery

Use the existing first-party production artwork. It portrays the actual public
landing journey and avoids fabricated product screenshots.

| Order | Repository asset | Source size | Upload caption |
|---|---|---:|---|
| Thumbnail | `assets/icons/app_icon.png` | 1024×1024 | 自分株式会社 |
| 1 | `assets/landing_journey/01-scattered.webp` | 1600×900 | When plans, notes, money, and learning are scattered, the next action gets harder to see. |
| 2 | `assets/landing_journey/02-unified.webp` | 1600×900 | Bring work, learning, money, and health back into one workspace. |
| 3 | `assets/landing_journey/03-prioritized.webp` | 1600×900 | AI organizes the situation and proposes a priority; you make the final call. |
| 4 | `assets/landing_journey/04-action.webp` | 1600×900 | Start with one short action and save the result for tomorrow. |

Product Hunt currently recommends a 240×240 thumbnail and 1270×760 gallery
images. The source files are larger; preview the platform crop before saving
the draft and replace any frame whose text or focal point is clipped. Do not
publish mock metrics or synthetic testimonials in the media.

## Hacker News human-writing worksheet

Do **not** copy an AI-written title, submission text, or comment into Hacker
News. The current HN guidelines prohibit generated or AI-edited comment text.
The owner must write the submission and every comment from scratch in their
own words.

Use these facts only as a worksheet:

- It is a usable Japanese Flutter Web product, not a waitlist or landing-page
  concept.
- Visitors can inspect the public journey before registration.
- The product combines health, learning, money, notes, and AI-assisted
  reflection.
- The design avoids rankings against other people and keeps decisions with the
  user.
- The Free plan does not require a card; paid options are disclosed separately.
- Link to the Hacker News primary Show HN URL above, not directly to checkout.
- Explain what was built, what is technically interesting, what remains rough,
  and what feedback would change the product.

Before submitting:

- [ ] Owner has personally tried the public URL in a signed-out session.
- [ ] The landing experience is usable without requiring an email first.
- [ ] Owner wrote the Show HN title and opening comment without AI generation
      or AI editing.
- [ ] The submission is a direct product link, not a press release or fundraiser.
- [ ] No request for upvotes, coordinated voting, or promotional replies.
- [ ] Owner is available to answer questions and disclose limitations.

## Scheduling and approval gate

Proposed date: **2026-09-10**. This is a review proposal, not a confirmed
appointment. At action time the owner must:

1. Approve the final Product Hunt fields, media crop, public date, and the
   timezone shown by Product Hunt.
2. Confirm that the #3671 migration and Edge Function changes are deployed.
3. Open the tagged landing and pricing URLs and confirm HTTP/UI behavior.
4. Create or update the Product Hunt draft and schedule it for the approved
   date.
5. On launch day, write the Hacker News submission independently and submit it
   only if the product is directly usable.

A public search on 2026-09-03 found no indexed Product Hunt post for the
product name or production domain. The owner's Product Hunt dashboard remains
the authority for detecting a private draft or prior unindexed launch and for
applying the platform's relaunch rules.

After launch, run `.github/workflows/first-user-acquisition-report.yml` once
for `producthunt / launch / ph_launch_v1` and once for
`hackernews / launch / hn_show_v1`. Keep the report privacy-safe and do not
publish raw visitor rows.

## Current primary-source checks

- Product Hunt posting fields:
  <https://help.producthunt.com/en/articles/479557-how-to-post-a-product>
- Product Hunt featuring guidelines:
  <https://help.producthunt.com/en/articles/9883485-product-hunt-featuring-guidelines>
- Product Hunt draft/scheduling change:
  <https://help.producthunt.com/en/articles/9823193-where-did-launch-now-go>
- Product Hunt relaunch eligibility:
  <https://help.producthunt.com/en/articles/484934-can-i-relaunch-my-product>
- Show HN guidance: <https://news.ycombinator.com/showhn.html>
- Hacker News guidelines: <https://news.ycombinator.com/newsguidelines.html>
