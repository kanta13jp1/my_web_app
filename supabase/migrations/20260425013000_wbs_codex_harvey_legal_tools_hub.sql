update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added Harvey Completion API support to tools-hub%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added Harvey Completion API support to tools-hub as legal.harvey.complete, wired the legal management UI to that action, and exposed configurable prompt, mode, citations, web knowledge, and matter/model inputs.'
  end
where title = '[追加要望] legal-assistant EF: Harvey APIをtools-hub の新actionとして追加可能';

update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex updated the LP legal management message to highlight Harvey%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex updated the LP legal management message to highlight Harvey-backed legal review as part of the product positioning.'
  end
where title = '[追加要望] LP掲載: 「法務管理」コア機能のバックエンドとしてHarveyをアピール材料に';
