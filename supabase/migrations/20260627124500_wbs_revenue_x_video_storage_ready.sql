-- The AI Share / Hedra / ElevenLabs path now produces durable public video
-- evidence. Keep the revenue task open until the X post produces a real user.

update public.wbs_tasks
set
  progress = greatest(progress, 98),
  remaining_work = 'Publish one Supabase-hosted Hedra MP4 from AI Share to X, record the X post URL and impressions/replies, then capture at least one non-warm X-origin user signal before asking for a 100 JPY supporter checkout.',
  recovery_plan = 'If X API posting fails, use the X intent/manual composer with the same MP4 URL and copy. If Hedra/ElevenLabs fails, continue with text-only posting and record the failure in Obsidian/WBS.',
  description = case
    when coalesce(description, '') like '%Durable video evidence 2026-06-27:%'
      then description
    else coalesce(description, '') ||
      E'\n\nDurable video evidence 2026-06-27: completed Hedra generation b68583c2-7ba4-4367-a06d-6d12b3e8e1c4 was stored as viral-ad-videos/hedra/2026-06-27/b68583c2-7ba4-4367-a06d-6d12b3e8e1c4-user_growth-en.mp4, and live UI generation e8fe90b2-c1f7-4d43-bdd7-38b4cbd6a250 was stored as viral-ad-videos/hedra/2026-06-27/e8fe90b2-c1f7-4d43-bdd7-38b4cbd6a250-feature_highlight-ja.mp4. Both are public MP4 objects suitable for X acquisition evidence.'
  end,
  updated_at = now()
where title = '[additional][revenue-p0][x-growth] Hedra + ElevenLabs AI share video path'
  and instance = 'codex';

update public.wbs_tasks
set
  progress = greatest(progress, 85),
  remaining_work = 'Append the first X post URL, observed X metrics, first X-origin user evidence, successful Stripe webhook evidence, and bank-payout evidence to memory/vault/revenue_first_growth_loop_20260627.md as they happen.',
  description = case
    when coalesce(description, '') like '%Durable video evidence linked 2026-06-27:%'
      then description
    else coalesce(description, '') ||
      E'\n\nDurable video evidence linked 2026-06-27: the Obsidian/repo memory note now records Supabase-hosted public MP4 URLs for the first-user X acquisition videos instead of relying on Hedra signed URLs.'
  end,
  updated_at = now()
where title = '[additional][revenue-p0][obsidian] Capture first-yen revenue loop in Obsidian'
  and instance = 'codex';
