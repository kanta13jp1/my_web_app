-- Progress the Tome additional-request queue.
--
-- Implementation on 2026-04-26:
-- - Added /tome-deck-studio.
-- - Added TomeDeckStudioService for three request paths:
--   #756 investor / internal reporting deck generation.
--   #757 AI University infographic to Tome page generation.
--   #758 competitor comparison from Airtable-style CSV/TSV source rows.
-- - Added Home catalog entry and direct route.
--
-- Verification:
-- - flutter test test/services/tome_deck_studio_service_test.dart
--   => 3 tests passed.
-- - dart analyze lib/services/tome_deck_studio_service.dart
--   lib/pages/tome_deck_studio_page.dart
--   test/services/tome_deck_studio_service_test.dart
--   => no issues.
-- - dart analyze lib/main.dart lib/data/home_tool_catalog.dart
--   => no issues.

update public.wbs_tasks
set
  instance = 'codex',
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-26'),
  end_date = date '2026-04-26',
  ai_review_status = 'approved',
  github_issue_state = 'CLOSED',
  remaining_work = 'Completed by Codex. Tome Deck Studio was added at /tome-deck-studio with KGI/CSF/KPI deck generation for investor and internal reporting.',
  description = case
    when coalesce(description, '') like '%Done 2026-04-26: Codex added Tome investor/internal deck generation.%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-26: Codex added Tome Deck Studio at /tome-deck-studio. The investor/internal report scenario generates a six-page Tome-ready outline, KGI/CSF/KPI, automation notes, and copyable Tome AI prompt/markdown.'
  end,
  updated_at = now()
where github_issue_number = 756;

update public.wbs_tasks
set
  instance = 'codex',
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-26'),
  end_date = date '2026-04-26',
  ai_review_status = 'approved',
  github_issue_state = 'CLOSED',
  remaining_work = 'Completed by Codex. Tome Deck Studio now generates AI University infographic/page outlines with quiz and RLHF feedback loops.',
  description = case
    when coalesce(description, '') like '%Done 2026-04-26: Codex added AI University Tome infographic generation.%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-26: Codex added the AI University scenario to /tome-deck-studio. It turns provider lessons into visual Tome page outlines, comparison cards, quiz-feedback loops, KGI/CSF/KPI, and shareable infographic prompts.'
  end,
  updated_at = now()
where github_issue_number = 757;

update public.wbs_tasks
set
  instance = 'codex',
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 60),
  start_date = coalesce(start_date, date '2026-04-26'),
  ai_review_status = 'pending',
  github_issue_state = 'OPEN',
  remaining_work = 'Tome Deck Studio supports pasted Airtable CSV/TSV rows for competitor deck drafts. Remaining work: configure Airtable token/base/table mapping and scheduled live refresh into Tome once credentials and destination behavior are confirmed.',
  description = case
    when coalesce(description, '') like '%Progress 2026-04-26: Codex added Airtable-style competitor deck drafting.%'
      then description
    else coalesce(description, '') ||
      E'\n\nProgress 2026-04-26: Codex added Airtable-style competitor deck drafting to /tome-deck-studio. It parses CSV/TSV source rows, builds a comparison deck, and emits Tome-ready prompt/markdown. Live Airtable scheduled sync remains open pending token/base/table mapping and Tome destination behavior.'
  end,
  updated_at = now()
where github_issue_number = 758;
