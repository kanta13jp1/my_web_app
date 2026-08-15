-- Revenue-first follow-up:
-- 1. Make Obsidian/memory useful for the first-yen revenue loop.
-- 2. Use paid Hedra and ElevenLabs APIs in the X acquisition media path.

INSERT INTO public.wbs_tasks
  (
    category,
    category_icon,
    category_order,
    title,
    description,
    instance,
    owner_instance,
    status,
    progress,
    start_date,
    end_date,
    milestone_code,
    priority,
    ai_review_status,
    stale_threshold_hours,
    remaining_work,
    recovery_plan,
    depends_on_titles
  )
VALUES
  (
    'revenue-p0 / memory-feedback-loop',
    'account_tree',
    0,
    '[additional][revenue-p0][obsidian] Capture first-yen revenue loop in Obsidian',
    'Verify that Obsidian/memory is not only connected but actively useful for the first-yen revenue goal. Capture the Stripe, X acquisition, Hedra/ElevenLabs media, webhook, and bank-payout evidence loop as a reusable memory note, and keep future X metrics/user evidence linked back to WBS.',
    'codex',
    'codex',
    'in_progress',
    80,
    DATE '2026-06-27',
    DATE '2026-06-27',
    'first-yen-revenue',
    'high',
    'pending',
    6,
    'Append the first X post URL, first X-origin user evidence, successful Stripe webhook evidence, and bank-payout evidence to memory/vault/revenue_first_growth_loop_20260627.md as they happen.',
    'If Obsidian is only showing old graph data, use the repo memory/vault note as the canonical source and manually open it from Obsidian until automation catches up.',
    ARRAY[
      '[additional][revenue-p0][x-growth] AI share first-user acquisition mode',
      '[additional][revenue-p0] Bank payout evidence for at least 1 JPY'
    ]::text[]
  ),
  (
    'revenue-p0 / x-first-user-growth',
    'movie',
    0,
    '[additional][revenue-p0][x-growth] Hedra + ElevenLabs AI share video path',
    'Use the paid Hedra and ElevenLabs APIs in the AI share flow: generate ElevenLabs speech, upload it as a Hedra audio asset, create a Hedra presenter video from the public OGP/start image, and fall back to Hedra TTS or text-only posting when upstream APIs fail.',
    'codex',
    'codex',
    'in_progress',
    95,
    DATE '2026-06-27',
    DATE '2026-06-27',
    'first-yen-revenue',
    'high',
    'pending',
    6,
    'Use the completed Hedra/ElevenLabs video, or generate one more from the updated first-user template, in an X post aimed at one non-warm first user.',
    'If ElevenLabs or Hedra quota/API calls fail, continue the X sprint with text-only X intent fallback and record the failure in Obsidian/WBS instead of blocking acquisition.',
    ARRAY[
      '[additional][revenue-p0][x-growth] AI share first-user acquisition mode'
    ]::text[]
  )
ON CONFLICT (title, instance) DO UPDATE SET
  category = EXCLUDED.category,
  category_icon = EXCLUDED.category_icon,
  category_order = EXCLUDED.category_order,
  description = EXCLUDED.description,
  owner_instance = EXCLUDED.owner_instance,
  status = CASE
    WHEN public.wbs_tasks.status = 'completed' THEN public.wbs_tasks.status
    ELSE EXCLUDED.status
  END,
  progress = GREATEST(public.wbs_tasks.progress, EXCLUDED.progress),
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  milestone_code = EXCLUDED.milestone_code,
  priority = EXCLUDED.priority,
  ai_review_status = EXCLUDED.ai_review_status,
  stale_threshold_hours = EXCLUDED.stale_threshold_hours,
  remaining_work = EXCLUDED.remaining_work,
  recovery_plan = EXCLUDED.recovery_plan,
  depends_on_titles = EXCLUDED.depends_on_titles,
  updated_at = now();
