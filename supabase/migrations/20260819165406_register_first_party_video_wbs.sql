-- Keep launch evidence open until the branch is merged, deployed, and proven
-- with a real non-admin buyer and a completed first-party GPU job.
-- nocheck: time-relative

insert into public.wbs_tasks (
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
values (
  'revenue / first-party-video',
  'movie_creation',
  0,
  '[revenue-p0][video-generation] Launch first-party prepaid video generation',
  'Ship an authenticated text-to-video service operated on an owned Wan2.2 GPU worker, with private outputs, bounded leases, atomic prepaid credits, Stripe-signed fulfillment, automatic failure refunds, and no external inference API.',
  'codex',
  'codex',
  'in_progress',
  92,
  date '2026-08-20',
  date '2026-08-22',
  'first-yen-revenue',
  'high',
  'pending',
  24,
  'Deploy the least-privilege Cloud Run wake controller, create and sync VIDEO_WORKER_WAKE_TOKEN, build the validated worker revision, and apply the startup metadata with 10-minute idle shutdown. Complete legal review, merge, and deploy the migration, video-generation-hub, video-worker-hub, schedule-hub, stripe-webhook, and Flutter route. Run one paid non-admin checkout, complete one 5-second 720p job, verify automatic VM stop, and confirm a payout/bank deposit.',
  'If the wake controller cannot accept an unclaimed job, fail it immediately and return the reservation. Heartbeat loss allows at most three leased attempts; exhaustion automatically fails the job and refunds credits. Each attempt uses a non-overwritable path, and fail/reclaim schedules abandoned objects for bounded-path deletion. Replay signed Stripe events for fulfillment failures. Never put the Supabase service-role key on the GPU host.',
  array[
    '[revenue-p0][stripe-account] Automate live charge and payout readiness evidence',
    '[revenue-p0][landing-auth] Make Google OAuth primary and diagnose every auth handoff'
  ]::text[]
)
on conflict (title, instance) do update set
  category = excluded.category,
  category_icon = excluded.category_icon,
  category_order = excluded.category_order,
  description = excluded.description,
  owner_instance = excluded.owner_instance,
  status = case
    when public.wbs_tasks.status = 'completed' then 'completed'
    else excluded.status
  end,
  progress = case
    when public.wbs_tasks.status = 'completed' then 100
    else excluded.progress
  end,
  start_date = excluded.start_date,
  end_date = excluded.end_date,
  milestone_code = excluded.milestone_code,
  priority = excluded.priority,
  ai_review_status = excluded.ai_review_status,
  stale_threshold_hours = excluded.stale_threshold_hours,
  remaining_work = excluded.remaining_work,
  recovery_plan = excluded.recovery_plan,
  depends_on_titles = excluded.depends_on_titles,
  updated_at = now();
