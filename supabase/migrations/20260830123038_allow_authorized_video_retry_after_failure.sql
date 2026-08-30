-- A terminal failed/cancelled generation must not permanently consume the
-- source review. The authorization envelope already counts every attempt, so
-- a bounded retry can safely reuse the same review while budget remains.
-- Keep queued, in-progress, and succeeded children as hard duplicate guards.
do $migration$
declare
  v_function regprocedure;
  v_definition text;
  v_updated text;
  v_marker constant text :=
    'and applied_review_id = p_source_review_id' || chr(10) ||
    '  ) then';
  v_replacement constant text :=
    'and applied_review_id = p_source_review_id' || chr(10) ||
    '      and status in (''queued'', ''in_progress'', ''succeeded'')' || chr(10) ||
    '  ) then';
begin
  foreach v_function in array array[
    'public.video_authorize_and_reserve_improvement(uuid,text,uuid,uuid,timestamptz,smallint,boolean,boolean,boolean,boolean)'::regprocedure,
    'public.video_reserve_authorized_improvement(uuid,uuid,uuid,uuid,text)'::regprocedure
  ] loop
    select pg_get_functiondef(v_function)
    into strict v_definition;

    if (
      char_length(v_definition) - char_length(replace(v_definition, v_marker, ''))
    ) / char_length(v_marker) <> 1 then
      raise exception 'video_retry_guard_marker_count_invalid:%', v_function::text;
    end if;

    v_updated := replace(v_definition, v_marker, v_replacement);
    execute v_updated;
  end loop;
end;
$migration$;

comment on function public.video_reserve_authorized_improvement(
  uuid,
  uuid,
  uuid,
  uuid,
  text
) is
  'Reserves one bounded improvement attempt. Failed/cancelled attempts may retry the same review; active or succeeded children remain duplicate-protected.';
