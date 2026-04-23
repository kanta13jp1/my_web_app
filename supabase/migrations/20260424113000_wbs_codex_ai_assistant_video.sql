update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  description = coalesce(description, '') ||
    E'\n\n[done] Codex: ai-assistant に Hedra 動画回答 action を追加し、/ai-assistant チャットから動画回答モードを選んで返答動画URL/状態を受け取れるようにした。'
where id = '394aaf93-d491-4014-b20d-c1b329969160';
