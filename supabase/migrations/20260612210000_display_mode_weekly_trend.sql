-- 表示モード実験集計の時系列トレンド化 (週次バケット / 個人情報なし)。
-- display_mode_events は append-only なので追加テーブル不要で導出できる。
create or replace function public.display_mode_experiment_summary()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'initial_minimum',
      count(*) filter (where event_type = 'initial' and mode = 'minimum'),
    'initial_standard',
      count(*) filter (where event_type = 'initial' and mode = 'standard'),
    'initial_full',
      count(*) filter (where event_type = 'initial' and mode = 'full'),
    'switch_total', count(*) filter (where event_type = 'switch'),
    'standard_retained', (
      select count(*)
      from display_mode_events i
      where i.event_type = 'initial' and i.mode = 'standard'
        and not exists (
          select 1 from display_mode_events s
          where s.user_id = i.user_id
            and s.event_type = 'switch'
            and s.created_at > i.created_at
        )
    ),
    'weekly', (
      select coalesce(
        jsonb_agg(week_row order by week_start desc),
        '[]'::jsonb
      )
      from (
        select
          date_trunc('week', created_at)::date as week_start,
          jsonb_build_object(
            'week_start', date_trunc('week', created_at)::date,
            'initials',
              count(*) filter (where event_type = 'initial'),
            'initial_standard',
              count(*) filter (
                where event_type = 'initial' and mode = 'standard'
              ),
            'switches', count(*) filter (where event_type = 'switch')
          ) as week_row
        from display_mode_events
        group by 1
        order by 1 desc
        limit 8
      ) weeks
    )
  )
  from display_mode_events;
$$;

revoke all on function public.display_mode_experiment_summary() from public;
revoke all on function public.display_mode_experiment_summary() from anon;
grant execute on function public.display_mode_experiment_summary()
  to authenticated;
