begin;
insert into auth.users values ('11111111-1111-4111-8111-111111111111'), ('22222222-2222-4222-8222-222222222222');
insert into public.wealth_struggles values ('33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111',123),('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222',456);
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.asset_calendar_reflections(user_id,source_key,occurred_on,kinds,title,source_label,linked_flow_id)
 values ('11111111-1111-4111-8111-111111111111','test:a','2026-01-02',array['dining'],'Test meal','Test diary','33333333-3333-4333-8333-333333333333');
-- Same import is idempotent; unknown amount remains null.
insert into public.asset_calendar_reflections(user_id,source_key,occurred_on,kinds,title,source_label)
 values ('11111111-1111-4111-8111-111111111111','test:a','2026-01-02',array['dining'],'Test meal','Test diary') on conflict(user_id,source_key) do nothing;
do $$ begin
 if (select count(*) from public.asset_calendar_reflections) <> 1 then raise exception 'dedup failed'; end if;
 if (select verified_amount from public.asset_calendar_reflections limit 1) is not null then raise exception 'unknown fabricated'; end if;
 begin
  update public.asset_calendar_reflections set user_id='22222222-2222-4222-8222-222222222222';
  raise exception 'owner reassignment allowed';
 exception when insufficient_privilege then null; end;
 begin
  update public.asset_calendar_reflections set linked_flow_id='44444444-4444-4444-8444-444444444444';
  raise exception 'foreign flow allowed';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$ begin
 if exists(select 1 from public.asset_calendar_reflections) then raise exception 'cross-user read'; end if;
 update public.asset_calendar_reflections set title='bad';
 if found then raise exception 'cross-user update'; end if;
 delete from public.asset_calendar_reflections;
 if found then raise exception 'cross-user delete'; end if;
 begin
  insert into public.asset_calendar_reflections(user_id,source_key,occurred_on,kinds,title,source_label)
  values ('11111111-1111-4111-8111-111111111111','bad','2026-01-02',array['reading'],'Bad','Test');
  raise exception 'cross-user insert';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform 1 from public.asset_calendar_reflections; raise exception 'anon read'; exception when insufficient_privilege then null; end;
 begin insert into public.asset_calendar_reflections(user_id,source_key,occurred_on,kinds,title,source_label) values ('11111111-1111-4111-8111-111111111111','anon','2026-01-02',array['reading'],'Bad','Test'); raise exception 'anon insert'; exception when insufficient_privilege then null; end;
 begin update public.asset_calendar_reflections set title='bad'; raise exception 'anon update'; exception when insufficient_privilege then null; end;
 begin delete from public.asset_calendar_reflections; raise exception 'anon delete'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 if (select sum(amount) from public.wealth_struggles) <> 579 then raise exception 'financial totals changed'; end if;
end $$;
rollback;
