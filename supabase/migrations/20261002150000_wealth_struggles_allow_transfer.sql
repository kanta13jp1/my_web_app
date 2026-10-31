-- Keep existing action types; transfers are account movements, not expenses.
-- A short lock timeout avoids blocking live bookkeeping during deployment.
set lock_timeout = '5s';
alter table public.wealth_struggles
  drop constraint if exists wealth_struggles_action_type_check,
  add constraint wealth_struggles_action_type_check
    check (action_type in ('defend', 'conquer', 'invest', 'expense', 'transfer'));
reset lock_timeout;
