-- Extend only course/revision domains. Preserve the approved authenticated sharing model.
alter table mario_private.campaigns drop constraint campaigns_revision_check;
alter table mario_private.campaigns add constraint campaigns_revision_check check (revision in ('world6-1','world7-1','world8-1'));
alter table mario_private.campaigns drop constraint campaigns_course_check;
alter table mario_private.campaigns add constraint campaigns_course_check check (course between 1 and 32);
alter table mario_private.campaigns drop constraint campaigns_reached_check;
alter table mario_private.campaigns add constraint campaigns_reached_check check (reached between course and 32);

create or replace function mario_private.campaign_access(p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 uid uuid := auth.uid(); r mario_private.campaigns; result jsonb; run_id uuid;
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
  if exists(select 1 from mario_private.campaigns where user_id=uid and id=run_id) then return jsonb_build_object('saved',true); end if;
  if exists(select 1 from mario_private.campaigns where user_id=uid and created_at>now()-interval '5 seconds') then raise exception 'rate_limit'; end if;
  if (select count(*) from mario_private.campaigns where user_id=uid and created_at>now()-interval '1 day')>=100 then raise exception 'daily_limit'; end if;
  insert into mario_private.campaigns(user_id,id,revision,course,controller,power,outcome,score,reached,cleared,elapsed_ms,eligible)
  values(uid,run_id,p_data->>'revision',(p_data->>'course')::smallint,p_data->>'controller',(p_data->>'power')::smallint,p_data->>'outcome',(p_data->>'score')::integer,(p_data->>'reached')::smallint,(p_data->>'cleared')::smallint,(p_data->>'elapsed_ms')::integer,(p_data->>'eligible')::boolean);
  -- Bounded retained history per account; shared best scores are within these 100 runs.
  delete from mario_private.campaigns where user_id=uid and id in
    (select id from mario_private.campaigns where user_id=uid order by created_at desc,id offset 100);
  return jsonb_build_object('saved',true);
 elsif p_action='mine' then
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from
   (select id,revision,course,controller,power,outcome,score,reached,cleared,elapsed_ms,eligible,created_at from mario_private.campaigns where user_id=uid order by created_at desc,id limit 100) x;
  return result;
 elsif p_action='list' then
  if p_data->>'course' is null or p_data->>'controller' is null or p_data->>'power' is null or not ((p_data->>'course')::int between 1 and 32) or (p_data->>'controller') not in ('manual','jev_only','jev_plus_local','lightgbm_plus_search') or not ((p_data->>'power')::int between 0 and 2) then raise exception 'invalid_filter'; end if;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
   select 'Player-'||left(md5(user_id::text),8) as player,outcome,score,reached,cleared,elapsed_ms,created_at from (
    select *, row_number() over(partition by user_id order by reached desc,cleared desc,score desc,elapsed_ms,created_at,id) as place
    from mario_private.campaigns where eligible and revision='world8-1' and course=(p_data->>'course')::int and controller=p_data->>'controller' and power=(p_data->>'power')::int
   ) ranked where place=1 order by reached desc,cleared desc,score desc,elapsed_ms,created_at,id limit 20
  ) x;
  return result;
 else raise exception 'invalid_action'; end if;
end $$;
revoke all on function mario_private.campaign_access(text,jsonb) from public,anon,authenticated;
grant execute on function mario_private.campaign_access(text,jsonb) to authenticated;
