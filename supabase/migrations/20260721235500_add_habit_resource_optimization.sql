-- Add measurable resource and outcome data to daily habits.

alter table public.daily_habits
  add column if not exists goal_id uuid references public.hub_data(id) on delete set null,
  add column if not exists goal_title text,
  add column if not exists default_time_cost_minutes integer
    check (default_time_cost_minutes between 1 and 1440),
  add column if not exists default_fatigue_score numeric(3, 1)
    check (default_fatigue_score between 1 and 10),
  add column if not exists default_goal_contribution_score numeric(5, 2)
    check (default_goal_contribution_score between 0 and 100);

alter table public.daily_habit_logs
  add column if not exists goal_id uuid references public.hub_data(id) on delete set null,
  add column if not exists goal_title text,
  add column if not exists time_cost_minutes integer
    check (time_cost_minutes between 1 and 1440),
  add column if not exists fatigue_score numeric(3, 1)
    check (fatigue_score between 1 and 10),
  add column if not exists goal_contribution_score numeric(5, 2)
    check (goal_contribution_score between 0 and 100);

comment on column public.daily_habit_logs.time_cost_minutes is
  'Actual minutes spent on this habit completion.';
comment on column public.daily_habit_logs.fatigue_score is
  'Self-reported fatigue from 1 (light) to 10 (exhausting).';
comment on column public.daily_habit_logs.goal_contribution_score is
  'Self-reported contribution to the selected goal from 0 to 100.';

create index if not exists idx_daily_habit_logs_resource_analysis
  on public.daily_habit_logs (user_id, completed_date desc, habit_id)
  where time_cost_minutes is not null
    and fatigue_score is not null
    and goal_contribution_score is not null;

create or replace function public.analyze_habit_resource_efficiency(
  p_days integer default 90
)
returns table (
  habit_id uuid,
  habit_title text,
  goal_title text,
  sample_count bigint,
  avg_time_minutes numeric,
  avg_fatigue_score numeric,
  avg_goal_contribution_score numeric,
  resource_cost_index numeric,
  efficiency_score numeric,
  time_performance_correlation double precision,
  fatigue_performance_correlation double precision,
  overall_time_performance_correlation double precision,
  overall_fatigue_performance_correlation double precision,
  is_pareto_optimal boolean
)
language sql
security invoker
set search_path = public
as $$
  with scoped_logs as (
    select
      l.habit_id,
      h.title as habit_title,
      coalesce(l.goal_title, h.goal_title) as goal_title,
      l.time_cost_minutes::double precision as time_cost_minutes,
      l.fatigue_score::double precision as fatigue_score,
      l.goal_contribution_score::double precision as goal_contribution_score
    from public.daily_habit_logs l
    join public.daily_habits h on h.id = l.habit_id
    where l.user_id = auth.uid()
      and h.user_id = auth.uid()
      and l.completed_date >=
        current_date - least(greatest(coalesce(p_days, 90), 7), 365)
      and l.time_cost_minutes is not null
      and l.fatigue_score is not null
      and l.goal_contribution_score is not null
  ),
  global_correlations as (
    select
      corr(goal_contribution_score, time_cost_minutes)
        as overall_time_performance_correlation,
      corr(goal_contribution_score, fatigue_score)
        as overall_fatigue_performance_correlation
    from scoped_logs
  ),
  habit_rollups as (
    select
      habit_id,
      max(habit_title) as habit_title,
      max(goal_title) filter (where goal_title is not null) as goal_title,
      count(*) as sample_count,
      round(avg(time_cost_minutes)::numeric, 2) as avg_time_minutes,
      round(avg(fatigue_score)::numeric, 2) as avg_fatigue_score,
      round(avg(goal_contribution_score)::numeric, 2)
        as avg_goal_contribution_score,
      round((avg(time_cost_minutes) + avg(fatigue_score) * 10)::numeric, 2)
        as resource_cost_index,
      round(
        (
          avg(goal_contribution_score) /
          nullif(avg(time_cost_minutes) + avg(fatigue_score) * 10, 0)
        )::numeric,
        4
      ) as efficiency_score,
      corr(goal_contribution_score, time_cost_minutes)
        as time_performance_correlation,
      corr(goal_contribution_score, fatigue_score)
        as fatigue_performance_correlation
    from scoped_logs
    group by habit_id
  )
  select
    candidate.habit_id,
    candidate.habit_title,
    candidate.goal_title,
    candidate.sample_count,
    candidate.avg_time_minutes,
    candidate.avg_fatigue_score,
    candidate.avg_goal_contribution_score,
    candidate.resource_cost_index,
    candidate.efficiency_score,
    candidate.time_performance_correlation,
    candidate.fatigue_performance_correlation,
    global_correlations.overall_time_performance_correlation,
    global_correlations.overall_fatigue_performance_correlation,
    not exists (
      select 1
      from habit_rollups competitor
      where competitor.habit_id <> candidate.habit_id
        and competitor.avg_time_minutes <= candidate.avg_time_minutes
        and competitor.avg_fatigue_score <= candidate.avg_fatigue_score
        and competitor.avg_goal_contribution_score >=
          candidate.avg_goal_contribution_score
        and (
          competitor.avg_time_minutes < candidate.avg_time_minutes
          or competitor.avg_fatigue_score < candidate.avg_fatigue_score
          or competitor.avg_goal_contribution_score >
            candidate.avg_goal_contribution_score
        )
    ) as is_pareto_optimal
  from habit_rollups candidate
  cross join global_correlations
  order by is_pareto_optimal desc, efficiency_score desc, habit_title;
$$;

revoke all on function public.analyze_habit_resource_efficiency(integer)
  from public;
grant execute on function public.analyze_habit_resource_efficiency(integer)
  to authenticated, service_role;

comment on function public.analyze_habit_resource_efficiency(integer) is
  'Returns authenticated-user habit cost/performance correlations and Pareto frontier membership.';
