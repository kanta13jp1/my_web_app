-- 標準維持率の推移 (週末時点 as-of) を集計へ追加。CFO カードの折れ線用。
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
    'first_event_at', (select min(created_at) from display_mode_events),
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
    ),
    'weekly_retention', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object('week_start', week_start, 'rate', rate)
          order by week_start desc
        ),
        '[]'::jsonb
      )
      from (
        select
          w.week_start,
          case
            when totals.total = 0 then null
            else round(100.0 * totals.kept / totals.total)
          end as rate
        from (
          select distinct
            date_trunc('week', created_at)::date as week_start,
            date_trunc('week', created_at) + interval '7 days' as week_end
          from display_mode_events
          order by 1 desc
          limit 8
        ) w
        cross join lateral (
          select
            count(*) as total,
            count(*) filter (
              where not exists (
                select 1 from display_mode_events s
                where s.user_id = i.user_id
                  and s.event_type = 'switch'
                  and s.created_at > i.created_at
                  and s.created_at < w.week_end
              )
            ) as kept
          from display_mode_events i
          where i.event_type = 'initial'
            and i.mode = 'standard'
            and i.created_at < w.week_end
        ) totals
      ) rates
    )
  )
  from display_mode_events;
$$;

revoke all on function public.display_mode_experiment_summary() from public;
revoke all on function public.display_mode_experiment_summary() from anon;
grant execute on function public.display_mode_experiment_summary()
  to authenticated;
