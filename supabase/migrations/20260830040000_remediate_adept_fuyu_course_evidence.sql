-- Tiger remediation #4850: replace the unsupported hosted-API lesson with a
-- source-bounded Fuyu-8B exercise and privacy-minimal outcome measurement.
-- nocheck: time-relative -- evidence and source revision dates are fixed.

do $migration$
declare
  v_target_count constant bigint := (
    select count(*)
    from public.ai_university_content
    where provider = 'adept'
      and category = 'api'
  );
  v_title constant text := 'Fuyu-8B 公開モデルカード検証入門';
  v_content constant text := $markdown$
## この講座の範囲

**根拠確認日: 2026-08-30 (JST)**

この講座は、Adeptの現行ホステッドAPIを説明または利用する講座ではありません。下記の固定model cardとTransformers資料は、現行の一般向けAPIキー、エンドポイント、料金、ホステッド提供状況を示す根拠ではないため、それらの有無をこの講座から結論づけません。公開されたFuyu-8Bの仕様と1回のローカル推論例だけを検証します。

## 固定した一次資料

- [Fuyu-8B model card（revision `f41defefdb89be0d28cac19d94ce216e37cb6be5`）](https://huggingface.co/adept/fuyu-8b/blob/f41defefdb89be0d28cac19d94ce216e37cb6be5/README.md)
- [同revisionのmetadata](https://huggingface.co/api/models/adept/fuyu-8b/revision/f41defefdb89be0d28cac19d94ce216e37cb6be5)（`lastModified`: 2023-11-04 UTC）
- [Transformers Fuyu documentation v5.15.1](https://huggingface.co/docs/transformers/v5.15.1/en/model_doc/fuyu)
- モデルID: `adept/fuyu-8b`
- ライセンス: `CC-BY-NC-4.0`（商用利用可能とは扱わない）
- 位置づけ: 画像とテキストを入力してテキストを生成する、研究用途向けのbase model

固定model cardは、用途によってfew-shotまたはfine-tuningが必要になり得ること、望ましくない出力を制御する追加のfine-tuning、postprocessing、sampling strategyがないことも明記しています。旧講座にあったApache 2.0、一般向けAPI、AWS Bedrock展開予定、料金の断定は、この資料では裏づけられないため引き継ぎません。

## 実行前提

1. CUDA対応GPU、ドライバー、Python隔離環境、モデル重み用の空き容量を実行者自身が確認する。
2. 隔離環境へ`transformers`、`torch`、`Pillow`、`requests`を導入し、Pythonと各packageのversionを実行記録へ残す。この講座は互換versionを断定しない。
3. 固定model cardの「How to Use」を開き、processorとmodelの両方の`from_pretrained`へ`revision="f41defefdb89be0d28cac19d94ce216e37cb6be5"`を追加する。
4. 画像URLも`https://huggingface.co/adept/fuyu-8b/resolve/f41defefdb89be0d28cac19d94ce216e37cb6be5/bus.png`へ固定する。
5. GPU、依存関係、ディスク容量のいずれかを確認できない場合は、重みを取得せず「読解専用フォールバック」へ進む。

## 1回だけの推論課題

固定した`bus.png`を使い、promptを`Generate a coco-style caption.\n`、`max_new_tokens`を`7`として、model cardの例を1回だけ実行します。

### 期待結果とエラー記録

固定model cardの期待結果は`A blue bus parked on the side of a road.`です。実行記録には開始時刻、model ID、model revision、画像URL、prompt、`max_new_tokens`、package version、実際の生成文字列を残します。期待結果と異なる場合は期待値と実値の差分を、失敗した場合は処理段階、例外型、エラーメッセージ全文を残します。成功・差分・エラーのどれも、Adeptの現行ホステッドAPIが利用可能または利用不能である証拠にはしません。

## 読解専用フォールバック

推論できない場合はモデル重みを取得せず、固定model cardの「How to Use」「Uses」「Limitations and Bias」だけを読みます。model ID、revision、ライセンス、想定用途、base modelとして必要になり得る調整、望ましくない出力への注意、推論例の期待結果を、各見出しと対応づけた表にして提出します。

## 4項目rubric（4/4で合格）

1. **出典固定**: model ID、revision、画像URL、根拠確認日を記録した。
2. **手順遵守**: 推論を1回だけ実行した、または重みを取得しない読解専用フォールバックを選び、その理由を記録した。
3. **結果検証**: 実値と期待値を比較し、差分またはエラーがあれば省略せず記録した。
4. **境界説明**: `CC-BY-NC-4.0`、研究用途、base modelの制約と、現行ホステッドAPIについてこの資料から結論づけられないことを説明した。

## 匿名成果計測

公開時点の実測値は0件で、学習成果を断定しません。下の提出カードは、課題の開始・完了、実行／読解の別、初回結果または自己回復の有限選択肢、完了秒数、rubric得点だけを匿名集計します。入力文、生成文、エラー本文、ユーザーID、session、IP、URLは送信しません。

推論を選んだ場合は「初回成功」「エラー後に自己回復」「出力差分後に自己回復」「エラー未解決」「出力差分未解決」から1つ、読解専用フォールバックの場合は「読解課題を完了」を選びます。これにより、公開後の初回成功率、平均完了時間、自己回復率を、個人を追跡せずに集計します。
$markdown$;
  v_source_url constant text :=
    'https://huggingface.co/adept/fuyu-8b/blob/f41defefdb89be0d28cac19d94ce216e37cb6be5/README.md';
  v_published_at constant date := date '2026-08-30';
  v_target_audience constant text :=
    'Fuyu-8Bの固定model cardを読み、現行APIの主張と公開モデルの検証を区別したい開発者・AI学習者';
  v_learning_outcome constant text :=
    '固定revisionの根拠からモデルID、ライセンス、base modelの制約、推論例の結果を説明し、現行ホステッドAPIの有無をこの資料から結論づけない';
  v_verification_method constant text :=
    '出典固定、1回の推論または読解専用フォールバック、結果・エラー記録、利用境界の説明からなる4項目rubricで確認する';
  v_evidence_verified_at constant timestamptz :=
    timestamptz '2026-08-30 00:00:00+09';
begin
  if v_target_count <> 1 then
    raise exception 'expected exactly one adept/api AI University row, found %',
      v_target_count
      using errcode = 'P0002';
  end if;

  -- The IS DISTINCT FROM guard makes replay a no-op, including avoiding an
  -- updated_at-only write from the table's BEFORE UPDATE trigger.
  update public.ai_university_content
  set title = v_title,
      content = v_content,
      source_url = v_source_url,
      published_at = v_published_at,
      target_audience = v_target_audience,
      observable_learning_outcome = v_learning_outcome,
      assessment_verification_method = v_verification_method,
      evidence_source_url = v_source_url,
      evidence_verified_at = v_evidence_verified_at
  where provider = 'adept'
    and category = 'api'
    and (
      title,
      content,
      source_url,
      published_at,
      target_audience,
      observable_learning_outcome,
      assessment_verification_method,
      evidence_source_url,
      evidence_verified_at
    ) is distinct from (
      v_title,
      v_content,
      v_source_url,
      v_published_at,
      v_target_audience,
      v_learning_outcome,
      v_verification_method,
      v_source_url,
      v_evidence_verified_at
    );
end
$migration$;

-- One fixed cohort only. No learner text or identifying/linkable field exists,
-- and no synthetic outcome row is seeded.
create table if not exists public.ai_university_fuyu_lab_events (
  id uuid primary key default gen_random_uuid(),
  event_name text not null check (
    event_name in ('lab_started', 'lab_completed')
  ),
  task_version text not null check (
    task_version = 'adept_fuyu_model_card_20260830_v1'
  ),
  task_mode text check (task_mode in ('inference', 'reading_fallback')),
  attempt_outcome text check (
    attempt_outcome in (
      'first_try_success',
      'success_after_error',
      'success_after_difference',
      'unresolved_error',
      'unresolved_difference',
      'reading_completed'
    )
  ),
  completion_seconds integer check (
    completion_seconds between 1 and 86400
  ),
  rubric_score smallint check (rubric_score between 0 and 4),
  occurred_at timestamptz not null default now(),
  constraint ai_university_fuyu_lab_event_shape check (
    (
      event_name = 'lab_started'
      and num_nonnulls(
        task_mode,
        attempt_outcome,
        completion_seconds,
        rubric_score
      ) = 0
    )
    or (
      event_name = 'lab_completed'
      and num_nonnulls(
        task_mode,
        attempt_outcome,
        completion_seconds,
        rubric_score
      ) = 4
      and (
        (
          task_mode = 'inference'
          and attempt_outcome in (
            'first_try_success',
            'success_after_error',
            'success_after_difference',
            'unresolved_error',
            'unresolved_difference'
          )
        )
        or (
          task_mode = 'reading_fallback'
          and attempt_outcome = 'reading_completed'
        )
      )
    )
  )
);

comment on table public.ai_university_fuyu_lab_events is
  'Anonymous fixed Fuyu model-card task outcomes; no learner text or identity.';

create index if not exists ai_university_fuyu_lab_event_time_idx
  on public.ai_university_fuyu_lab_events (
    task_version,
    event_name,
    occurred_at desc
  );

alter table public.ai_university_fuyu_lab_events enable row level security;

revoke all on table public.ai_university_fuyu_lab_events
  from public, anon, authenticated;
grant insert (
  event_name,
  task_version,
  task_mode,
  attempt_outcome,
  completion_seconds,
  rubric_score
) on table public.ai_university_fuyu_lab_events to anon, authenticated;
grant select on table public.ai_university_fuyu_lab_events to service_role;

drop policy if exists "anonymous clients insert bounded Fuyu lab outcomes"
  on public.ai_university_fuyu_lab_events;
create policy "anonymous clients insert bounded Fuyu lab outcomes"
  on public.ai_university_fuyu_lab_events
  for insert
  to anon, authenticated
  with check (task_version = 'adept_fuyu_model_card_20260830_v1');

create or replace view public.ai_university_fuyu_lab_summary
with (security_invoker = true) as
select
  task_version,
  count(*) filter (where event_name = 'lab_started') as start_count,
  count(*) filter (where event_name = 'lab_completed') as completion_count,
  round(
    100.0 * count(*) filter (where event_name = 'lab_completed')
    / nullif(count(*) filter (where event_name = 'lab_started'), 0),
    1
  ) as completion_rate_percent,
  round(
    100.0 * count(*) filter (
      where event_name = 'lab_completed'
        and attempt_outcome = 'first_try_success'
    )
    / nullif(count(*) filter (
      where event_name = 'lab_completed'
        and task_mode = 'inference'
    ), 0),
    1
  ) as first_attempt_success_percent,
  round(
    avg(completion_seconds) filter (where event_name = 'lab_completed'),
    1
  ) as average_completion_seconds,
  round(
    100.0 * count(*) filter (
      where event_name = 'lab_completed'
        and attempt_outcome in (
          'success_after_error',
          'success_after_difference'
        )
    )
    / nullif(count(*) filter (
      where event_name = 'lab_completed'
        and attempt_outcome in (
          'success_after_error',
          'success_after_difference',
          'unresolved_error',
          'unresolved_difference'
        )
    ), 0),
    1
  ) as self_recovery_percent,
  round(
    avg(rubric_score) filter (where event_name = 'lab_completed'),
    2
  ) as average_rubric_score
from public.ai_university_fuyu_lab_events
group by task_version;

revoke all on table public.ai_university_fuyu_lab_summary
  from public, anon, authenticated;
grant select on table public.ai_university_fuyu_lab_summary to service_role;
