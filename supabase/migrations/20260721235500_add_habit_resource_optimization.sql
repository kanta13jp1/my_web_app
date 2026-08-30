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
    check (goal_contribution_score between 0 and 100),
  add column if not exists goal_contribution_measurement_source text
    not null default 'habit_default_proxy'
    check (
      goal_contribution_measurement_source in (
        'habit_default_proxy',
        'self_reported_goal_contribution_proxy'
      )
    );

-- PostgreSQL does not automatically index referencing foreign-key columns.
-- These indexes keep hub_data deletes from scanning every user's habit rows.
create index if not exists idx_daily_habits_goal_id
  on public.daily_habits (goal_id)
  where goal_id is not null;

create index if not exists idx_daily_habit_logs_goal_id
  on public.daily_habit_logs (goal_id)
  where goal_id is not null;

comment on column public.daily_habit_logs.time_cost_minutes is
  'Actual minutes spent on this habit completion.';
comment on column public.daily_habit_logs.fatigue_score is
  'Self-reported fatigue from 1 (light) to 10 (exhausting).';
comment on column public.daily_habit_logs.goal_contribution_score is
  'Self-reported 0-100 proxy, not an observed change in actual goal progress.';
comment on column public.daily_habit_logs.goal_contribution_measurement_source is
  'Measurement provenance. One-tap copies of habit defaults use habit_default_proxy and are excluded from inference. Only an explicit self_reported_goal_contribution_proxy is analyzed; hub_data goals have no timestamped progress history that can be joined safely to a habit completion.';

create index if not exists idx_daily_habit_logs_resource_analysis
  on public.daily_habit_logs (user_id, completed_date desc, habit_id)
  where time_cost_minutes is not null
    and fatigue_score is not null
    and goal_contribution_score is not null
    and goal_contribution_measurement_source =
      'self_reported_goal_contribution_proxy';

-- Keep every relationship inside the authenticated user's tenant. Foreign-key
-- checks alone only prove that a UUID exists; they do not enforce ownership.
drop policy if exists "users_own_daily_habits" on public.daily_habits;
create policy "users_own_daily_habits"
  on public.daily_habits for all
  to authenticated
  using (
    user_id = (select auth.uid())
    and (
      goal_id is null
      or exists (
        select 1
        from public.hub_data goal
        where goal.id = daily_habits.goal_id
          and goal.source = 'goal'
          and goal.metadata ->> 'user_id' = daily_habits.user_id::text
      )
    )
  )
  with check (
    user_id = (select auth.uid())
    and (
      goal_id is null
      or exists (
        select 1
        from public.hub_data goal
        where goal.id = daily_habits.goal_id
          and goal.source = 'goal'
          and goal.metadata ->> 'user_id' = daily_habits.user_id::text
      )
    )
  );

drop policy if exists "users_own_daily_habit_logs"
  on public.daily_habit_logs;
