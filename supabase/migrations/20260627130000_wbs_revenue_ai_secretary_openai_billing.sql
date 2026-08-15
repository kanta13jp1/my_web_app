-- Revenue-first media quality follow-up:
-- OpenAI API billing is now the blocking condition for generated share images.
-- Keep the video/social acquisition work registered as P0 until one X-origin
-- user and a later bank payout are evidenced.

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
    'revenue-p0 / x-first-user-growth',
    'credit_card',
    0,
    '[additional][revenue-p0][x-growth] OpenAI API billing unblock for image-gen2 media',
    'Restore OpenAI Platform API credits for AI Share image generation. The current production error is an OpenAI API billing hard-limit error for GPT Image models, not a ChatGPT subscription issue. The media-hub function now surfaces openai_billing_required and does not send the obsolete style parameter to the DALL-E fallback.',
    'codex',
    'codex',
    'in_progress',
    70,
    DATE '2026-06-27',
    DATE '2026-06-27',
    'first-yen-revenue',
    'high',
    'pending',
    6,
    'Add or raise OpenAI Platform API credits at https://platform.openai.com/settings/organization/billing/overview, then rerun AI Share image generation and confirm the response contains a public image URL or stored image URL.',
    'If OpenAI billing is not restored immediately, keep the X acquisition sprint moving with text-only posts and existing Supabase-hosted Hedra MP4 assets. Do not block first-user acquisition on image generation.',
    ARRAY[
      '[additional][revenue-p0][x-growth] AI share first-user acquisition mode'
    ]::text[]
  ),
  (
    'revenue-p0 / x-first-user-growth',
    'smart_display',
    0,
    '[additional][revenue-p0][x-growth] High-quality AI secretary video for first-user acquisition',
    'Produce a brand-safe high-quality AI secretary explainer video for X: GPT copy/script, image-gen2 style visual generation when OpenAI billing is available, ElevenLabs narration, Hedra presenter video, and Seedance-style short-video prompt/copy. The video should explain Site Guide AI, AI Secretary, AI University, notes, asset management, English reading, release notes, and supporter checkout.',
    'codex',
    'codex',
    'in_progress',
    82,
    DATE '2026-06-27',
    DATE '2026-06-27',
    'first-yen-revenue',
    'high',
    'pending',
    6,
    'After OpenAI API credits are restored, generate one AI secretary share image/video from the live dialog, post it to X with the first-user UTM URL, and record the X post URL plus impressions/replies/site visits.',
    'If image-gen2 remains unavailable, use the already stored Hedra/ElevenLabs MP4 or a text-only post, then iterate the creative once billing is restored.',
    ARRAY[
      '[additional][revenue-p0][x-growth] OpenAI API billing unblock for image-gen2 media',
      '[additional][revenue-p0][x-growth] Hedra + ElevenLabs AI share video path'
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

UPDATE public.wbs_tasks
SET
  progress = GREATEST(progress, 99),
  remaining_work = 'Use the AI Share dialog with OpenAI billing restored, or the stored Hedra MP4 fallback, to publish one X acquisition post and record the first non-warm user signal.',
  recovery_plan = 'If OpenAI API billing remains blocked, proceed with text-only X intent posting and existing Supabase-hosted Hedra MP4 assets; then retry image-gen2 once credits are added.',
  updated_at = now()
WHERE title = '[additional][revenue-p0][x-growth] AI share first-user acquisition mode'
  AND instance = 'codex';
