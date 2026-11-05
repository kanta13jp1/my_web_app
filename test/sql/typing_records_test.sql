\set ON_ERROR_STOP on
-- Disposable PostgreSQL only: minimal Supabase auth fixture, no live endpoint.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
$$;
grant usage on schema auth to anon, authenticated;
\ir ../../docs/typing-game/records-schema.draft.sql

create function public.test_assert(ok boolean, label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'ASSERTION: %', label; end if; end $$;
create function public.test_denied(statement text, expected_state text) returns void language plpgsql as $$
begin
  execute statement;
  raise exception 'Expected rejection: %', statement;
exception when others then
  if sqlstate <> expected_state then raise; end if;
end $$;
insert into auth.users values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
set role anon;
select test_denied($q$select public.typing_game_records('mine')$q$, '42501');
reset role;
set role authenticated;
select test_denied($q$select public.typing_game_records('mine')$q$, '42501');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select set_config('request.jwt.claims', '{"is_anonymous":true}', false);
select test_denied($q$select public.typing_game_records('mine')$q$, '42501');
select set_config('request.jwt.claims', '{"is_anonymous":false}', false);
select test_denied($q$select * from typing_private.runs$q$, '42501');
select test_denied($q$insert into typing_private.entries values ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Stolen')$q$, '42501');
select test_denied($q$select public.typing_game_records('save', null)$q$, '22023');
select test_denied($q$select public.typing_game_records('save', '{}')$q$, '22023');

-- Validate all inputs before accepting a score; score/owner supplied by client rejected.
do $$
declare base jsonb := '{"id":"10000000-0000-0000-0000-000000000001","revision":"romaji36-v1","mode":"challenge","correct":30,"mistakes":2,"words":5,"elapsed_ms":60000}';
 bad jsonb;
begin
 for bad in select value from jsonb_array_elements('[{"score":9999},{"owner_id":"00000000-0000-0000-0000-000000000002"},{"correct":null},{"correct":"30"},{"correct":30.5},{"correct":-1}]') loop
   perform test_denied(format('select public.typing_game_records(''save'', %L::jsonb)', base || bad), '22023');
 end loop;
 perform test_denied(format('select public.typing_game_records(''save'', %L::jsonb)', base || '{"correct":12001}'), '23514');
 perform test_denied(format('select public.typing_game_records(''save'', %L::jsonb)', base || '{"elapsed_ms":59999}'), '23514');
end $$;
select test_assert((public.typing_game_records('save', '{"id":"10000000-0000-0000-0000-000000000001","revision":"romaji36-v1","mode":"challenge","correct":30,"mistakes":2,"words":5,"elapsed_ms":60000}')->>'score')::int = 550, 'server computes score');
-- An identical retry succeeds even inside the frequency window.
select public.typing_game_records('save', '{"id":"10000000-0000-0000-0000-000000000001","revision":"romaji36-v1","mode":"challenge","correct":30,"mistakes":2,"words":5,"elapsed_ms":60000}');
select test_assert(jsonb_array_length(public.typing_game_records('mine')) = 1, 'dedupe');
select test_denied($q$select public.typing_game_records('save', '{"id":"10000000-0000-0000-0000-000000000001","revision":"romaji36-v1","mode":"challenge","correct":31,"mistakes":2,"words":5,"elapsed_ms":60000}')$q$, '22023');
select test_denied($q$select public.typing_game_records('save', '{"id":"10000000-0000-0000-0000-000000000002","revision":"romaji36-v1","mode":"challenge","correct":30,"mistakes":2,"words":5,"elapsed_ms":60000}')$q$, '54000');
select test_assert(public.typing_game_records('ranking') = '[]', 'saving does not publish');
select test_denied($q$select public.typing_game_records('publish', '{"id":"10000000-0000-0000-0000-000000000001","alias":"mail@example.com"}')$q$, '22023');
select test_denied($q$select public.typing_game_records('publish', '{"id":"10000000-0000-0000-0000-000000000001","alias":null}')$q$, '22023');
select public.typing_game_records('publish', '{"id":"10000000-0000-0000-0000-000000000001","alias":"TypingFan"}');
select test_assert(public.typing_game_records('ranking')->0->>'alias' = 'TypingFan', 'explicit publication');
select test_assert(not ((public.typing_game_records('ranking')->0) ?| array['owner_id','id','email','created_at']), 'no identity leakage');

-- A fresh session sees persisted history. Another account cannot change it.
reset role;
set role authenticated;
select test_assert(jsonb_array_length(public.typing_game_records('mine')) = 1, 'reload persisted history');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
select test_assert(public.typing_game_records('mine') = '[]', 'private history');
select test_denied($q$select public.typing_game_records('delete', '{"id":"10000000-0000-0000-0000-000000000001"}')$q$, '42501');
select test_denied($q$select public.typing_game_records('withdraw', '{"id":"10000000-0000-0000-0000-000000000001"}')$q$, '42501');
select test_denied($q$select public.typing_game_records('publish', '{"id":"10000000-0000-0000-0000-000000000001","alias":"Stolen"}')$q$, '42501');
select public.typing_game_records('save', '{"id":"20000000-0000-0000-0000-000000000001","revision":"romaji36-v1","mode":"practice","correct":30,"mistakes":0,"words":10,"elapsed_ms":30000}');
select test_denied($q$select public.typing_game_records('publish', '{"id":"20000000-0000-0000-0000-000000000001","alias":"Practice"}')$q$, '22023');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select public.typing_game_records('withdraw', '{"id":"10000000-0000-0000-0000-000000000001"}');
select test_assert(public.typing_game_records('ranking') = '[]', 'withdraw is effective');
select test_assert(jsonb_array_length(public.typing_game_records('mine')) = 1, 'withdraw retains private history');
select public.typing_game_records('publish', '{"id":"10000000-0000-0000-0000-000000000001","alias":"TypingFan"}');
reset role;
update typing_private.runs set created_at = now() - interval '91 days' where owner_id = '00000000-0000-0000-0000-000000000001';
set role authenticated;
select test_assert(public.typing_game_records('ranking') = '[]', 'expired scores are invisible');
select test_assert(jsonb_array_length(public.typing_game_records('mine')) = 1, 'private history survives publication expiry');
select test_assert(public.typing_game_records('mine')->0->'can_publish' = 'false'::jsonb, 'expired run cannot be republished');
reset role;
select test_assert(not exists(select from typing_private.entries where owner_id = '00000000-0000-0000-0000-000000000001'), 'expiry removes only publication');
select test_assert((select bool_and(relrowsecurity) from pg_class where oid in ('typing_private.runs'::regclass, 'typing_private.entries'::regclass)), 'RLS enabled');
select test_assert(not has_function_privilege('anon','public.typing_game_records(text,jsonb)','execute'), 'anon cannot call');
select test_assert(not has_table_privilege('authenticated','typing_private.runs','insert'), 'direct writes revoked');
-- Rate/day limits still apply after record deletion.
update typing_private.budgets set saves = 100, last_saved = now() - interval '10 seconds' where owner_id = '00000000-0000-0000-0000-000000000001';
set role authenticated;
select test_denied($q$select public.typing_game_records('save', '{"id":"10000000-0000-0000-0000-000000000002","revision":"romaji36-v1","mode":"challenge","correct":30,"mistakes":2,"words":5,"elapsed_ms":60000}')$q$, '54000');
reset role;
-- Reset only the disposable budget fixture for deletion checks.
update typing_private.budgets set day = (now() at time zone 'UTC')::date - 1 where owner_id = '00000000-0000-0000-0000-000000000001';
set role authenticated;
select public.typing_game_records('save', '{"id":"10000000-0000-0000-0000-000000000002","revision":"romaji36-v1","mode":"challenge","correct":30,"mistakes":2,"words":5,"elapsed_ms":60000}');
select public.typing_game_records('publish', '{"id":"10000000-0000-0000-0000-000000000002","alias":"TypingFan"}');
select public.typing_game_records('delete', '{"id":"10000000-0000-0000-0000-000000000002"}');
select test_assert(public.typing_game_records('ranking') = '[]', 'delete removes publication');
select test_denied($q$select public.typing_game_records('save', '{"id":"10000000-0000-0000-0000-000000000003","revision":"romaji36-v1","mode":"challenge","correct":30,"mistakes":2,"words":5,"elapsed_ms":60000}')$q$, '54000');
reset role;
-- A full private history rejects a new record without pruning any old row.
insert into typing_private.runs(owner_id,id,revision,mode,correct,mistakes,words,elapsed_ms,created_at)
select '00000000-0000-0000-0000-000000000002', md5('cap-fixture-' || g)::uuid,
  'romaji36-v1', 'practice', 3, 0, 1, 1000, now() - interval '1 day'
from generate_series(1,99) g;
update typing_private.budgets set day = (now() at time zone 'UTC')::date - 1,
  last_saved = now() - interval '10 seconds' where owner_id = '00000000-0000-0000-0000-000000000002';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
select test_denied($q$select public.typing_game_records('save', '{"id":"20000000-0000-0000-0000-000000000002","revision":"romaji36-v1","mode":"practice","correct":3,"mistakes":0,"words":1,"elapsed_ms":1000}')$q$, '54000');
select test_assert(jsonb_array_length(public.typing_game_records('mine')) = 100, 'full private history is retained');
select test_denied($q$select typing_private.purge_expired_publications()$q$, '42501');
reset role;
\echo TYPING_DATABASE_ASSERTIONS_PASSED
