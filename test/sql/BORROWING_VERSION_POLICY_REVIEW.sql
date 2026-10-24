-- Review prototype only. Not a migration; not approved or applied.
-- Requires compatible client headers plus role/owner/API tests first.
-- Keep the existing permissive ownership policy unchanged.
-- This is a compatibility marker, NOT authentication or authorization.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '30s';
create policy borrowing_client_compatibility
on public.wealth_struggles
as restrictive
for all
to authenticated
using (
  action_type is distinct from 'borrowing'
  or coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb
      ->> 'x-asset-flow-version',
    ''
  ) = 'borrowing-v1'
)
with check (
  action_type is distinct from 'borrowing'
  or coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb
      ->> 'x-asset-flow-version',
    ''
  ) = 'borrowing-v1'
);
commit;

-- Does not deduplicate CSV deposits against manually entered borrowing.
-- Clients without the marker intentionally cannot see borrowing rows.
-- Rollback must first disable new borrowing entry and review the effect of
-- exposing borrowing rows again to old clients. No rollback is authorized.
