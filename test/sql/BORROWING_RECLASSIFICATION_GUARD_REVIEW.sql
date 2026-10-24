-- Review candidate only. NOT a migration; not applied or approved.
-- Narrow protection: stops borrowing -> another action_type on UPDATE.
-- Also blocks legitimate type corrections until a reviewed correction path exists.
-- Does NOT fix old-client display, deletion, amount edits, or CSV matching.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '30s';

create function public.reject_borrowing_reclassification()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using
    errcode = '23514',
    message = 'Borrowing classification requires a reviewed correction path';
end;
$$;

revoke all on function public.reject_borrowing_reclassification() from public;

create trigger protect_borrowing_classification
before update of action_type on public.wealth_struggles
for each row
when (old.action_type = 'borrowing'
      and new.action_type is distinct from old.action_type)
execute function public.reject_borrowing_reclassification();
commit;

-- Rollback candidate (separate approval required): drop trigger first, then
-- drop this function. Data is not changed, but removing the guard reopens the
-- old-client reclassification risk. No automatic rollback is authorized.
