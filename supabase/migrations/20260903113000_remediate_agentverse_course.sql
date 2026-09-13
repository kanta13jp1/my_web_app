-- Tiger remediation #5049: pin the official AgentVerse contract, replace
-- nonexistent imports, add a fixed comparison lab, and collect only bounded
-- anonymous outcome evidence.
-- nocheck: time-relative -- evidence dates and source revisions are fixed.

do $migration$
declare
  v_target_count constant bigint := (
    select count(*)
    from public.ai_university_content
    where provider = 'agentverse'
      and category = 'overview'
  );
  v_title constant text :=
    'AgentVerse — 公式TaskSolvingで比較する役割ベース協調lab (9/9)';
  v_content constant text := $markdown$
## この講座の検証範囲

**根拠確認日: 2026-09-03 (JST)**

この講座は、OpenBMB/AgentVerseの公式repositoryを固定して、実在する
TaskSolving exportと公式CLIを再現し、同じ課題をsingle agent、fixed role
team、conditional role teamの3条件で比較します。旧講座で紹介された非公式classの
importは、固定commitのpackage exportに存在しないため使用しません。

公開時点の実在学習者データは0件です。以下のrubricと匿名集計を実施するまで、
学習効果、再現率、職場適用率を断定しません。

## 固定した一次資料

