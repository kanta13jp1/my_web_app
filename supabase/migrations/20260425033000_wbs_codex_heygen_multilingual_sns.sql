update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added a HeyGen multilingual SNS expansion kit%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added a HeyGen multilingual SNS expansion kit to the viral ad generator. Generated ads now produce localized short-video scripts, HeyGen lip-sync briefs, X copy, LinkedIn copy, per-language copy actions, and X intent launch links for Japanese, English, Korean, Chinese, and Spanish distribution.'
  end
where id = '34b6906f-bd90-4e17-821a-b2d269083ae2';
