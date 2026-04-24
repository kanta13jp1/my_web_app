alter table public.viral_ad_generations
  add column if not exists generated_video_url text,
  add column if not exists generated_preview_url text,
  add column if not exists generated_download_url text,
  add column if not exists video_provider text,
  add column if not exists video_status text,
  add column if not exists video_reason text;

update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added Hedra presenter-video generation to viral-video-ad-generator%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added Hedra presenter-video generation to viral-video-ad-generator, including UI output switching, video preview/open flow, X post routing, and history support for presenter videos.'
  end
where title = '[追加要望] バイラル動画パイプライン強化';
