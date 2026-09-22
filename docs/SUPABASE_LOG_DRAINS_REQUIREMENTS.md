# Supabase Log Drains 要件・運用方針

> **Issue**: [#2860](https://github.com/kanta13jp1/my_web_app/issues/2860)
>
> **制定日**: 2026-08-27
>
> **対象**: Supabase Platform の Postgres / API Gateway / Auth / Storage /
> Realtime / Edge Functions を含むプラットフォームログ
>
> **位置づけ**: 外部ログ転送を有効化する前の要件、費用判断、データ保護、
> 保持・削除、検証および停止手順の正本

## 1. 結論

現時点では Log Drains を有効化しない。Issue 作成時の前提は Free plan であり、
Free plan では Log Drains を利用できないためである。法令・顧客契約・
インシデント調査のいずれかが現在のログ保持期間を超えることを要求し、かつ
月額予算と転送先のデータ処理条件を CEO が承認した時点で導入する。

導入時の第一候補は **Amazon S3 への direct drain 1本**とする。既存の
[`PRIVACY_POLICY_DRAFT.md`](./PRIVACY_POLICY_DRAFT.md) に合わせ、raw access log
は90日で自動削除し、長期保管が必要な集計値だけを匿名化して残す。リアルタイム
検索やアラートが必要になった場合に限り、Sentry または Datadog 等への2本目を
追加する。

この文書は要件定義であり、plan upgrade、AWS/SaaS契約、credential作成、
production drain作成を承認するものではない。

## 2. 公式仕様の確認結果

2026-08-27時点のSupabase公式情報は次のとおり。

| 項目 | 確認結果 | 設計への影響 |
| --- | --- | --- |
| 利用可能plan | Pro / Team / Enterprise。Freeは対象外 | Freeのまま有効化しない |
| 転送対象 | Supabase stack全体のログ | source単位の除外に依存せず、発生元で機密情報をログへ出さない |
| 対応destination | Custom HTTP、OTLP、Datadog、Loki、S3、Sentry、Axiom、Last9、Syslog | MVPはdirect S3を優先 |
| 配信 | HTTP系は最大250 eventsまたは1秒でbatch | 転送先はburstを許容する |
| Custom HTTP | header認証は可能だがrequestは現在unsigned | productionでは採用しない |
| S3 | 所有bucketへbatch fileを書き込む。専用Access Keyが必要 | 最小権限IAM、暗号化、private bucketを必須にする |
| 課金 | 1 drain $0.0822/時（約$60/月）、$0.20/100万events、egress | drain数を最小化する |
| Spend Cap | Log Drainsは対象外 | 別途budget alertと月次確認が必要 |

Supabase dashboardの現在planは、導入直前にOwnerが再確認する。Issue本文の
「Free plan」という記録だけを将来の課金判断に使わない。

## 3. 転送対象ログ

Log Drainsはstack全体を転送する前提とし、次を監査対象とする。

| Source | 主な用途 | 重点event |
| --- | --- | --- |
| API Gateway / PostgREST | 不正利用、障害、rate limit調査 | status、method、route、latency、request ID |
| Auth | account takeover、login障害調査 | sign-in、sign-up、token失敗、provider、IPの匿名化値 |
| Postgres | 接続・query・migration障害調査 | error level、database role、duration、SQLSTATE |
| Storage | unauthorized access、配信障害調査 | bucket、operation、status、request ID |
| Realtime | connection・subscription障害調査 | channel種別、disconnect理由、status |
| Edge Functions | application障害、trace相関 | function名、status、duration、trace ID |

raw request/response body、SQL bind値、Authorization/Cookie/apikey、OAuth token、
Supabase secret/service-role key、LLM prompt全文、ユーザー作成コンテンツ本文を
観測目的で新たに記録してはならない。email、IP、user ID、URL queryは個人情報を
含み得るため、転送先では**機密ログ**として扱う。

## 4. 転送先の費用対効果

### 4.1 Supabase側の最低費用

1 project、1 drainの月額概算は次式で管理する。

```text
Supabase monthly cost
= plan base ($25 for Pro)
+ drain hours (about $60 per continuously configured drain)
+ ceil(events / 1,000,000) * $0.20
+ exported GB * $0.09
+ destination storage/query/request cost
```

したがって、Pro + 1 drainは少なくとも**約$85/月**、2 drainsは少なくとも
**約$145/月**である。例として5百万events・10GB egress・1 drainなら、
destination費用を除く追加込み概算は `$25 + $60 + $1 + $0.90 = $86.90/月`。
税、project compute、保存・検索費用は別に見積もる。

### 4.2 候補比較

| Destination | 適性 | コスト特性 | セキュリティ/運用 | 判定 |
| --- | --- | --- | --- | --- |
| Amazon S3 | 90日archive、監査証跡、将来のAthena調査 | 従量storage/request。検索時に追加費用 | private bucket、SSE-KMS、最小権限IAM、Lifecycleが必要 | **第一候補** |
| Sentry Logs | 障害調査、既存Sentryとの相関、alert | Developerは5GB・30日lookback。Teamは$26/月からで最大90日 | DSN管理、PII設定、quota設定が必要 | hot検索が必要な時の第二候補 |
| Axiom | 高速検索、低〜中volumeのpilot | Personalのalways-free枠あり。超過はusage based | ingest-only token、DPA、data region確認が必要 | pilot候補、監査正本には未採用 |
| Datadog | SIEM、複合dashboard、alert | ingestとindex eventの従量課金 | 強力だがsolo/MVPには運用面が過剰 | 法人要件発生時に再評価 |
| Custom HTTP / OTLP | 独自filter・fan-out | drainを1本にできる可能性があるが運用費を内製 | Custom HTTPはunsigned。receiver保守とDLQが必要 | production不採用 |

S3は保存単価だけでなくrequest、retrieval、最低保存期間の条件があるため、
導入時は東京regionのAWS Pricing Calculatorで「平均events/日」「batch timeout」
「90日保持」「月1回の調査」を入力して再見積もりする。S3 batch timeoutは
Supabase推奨の2,000〜5,000msから開始し、小objectとPUT回数を実測して調整する。

## 5. セキュリティ・プライバシー要件

### 5.1 必須統制

1. 転送先はprivateで、public accessを全面禁止する。
2. 保存時暗号化とTLS転送を必須にする。S3はSSE-KMSを第一候補とする。
3. Supabaseに登録するcredentialは転送専用とし、対象prefixへの書込み以外を
   許可しない。長期access keyを発行する場合は四半期ごとに棚卸しする。
4. credential値をrepository、Issue、PR、Actions log、スクリーンショットへ
   記録しない。記録するのはcredential名、owner、作成日、rotation期限だけとする。
5. 転送先の閲覧権限はCEOとインシデント対応ownerに限定し、四半期ごとに確認する。
6. destination vendorのDPA、subprocessor、data region、削除保証、侵害通知条項を
   production有効化前に確認する。
7. stagingで24時間sampleを取得し、secret、token、本文、不要なPIIが含まれないことを
   security reviewerが確認する。違反が1件でもあればproductionへ進めない。
8. raw logのexportや共有はincident IDと目的を伴う場合だけ許可する。

### 5.2 発生元でのredaction

Log Drains側のfilterやsamplingを前提にしない。アプリとEdge Functionsは、
`trace_id`、action名、status、duration、categorical error codeを記録し、入力本文や
credentialを記録しない。emailは必要な場合もmaskまたはhash化し、IPは
[`PRIVACY_POLICY_DRAFT.md`](./PRIVACY_POLICY_DRAFT.md) の即時匿名化方針に従う。

## 6. 保持・ローテーション・削除方針

| Data | Hot/searchable | Archive | 削除 |
| --- | --- | --- | --- |
| Supabase raw platform logs | plan標準期間内 | S3で90日 | object作成から90日後にLifecycleで自動削除 |
| Incident evidence | incident対応中 | legal hold prefix | CEO解除後、元の90日policyへ戻す |
| 匿名化した月次集計 | dashboard/Wiki | 必要な期間 | 個人を再識別できないことを年次確認 |
| drain設定・access変更履歴 | GitHub Issue/PRとvendor audit | 1年 | 年次review後に削除可 |

- raw access logは90日を超えて保持しない。契約・法令・係争に基づくlegal holdだけを
  期限付き例外とし、理由、owner、解除条件をIssueへ記録する。
- Lifecycle ruleの変更、bucket policyの変更、drainの追加・停止はPRまたはIssueに
  変更理由と検証結果を残す。
- 月次でobject到着、最古object日付、削除実績、Supabase usage/invoiceを確認する。
- 四半期で閲覧者、IAM key、destination契約、90日policyとの整合を確認する。

## 7. 導入ゲートと実施手順

### 7.1 Go条件

次のすべてを満たした場合だけproduction導入へ進む。

- 法令、顧客契約、またはincident responseで外部保持の必要性が文書化されている。
- CEOがplan upgradeと最低約$85/月 + destination費用を承認している。
- destinationのDPA/data region/security reviewが完了している。
- staging sampleのPII/secret reviewがpassしている。
- 90日Lifecycle、budget alert、到着遅延alert、ownerが設定済みである。
- [`ONCALL_INCIDENT_SOP.md`](./ONCALL_INCIDENT_SOP.md) から参照できる。

### 7.2 Staging

1. Supabase dashboardで現在planと対象projectを再確認する。
2. 専用S3 bucket、KMS key、write-only IAM principal、90日Lifecycleを作成する。
3. Project Settings > Log DrainsでS3 drainを1本作成する。secret値は画面外へコピーしない。
4. Auth失敗、正常API request、Postgres error、Storage request、Edge Function traceを
   意図的に発生させ、各sourceが5分以内に到着することを確認する。
5. 24時間後、secret/PII scan、event数、GB、PUT数、検索/復旧手順を確認する。
6. 不足や漏えいがあればdrainを停止し、ログ発生元を修正して再試験する。

### 7.3 Production

1. Issueに承認者、予算、destination、保持期間、staging証跡を記録する。
2. production専用credentialとprefixでdrainを作成する。
3. canary eventを送り、destinationのtimestampとsourceを照合する。
4. 24時間のevent/egress見積もりから月額を再計算し、budget超過なら停止する。
5. 月次・四半期点検をWBSへ登録する。

## 8. 監視、障害、停止

- 最終到着時刻が15分以上遅れた場合はSEV2候補として調査する。
- destinationの4xx/5xx、credential失効、bucket deny、egress急増をalert対象にする。
- 転送停止時もSupabase標準ログを最初の調査源とし、drain復旧までアプリの機密情報を
  増やしてログ出力しない。
- credential漏えい時はdrainを停止し、credentialを失効、再発行してから再開する。
- 予算超過、不要化、vendor incident時はdashboardからdrainを削除する。時間課金は
  削除時点以降停止するが、destinationの既存objectは90日policyに従って削除する。
- Custom HTTPへのfallbackは、request署名、replay対策、DLQ、receiver監視が揃うまで
  禁止する。

## 9. 受入条件との対応

| Issue #2860 Acceptance Criteria | 対応 |
| --- | --- |
| 転送対象ログの種類が一覧化されている | §3で6 sourceと重点eventを定義 |
| 費用対効果とdata protection riskの評価 | §4、§5で最低費用、5候補、統制、非採用理由を定義 |
| 保存期間・rotationの組織policyがWiki化されている | §6で90日削除、legal hold、月次/四半期点検を定義 |
| Free/paid planと公式仕様の事前確認 | §2で公式仕様を確認し、§7で再確認gateを必須化 |

## 10. 公式参照

- [Supabase Log Drains](https://supabase.com/docs/guides/monitoring-and-debugging/log-drains)
- [Supabase Manage Log Drain usage](https://supabase.com/docs/guides/platform/manage-your-usage/log-drains)
- [Supabase Pricing](https://supabase.com/pricing)
- [Supabase Logging](https://supabase.com/docs/guides/monitoring-and-debugging/logs)
- [Amazon S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [Sentry Pricing](https://sentry.io/pricing/)
- [Axiom Limits](https://axiom.co/docs/reference/limits)
- [Datadog Pricing](https://www.datadoghq.com/pricing/)
