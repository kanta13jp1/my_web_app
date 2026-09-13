-- Tiger remediation #4982: pin Agentless claims to versioned evidence, add a
-- fixed 60-minute SWE-bench lab, and define privacy-minimal run/cohort evidence.
-- No learner outcome rows are seeded: evidence remains uncollected until a
-- learner explicitly starts or completes the lab.
-- nocheck: time-relative -- source and dataset revisions are fixed below.

update public.ai_university_content
set content = $markdown$
## 到達目標

Agentless の `localize → repair → validate/rerank` を固定した1 issueで実行し、再現テストと回帰テストを根拠に最終patchを選び、費用・token・時間を再現可能なmanifestへ残せる。

## Versioned evidence block v1（確認日: 2026-08-30 JST）

**一次論文と公式release artifactを一組として読む。** 主比較は [Agentless論文 v2](https://arxiv.org/abs/2407.01489v2) と [公式 v1.5.0 release](https://github.com/OpenAutoCoder/Agentless/releases/tag/v1.5.0)（revision `b150f28465a77a81a7f4776384957a4271f5bd69`、artifact `agentless_swebench_lite.zip`）である。

| 設定 | Agentless / model | subset | resolved | 平均API費用 | 根拠 |
| --- | --- | --- | ---: | ---: | --- |
| 論文v2の主結果 | v1.5.0に対応する公式artifact / `GPT-4o` | SWE-bench Lite 300 | **96/300 (32.00%)** | **$0.70/issue** | 論文v2 Table 1 + v1.5.0 release |
| 2024-07-01公式announcement | 最初の公式tag `v0.1.0` (`a132f72ed0699118bdaa51e0ec01b8164654c1f6`) / artifact名 `20240630_agentless_gpt4o.zip` | SWE-bench Lite 300 | **82/300 (27.3%)** | **$0.34/issue** | 公式READMEのNews + v0.1.0 release |
| 2024-12-02公式announcement | v1.5.0 / `Claude 3.5 Sonnet` | SWE-bench Lite 300 | **122/300 (40.7%)** | **未公表** | 公式READMEのNews。122は公表率40.7%と母数300からの対応件数 |
| 2024-12-02公式announcement | v1.5.0 / `Claude 3.5 Sonnet` | SWE-bench Verified 500 | **254/500 (50.8%)** | **未公表** | 公式READMEのNews。254は公表率50.8%と母数500からの対応件数 |

`32.00% / $0.70`、`27.3% / $0.34`、`40.7% / 50.8%` は、版・model・subset・候補生成/選択条件が異なる。後二者に `$0.70` や `$0.34` を転記しない。この講座の短縮labも公式benchmark scoreとは比較しない。

## 60分lab v1: `django__django-10914`

固定条件: Agentless `v1.5.0` / revision `b150f28465a77a81a7f4776384957a4271f5bd69`、Python `3.11.x`、dataset `princeton-nlp/SWE-bench_Lite` revision `6ec7bb89b9342f664a54a6e0a6ea6501d3437cc2`、model `gpt-4o-2024-05-13`、issue `django__django-10914`、候補数 **4**、最大threads **10**。API keyやpatch本文を講座へ送信しない。

1. **0–10分 — baseline**: issue文を保存し、元checkoutで再現テストを実行する。期待は「元実装で再現テストが失敗」。
2. **10–20分 — localization**: suspicious file、関係するclass/function、具体的なedit locationを記録する。
3. **20–35分 — repair**: 同じlocalizationから4候補patchを生成する。各候補の適用可否と差分要約を記録する。
4. **35–50分 — validation**: 元実装で通るregression testsと、元実装で失敗するreproduction testを各候補に実行する。
5. **50–57分 — reranking**: `regression → reproduction → 重複排除` の順で候補を順位付けし、選択理由を残す。
6. **57–60分 — final**: final patchを固定し、下のmanifestを完成する。60分で終わらなければ `test_result: not_run` または失敗結果をそのまま残す。

### 明示的な成功基準

- suspicious fileとedit locationがgold patchの変更箇所を含む。
- reproduction testはbaselineで失敗し、final patchで成功する。
- 選択したregression testsはbaselineとfinal patchの両方で成功する。
- reranking記録が4候補すべてを参照し、final patchがcleanに適用できる。
- 公式SWE-bench評価の当該instanceが `resolved`。未実行は成功扱いにしない。
- token、実費、wall time、全test結果をrun manifestへ実測値で保存する。

## Course-specific run manifest contract v1

ローカルに次のキーを持つJSONを1 runにつき1件保存する。下の数値 `0` は未入力templateであり、実測値へ置き換える。`lab_completed` は `prompt_tokens + completion_tokens > 0`、`api_cost_usd > 0`、`wall_time_seconds > 0` でなければ受理しない。`null` や推定値を実測値として扱わない。

```json
{
  "task_version": "agentless_lab_20260830_v1",
  "python_version": "3.11.x",
  "agentless_release": "v1.5.0",
  "agentless_revision": "b150f28465a77a81a7f4776384957a4271f5bd69",
  "dataset": "princeton-nlp/SWE-bench_Lite",
  "dataset_revision": "6ec7bb89b9342f664a54a6e0a6ea6501d3437cc2",
  "instance_id": "django__django-10914",
  "model": "gpt-4o-2024-05-13",
  "candidate_count": 4,
  "max_threads": 10,
  "prompt_tokens": 0,
  "completion_tokens": 0,
  "embedding_tokens": 0,
  "api_cost_usd": 0.0,
  "predicted_api_cost_usd": 0.0,
  "wall_time_seconds": 0,
  "localization_correct": false,
  "regression_result": "not_run",
  "reproduction_result": "not_run",
  "test_result": "not_run",
  "reproducibility_result": "not_checked",
  "workplace_application": "not_yet"
}
```

## 匿名1 cohort evidence contract

cohortは `agentless_lab_20260830_v1` の1組だけ。匿名eventは `lab_started` と `lab_completed` の集計で、個人・session・IP・URL・issue本文・patch・回答本文を保存しない。completionでは localization correctness、regression/reproduction/final test result、予測/実費から算出するcost prediction error、再現性、職場適用状況だけを有限値で記録する。

**公開時点のseed証拠: 未収集（start 0、completion 0、各率/平均は n/a）。** migrationは契約だけを作り、learner outcomeを捏造するseed rowを追加しない。公開後の実測値はservice-role限定summaryで集計する。匿名eventは同一人物を結合できないためcompletion rateは方向的指標であり、請求・個人評価には使わない。

## 公式手順

- [Agentless v1.5.0 SWE-bench guide](https://github.com/OpenAutoCoder/Agentless/blob/v1.5.0/README_swebench.md)
- [Agentless v1.5.0 release artifacts](https://github.com/OpenAutoCoder/Agentless/releases/tag/v1.5.0)
- [Agentless論文 v2](https://arxiv.org/abs/2407.01489v2)
$markdown$,
    source_url = 'https://github.com/OpenAutoCoder/Agentless/tree/v1.5.0',
    published_at = date '2026-08-30',
    target_audience =
      '固定したSWE-bench issueでAgentlessの局所化、候補生成、test選択、rerankingを再現したいソフトウェア開発者',
    observable_learning_outcome =
      'django__django-10914を局所化し、4候補patchをtest結果でrerankして、再現可能な最終patchとrun manifestを提出できる',
    assessment_verification_method =
      '60分labのmanifestと匿名cohort集計でlocalization、test、cost予測誤差、再現性、職場適用を確認する',
    evidence_source_url = 'https://arxiv.org/abs/2407.01489v2',
    evidence_verified_at = timestamptz '2026-08-30 00:00:00+09'
where id = '50609809-2da6-41ba-9c35-4bbec9668493'::uuid
  and provider = 'agentless'
  and category = 'overview';

create table if not exists public.ai_university_agentless_lab_events (
  id uuid primary key default gen_random_uuid(),
  event_name text not null check (event_name in ('lab_started', 'lab_completed')),
  task_version text not null check (task_version = 'agentless_lab_20260830_v1'),
  python_version text,
  agentless_release text,
  agentless_revision text,
  dataset text,
  dataset_revision text,
  instance_id text,
  model text,
  candidate_count smallint,
  max_threads smallint,
  prompt_tokens integer,
  completion_tokens integer,
  embedding_tokens integer,
  api_cost_usd numeric(8, 4),
  predicted_api_cost_usd numeric(8, 4),
  wall_time_seconds integer,
  localization_correct boolean,
  regression_result text,
  reproduction_result text,
  test_result text,
  reproducibility_result text,
  workplace_application text,
  occurred_at timestamptz not null default now(),
  constraint ai_university_agentless_lab_event_shape check (
    (
      event_name = 'lab_started'
      and python_version is null
      and agentless_release is null
      and agentless_revision is null
      and dataset is null
      and dataset_revision is null
      and instance_id is null
      and model is null
      and candidate_count is null
      and max_threads is null
      and prompt_tokens is null
      and completion_tokens is null
      and embedding_tokens is null
      and api_cost_usd is null
      and predicted_api_cost_usd is null
      and wall_time_seconds is null
      and localization_correct is null
      and regression_result is null
      and reproduction_result is null
      and test_result is null
      and reproducibility_result is null
      and workplace_application is null
    )
    or (
      event_name = 'lab_completed'
      and num_nonnulls(
        python_version, agentless_release, agentless_revision, dataset,
        dataset_revision, instance_id, model, candidate_count, max_threads,
        prompt_tokens, completion_tokens, embedding_tokens, api_cost_usd,
        predicted_api_cost_usd, wall_time_seconds, localization_correct,
        regression_result, reproduction_result, test_result,
        reproducibility_result, workplace_application
      ) = 21
      and python_version ~ '^3[.]11[.][0-9]+$'
      and agentless_release = 'v1.5.0'
      and agentless_revision = 'b150f28465a77a81a7f4776384957a4271f5bd69'
      and dataset = 'princeton-nlp/SWE-bench_Lite'
      and dataset_revision = '6ec7bb89b9342f664a54a6e0a6ea6501d3437cc2'
      and instance_id = 'django__django-10914'
      and model = 'gpt-4o-2024-05-13'
      and candidate_count = 4
      and max_threads between 1 and 10
      and prompt_tokens >= 0
      and prompt_tokens <= 100000000
      and completion_tokens >= 0
      and completion_tokens <= 100000000
      and embedding_tokens >= 0
      and embedding_tokens <= 100000000
      and prompt_tokens + completion_tokens > 0
      and api_cost_usd > 0
      and api_cost_usd <= 100
      and predicted_api_cost_usd between 0 and 100
      and wall_time_seconds between 1 and 3600
      and localization_correct is not null
      and regression_result in ('passed', 'failed', 'not_run')
      and reproduction_result in ('passed', 'failed', 'not_run')
      and test_result in ('resolved', 'unresolved', 'not_run')
      and reproducibility_result in ('reproduced', 'not_reproduced', 'not_checked')
      and workplace_application in ('applied', 'planned', 'not_yet')
    )
  )
);

comment on table public.ai_university_agentless_lab_events is
  'Anonymous fixed Agentless lab starts and bounded run manifests; no learner text or identity.';

create index if not exists ai_university_agentless_lab_event_time_idx
  on public.ai_university_agentless_lab_events (task_version, event_name, occurred_at desc);

alter table public.ai_university_agentless_lab_events enable row level security;

revoke all on table public.ai_university_agentless_lab_events
  from public, anon, authenticated;
grant insert (
  event_name, task_version, python_version, agentless_release,
  agentless_revision, dataset, dataset_revision, instance_id, model,
  candidate_count, max_threads, prompt_tokens, completion_tokens,
  embedding_tokens, api_cost_usd, predicted_api_cost_usd,
  wall_time_seconds, localization_correct, regression_result,
  reproduction_result, test_result, reproducibility_result,
  workplace_application
) on table public.ai_university_agentless_lab_events to anon, authenticated;
grant select on table public.ai_university_agentless_lab_events to service_role;

drop policy if exists "anonymous clients insert bounded Agentless lab evidence"
  on public.ai_university_agentless_lab_events;
create policy "anonymous clients insert bounded Agentless lab evidence"
  on public.ai_university_agentless_lab_events
  for insert
  to anon, authenticated
  with check (task_version = 'agentless_lab_20260830_v1');

create or replace view public.ai_university_agentless_lab_summary
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
  round(100.0 * avg(localization_correct::integer)
    filter (where event_name = 'lab_completed'), 1) as localization_correct_percent,
  round(100.0 * avg((test_result = 'resolved')::integer)
    filter (where event_name = 'lab_completed'), 1) as resolved_percent,
  round(avg(
    case
      when api_cost_usd = 0 and predicted_api_cost_usd = 0 then 0
      when api_cost_usd > 0 then
        100.0 * abs(predicted_api_cost_usd - api_cost_usd) / api_cost_usd
    end
  ) filter (where event_name = 'lab_completed'), 2) as average_cost_prediction_error_percent,
  round(100.0 * avg((reproducibility_result = 'reproduced')::integer)
    filter (where event_name = 'lab_completed'), 1) as reproduced_percent,
  round(100.0 * avg((workplace_application = 'applied')::integer)
    filter (where event_name = 'lab_completed'), 1) as workplace_applied_percent
from public.ai_university_agentless_lab_events
group by task_version;

revoke all on table public.ai_university_agentless_lab_summary
  from public, anon, authenticated;
grant select on table public.ai_university_agentless_lab_summary to service_role;
