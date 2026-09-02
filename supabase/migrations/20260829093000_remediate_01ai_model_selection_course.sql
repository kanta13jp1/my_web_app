-- Tiger remediation #4737: replace the stale 01.AI model list with a dated
-- official-document snapshot, a live availability check, and a measurable
-- model-selection task that stores no learner text or identifiers.
-- nocheck: time-relative -- fixed evidence dates make this migration replayable.

update public.ai_university_content
set content = $markdown$
## 01.AI (Yi) モデル一覧

**公式ドキュメント確認日: 2026-08-29 (JST)**

### 公式ドキュメントのモデル表

| モデル | 文脈長 | 主な用途 | 入力 / 出力（100万token） |
| --- | ---: | --- | ---: |
| `yi-large` | 32K | 複雑な推論・予測・自然言語理解 | $3 / $3 |
| `yi-large-turbo` | 4K | 短い文脈での高品質・コスト重視処理 | $0.19 / $0.19 |
| `yi-large-fc` | 32K | tool useを伴うエージェント・workflow | $3 / $3 |
| `yi-vision` | 16K | 画像・図表・OCR・視覚推論 | $0.19 / $0.19 |

この表は確認日時点の公式ドキュメントの記載です。契約・アカウント・地域による**実際の利用可能モデル**は、認証済みのモデル一覧APIを利用時点で確認してください。

### 稼働モデルを確認する

```bash
curl --location 'https://api.01.ai/v1/models' \
  --header "Authorization: Bearer $YI_API_KEY"
```

レスポンスの `data[].id` が、その認証情報で利用できるモデルIDです。APIキーやレスポンス本文を講座へ貼り付けないでください。

### 定期差分の確認手順

1. 利用前と月1回、上の認証済みAPIを実行する。
2. `data[].id` を昇順に並べ、前回の**確認日とモデルID一覧**に対して追加・削除を比較する。
3. 公式ドキュメントの文脈長・用途・料金と照合する。
4. 差分があれば、確認日、追加・削除モデル、用途・料金の変更をこの講座へ反映する。

### 5分課題

公式モデル表を開き、**用途・予算・必要文脈長**を1行ずつ書いてからモデルを選んでください。下の3問と自己評価を送ると、回答本文や個人情報を保存せず、課題の閲覧数・完了数・正答数・自己評価だけを匿名集計します。
$markdown$,
    source_url = 'https://platform.01.ai/docs',
    published_at = date '2026-08-29',
    target_audience =
      '01.AI APIのモデルを用途、予算、必要文脈長で選びたい学習者',
    observable_learning_outcome =
      '認証済みモデル一覧を確認し、用途、予算、必要文脈長から適切なモデルを選定できる',
    assessment_verification_method =
      '用途、予算、必要文脈長を扱う3問、課題完了申告、5段階自己評価を匿名集計する',
    evidence_source_url = 'https://platform.01.ai/docs',
    evidence_verified_at = timestamptz '2026-08-29 00:00:00+09'
where provider = '01ai'
  and category = 'models';

alter table public.ai_university_learning_outcome_events
  drop constraint if exists ai_university_learning_outcome_events_task_version_check,
  drop constraint if exists ai_university_learning_outcome_events_provider_check,
  drop constraint if exists ai_university_learning_outcome_events_category_check;

alter table public.ai_university_learning_outcome_events
  add constraint ai_university_learning_outcome_task_identity check (
    (
      task_version = '01ai_latest_20260828_v1'
      and provider = '01ai'
      and category = 'news'
    )
    or (
      task_version = '01ai_models_20260829_v1'
      and provider = '01ai'
      and category = 'models'
    )
  );
comment on table public.ai_university_learning_outcome_events is
  'Privacy-minimal anonymous outcome counters for finite 01.AI learning tasks.';

drop policy if exists "anonymous clients insert bounded learning outcomes"
  on public.ai_university_learning_outcome_events;
create policy "anonymous clients insert bounded learning outcomes"
  on public.ai_university_learning_outcome_events
  for insert
  to anon, authenticated
  with check (
    (
      (
        task_version = '01ai_latest_20260828_v1'
        and provider = '01ai'
        and category = 'news'
      )
      or (
        task_version = '01ai_models_20260829_v1'
        and provider = '01ai'
        and category = 'models'
      )
    )
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
