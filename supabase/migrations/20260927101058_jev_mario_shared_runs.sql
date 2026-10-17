-- Self-reported game records. No email, public auth UUID or arbitrary display name.
create schema if not exists mario_private;
revoke all on schema mario_private from public, anon, authenticated;
grant usage on schema mario_private to authenticated;
create table mario_private.runs (
 user_id uuid not null references auth.users(id) on delete cascade,
 id uuid not null,
 revision text not null check (revision = 'world5-1'),
 course smallint not null check (course between 1 and 20),
 controller text not null check (controller in ('manual','jev_only','jev_plus_local','lightgbm_plus_search')),
 power smallint not null check (power between 0 and 2),
 outcome text not null check (outcome in ('won','dead','stopped')),
 score integer not null check (score between 0 and 1000000),
 frames integer not null check (frames between 1 and 216000),
 eligible boolean not null,
 created_at timestamptz not null default now(),
 primary key (user_id,id)
);
alter table mario_private.runs enable row level security;
revoke all on mario_private.runs from public, anon, authenticated;
create policy own_run on mario_private.runs for select to authenticated using ((select auth.uid()) = user_id);
create index mario_runs_recent on mario_private.runs (user_id,created_at desc);
create index mario_runs_rank on mario_private.runs (revision,course,controller,power,outcome,score desc,frames) where eligible;

-- Privileged implementation is in a non-exposed schema. Every path verifies identity.
create function mario_private.run_access(p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 uid uuid := auth.uid(); r mario_private.runs; result jsonb; run_id uuid;
begin
 if uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
  raise exception 'login_required' using errcode='42501';
 end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>3000 then raise exception 'invalid_record'; end if;
 if p_action='submit' then
  run_id := (p_data->>'id')::uuid;
  if run_id is null then raise exception 'invalid_record'; end if;
  -- Serialize by user so parallel submissions cannot bypass the frequency limit.
  perform pg_advisory_xact_lock(hashtextextended(uid::text,75421));
  if exists(select 1 from mario_private.runs where user_id=uid and id=run_id) then return jsonb_build_object('saved',true); end if;
  if exists(select 1 from mario_private.runs where user_id=uid and created_at>now()-interval '5 seconds') then raise exception 'rate_limit'; end if;
  if (select count(*) from mario_private.runs where user_id=uid and created_at>now()-interval '1 day')>=100 then raise exception 'daily_limit'; end if;
  insert into mario_private.runs(user_id,id,revision,course,controller,power,outcome,score,frames,eligible)
  values(uid,run_id,p_data->>'revision',(p_data->>'course')::smallint,p_data->>'controller',(p_data->>'power')::smallint,p_data->>'outcome',(p_data->>'score')::integer,(p_data->>'frames')::integer,(p_data->>'eligible')::boolean);
  -- Bounded retained history per account; shared best scores are within these 100 runs.
  delete from mario_private.runs where user_id=uid and id in
    (select id from mario_private.runs where user_id=uid order by created_at desc,id offset 100);
  return jsonb_build_object('saved',true);
 elsif p_action='mine' then
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from
   (select id,revision,course,controller,power,outcome,score,frames,eligible,created_at from mario_private.runs where user_id=uid order by created_at desc,id limit 100) x;
  return result;
 elsif p_action='list' then
  if not ((p_data->>'course')::int between 1 and 20) or (p_data->>'controller') not in ('manual','jev_only','jev_plus_local','lightgbm_plus_search') or not ((p_data->>'power')::int between 0 and 2) then raise exception 'invalid_filter'; end if;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
   select 'Player-'||left(md5(user_id::text),8) as player,outcome,score,frames,created_at from (
    select *, row_number() over(partition by user_id order by (outcome='won') desc,score desc,frames,created_at,id) as place
    from mario_private.runs where eligible and revision='world5-1' and course=(p_data->>'course')::int and controller=p_data->>'controller' and power=(p_data->>'power')::int
   ) ranked where place=1 order by (outcome='won') desc,score desc,frames,created_at,id limit 20
  ) x;
  return result;
 else raise exception 'invalid_action'; end if;
end $$;
revoke all on function mario_private.run_access(text,jsonb) from public,anon,authenticated;
grant execute on function mario_private.run_access(text,jsonb) to authenticated;
create function public.jev_mario_runs(p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path = '' as $$
 select mario_private.run_access(p_action,p_data);
$$;
revoke all on function public.jev_mario_runs(text,jsonb) from public,anon,authenticated;
grant execute on function public.jev_mario_runs(text,jsonb) to authenticated;
comment on function public.jev_mario_runs(text,jsonb) is 'Authenticated, self-reported Mario history/ranking. Never verified competitive scores.';
