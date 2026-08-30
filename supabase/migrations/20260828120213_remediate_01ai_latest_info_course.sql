-- Tiger remediation #4734: make the 01.AI latest-information lesson dated,
-- source-attributed, assessable, and measurable without collecting learner
-- text or identifiers.
-- nocheck: time-relative -- UPDATE uses fixed evidence dates; the only
-- time-relative trigger assigns updated_at = now() and cannot reject replay.

update public.ai_university_content
set content = $markdown$
## 01.AI (Yi) 最新情報

**公式情報確認日: 2026-08-28 (JST)**

### 2026-04-13版からの主な更新

- **2026.07 — TrueNorthを公開**: 公式会社沿革では、企業の意思決定を支援するTrueNorthと、Boss AI・Investor AI・TopSales AIの3アプリを公開したと説明されています。
- **2026.01 — WorldWise 2.5**: WorldWise Platformが2.5へ進み、企業向けマルチエージェント機能を公開したと記録されています。
- **現在の事業説明**: 公式サイトは、基盤モデル単体ではなく、企業・産業・ソブリンAIの導入と、意思決定から実行・改善までの閉ループを前面に出しています。

### 旧情報の扱い

2026-04-13版にあった価格比較、他社モデルとの性能比較、出典のない日本市場の採用状況、出典を確認できないコメントは、この更新版へ引き継ぎません。価格・利用可能モデル・性能は変わるため、利用時点で公式APIドキュメントとアカウント画面を再確認してください。

Yiのオープンソース公開履歴は歴史資料として区別します。公式GitHubのNews欄で最後に日付が付いた項目は **2024-07-29のYi Cookbook 1.0** です。これは2026年の企業向け製品更新とは別の時系列です。

### 一次情報

- [01.AI Company Overview / 会社沿革（確認日: 2026-08-28）](https://www.01.ai/about.html)
- [TrueNorth公式製品ページ（確認日: 2026-08-28）](https://www.01.ai/TrueNorth.html)
- [01.AI Yi公式GitHub News（確認日: 2026-08-28）](https://github.com/01-ai/Yi#news)

### 5分課題

一次情報を開き、**確認日付きの3点要約**と、2026-04-13版から**何を更新・削除したか**を手元のメモにまとめてください。下の確認問題と自己評価を送ると、本文や個人情報を保存せず、課題の閲覧数・完了数・正答数・自己評価だけを匿名集計します。
$markdown$,
    source_url = 'https://www.01.ai/about.html',
    published_at = date '2026-08-28',
    target_audience =
      'AI提供企業の最新情報を、日付付き一次情報と旧版との差分で確認したい学習者',
    observable_learning_outcome =
      '確認日付きの3点要約を作り、2026-04-13版から更新または削除すべき情報を説明できる',
    assessment_verification_method =
      '一次情報を参照する3問の確認問題、課題完了申告、5段階自己評価を匿名集計する',
    evidence_source_url = 'https://www.01.ai/about.html',
    evidence_verified_at = timestamptz '2026-08-28 00:00:00+09'
where provider = '01ai'
  and category = 'news';

-- Anonymous aggregate learning events only. There is intentionally no
-- user/session/IP/answer/summary/content/free-text column.
create table if not exists public.ai_university_learning_outcome_events (
  id uuid primary key default gen_random_uuid(),
  event_name text not null check (
    event_name in ('task_viewed', 'task_completed')
  ),
  task_version text not null check (
    task_version = '01ai_latest_20260828_v1'
  ),
  provider text not null check (provider = '01ai'),
  category text not null check (category = 'news'),
  correct_answers smallint,
  total_questions smallint,
  self_rating smallint,
  occurred_at timestamptz not null default now(),
  constraint ai_university_learning_outcome_event_shape check (
    (
      event_name = 'task_viewed'
      and correct_answers is null
      and total_questions is null
      and self_rating is null
    )
    or (
      event_name = 'task_completed'
      and correct_answers between 0 and 3
      and total_questions = 3
      and self_rating between 1 and 5
    )
  )
);

comment on table public.ai_university_learning_outcome_events is
  'Privacy-minimal anonymous outcome counters for the 01.AI latest-information task.';

create index if not exists ai_university_learning_outcome_task_event_time_idx
  on public.ai_university_learning_outcome_events
  (task_version, event_name, occurred_at desc);

alter table public.ai_university_learning_outcome_events
  enable row level security;

revoke all on table public.ai_university_learning_outcome_events
  from public, anon, authenticated;
grant insert (
  event_name,
  task_version,
  provider,
  category,
  correct_answers,
  total_questions,
  self_rating
) on table public.ai_university_learning_outcome_events
  to anon, authenticated;
grant select on table public.ai_university_learning_outcome_events
  to service_role;

drop policy if exists "anonymous clients insert bounded learning outcomes"
  on public.ai_university_learning_outcome_events;
create policy "anonymous clients insert bounded learning outcomes"
  on public.ai_university_learning_outcome_events
  for insert
  to anon, authenticated
  with check (
    task_version = '01ai_latest_20260828_v1'
    and provider = '01ai'
    and category = 'news'
    and (
      (
        event_name = 'task_viewed'
        and correct_answers is null
        and total_questions is null
        and self_rating is null
      )
      or (
        event_name = 'task_completed'
        and correct_answers between 0 and 3
        and total_questions = 3
        and self_rating between 1 and 5
      )
    )
  );

create or replace view public.ai_university_learning_outcome_summary
with (security_invoker = true) as
select
  task_version,
  provider,
  category,
  count(*) filter (where event_name = 'task_viewed') as view_count,
  count(*) filter (where event_name = 'task_completed') as completion_count,
  round(
    100.0 * count(*) filter (where event_name = 'task_completed')
    / nullif(count(*) filter (where event_name = 'task_viewed'), 0),
    1
  ) as completion_rate_percent,
  round(
    100.0 * avg(correct_answers) filter (where event_name = 'task_completed')
    / 3.0,
    1
  ) as average_correct_percent,
  round(
    avg(self_rating) filter (where event_name = 'task_completed'),
    2
  ) as average_self_rating
from public.ai_university_learning_outcome_events
group by task_version, provider, category;

revoke all on table public.ai_university_learning_outcome_summary
  from public, anon, authenticated;
grant select on table public.ai_university_learning_outcome_summary
  to service_role;