- [AgentVerse main commit f90c4bd9680fdd3bcff8c52c9170911a59b23478](https://github.com/OpenBMB/AgentVerse/tree/f90c4bd9680fdd3bcff8c52c9170911a59b23478)
- [公式package export](https://github.com/OpenBMB/AgentVerse/blob/f90c4bd9680fdd3bcff8c52c9170911a59b23478/agentverse/__init__.py): SimulationとTaskSolving
- [公式setup.py](https://github.com/OpenBMB/AgentVerse/blob/f90c4bd9680fdd3bcff8c52c9170911a59b23478/setup.py): agentverse 0.1.8.1、Python 3.9以上、console scripts
- [公式requirements.txt](https://github.com/OpenBMB/AgentVerse/blob/f90c4bd9680fdd3bcff8c52c9170911a59b23478/requirements.txt)
- [公式brainstorming config](https://github.com/OpenBMB/AgentVerse/blob/f90c4bd9680fdd3bcff8c52c9170911a59b23478/agentverse/tasks/tasksolving/brainstorming/config.yaml)
- [simulation安定系release-0.1 commit 4ed4783f248875bc9e6efeda33482cc2d460f139](https://github.com/OpenBMB/AgentVerse/tree/4ed4783f248875bc9e6efeda33482cc2d460f139)

## Environment manifest

| 項目 | 固定値 / 境界 |
|---|---|
| repository | OpenBMB/AgentVerse |
| main commit | f90c4bd9680fdd3bcff8c52c9170911a59b23478 (2024-09-09 UTC) |
| framework | TaskSolving |
| stable simulation branch | release-0.1 / 4ed4783f248875bc9e6efeda33482cc2d460f139 |
| package / Python | agentverse 0.1.8.1 / Python 3.9以上 |
| model backend | 公式brainstorming configに記録されたgpt-3.5-turbo |
| credential | 公式READMEのOPENAI_API_KEY。値は提出・送信しない |
| dependency source | setup.py、requirements.txt |
| known constraint | mainのsimulationは公式README上でrefactor中。安定simulationはrelease-0.1を使う |

gpt-3.5-turboという固定configは2024年時点の再現対象であり、2026年時点の
提供継続や利用可能性を保証しません。backendが利用できない場合は、エラーを
保存したうえで、利用者の契約で利用可能なmodelへ変更したconfig差分、model名、
確認日を提出物に明示します。API key、prompt、生成結果、error本文は匿名集計へ
送信しません。

## 公式exportとCLIだけを使う開始手順

隔離環境で次を実行します。Windowsでは .venv/bin/python を
.venv\Scripts\python.exe に読み替えます。

    git clone https://github.com/OpenBMB/AgentVerse.git
    cd AgentVerse
    git checkout --detach f90c4bd9680fdd3bcff8c52c9170911a59b23478
    python -m venv .venv
    .venv/bin/python -m pip install -e .
    .venv/bin/python -c "from agentverse import TaskSolving; print(TaskSolving.__name__)"
    agentverse-tasksolving --task tasksolving/brainstorming

### 期待出力と合格条件

1. import確認がTaskSolvingを出力し、終了code 0になる。
2. CLIがtasksolving/brainstorming/config.yamlを読み、role assignmentと
   solver処理を開始する。
3. 利用可能なbackendで最終案まで到達した場合は終了code 0、実行時間、
   token、cost、最終案をローカル提出物へ残す。
4. backend driftで完走できない場合も、固定commit、実行command、処理段階、
   例外型、error全文、変更したconfig差分を残せば再現記録として扱う。

代表的な失敗は、editable install前のModuleNotFoundError: agentverse、
OPENAI_API_KEY未設定または認証失敗、固定modelの提供終了、requirementsと
Python環境の依存衝突、role数と生成されたrole数の不一致です。原因を推測だけで
閉じず、command、終了code、例外型、error全文を提出物へ残します。

## 60分lab: 同じ固定taskを3条件で比較

固定taskは次の1文です。

> Flutter Webの通知機能追加案を、実装範囲、障害時fallback、test、
> 運用指標を含む10項目以内の計画にする。

0〜10分でmanifest、install、TaskSolving importを確認します。公式
brainstorming directoryを3つ複製し、task_descriptionだけを上の固定taskへ
変更します。各directoryのconfig差分と標準出力はローカル提出物に残します。

### Run 1: single agent（10〜25分）

cnt_agentsを1にし、1人のgeneralistで1回実行します。

    agentverse-tasksolving --task tasksolving/agentverse_lab_single

### Run 2: fixed role team（25〜40分）

cnt_agentsを3にし、role_assigner promptへPM、実装engineer、QAの3役をこの順で
返す制約を追加して1回実行します。role名と役割説明を提出物に固定します。

    agentverse-tasksolving --task tasksolving/agentverse_lab_fixed

### Run 3: conditional role team（40〜55分）

Run 2の品質rubricが3未満、専門知識不足、未解消の意見衝突のいずれかなら、
不足理由に対応する4人目を1人だけ追加します。条件を満たさなければ
no_role_addedを記録し、同じ3役で再実行します。

    agentverse-tasksolving --task tasksolving/agentverse_lab_conditional

各runで品質rubric 0〜4、wall time秒、合計tokens、実測cost USDを記録し、
3条件の差分表を作ります。55〜60分でrole追加理由、同じmanifestでの再現性、
職場への適用方針を有限選択で提出します。

## 4項目rubric（4/4で合格）

1. **version contract**: 確認日、40桁commit、Python、dependency、
   backend、credential境界、simulation refactorを記録した。
2. **実行証拠**: TaskSolving importと公式CLIのcommand、終了code、
   期待結果との差、代表errorを省略せず記録した。
3. **比較可能性**: 同じ固定taskをsingle、fixed、conditionalの3条件で実行し、
   品質、wall time、tokens、costを同じ単位で比較した。
4. **判断と転用**: role追加の条件と理由、再現結果、職場適用を説明した。

## 匿名成果計測

下の提出cardは、明示的なStart後に、import成功/失敗を1件として匿名送信します。
完了時は3runのboundedな品質得点、wall time、token数、cost、role追加理由、
rubric得点、再現性、職場適用、完了秒数だけを送信します。prompt、生成結果、
config、error本文、API key、user ID、session、IP、URLは送信しません。

集計はservice roleだけが読み取り、開始数、完了率、import成功率、各runの
平均品質・時間・token・cost、再現率、職場適用率を公開後の実測として扱います。
$markdown$;
  v_source_url constant text :=
    'https://github.com/OpenBMB/AgentVerse/tree/f90c4bd9680fdd3bcff8c52c9170911a59b23478';
  v_published_at constant date := date '2026-09-03';
  v_target_audience constant text :=
    '公式AgentVerseのversion差と実行境界を固定し、同一taskで役割構成の効果とcostを比較したいAI学習者・開発者';
  v_learning_outcome constant text :=
    'TaskSolvingの実在exportと公式CLIを再現し、single、fixed role、conditional roleの品質・時間・token・cost差から役割追加を判断できる';
  v_verification_method constant text :=
    '固定manifest、import/CLI証拠、3条件の同一task比較、役割追加理由・再現性・職場適用からなる4項目rubricで確認する';
  v_evidence_verified_at constant timestamptz :=
    timestamptz '2026-09-03 20:20:00+09';
begin
  if v_target_count <> 1 then
    raise exception
      'expected exactly one agentverse/overview AI University row, found %',
      v_target_count
      using errcode = 'P0002';
  end if;

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
  where provider = 'agentverse'
    and category = 'overview'
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

create table if not exists public.ai_university_agentverse_lab_events (
  id uuid primary key default gen_random_uuid(),
  event_name text not null check (
    event_name in ('lab_started', 'import_checked', 'lab_completed')
  ),
  task_version text not null check (
    task_version = 'agentverse_role_comparison_20260903_v1'
  ),
  import_outcome text check (import_outcome in ('succeeded', 'failed')),
  single_quality_score smallint check (single_quality_score between 0 and 4),
  single_wall_seconds integer check (single_wall_seconds between 1 and 3600),
  single_token_count integer check (
    single_token_count between 1 and 10000000
  ),
  single_cost_usd numeric(10, 6) check (single_cost_usd between 0 and 100),
  fixed_quality_score smallint check (fixed_quality_score between 0 and 4),
  fixed_wall_seconds integer check (fixed_wall_seconds between 1 and 3600),
  fixed_token_count integer check (
    fixed_token_count between 1 and 10000000
  ),
  fixed_cost_usd numeric(10, 6) check (fixed_cost_usd between 0 and 100),
  conditional_quality_score smallint check (
    conditional_quality_score between 0 and 4
  ),
  conditional_wall_seconds integer check (
    conditional_wall_seconds between 1 and 3600
  ),
  conditional_token_count integer check (
    conditional_token_count between 1 and 10000000
  ),
  conditional_cost_usd numeric(10, 6) check (
    conditional_cost_usd between 0 and 100
  ),
  role_add_reason text check (
    role_add_reason in (
      'missing_expertise',
      'quality_gate_failed',
      'conflict_resolution',
      'no_role_added'
    )
  ),
  rubric_score smallint check (rubric_score between 0 and 4),
  reproducibility_result text check (
    reproducibility_result in (
      'reproduced',
      'not_reproduced',
      'not_checked'
    )
  ),
  workplace_application text check (
    workplace_application in ('applied', 'planned', 'not_yet')
  ),
  completion_seconds integer check (completion_seconds between 1 and 7200),
  occurred_at timestamptz not null default now(),
  constraint ai_university_agentverse_lab_event_shape check (
    (
      event_name = 'lab_started'
      and num_nonnulls(
        import_outcome,
        single_quality_score,
        single_wall_seconds,
        single_token_count,
        single_cost_usd,
        fixed_quality_score,
        fixed_wall_seconds,
        fixed_token_count,
        fixed_cost_usd,
        conditional_quality_score,
        conditional_wall_seconds,
        conditional_token_count,
        conditional_cost_usd,
        role_add_reason,
        rubric_score,
        reproducibility_result,
        workplace_application,
        completion_seconds
      ) = 0
    )
    or (
      event_name = 'import_checked'
      and import_outcome is not null
      and num_nonnulls(
        single_quality_score,
        single_wall_seconds,
        single_token_count,
        single_cost_usd,
        fixed_quality_score,
        fixed_wall_seconds,
        fixed_token_count,
        fixed_cost_usd,
        conditional_quality_score,
        conditional_wall_seconds,
        conditional_token_count,
        conditional_cost_usd,
        role_add_reason,
        rubric_score,
        reproducibility_result,
        workplace_application,
        completion_seconds
      ) = 0
    )
    or (
      event_name = 'lab_completed'
      and import_outcome is null
      and num_nonnulls(
        single_quality_score,
        single_wall_seconds,
        single_token_count,
        single_cost_usd,
        fixed_quality_score,
        fixed_wall_seconds,
        fixed_token_count,
        fixed_cost_usd,
        conditional_quality_score,
        conditional_wall_seconds,
        conditional_token_count,
        conditional_cost_usd,
        role_add_reason,
        rubric_score,
        reproducibility_result,
        workplace_application,
        completion_seconds
      ) = 17
    )
  )
);

comment on table public.ai_university_agentverse_lab_events is
  'Anonymous fixed AgentVerse comparison outcomes; no learner text or identity.';

create index if not exists ai_university_agentverse_lab_event_time_idx
  on public.ai_university_agentverse_lab_events (
    task_version,
    event_name,
    occurred_at desc
  );

alter table public.ai_university_agentverse_lab_events
  enable row level security;

revoke all on table public.ai_university_agentverse_lab_events
  from public, anon, authenticated;
grant insert (
  event_name,
  task_version,
  import_outcome,
  single_quality_score,
  single_wall_seconds,
  single_token_count,
  single_cost_usd,
  fixed_quality_score,
  fixed_wall_seconds,
  fixed_token_count,
  fixed_cost_usd,
  conditional_quality_score,
  conditional_wall_seconds,
  conditional_token_count,
  conditional_cost_usd,
  role_add_reason,
  rubric_score,
  reproducibility_result,
  workplace_application,
  completion_seconds
) on table public.ai_university_agentverse_lab_events
  to anon, authenticated;
grant select on table public.ai_university_agentverse_lab_events
  to service_role;

drop policy if exists
  "anonymous clients insert bounded AgentVerse lab outcomes"
  on public.ai_university_agentverse_lab_events;
create policy "anonymous clients insert bounded AgentVerse lab outcomes"
  on public.ai_university_agentverse_lab_events
  for insert
  to anon, authenticated
  with check (task_version = 'agentverse_role_comparison_20260903_v1');

create or replace view public.ai_university_agentverse_lab_summary
with (security_invoker = true) as
select
  task_version,
  count(*) filter (where event_name = 'lab_started') as start_count,
  count(*) filter (where event_name = 'import_checked') as import_check_count,
  count(*) filter (where event_name = 'lab_completed') as completion_count,
  round(
    100.0 * count(*) filter (where event_name = 'lab_completed')
    / nullif(count(*) filter (where event_name = 'lab_started'), 0),
    1
  ) as completion_rate_percent,
  round(
    100.0 * count(*) filter (
      where event_name = 'import_checked'
        and import_outcome = 'succeeded'
    )
    / nullif(count(*) filter (where event_name = 'import_checked'), 0),
    1
  ) as import_success_percent,
  round(avg(single_quality_score) filter (
    where event_name = 'lab_completed'
  ), 2) as average_single_quality,
  round(avg(fixed_quality_score) filter (
    where event_name = 'lab_completed'
  ), 2) as average_fixed_quality,
  round(avg(conditional_quality_score) filter (
    where event_name = 'lab_completed'
  ), 2) as average_conditional_quality,
  round(avg(single_wall_seconds) filter (
    where event_name = 'lab_completed'
  ), 1) as average_single_wall_seconds,
  round(avg(fixed_wall_seconds) filter (
    where event_name = 'lab_completed'
  ), 1) as average_fixed_wall_seconds,
  round(avg(conditional_wall_seconds) filter (
    where event_name = 'lab_completed'
  ), 1) as average_conditional_wall_seconds,
  round(avg(single_token_count) filter (
    where event_name = 'lab_completed'
  ), 1) as average_single_tokens,
  round(avg(fixed_token_count) filter (
    where event_name = 'lab_completed'
  ), 1) as average_fixed_tokens,
  round(avg(conditional_token_count) filter (
    where event_name = 'lab_completed'
  ), 1) as average_conditional_tokens,
  round(avg(single_cost_usd) filter (
    where event_name = 'lab_completed'
  ), 4) as average_single_cost_usd,
  round(avg(fixed_cost_usd) filter (
    where event_name = 'lab_completed'
  ), 4) as average_fixed_cost_usd,
  round(avg(conditional_cost_usd) filter (
    where event_name = 'lab_completed'
  ), 4) as average_conditional_cost_usd,
  round(
    100.0 * count(*) filter (
      where event_name = 'lab_completed'
        and reproducibility_result = 'reproduced'
    )
    / nullif(count(*) filter (where event_name = 'lab_completed'), 0),
    1
  ) as reproduced_percent,
  round(
    100.0 * count(*) filter (
      where event_name = 'lab_completed'
        and workplace_application = 'applied'
    )
    / nullif(count(*) filter (where event_name = 'lab_completed'), 0),
    1
  ) as workplace_applied_percent
from public.ai_university_agentverse_lab_events
group by task_version;

revoke all on table public.ai_university_agentverse_lab_summary
  from public, anon, authenticated;
grant select on table public.ai_university_agentverse_lab_summary
  to service_role;
