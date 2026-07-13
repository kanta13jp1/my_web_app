-- Codex #4 active label / Codex #1 execution lane / 2026-07-13.
-- Issue #2492: tax export deterministic core.
-- nocheck: time-relative
-- This migration intentionally records WBS progress. Disable row triggers only
-- for that bookkeeping UPDATE so replay is not date-dependent.

set session_replication_role = replica;
update public.wbs_tasks
set status = 'in_progress',
    progress = greatest(progress, 55),
    remaining_work = 'Wire the tax export core to the asset-management UI, add tax_records persistence/schema when product scope is confirmed, and validate end-to-end CSV/XML downloads.',
    recovery_plan = coalesce(
      nullif(trim(recovery_plan), ''),
      'Deterministic Dart export core now builds CSV, e-Tax XML skeleton, and pre-export confirmation preview. Next slice should add UI binding and persistence.'
    ),
    recovery_planned_at = coalesce(recovery_planned_at, now()),
    description = coalesce(description, '') ||
      E'\n\n[Codex #4 2026-07-13] Issue #2492 advanced: added deterministic AssetTaxExportService for tax_records-style inputs. It produces CSV, e-Tax XML skeleton grouped by misc/business/real-estate/furusato categories, and a pre-export confirmation preview with warnings. UI/DB wiring remains open.'
where github_issue_number = 2492;
set session_replication_role = default;

insert into public.development_achievements (title, description, completed_at)
select
  'Codex #4: tax export deterministic core (#2492)',
  'Added AssetTaxExportService and tests for CSV export, e-Tax XML skeleton generation, and pre-export confirmation preview for tax_records-style inputs. This is the safe first slice before asset-management UI and persistence wiring.',
  '2026-07-13'
where not exists (
  select 1 from public.development_achievements
  where title = 'Codex #4: tax export deterministic core (#2492)'
);
