-- Tiger remediation #4941: turn the Adobe Firefly API lesson into a
-- server-side-only, failure-first, production-readiness lab with bounded,
-- anonymous role-level outcome evidence.
-- nocheck: time-relative -- evidence dates and limits are fixed snapshots.

update public.ai_university_content
set content = $markdown$
## Adobe Firefly API 利用方法

**Adobe公式資料確認日: 2026-08-31 (JST)**

### 絶対境界: secretはserver-sideだけ

Firefly APIの全requestにはaccess tokenが必要です。Client IDとClient Secretは、secret managerまたは安全なserver-side環境変数だけに保存します。Flutter/Web client、公開repository、スクリーンショット、analytics、request/response logへClient Secretやaccess tokenを出してはいけません。

server-side applicationはAdobe IMSのOAuth Server-to-Server token endpointからtokenを取得します。token responseの`expires_in`は約86,399秒で、tokenは24時間有効です。期限前に更新し、401を受けた場合はserver-sideで1回だけ再取得して再送します。

- [Authentication](https://developer.adobe.com/firefly-services/docs/firefly-api/getting-started/)
- [Create credentials](https://developer.adobe.com/firefly-services/docs/firefly-api/getting-started/create-credentials/)

### 失敗先行の認証演習

1. local mockへAuthorization headerなしのrequestを送り、**401を期待するtest**を先に作る。
2. 401の構造化logに`event`、`status`、`attempt`、`elapsed_ms`だけがあり、secret、token、prompt、個人情報がないことを確認する。
3. 安全なserver-side環境でClient ID/Secretを読み、IMSからtokenを取得する。token値は表示しない。
4. `expires_in`から更新予定を作り、期限前更新と、401時の1回限定更新をtestする。

**認証の合格条件**: client bundle・repository・logにsecret/tokenが0件、欠落認証は401、server-side token取得は成功、24時間以内の期限前更新と401時1回再送を再現できること。

### v3 Generate Image 小規模lab

確認日時点の公式Quickstartは、次のversioned endpointを使用します。

```text
POST https://firefly-api.adobe.io/v3/images/generate-async
Authorization: Bearer <server-side access token>
x-api-key: <Client ID>
Content-Type: application/json
Accept: application/json
```

1. `prompt`を1件requestとして送信し、2xx、output URL、request ID、所要時間を確認する。
2. 2〜3件の小さな配列をqueueし、**組織単位の既定4 RPM**を超えないよう逐次実行する。
3. 非2xxをstatus別に扱う。401はtokenを1回更新、429は`Retry-After`または指数backoff、その他4xxは入力修正、5xxは上限付き再試行後に失敗とする。
4. structured logには`event`、`status`、`request_id`、`attempt`、`elapsed_ms`、`retry_after`、`budget_remaining`だけを残す。secret、token、prompt、画像URL、個人情報は記録しない。
5. 利用前に1日上限を決める。確認日時点の既定上限は**4 requests/minute、9,000 requests/day（組織単位）**。契約上限がそれより小さい場合は小さい方をbudgetとし、送信前に残量を検査する。

- [Generate Image Quickstart](https://developer.adobe.com/firefly-services/docs/firefly-api/guides/)
- [Firefly API usage notes](https://developer.adobe.com/firefly-services/docs/firefly-api/getting-started/usage-notes/)

### production-readiness checklist

- [ ] Client Secret/tokenはserver-side secret managerだけにあり、client bundle・repository・logのscanが0件
- [ ] `/v3/images/generate-async`を固定し、変更時は公式Quickstartとの差分をreview
- [ ] 1件と複数件requestを再現し、各requestの成功/失敗を個別判定
- [ ] 401、429、4xx、5xxの分岐と上限付きretryをtest
- [ ] secret/token/promptを除外したstructured loggingとrequest ID相関
- [ ] 24時間token更新、4 RPM、9,000 RPD、契約上限の小さい方をbudget化
- [ ] timeout、cancellation、監視、runbook、障害時停止条件を定義

### 匿名の成果確認

下のカードで役割、初回call結果、secret handling、API選択、非2xx recovery、1日request見積もり、完了時間、自己評価を送ります。選択肢と数値の有限集計だけを保存し、利用者ID、session ID、secret、token、prompt、回答本文は保存しません。
$markdown$,
    source_url =
      'https://developer.adobe.com/firefly-services/docs/firefly-api/guides/',
    published_at = date '2026-08-31',
    target_audience =
      'Adobe Firefly APIをsecretを漏らさず小規模運用へ移したい開発・運用・制作・企画担当者',
    observable_learning_outcome =
      'server-side OAuth、24時間token更新、v3画像生成、非2xx回復、構造化log、usage budgetを実装判断できる',
    assessment_verification_method =
      '失敗先行認証、単発/複数件lab、3問、production checklist、役割別の初回call・安全性・回復・利用量・完了時間を匿名集計する',
    evidence_source_url =
      'https://developer.adobe.com/firefly-services/docs/firefly-api/getting-started/',
    evidence_verified_at = timestamptz '2026-08-31 00:00:00+09'
where provider = 'adobe_firefly'
  and category = 'api';

alter table public.ai_university_learning_outcome_events
  add column if not exists learner_role text,
  add column if not exists first_call_succeeded boolean,
  add column if not exists secret_handling_passed boolean,
  add column if not exists api_selection_passed boolean,
  add column if not exists non_2xx_recovery_passed boolean,
  add column if not exists estimated_daily_requests integer,
  add column if not exists completion_seconds integer;

alter table public.ai_university_learning_outcome_events
  drop constraint if exists ai_university_learning_outcome_task_identity,
  drop constraint if exists ai_university_learning_outcome_firefly_fields;

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
  ),
  add constraint ai_university_learning_outcome_firefly_fields check (
    (
      task_version <> 'adobe_firefly_api_20260831_v1'
      and learner_role is null
      and first_call_succeeded is null
      and secret_handling_passed is null
      and api_selection_passed is null
      and non_2xx_recovery_passed is null
      and estimated_daily_requests is null
      and completion_seconds is null
    )
    or (
      task_version = 'adobe_firefly_api_20260831_v1'
      and (
        (
          event_name = 'task_viewed'
          and learner_role is null
          and first_call_succeeded is null
          and secret_handling_passed is null
          and api_selection_passed is null
          and non_2xx_recovery_passed is null
          and estimated_daily_requests is null
          and completion_seconds is null
        )
        or (
          event_name = 'task_completed'
          and learner_role in (
            'developer', 'operations', 'creator', 'product_owner'
          )
          and first_call_succeeded is not null
          and secret_handling_passed is not null
          and api_selection_passed is not null
          and non_2xx_recovery_passed is not null
          and estimated_daily_requests between 1 and 9000
          and completion_seconds between 1 and 3600
        )
      )
    )
  );

grant insert (
  learner_role,
  first_call_succeeded,
  secret_handling_passed,
  api_selection_passed,
  non_2xx_recovery_passed,
  estimated_daily_requests,
  completion_seconds
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
      )
      or (
        event_name = 'task_completed'
        and correct_answers between 0 and 3
        and total_questions = 3
        and self_rating between 1 and 5
        and (
          (
            task_version <> 'adobe_firefly_api_20260831_v1'
            and learner_role is null
            and first_call_succeeded is null
            and secret_handling_passed is null
            and api_selection_passed is null
            and non_2xx_recovery_passed is null
            and estimated_daily_requests is null
            and completion_seconds is null
          )
          or (
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
          )
        )
      )
    )
  );

create index if not exists ai_university_firefly_outcome_role_time_idx
  on public.ai_university_learning_outcome_events
  (learner_role, occurred_at desc)
  where task_version = 'adobe_firefly_api_20260831_v1'
    and event_name = 'task_completed';

create or replace view public.ai_university_firefly_api_outcome_summary
with (security_invoker = true) as
select
  learner_role,
  count(*) as completion_count,
  round(100.0 * avg(first_call_succeeded::integer), 1)
    as first_call_success_percent,
  round(100.0 * avg(secret_handling_passed::integer), 1)
    as secret_handling_pass_percent,
  round(100.0 * avg(api_selection_passed::integer), 1)
    as api_selection_pass_percent,
  round(100.0 * avg(non_2xx_recovery_passed::integer), 1)
    as non_2xx_recovery_pass_percent,
  round(avg(estimated_daily_requests), 1)
    as average_estimated_daily_requests,
  round(avg(completion_seconds), 1)
    as average_completion_seconds
from public.ai_university_learning_outcome_events
where task_version = 'adobe_firefly_api_20260831_v1'
  and event_name = 'task_completed'
group by learner_role;

revoke all on table public.ai_university_firefly_api_outcome_summary
  from public, anon, authenticated;
grant select on table public.ai_university_firefly_api_outcome_summary
  to service_role;

comment on view public.ai_university_firefly_api_outcome_summary is
  'Role-level anonymous Firefly API lab outcomes; no learner identity, secret, token, prompt, or free text.';
