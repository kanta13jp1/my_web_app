-- Isolated CI database only; transaction rollback removes synthetic users/rows.
begin;
create schema if not exists auth;
create table if not exists auth.users(id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create or replace function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
grant usage on schema auth to authenticated,anon;
grant execute on function auth.uid(),auth.jwt() to authenticated,anon;
\i supabase/migrations/20260927115703_jev_mario_campaigns.sql
insert into auth.users values('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
set local role anon;
do $$ begin
 begin perform public.jev_mario_campaigns('mine');raise exception 'anon unexpectedly allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select public.jev_mario_campaigns('submit','{"id":"10000000-0000-4000-8000-000000000001","revision":"world6-1","course":17,"controller":"manual","power":0,"outcome":"won","score":1200,"reached":18,"cleared":17,"elapsed_ms":15000,"eligible":true}');
do $$ declare n int;v jsonb;begin
 v:=public.jev_mario_campaigns('mine');if jsonb_array_length(v)<>1 or v::text like '%user_id%' then raise exception 'history isolation';end if;
 v:=public.jev_mario_campaigns('list','{"course":17,"controller":"manual","power":0}');if jsonb_array_length(v)<>1 or v::text like '%00000000-0000%' then raise exception 'public id exposed';end if;
 begin select count(*) into n from mario_private.campaigns;raise exception 'direct table read allowed';exception when insufficient_privilege then null;end;
 begin insert into mario_private.campaigns(user_id,id) values(auth.uid(),gen_random_uuid());raise exception 'direct insert allowed';exception when insufficient_privilege then null;end;
 begin update mario_private.campaigns set score=0;raise exception 'direct update allowed';exception when insufficient_privilege then null;end;
 begin delete from mario_private.campaigns;raise exception 'direct delete allowed';exception when insufficient_privilege then null;end;
 -- Idempotent retry must work even inside the frequency window.
 perform public.jev_mario_campaigns('submit','{"id":"10000000-0000-4000-8000-000000000001"}');
 begin perform public.jev_mario_campaigns('submit','{"id":"10000000-0000-4000-8000-000000000002"}');raise exception 'rate limit absent';exception when raise_exception then if sqlerrm<>'rate_limit' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $$ begin
 if public.jev_mario_campaigns('mine')<>'[]'::jsonb then raise exception 'other user history leak';end if;
 begin perform public.jev_mario_campaigns('submit','{"id":"10000000-0000-4000-8000-000000000002","revision":"world6-1","course":17,"controller":"manual","power":0,"outcome":"won","score":-1,"reached":18,"cleared":17,"elapsed_ms":15000,"eligible":true}');raise exception 'negative score allowed';exception when check_violation then null;end;
end $$;
select public.jev_mario_campaigns('submit','{"id":"10000000-0000-4000-8000-000000000002","revision":"world6-1","course":17,"controller":"manual","power":0,"outcome":"dead","score":99999,"reached":17,"cleared":16,"elapsed_ms":9000,"eligible":true}');
do $$ declare v jsonb;begin
 v:=public.jev_mario_campaigns('list','{"course":17,"controller":"manual","power":0}');if jsonb_array_length(v)<>2 or v->0->>'outcome'<>'won' then raise exception 'clear ordering';end if;
 if public.jev_mario_campaigns('list','{"course":18,"controller":"manual","power":0}')<>'[]'::jsonb then raise exception 'course filter';end if;
 if public.jev_mario_campaigns('list','{"course":17,"controller":"jev_only","power":0}')<>'[]'::jsonb then raise exception 'controller filter';end if;
 if public.jev_mario_campaigns('list','{"course":17,"controller":"manual","power":1}')<>'[]'::jsonb then raise exception 'power filter';end if;
end $$;
select set_config('request.jwt.claims','{"is_anonymous":true}',true);
do $$ begin
 begin perform public.jev_mario_campaigns('mine');raise exception 'anonymous sign in allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
