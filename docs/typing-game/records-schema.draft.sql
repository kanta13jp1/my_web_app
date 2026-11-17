-- REVIEW DRAFT ONLY. Not in migrations; never apply automatically.
-- Proposed: authenticated audience, alias, 90-day visibility, 100 retained runs.
-- No automatic deletion, private-history pruning, purge function or cron.
-- Requires owner decisions and reviewed migration before enabling the client.
begin;
create schema typing_private;
revoke all on schema typing_private from public, anon, authenticated, service_role;
grant usage on schema typing_private to authenticated;

create table typing_private.runs (
  owner_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  revision text not null check (revision = 'romaji36-v1'),
  mode text not null check (mode in ('challenge', 'practice')),
  correct integer not null check (correct between 0 and 12000),
  mistakes integer not null check (mistakes between 0 and 12000),
  words integer not null check (words between 0 and 2000),
  elapsed_ms integer not null check (elapsed_ms between 0 and 86400000),
  score integer generated always as (correct * 10 + words * 50) stored,
  created_at timestamptz not null default now(),
  primary key (owner_id, id),
  check (correct >= words * 3 and correct <= words * 32 + 31),
  check ((mode = 'challenge' and elapsed_ms = 60000) or
         (mode = 'practice' and words <= 10))
);
create table typing_private.entries (
  owner_id uuid not null,
  id uuid not null,
  alias text not null check (alias ~ '^[A-Za-z0-9][A-Za-z0-9 _-]{2,23}$' and alias = btrim(alias)),
  primary key (owner_id, id),
  foreign key (owner_id, id) references typing_private.runs(owner_id, id) on delete cascade
);
-- Per-day budget survives record deletion so retry/delete cannot bypass limits.
create table typing_private.budgets (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  day date not null,
  saves integer not null check (saves between 0 and 100),
  last_saved timestamptz not null
);
alter table typing_private.runs enable row level security;
alter table typing_private.entries enable row level security;
alter table typing_private.budgets enable row level security;
revoke all on typing_private.runs, typing_private.entries from public, anon, authenticated, service_role;
revoke all on typing_private.budgets from public, anon, authenticated, service_role;
create policy own_run on typing_private.runs for select to authenticated using ((select auth.uid()) = owner_id);
create policy own_entry on typing_private.entries for select to authenticated using ((select auth.uid()) = owner_id);
create index typing_runs_recent on typing_private.runs(owner_id, created_at desc);

