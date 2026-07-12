-- R24/R25: intent 経由で投稿され x_post_log 外にあった選挙集計ポストAを、
-- X 学習ループへ一度だけバックフィルする。
--
-- 投稿ID: 2043540153176936653 (2026-04-13T04:01:54.314Z)
-- 導入時の運用観測値: 8,000 impressions。metrics_checked_at は意図的に
-- 書かない。次回 x.metrics_collect の「未計測レスキュー」が公式X API値で
-- latest_metrics を更新し、観測値を恒久的な擬似値にしないため。

do $$
declare
  owner_user_id text;
  base_metadata jsonb;
  seed_latest_metrics jsonb;
begin
  select up.user_id::text
    into owner_user_id
    from public.user_profiles up
   where up.is_admin = true
   order by up.created_at asc nulls last
   limit 1;
  owner_user_id := coalesce(owner_user_id, 'service_role');

  base_metadata := jsonb_build_object(
    'historical_backfill', true,
    'tweet_id', '2043540153176936653',
    'posted_at', '2026-04-13T04:01:54.314Z',
    'observed_at', '2026-07-12T00:00:00+09:00',
    'metric_observation_kind', 'lifetime_cumulative',
    'learning_cohort', 'historical_benchmark',
    'historical_benchmark_impressions', 8000,
    'historical_benchmark_observed_at', '2026-07-12T00:00:00+09:00',
    'historical_benchmark_provenance', 'operator_observed_8k',
    'text', E'国民民主党の地方議員数 2026/04/13\n346人\n700まで残り354人\n🔴議員不在 1県\n🟡要強化(4人以下) 22県',
    'reply_texts', '[]'::jsonb,
    'source', 'election_post_a_backfill',
    'route', '/local-election-700',
    'experiment_key', 'x_first_user_growth_10k',
    'variant', 'local_election_tally',
    'content_kind', 'data_report',
    'content_archetype', 'data_report'
  );
  seed_latest_metrics := jsonb_build_object(
    'tweet_id', '2043540153176936653',
    'tweet_role', 'lead',
    'text', '国民民主党の地方議員数 2026/04/13',
    'source', 'election_post_a_backfill',
    'variant', 'local_election_tally',
    'impressions', 8000,
    'score', 8000,
    'metric_observation_kind', 'lifetime_cumulative'
  );

  -- Repair an existing partial log as well as inserting a missing one. Existing
  -- official metrics win over the 8K seed, while the required lineage tags are
  -- normalized on every run.
  update only public.hub_data as existing
     set metadata = existing.metadata
       || base_metadata
       || jsonb_build_object(
         'user_id', coalesce(nullif(existing.metadata ->> 'user_id', ''), owner_user_id),
         'status', coalesce(nullif(existing.metadata ->> 'status', ''), 'tracked_existing'),
         'metric_provenance', case
           when nullif(existing.metadata ->> 'metrics_checked_at', '') is not null
             or nullif(existing.metadata -> 'latest_metrics' ->> 'checked_at', '') is not null
             then 'x_api'
           else coalesce(
             nullif(existing.metadata ->> 'metric_provenance', ''),
             'operator_observed_8k'
           )
         end,
         'impressions', coalesce(
           nullif(existing.metadata -> 'impressions', 'null'::jsonb),
           '8000'::jsonb
         ),
         'engagement_score', coalesce(
           nullif(existing.metadata -> 'engagement_score', 'null'::jsonb),
           '8000'::jsonb
         ),
         'latest_metrics', seed_latest_metrics
           || case
             when jsonb_typeof(existing.metadata -> 'latest_metrics') = 'object'
               then existing.metadata -> 'latest_metrics'
             else '{}'::jsonb
           end
       )
   where existing.source = 'x_post_log'
     and existing.metadata ->> 'tweet_id' = '2043540153176936653';

  if not found then
    insert into public.hub_data (source, metadata)
    values (
      'x_post_log',
      base_metadata || jsonb_build_object(
        'user_id', owner_user_id,
        'status', 'tracked_existing',
        'metric_provenance', 'operator_observed_8k',
        'impressions', 8000,
        'engagement_score', 8000,
        'latest_metrics', seed_latest_metrics
      )
    );
  end if;
end
$$;
