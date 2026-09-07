-- Tiger remediation #4757: give the 01.AI introduction course a dated
-- company/model/platform/product map and bounded anonymous learner evidence.
-- nocheck: time-relative -- fixed evidence dates make this migration replayable.

update public.ai_university_content
set content = $markdown$
## 01.AI (Yi) とは

**公式情報確認日: 2026-09-03 (JST)**

### 現在の4層マップ

| 層 | 何を指すか | 公式情報で確認できる役割 |
| --- | --- | --- |
| 1. 会社 | **01.AI** | 企業向けフルスタックAI、業界agent、業界・主権model trainingを提供する会社 |
| 2. モデル群 | **Yi** | 01.AIがゼロから訓練した公開大規模言語モデル群。技術・公開状況は公式GitHubで確認する |
| 3. 企業向け基盤 | **WorldWise Enterprise LLM Platform** | model deployment、application practice、model fine-tuning toolsをまとめた基盤（2025-03公開） |
| 4. 意思決定製品群 | **TrueNorth** | enterprise AI decision hub。2026-07に公開され、Boss AI、Investor AI、TopSales AIへ展開 |

Yiは会社名でもTrueNorthの製品名でもありません。WorldWiseとTrueNorthもYiのモデルサイズではなく、01.AIが現在展開する別レイヤーの基盤・製品です。現在の会社・製品構成は01.AI公式サイト、Yiモデルの技術・公開状況は公式GitHubを確認してください。

- [01.AI公式サイト（会社・沿革・製品）](https://www.01.ai/)
- [Yi公式GitHub（モデル群）](https://github.com/01-ai/Yi)
- [TrueNorth公式ページ](https://www.01.ai/TrueNorth.html)

### 学習後に説明できるべき3項目

1. **会社とモデルの区別**: 01.AIは会社、Yiは同社が訓練したモデル群。
2. **基盤と製品の区別**: WorldWiseは企業向けLLM基盤、TrueNorthは意思決定ハブと製品群。
3. **調査先の選択**: 現在の会社・製品は01.AI公式サイト、Yiの技術詳細は公式GitHub、TrueNorthの機能は製品ページで確認する。

### 5分の分類課題

下の3問で会社・モデル・基盤・製品を分類し、Yiの技術詳細を次に調べる公式ページを選んでください。課題の閲覧数、完了数、初回正答数、最終正答数、自己評価、選んだページ種別だけを匿名集計します。利用者ID、session ID、回答本文、自由記述は保存しません。
$markdown$,
    source_url = 'https://www.01.ai/',
    published_at = date '2026-09-03',
    target_audience =
      '01.AI、Yi、WorldWise、TrueNorthの違いを短時間で把握したい初学者',
    observable_learning_outcome =
      '会社、モデル群、企業向け基盤、意思決定製品群を区別し、目的に合う公式調査先を選べる',
    assessment_verification_method =
      '3問分類、次の公式ページ選択、初回/最終正答数、5段階自己評価、閲覧/完了を匿名集計する',
    evidence_source_url = 'https://www.01.ai/',
    evidence_verified_at = timestamptz '2026-09-03 00:00:00+09'
where id = 'e1712bb5-2bca-4fc0-8347-0529513411d3'::uuid;

create table if not exists public.ai_university_yi_intro_outcome_events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  event_name text not null check (event_name in ('task_viewed', 'task_completed')),
  task_version text not null check (
    task_version = '01ai_introduction_20260903_v1'
  ),
  provider text not null check (provider = '01ai'),
  category text not null check (category = 'introduction'),
  correct_answers integer,
  total_questions integer,
  self_rating integer,
  first_attempt_correct_answers integer,
  next_official_page text,
  constraint ai_university_yi_intro_event_shape check (
    (
      event_name = 'task_viewed'
      and correct_answers is null
      and total_questions is null
      and self_rating is null
      and first_attempt_correct_answers is null
      and next_official_page is null
    )
    or (
      event_name = 'task_completed'
      and correct_answers between 0 and 3
      and total_questions = 3
      and self_rating between 1 and 5
      and first_attempt_correct_answers between 0 and 3
      and next_official_page in (
        'yi_repository', 'worldwise_overview', 'truenorth_product'
      )
    )
  )
);

alter table public.ai_university_yi_intro_outcome_events enable row level security;

revoke all on table public.ai_university_yi_intro_outcome_events
  from public, anon, authenticated;
grant insert (
  event_name,
  task_version,
  provider,
  category,
  correct_answers,
  total_questions,
  self_rating,
  first_attempt_correct_answers,
  next_official_page
) on table public.ai_university_yi_intro_outcome_events
  to anon, authenticated;

drop policy if exists "anonymous clients insert bounded Yi introduction outcomes"
  on public.ai_university_yi_intro_outcome_events;
create policy "anonymous clients insert bounded Yi introduction outcomes"
  on public.ai_university_yi_intro_outcome_events
  for insert
  to anon, authenticated
  with check (
    task_version = '01ai_introduction_20260903_v1'
    and provider = '01ai'
    and category = 'introduction'
    and (
      (
        event_name = 'task_viewed'
        and correct_answers is null
        and total_questions is null
        and self_rating is null
        and first_attempt_correct_answers is null
        and next_official_page is null
      )
      or (
        event_name = 'task_completed'
        and correct_answers between 0 and 3
        and total_questions = 3
        and self_rating between 1 and 5
        and first_attempt_correct_answers between 0 and 3
        and next_official_page in (
          'yi_repository', 'worldwise_overview', 'truenorth_product'
        )
      )
    )
  );

create index if not exists ai_university_yi_intro_outcome_event_time_idx
  on public.ai_university_yi_intro_outcome_events
  (event_name, occurred_at desc);

create or replace view public.ai_university_yi_intro_outcome_summary
with (security_invoker = true) as
select
  count(*) filter (where event_name = 'task_viewed') as view_count,
  count(*) filter (where event_name = 'task_completed') as completion_count,
  round(
    100.0 * count(*) filter (where event_name = 'task_completed')
      / nullif(count(*) filter (where event_name = 'task_viewed'), 0),
    1
  ) as completion_rate_percent,
  round(
    100.0 * avg(first_attempt_correct_answers)
      filter (where event_name = 'task_completed') / 3.0,
    1
  ) as first_attempt_accuracy_percent,
  round(
    avg(self_rating) filter (where event_name = 'task_completed'),
    2
  ) as average_self_rating,
  round(
    100.0 * avg((next_official_page = 'yi_repository')::integer)
      filter (where event_name = 'task_completed'),
    1
  ) as next_page_correct_percent
from public.ai_university_yi_intro_outcome_events;

revoke all on table public.ai_university_yi_intro_outcome_summary
  from public, anon, authenticated;
grant select on table public.ai_university_yi_intro_outcome_summary
  to service_role;

comment on table public.ai_university_yi_intro_outcome_events is
  'Anonymous finite outcomes for the 01.AI/Yi introduction task; no learner or session identity and no free text.';
comment on view public.ai_university_yi_intro_outcome_summary is
  'Service-role-only aggregate view count, completion rate, first-attempt accuracy, next-page accuracy, and self-rating.';
