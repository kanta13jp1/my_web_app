-- Revenue-first AI Share media recovery follow-up.
-- OpenAI Platform credits are restored, image generation is working again, and
-- Hedra TTS model resolution has been deployed for AI secretary videos.

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
    'smart_display',
    0,
    '[additional][revenue-p0][x-growth] Hedra TTS model resolver for AI secretary video',
    'Fix the production Hedra error "model missing not valid for generation type text_to_speech" by resolving a valid Hedra TTS model_id from /models, simplifying the ElevenLabs text-to-speech request body, and preserving audio fallback reasons in the response.',
    'codex',
    'codex',
    'completed',
    100,
    DATE '2026-06-27',
    DATE '2026-06-27',
    'first-yen-revenue',
    'high',
    'pending',
    6,
    'Production deployment is complete. Rerun AI Share video generation from the live dialog and confirm it returns ai_secretary_site_tour plus a durable public video URL.',
    'If Hedra still rejects TTS, use ElevenLabs audio assets as the primary path and keep text/image-only X posting available so the first-user sprint does not stall.',
    ARRAY[
      '[additional][revenue-p0][x-growth] High-quality AI secretary video for first-user acquisition'
    ]::text[]
  )
ON CONFLICT (title, instance) DO UPDATE SET
  category = EXCLUDED.category,
  category_icon = EXCLUDED.category_icon,
  category_order = EXCLUDED.category_order,
  description = EXCLUDED.description,
  owner_instance = EXCLUDED.owner_instance,
  status = EXCLUDED.status,
  progress = EXCLUDED.progress,
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
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 95),
  ai_review_status = 'pending',
  remaining_work = 'OpenAI Platform credits are restored and AI Share image generation returned a public Supabase Storage URL. Monitor credit balance, then use the regenerated image as the AI secretary video key visual.',
  recovery_plan = 'If credits are exhausted again, keep the X first-user sprint moving with text-only posts and Supabase-hosted Hedra MP4 assets while returning openai_billing_required from media-hub.',
  updated_at = now()
WHERE title = '[additional][revenue-p0][x-growth] OpenAI API billing unblock for image-gen2 media'
  AND instance = 'codex';

UPDATE public.wbs_tasks
SET
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 97),
  remaining_work = 'AI secretary site-tour video is generated and stored at https://smmkxxavexumewbfaqpy.supabase.co/storage/v1/object/public/viral-ad-videos/hedra/2026-06-27/5333ecf8-6a39-49d3-9f9b-b5c1aa63e812-ai_secretary_site_tour-ja.mp4. Post it to X with first-user UTM tracking and record impressions, replies, clicks, and the first non-warm user signal.',
  recovery_plan = 'If X media posting fails, copy the post text and attach the stored MP4 manually in X, then record the post URL and metrics back into WBS/memory.',
  updated_at = now()
WHERE title = '[additional][revenue-p0][x-growth] High-quality AI secretary video for first-user acquisition'
  AND instance = 'codex';
