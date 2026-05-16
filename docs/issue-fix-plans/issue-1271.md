# Issue #1271: AI日記分析・フィードバック

## Goal

Daily diary entries should turn into actionable feedback: emotion/trigger analysis, next-day action proposals, and saved records that can be reviewed later.

## Implemented slice

- `mental_health_records` table with RLS and AI analysis columns.
- `lifestyle-hub` actions:
  - `journal.analyze`: save or load a diary record, analyze it with `ai-hub` when available, fall back to deterministic local analysis, and create next-day `daily_todos`.
  - `journal.list`: list the user's recent diary analysis records.
- `MentalHealthTrackerPage` now has clean Japanese copy, an "AI分析して保存" flow, history cards, tags, and next-action display.

## Validation

- `deno test --config supabase/functions/deno.json supabase/functions/lifestyle-hub/journal_analysis_test.ts`
- `deno check --config supabase/functions/deno.json supabase/functions/lifestyle-hub/index.ts`
- `deno lint --config supabase/functions/deno.json supabase/functions/lifestyle-hub/index.ts supabase/functions/lifestyle-hub/journal_analysis.ts supabase/functions/lifestyle-hub/journal_analysis_test.ts`
- `flutter analyze lib/pages/mental_health_tracker_page.dart`
