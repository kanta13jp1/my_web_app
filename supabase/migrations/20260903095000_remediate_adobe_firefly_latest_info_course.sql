-- Tiger remediation #4979: ground the Adobe Firefly latest-information
-- lesson in a dated official release ledger, define a 45-day freshness
-- fallback, and collect finite anonymous old/new workflow outcomes.
-- nocheck: time-relative -- evidence dates and the stale cutoff are fixed
-- snapshots; this migration contains no clock-dependent CHECK constraint.

update public.ai_university_content
set content = $markdown$
## Adobe Firefly 最新情報

**Adobe公式情報確認日: 2026-09-03 (JST)**  
**公式ページ最終更新: 2026-08-19**  
**最新release month: 2026-08**

### August 2026 change ledger

- **一元化されたワークスペース（Beta）**: 画像と動画の生成・編集、プロジェクトアセットの整理、動画タイムラインを1つの生成・編集環境で扱えます。
- **Interfaces（Beta）**: 組織の専門家がproduction workflowから公開した簡潔な画面を利用し、複雑なnode graphを操作せず、最大500個の入力アセットでbatch production jobを実行できます。Firefly Creative Production for Enterprise向けです。
- **Generate music / Generate speech**: 動画等に合わせた音楽トラックと、多言語の自然なvoice-over生成がAugust 2026項目に追加されています。

比較の基準線として、July 2026は整理済みworkflow template、June 2026はsemantic search、新しいFirefly workspace、AI Assistant、Create workflows等です。機能名・Beta状態・利用条件は変わるため、利用前に公式ページを再確認してください。

### 30分workflow比較課題

1. 「一元化されたワークスペース」または「Interfaces batch」のどちらか1機能を選ぶ。
2. 同じ入力（画像・動画・アセット一式）と同じ完成条件を旧workflowと新workflowへ適用する。素材やpromptは外部へ共有せず、手元だけで管理する。
3. 旧手順と新手順について、入力、操作手順、出力、所要時間、修正回数を手元の比較表へ記録する。
4. usable outputか、職場・実案件へ適用できるかを判定し、採用・試験導入・保留のいずれかを選ぶ。
5. 下の3問と有限選択だけを匿名送信する。入力素材、prompt、出力、比較本文、利用者・session識別子は保存しない。

### freshness contract

- **source of truth**: Adobe公式What’s New。確認時点の最終更新日と最新release monthを上記へ固定する。
- **change ledger**: 新しい月が公開されたら、追加・変更・Beta/提供条件の差分をこの節へ追記する。
- **freshness threshold: 45日**: `evidence_verified_at`から45日を超えた場合、この教材を「最新」と断定しない。
- **stale fallback**: 2026-10-18以降に再確認されていない場合は歴史的snapshotとして扱い、課題より先に公式What’s Newを開く。差分があれば教材更新Issueを起票し、確認日、release month、feature、提供条件を更新する。

### 公式一次情報

