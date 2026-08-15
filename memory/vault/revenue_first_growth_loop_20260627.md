# Revenue First Growth Loop 2026-06-27

## Purpose

This note connects the current session goal to the Obsidian / memory graph:
earn at least 1 JPY of real revenue, verify the Stripe webhook evidence, and
confirm the bank payout evidence before calling the session complete.

## Current Evidence

- Stripe live checkout readiness passed: live Checkout can create a 100 JPY
  session, but successful live payment and bank payout evidence are still
  missing.
- Stripe account status still matters: do not ask for paid supporter conversion
  while identity review or payout pause risk remains visible.
- X acquisition is the active first-user channel because warm contacts are
  explicitly out of scope.
- The AI share dialog now has first-user X copy, UTM tagging, image-generation
  fallback, and X intent fallback for API credit errors.
- Hedra API and ElevenLabs API secrets are present in Supabase. The video path
  should use ElevenLabs speech as a Hedra audio asset first, then fall back to
  Hedra TTS if needed.
- Knowledge vault lint on 2026-06-27 reported health 96/100, so the system is
  structurally healthy; the main gap was that this revenue sprint had not yet
  been captured as a reusable note.
- Obsidian is currently opening
  `C:\Users\kanta\.claude\projects\c--Users-kanta-GitHub-my-web-app\memory`;
  this note was mirrored there as `revenue_first_growth_loop_20260627.md` and
  indexed from that vault's `MEMORY.md`.
- Production Hedra/ElevenLabs check succeeded on 2026-06-27:
  `viral-video-ad-generator` created ElevenLabs audio asset
  `40cab44e-53b3-4c54-a69a-0eb0e7467e38`, then completed Hedra generation
  `b68583c2-7ba4-4367-a06d-6d12b3e8e1c4`. The returned video URL is a signed
  temporary URL, so the stable evidence is the generation id and DB history row.
- The completed Hedra video was copied into Supabase Storage on 2026-06-27 so
  the X acquisition asset survives Hedra signed URL expiry:
  `https://smmkxxavexumewbfaqpy.supabase.co/storage/v1/object/public/viral-ad-videos/hedra/2026-06-27/b68583c2-7ba4-4367-a06d-6d12b3e8e1c4-user_growth-en.mp4`
  (`video/mp4`, 8,481,747 bytes).
- A second AI Share Hedra job from the live UI completed and was also copied to
  Supabase Storage:
  `https://smmkxxavexumewbfaqpy.supabase.co/storage/v1/object/public/viral-ad-videos/hedra/2026-06-27/e8fe90b2-c1f7-4d43-bdd7-38b4cbd6a250-feature_highlight-ja.mp4`
  (`video/mp4`, 17,550,237 bytes). This confirms the in-app `Hedra確認`
  polling path can return durable MP4 evidence for X posting.

- OpenAI Platform API credits were restored on 2026-06-27. The billing page
  showed about 15 USD of credit, and AI Share image generation recovered enough
  to return a public Supabase Storage image URL. The production `media-hub`
  function still returns `openai_billing_required` with the billing URL if
  credits are exhausted again, and it no longer sends obsolete DALL-E `style`
  or `response_format` parameters.
- A live UI video attempt then exposed a Hedra TTS error:
  `model missing not valid for generation type text_to_speech`. The production
  `viral-video-ad-generator` function was updated and deployed on 2026-06-27 to
  resolve a Hedra TTS `model_id` from `/models`, simplify the ElevenLabs TTS
  request body, preserve ElevenLabs fallback reasons, and send the AI secretary
  `ai_secretary_site_tour` template from the frontend.
- A regenerated AI secretary site-tour video completed on 2026-06-27 and was
  copied to Supabase Storage:
  `https://smmkxxavexumewbfaqpy.supabase.co/storage/v1/object/public/viral-ad-videos/hedra/2026-06-27/5333ecf8-6a39-49d3-9f9b-b5c1aa63e812-ai_secretary_site_tour-ja.mp4`
  (`video/mp4`, 10,917,347 bytes). DB evidence row:
  `viral_ad_generations.id = 4ebc21f3-918c-41cb-b175-99e197d41c27`,
  `video_status = complete`.
- The AI Share video prompt/script now targets a brand-safe intelligent,
  elegant AI secretary explainer that covers Site Guide AI, AI Secretary, AI
  University, notes, asset management, English reading, release notes, and the
  supporter checkout.

## Revenue Loop

1. Publish X post from AI Share with UTM:
   `utm_source=x&utm_medium=ai_share&utm_campaign=first_user_growth`.
2. Capture one X-origin real user signal: reply, DM, screenshot, product
   feedback, or analytics-supported site visit with a human follow-up.
3. After Stripe account status clears, ask the real interested user to complete
   the 100 JPY Founding Supporter checkout.
4. Confirm `stripe-webhook` recorded supporter-payment evidence.
5. Confirm at least 1 JPY reaches the bank account.

## Links

- [[MEMORY]]
- [[log]]
- [[ingest_20260505_karpathy-ai-external-brain-2026-05-05]]
- [[MONETIZATION_REVENUE_FIRST_REVIEW]]
- [[WBS]]
- [[x-impression-growth-sprint]]
- [[first-revenue-outreach]]
- [[first-user-acquisition-sprint]]

## Files

- `docs/WBS.md`
- `docs/marketing/x-impression-growth-sprint.md`
- `docs/marketing/first-revenue-outreach.md`
- `docs/marketing/first-user-acquisition-sprint.md`
- `docs/knowledge-vault-lint/2026-06-27-revenue-obsidian-audit.md`
- `lib/services/universal_x_share_service.dart`
- `lib/widgets/universal_ai_share_shell.dart`
- `supabase/functions/media-hub/index.ts`
- `supabase/functions/viral-video-ad-generator/index.ts`
- `supabase/migrations/20260627130000_wbs_revenue_ai_secretary_openai_billing.sql`
- `supabase/migrations/20260627123000_viral_ad_video_storage.sql`
- `scripts/check_first_revenue_readiness.py`
- `scripts/rotate_stripe_live_secret_and_check.ps1`

## Next Actions

- Use the regenerated AI secretary video in the next X post with the
  first-user UTM URL.
- Record the first X post URL and observed X metrics back into this note or the
  WBS.
- Do not mark the session goal complete until bank payout evidence passes the
  revenue readiness gate.
