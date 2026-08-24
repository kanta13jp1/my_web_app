-- Minimal commerce dependency plus one previously completed job. Applying the
-- artifact migration after this fixture proves that existing videos are kept.
create table if not exists public.shop_products (
  id text primary key
);

insert into auth.users (id)
values ('77777777-7777-4777-8777-777777777777')
on conflict (id) do nothing;

insert into public.video_generation_jobs (
  id,
  user_id,
  idempotency_key,
  model_key,
  inference_engine,
  model_revision,
  prompt,
  duration_seconds,
  aspect_ratio,
  resolution,
  status,
  quoted_credits,
  reserved_credits,
  charged_credits,
  output_storage_path,
  completed_at
)
values (
  '88888888-8888-4888-8888-888888888888',
  '77777777-7777-4777-8777-777777777777',
  'artifact-backfill-contract',
  'studio-video-v1',
  'omocha_works_gpu',
  'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e',
  'A designer works in a bright office',
  5,
  '16:9',
  '720p',
  'succeeded',
  300,
  0,
  300,
  '77777777-7777-4777-8777-777777777777/88888888-8888-4888-8888-888888888888-attempt-1.mp4',
  now()
);