create policy "users_own_daily_habit_logs"
  on public.daily_habit_logs for all
  to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.daily_habits habit
      where habit.id = daily_habit_logs.habit_id
        and habit.user_id = daily_habit_logs.user_id
    )
    and (
      goal_id is null
      or exists (
        select 1
        from public.hub_data goal
        where goal.id = daily_habit_logs.goal_id
          and goal.source = 'goal'
          and goal.metadata ->> 'user_id' = daily_habit_logs.user_id::text
      )
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.daily_habits habit
      where habit.id = daily_habit_logs.habit_id
        and habit.user_id = daily_habit_logs.user_id
    )
    and (
      goal_id is null
      or exists (
        select 1
        from public.hub_data goal
        where goal.id = daily_habit_logs.goal_id
          and goal.source = 'goal'
          and goal.metadata ->> 'user_id' = daily_habit_logs.user_id::text
      )
    )
  );

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
  performance_measurement_source text,
  performance_is_proxy boolean,
  performance_sample_stddev numeric,
  has_sufficient_data boolean,
  insufficient_data_reason text,
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
set search_path = ''
as $$
  with scoped_logs as (
    select
      l.habit_id,
      h.title as habit_title,
      coalesce(l.goal_title, h.goal_title) as goal_title,
      l.time_cost_minutes::double precision as time_cost_minutes,
      l.fatigue_score::double precision as fatigue_score,
      l.goal_contribution_score::double precision as goal_contribution_score,
      l.goal_contribution_measurement_source
    from public.daily_habit_logs l
    join public.daily_habits h on h.id = l.habit_id
    where l.user_id = (select auth.uid())
      and h.user_id = (select auth.uid())
      and l.completed_date >=
        current_date - least(greatest(coalesce(p_days, 90), 7), 365)
      and l.time_cost_minutes is not null
      and l.fatigue_score is not null
      and l.goal_contribution_score is not null
      and l.goal_contribution_measurement_source =
        'self_reported_goal_contribution_proxy'
  ),
  global_correlations as (
    select
      case
        when count(*) >= 7
          and count(distinct goal_contribution_score) >= 2
          and count(distinct time_cost_minutes) >= 2
        then corr(goal_contribution_score, time_cost_minutes)
      end as overall_time_performance_correlation,
      case
        when count(*) >= 7
          and count(distinct goal_contribution_score) >= 2
          and count(distinct fatigue_score) >= 2
        then corr(goal_contribution_score, fatigue_score)
      end as overall_fatigue_performance_correlation
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
      'self_reported_goal_contribution_proxy'::text
        as performance_measurement_source,
      true as performance_is_proxy,
      round(stddev_samp(goal_contribution_score)::numeric, 4)
        as performance_sample_stddev,
      (
        count(*) >= 7
        and count(distinct goal_contribution_score) >= 2
        and (
          count(distinct time_cost_minutes) >= 2
          or count(distinct fatigue_score) >= 2
        )
      ) as has_sufficient_data,
      case
        when count(*) < 7 then 'minimum_7_samples_required'
        when count(distinct goal_contribution_score) < 2
          then 'insufficient_performance_variance'
        when count(distinct time_cost_minutes) < 2
          and count(distinct fatigue_score) < 2
          then 'insufficient_resource_variance'
      end as insufficient_data_reason,
      round((avg(time_cost_minutes) + avg(fatigue_score) * 10)::numeric, 2)
        as resource_cost_index,
      round(
        (
          avg(goal_contribution_score) /
          nullif(avg(time_cost_minutes) + avg(fatigue_score) * 10, 0)
        )::numeric,
        4
      ) as efficiency_score,
      case
        when count(*) >= 7
          and count(distinct goal_contribution_score) >= 2
          and count(distinct time_cost_minutes) >= 2
        then corr(goal_contribution_score, time_cost_minutes)
      end as time_performance_correlation,
      case
        when count(*) >= 7
          and count(distinct goal_contribution_score) >= 2
          and count(distinct fatigue_score) >= 2
        then corr(goal_contribution_score, fatigue_score)
      end as fatigue_performance_correlation
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
    candidate.performance_measurement_source,
    candidate.performance_is_proxy,
    candidate.performance_sample_stddev,
    candidate.has_sufficient_data,
    candidate.insufficient_data_reason,
    candidate.resource_cost_index,
    candidate.efficiency_score,
    candidate.time_performance_correlation,
    candidate.fatigue_performance_correlation,
    global_correlations.overall_time_performance_correlation,
    global_correlations.overall_fatigue_performance_correlation,
    candidate.has_sufficient_data and not exists (
      select 1
      from habit_rollups competitor
      where competitor.habit_id <> candidate.habit_id
        and competitor.has_sufficient_data
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
  to authenticated;

comment on function public.analyze_habit_resource_efficiency(integer) is
  'Returns authenticated-user habit cost/performance analysis using only explicit self-reported goal-contribution proxy rows. Habit-default proxy rows are excluded. Correlations and Pareto membership require at least 7 eligible samples and non-zero performance/resource variance.';
