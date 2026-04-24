update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added a Legal AI genre entry point to AI University%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added a Legal AI genre entry point to AI University and the Home card, wired direct Harvey launch, seeded a legal-AI tutorial, and aligned Harvey provider status with the existing tools-hub integration.'
  end
where title = '[追加要望] AI大学コンテンツ: 法律AIという新ジャンルを開拓（競合は未対応が多い）';