- [Adobe Firefly What’s New（最終更新 2026-08-19、確認 2026-09-03）](https://helpx.adobe.com/firefly/web/whats-new/new-features/whats-new.html)
- [一元化された生成・編集環境（最終更新 2026-08-19、Beta）](https://helpx.adobe.com/firefly/web/unified-generation-and-editing-experience/generation-and-editing-experience-overview.html)
- [Interfacesの作成・公開（最終更新 2026-08-12、最大500入力）](https://helpx.adobe.com/firefly/web/work-with-enterprise-features/creative-production/create-and-manage-interfaces.html)

### 匿名の成果確認

課題の閲覧・完了、正答数、自己評価、選択feature、出力種別、入力数、旧/新所要時間、修正回数、usable output、職場適用、採用判断だけを有限値で集計します。自由記述、入力素材、生成物、prompt、利用者・session・IPは保存しません。
$markdown$,
    source_url =
      'https://helpx.adobe.com/firefly/web/whats-new/new-features/whats-new.html',
    published_at = date '2026-08-19',
    target_audience =
      'Adobe Fireflyの直近releaseを旧workflowと比較し、実務採用を判断したい制作・運用担当者',
    observable_learning_outcome =
      'August 2026の機能と提供条件を説明し、同じ入力で旧/新workflowの時間・修正・usable output・職場適用を比較して採用判断できる',
    assessment_verification_method =
      '3問と30分比較課題を完了し、feature・入出力種別・旧新時間・修正回数・利用可否・職場適用・採用判断を有限値で匿名集計する',
    evidence_source_url =
      'https://helpx.adobe.com/firefly/web/whats-new/new-features/whats-new.html',
    evidence_verified_at = timestamptz '2026-09-03 00:00:00+09'
where provider = 'adobe_firefly'
  and category = 'news';

alter table public.ai_university_learning_outcome_events
  add column if not exists release_feature text,
  add column if not exists output_kind text,
  add column if not exists input_asset_count integer,
  add column if not exists legacy_workflow_minutes integer,
  add column if not exists latest_workflow_minutes integer,
  add column if not exists revision_count smallint,
  add column if not exists usable_output boolean,
  add column if not exists workplace_applicable boolean,
  add column if not exists adoption_decision text;

alter table public.ai_university_learning_outcome_events
  drop constraint if exists ai_university_learning_outcome_task_identity,
  drop constraint if exists ai_university_learning_outcome_firefly_news_fields;

alter table public.ai_university_learning_outcome_events
  add constraint ai_university_learning_outcome_task_identity check (
    (task_version = '01ai_latest_20260828_v1' and provider = '01ai' and category = 'news')
    or (task_version = '01ai_models_20260829_v1' and provider = '01ai' and category = 'models')
    or (
      task_version = 'academic_llm_mechanics_20260829_v1'
      and provider = 'academic'
      and category = 'llm_mechanics'
    )
    or (
      task_version = 'adobe_firefly_api_20260831_v1'
      and provider = 'adobe_firefly'
      and category = 'api'
    )
    or (
      task_version = 'adobe_firefly_news_20260903_v1'
      and provider = 'adobe_firefly'
      and category = 'news'
    )
  ),
  add constraint ai_university_learning_outcome_firefly_news_fields check (
    (
      task_version <> 'adobe_firefly_news_20260903_v1'
      and release_feature is null
      and output_kind is null
      and input_asset_count is null
      and legacy_workflow_minutes is null
      and latest_workflow_minutes is null
      and revision_count is null
      and usable_output is null
      and workplace_applicable is null
      and adoption_decision is null
    )
    or (
      task_version = 'adobe_firefly_news_20260903_v1'
      and (
        (
          event_name = 'task_viewed'
          and release_feature is null
          and output_kind is null
          and input_asset_count is null
          and legacy_workflow_minutes is null
          and latest_workflow_minutes is null
          and revision_count is null
          and usable_output is null
          and workplace_applicable is null
          and adoption_decision is null
        )
        or (
          event_name = 'task_completed'
          and release_feature in ('central_workspace', 'interfaces_batch')
          and output_kind in ('image', 'video', 'asset_batch')
          and input_asset_count in (1, 10, 100, 500)
          and legacy_workflow_minutes between 1 and 120
          and latest_workflow_minutes between 1 and 120
          and revision_count between 0 and 20
          and usable_output is not null
          and workplace_applicable is not null
          and adoption_decision in ('adopt', 'pilot', 'defer')
        )
      )
    )
  );

grant insert (
  release_feature,
  output_kind,
  input_asset_count,
  legacy_workflow_minutes,
  latest_workflow_minutes,
  revision_count,
  usable_output,
  workplace_applicable,
  adoption_decision
) on table public.ai_university_learning_outcome_events
  to anon, authenticated;

drop policy if exists "anonymous clients insert bounded learning outcomes"
  on public.ai_university_learning_outcome_events;
create policy "anonymous clients insert bounded learning outcomes"
  on public.ai_university_learning_outcome_events
  for insert
  to anon, authenticated
  with check (
    (
      (task_version = '01ai_latest_20260828_v1' and provider = '01ai' and category = 'news')
      or (task_version = '01ai_models_20260829_v1' and provider = '01ai' and category = 'models')
      or (
        task_version = 'academic_llm_mechanics_20260829_v1'
        and provider = 'academic'
        and category = 'llm_mechanics'
      )
      or (
        task_version = 'adobe_firefly_api_20260831_v1'
        and provider = 'adobe_firefly'
        and category = 'api'
      )
      or (
        task_version = 'adobe_firefly_news_20260903_v1'
        and provider = 'adobe_firefly'
        and category = 'news'
      )
    )
    and (
      (
        event_name = 'task_viewed'
        and correct_answers is null
        and total_questions is null
        and self_rating is null
        and learner_role is null
        and first_call_succeeded is null
        and secret_handling_passed is null
        and api_selection_passed is null
        and non_2xx_recovery_passed is null
        and estimated_daily_requests is null
        and completion_seconds is null
        and release_feature is null
        and output_kind is null
        and input_asset_count is null
        and legacy_workflow_minutes is null
        and latest_workflow_minutes is null
        and revision_count is null
        and usable_output is null
        and workplace_applicable is null
        and adoption_decision is null
      )
      or (
        event_name = 'task_completed'
        and correct_answers between 0 and 3
        and total_questions = 3
        and self_rating between 1 and 5
        and (
          (
            task_version = 'adobe_firefly_api_20260831_v1'
            and learner_role in (
              'developer', 'operations', 'creator', 'product_owner'
            )
            and first_call_succeeded is not null
            and secret_handling_passed is not null
            and api_selection_passed is not null
            and non_2xx_recovery_passed is not null
            and estimated_daily_requests between 1 and 9000
            and completion_seconds between 1 and 3600
            and release_feature is null
            and output_kind is null
            and input_asset_count is null
            and legacy_workflow_minutes is null
            and latest_workflow_minutes is null
            and revision_count is null
            and usable_output is null
            and workplace_applicable is null
            and adoption_decision is null
          )
          or (
            task_version = 'adobe_firefly_news_20260903_v1'
            and learner_role is null
            and first_call_succeeded is null
            and secret_handling_passed is null
            and api_selection_passed is null
            and non_2xx_recovery_passed is null
            and estimated_daily_requests is null
            and completion_seconds is null
            and release_feature in ('central_workspace', 'interfaces_batch')
            and output_kind in ('image', 'video', 'asset_batch')
            and input_asset_count in (1, 10, 100, 500)
            and legacy_workflow_minutes between 1 and 120
            and latest_workflow_minutes between 1 and 120
            and revision_count between 0 and 20
            and usable_output is not null
            and workplace_applicable is not null
            and adoption_decision in ('adopt', 'pilot', 'defer')
          )
          or (
            task_version not in (
              'adobe_firefly_api_20260831_v1',
              'adobe_firefly_news_20260903_v1'
            )
            and learner_role is null
            and first_call_succeeded is null
            and secret_handling_passed is null
            and api_selection_passed is null
            and non_2xx_recovery_passed is null
            and estimated_daily_requests is null
            and completion_seconds is null
            and release_feature is null
            and output_kind is null
            and input_asset_count is null
            and legacy_workflow_minutes is null
            and latest_workflow_minutes is null
            and revision_count is null
            and usable_output is null
            and workplace_applicable is null
            and adoption_decision is null
          )
        )
      )
    )
  );

create index if not exists ai_university_firefly_news_feature_time_idx
  on public.ai_university_learning_outcome_events
  (release_feature, occurred_at desc)
  where task_version = 'adobe_firefly_news_20260903_v1'
    and event_name = 'task_completed';

create or replace view public.ai_university_firefly_news_outcome_summary
with (security_invoker = true) as
select
  release_feature,
  output_kind,
  adoption_decision,
  count(*) as completion_count,
  round(avg(legacy_workflow_minutes), 1) as average_legacy_minutes,
  round(avg(latest_workflow_minutes), 1) as average_latest_minutes,
  round(avg(legacy_workflow_minutes - latest_workflow_minutes), 1)
    as average_minutes_saved,
  round(avg(revision_count), 1) as average_revision_count,
  round(100.0 * avg(usable_output::integer), 1) as usable_output_percent,
  round(100.0 * avg(workplace_applicable::integer), 1)
    as workplace_applicable_percent,
  round(avg(self_rating), 2) as average_self_rating
from public.ai_university_learning_outcome_events
where task_version = 'adobe_firefly_news_20260903_v1'
  and event_name = 'task_completed'
group by release_feature, output_kind, adoption_decision;

revoke all on table public.ai_university_firefly_news_outcome_summary
  from public, anon, authenticated;
grant select on table public.ai_university_firefly_news_outcome_summary
  to service_role;

comment on view public.ai_university_firefly_news_outcome_summary is
  'Anonymous Firefly release workflow comparison outcomes; no learner identity, prompt, input asset, generated output, or free text.';