-- Private definer implementation is required to mediate rows without granting
-- direct table writes or letting clients choose their owner. No dynamic SQL.
create function typing_private.records(p_action text, p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  run_id uuid;
  v_run typing_private.runs;
  result jsonb;
  v_correct integer;
  v_mistakes integer;
  v_words integer;
  v_elapsed integer;
begin
  if uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    raise exception 'login_required' using errcode = '42501';
  end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' or octet_length(p_data::text) > 2000 then
    raise exception 'invalid_record' using errcode = '22023';
  end if;
  -- Serialization covers dedupe, limits, delete and publication for this owner.
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 64312));
  -- Expiry is a read filter only; neither private nor published rows are
  -- automatically deleted. Only explicit owner actions below can remove rows.

  if p_action = 'save' then
    if not (p_data ?& array['id','revision','mode','correct','mistakes','words','elapsed_ms']) or
       (p_data - array['id','revision','mode','correct','mistakes','words','elapsed_ms']) <> '{}'::jsonb then
      raise exception 'invalid_record' using errcode = '22023';
    end if;
    if jsonb_typeof(p_data->'id') <> 'string' or jsonb_typeof(p_data->'revision') <> 'string' or
       jsonb_typeof(p_data->'mode') <> 'string' then
      raise exception 'invalid_record' using errcode = '22023';
    end if;
    -- Accept JSON integers only (not string coercions, nulls, fractions or exponents).
    if not (p_data->'correct')::text ~ '^[0-9]{1,5}$' or
       not (p_data->'mistakes')::text ~ '^[0-9]{1,5}$' or
       not (p_data->'words')::text ~ '^[0-9]{1,5}$' or
       not (p_data->'elapsed_ms')::text ~ '^[0-9]{1,8}$' or
       p_data->'correct' = 'null'::jsonb or p_data->'mistakes' = 'null'::jsonb or
       p_data->'words' = 'null'::jsonb or p_data->'elapsed_ms' = 'null'::jsonb then
      raise exception 'invalid_record' using errcode = '22023';
    end if;
    run_id := (p_data->>'id')::uuid;
    v_correct := (p_data->>'correct')::integer;
    v_mistakes := (p_data->>'mistakes')::integer;
    v_words := (p_data->>'words')::integer;
    v_elapsed := (p_data->>'elapsed_ms')::integer;
    if run_id is null then raise exception 'invalid_record' using errcode = '22023'; end if;
    select * into v_run from typing_private.runs where owner_id = uid and id = run_id;
    if found then
      if v_run.revision is distinct from p_data->>'revision' or v_run.mode is distinct from p_data->>'mode' or
         v_run.correct <> v_correct or v_run.mistakes <> v_mistakes or v_run.words <> v_words or v_run.elapsed_ms <> v_elapsed then
        raise exception 'run_id_conflict' using errcode = '22023';
      end if;
      return jsonb_build_object('saved', true, 'score', v_run.score);
    end if;
    if exists(select 1 from typing_private.budgets where owner_id = uid and last_saved > now() - interval '5 seconds') then
      raise exception 'rate_limit' using errcode = '54000';
    end if;
    if exists(select 1 from typing_private.budgets where owner_id = uid and day = (now() at time zone 'UTC')::date and saves >= 100) then
      raise exception 'daily_limit' using errcode = '54000';
    end if;
    -- Reaching the history cap rejects a new save; it never deletes private
    -- history. The owner must deliberately delete records to make room.
    if (select count(*) from typing_private.runs where owner_id = uid) >= 100 then
      raise exception 'history_limit' using errcode = '54000';
    end if;
    insert into typing_private.runs(owner_id, id, revision, mode, correct, mistakes, words, elapsed_ms)
      values(uid, run_id, p_data->>'revision', p_data->>'mode', v_correct, v_mistakes, v_words, v_elapsed)
      returning * into v_run;
    insert into typing_private.budgets(owner_id, day, saves, last_saved)
      values(uid, (now() at time zone 'UTC')::date, 1, now())
      on conflict (owner_id) do update set
        day = excluded.day,
        saves = case when typing_private.budgets.day = excluded.day then typing_private.budgets.saves + 1 else 1 end,
        last_saved = excluded.last_saved;
    return jsonb_build_object('saved', true, 'score', v_run.score);
  elsif p_action in ('publish', 'withdraw', 'delete') then
    if not (p_data ? 'id') or jsonb_typeof(p_data->'id') <> 'string' or
       (p_data - case when p_action = 'publish' then array['id','alias'] else array['id'] end) <> '{}'::jsonb then
      raise exception 'invalid_record' using errcode = '22023';
    end if;
    run_id := (p_data->>'id')::uuid;
    select * into v_run from typing_private.runs where owner_id = uid and id = run_id;
    if not found then raise exception 'record_not_found' using errcode = '42501'; end if;
    if p_action = 'publish' then
      if v_run.mode <> 'challenge' or v_run.created_at <= now() - interval '90 days' or
         not (p_data ? 'alias') or jsonb_typeof(p_data->'alias') <> 'string' or
         not (p_data->>'alias') ~ '^[A-Za-z0-9][A-Za-z0-9 _-]{2,23}$' or
         p_data->>'alias' <> btrim(p_data->>'alias') then
        raise exception 'invalid_publication' using errcode = '22023';
      end if;
      insert into typing_private.entries(owner_id, id, alias) values(uid, run_id, p_data->>'alias')
        on conflict (owner_id, id) do update set alias = excluded.alias;
    elsif p_action = 'withdraw' then
      delete from typing_private.entries where owner_id = uid and id = run_id;
    else
      delete from typing_private.runs where owner_id = uid and id = run_id;
    end if;
    return jsonb_build_object('updated', true);
  elsif p_action = 'mine' and p_data = '{}'::jsonb then
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result from (
      select r.id, r.mode, r.correct, r.mistakes, r.words, r.elapsed_ms, r.score, r.created_at, e.alias,
        (r.mode = 'challenge' and r.created_at > now() - interval '90 days') as can_publish
      from typing_private.runs r left join typing_private.entries e using(owner_id, id)
      where r.owner_id = uid order by r.created_at desc, r.id limit 100
    ) x;
    return result;
  elsif p_action = 'ranking' and p_data = '{}'::jsonb then
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result from (
      select alias, score, accuracy, words from (
        select e.alias, r.score, r.words,
          case when r.correct + r.mistakes = 0 then 100.0 else round(r.correct * 100.0 / (r.correct + r.mistakes), 1) end as accuracy,
          r.created_at, r.id,
          row_number() over(partition by r.owner_id order by r.score desc, r.mistakes, r.created_at, r.id) as place
        from typing_private.entries e join typing_private.runs r using(owner_id, id)
        where r.created_at > now() - interval '90 days' and r.revision = 'romaji36-v1' and r.mode = 'challenge'
      ) ranked where place = 1 order by score desc, accuracy desc, created_at, id limit 20
    ) x;
    return result;
  else
    raise exception 'invalid_action' using errcode = '22023';
  end if;
end $$;
revoke all on function typing_private.records(text,jsonb) from public, anon, authenticated, service_role;
grant execute on function typing_private.records(text,jsonb) to authenticated;
create function public.typing_game_records(p_action text, p_data jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path = '' as $$
  select typing_private.records(p_action, p_data);
$$;
revoke all on function public.typing_game_records(text,jsonb) from public, anon, authenticated, service_role;
grant execute on function public.typing_game_records(text,jsonb) to authenticated;
comment on function public.typing_game_records(text,jsonb) is
  'Private opt-in history and separately published self-reported romaji36 scores; not verified competitive results.';

commit;
