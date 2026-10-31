-- Review draft only. Not executed against production.
-- Keep all existing action types, amount checks, grants and RLS policies.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '30s';
alter table public.wealth_struggles
  drop constraint wealth_struggles_action_type_check,
  add constraint wealth_struggles_action_type_check
  check (action_type in (
    'defend', 'conquer', 'invest', 'expense', 'transfer', 'borrowing'
  ));
commit;

-- Rollback is permitted only before borrowing rows exist. Never remove rows
-- or relabel a borrowing receipt as income merely to make rollback succeed.
-- If receipts already exist, disable new UI entry and preserve the expanded
-- constraint until a separately reviewed data-preserving plan is available.
