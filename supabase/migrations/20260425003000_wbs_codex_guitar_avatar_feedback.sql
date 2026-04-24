update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added avatar video feedback to the guitar recording studio%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added avatar video feedback to the guitar recording studio so the latest AI evaluation can be explained as a Hedra-backed video coach response, with script fallback and direct video-open UI.'
  end
where title in (
  '[追加要望] ギター評価の進化',
  '[追加要望] ギター評価フィードバック'
);
