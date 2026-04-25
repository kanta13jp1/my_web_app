-- Complete Tome competitor comparison / Airtable integration request.
--
-- Implementation on 2026-04-26:
-- - Added enterprise-hub action: tome.competitor_airtable_deck.
-- - Reads Airtable when AIRTABLE_API_KEY/PAT, AIRTABLE_BASE_ID, and
--   AIRTABLE_TABLE_NAME or AIRTABLE_COMPETITOR_TABLE are configured.
-- - Falls back to public.competitors when Airtable is not configured or fails.
-- - Returns CSV and Tome-ready markdown, and stores a tome_competitor_deck
--   report in hub_data.
-- - Added /tome-deck-studio button to sync Airtable / competitor source.
--
-- Verification:
-- - flutter test test/services/tome_deck_studio_service_test.dart
--   => 3 tests passed.
-- - dart analyze lib/pages/tome_deck_studio_page.dart
--   lib/services/tome_deck_studio_service.dart
--   test/services/tome_deck_studio_service_test.dart
--   => no issues.
-- - dart analyze lib/main.dart lib/data/home_tool_catalog.dart
--   => no issues.
-- - deno check --config supabase/functions/deno.json
--   supabase/functions/enterprise-hub/index.ts
--   => passed.

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
  remaining_work = 'Completed by Codex. /tome-deck-studio can sync Airtable-backed competitor rows through enterprise-hub action tome.competitor_airtable_deck, with Supabase competitors fallback when Airtable secrets are not configured.',
  description = case
    when coalesce(description, '') like '%Done 2026-04-26: Codex completed Tome competitor Airtable sync.%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-26: Codex completed Tome competitor Airtable sync. The /tome-deck-studio competitor scenario now calls enterprise-hub action tome.competitor_airtable_deck to load Airtable rows when secrets are present, fall back to public.competitors, generate CSV/Tome markdown, and store the generated deck report in hub_data.'
  end,
  updated_at = now()
where github_issue_number = 758;
