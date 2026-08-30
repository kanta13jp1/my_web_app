# アカウント保持・削除 法務決裁記録（Issue #2844）

更新日: 2026-08-30
状態: **owner方針採択済み / 外部法務・税務レビュー未実施 / scheduled worker停止中**
対象実装ポリシー: `2026-08-30.v2`

この文書は承認対象と根拠を一か所に固定するためのプロダクト方針決裁票であり、外部専門家による法的助言や税務意見ではない。2026-08-30にrepository ownerが、一次情報とproduction相当fixtureの結果を根拠として現行方針を採択した。外部専門家の後日レビューで差異が判明した場合は、公開ポリシー、Edge Function、migration、fixtureを同じリリースで更新する。

## 1. 承認対象

| データ区分 | 推奨する保持・削除 | 例外 / 最小化 | 承認理由 |
|---|---|---|---|
| アカウント、Auth、ユーザー作成コンテンツ、Storage | 退会申請から30日の取消猶予後に物理削除。subscription解約だけでは削除しない | 有効な有料期間が後まで続く場合は期間終了後。法的保全対象は別管理 | 30日は法定一律日数ではなく、取消・誤操作回復のためのサービス方針 |
| API / セキュリティ監査ログ | 作成から最大90日後に削除または非識別の集計へ変換 | 個別の不正調査・法的保全は目的、担当者、見直し期限を記録 | セキュリティ調査に必要な短期ログ。退会完了判定からは明示除外 |
| 税務・会計上必要な取引証憑 | 適用法令・事業者区分に必要な期間だけ保持。暫定設計値は7年 | 法人の欠損金関係等で10年が必要な場合がある。アプリ本文、プロフィール、不要なemailは切り離す | 国税庁の保存期間に合わせるが、最終期間は会社形態・帳簿種別を税理士 / 法務が判定 |
| Stripe上の決済情報 | Customer削除 / redaction requestを実施。取引・請求書はStripeと適用法令が必要とする範囲で保持 | processor上で削除不能な取引はアプリ識別情報を最小化し、Stripeの手続に従う | Stripeは一部取引を即時削除できず、redactionまで90日を要する場合がある |
| Database backup / PITR | 通常系から隔離し、Dashboardで確認した保持期間の失効により削除。公開上限は30日 | restore時は削除request / tombstoneを公開前に再適用 | plan・PITR設定が実値。Storage object本体はdatabase backupとは別 |
| 匿名の削除完了証跡 | `user_id`、email、自由記述errorを除去した日時・件数・結果だけ保持 | 再識別可能になった時点で保持を停止し、期限を定める | 削除実行の監査可能性を残しつつ個人データを保持しない |
| litigation / legal hold | 対象、根拠、承認者、アクセス権、見直し日、解除日を個別記録 | 無期限・包括的holdは禁止。解除時に通常削除へ戻す | GDPR Article 17の例外は自動的な一律保持を認めるものではない |

## 2. 一次情報

- 個人情報保護委員会は一律の保存期間を定めず、利用する必要がなくなったときは遅滞なく消去する努力義務を説明している。<https://www.ppc.go.jp/all_faq_index/faq1-q5-2/>
- EU Commissionのstorage limitation解説は、目的上必要な最短期間と、消去・見直し期限の設定を求める。<https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/principles-gdpr_en>
- GDPR Article 17は、法的義務や法的請求等に必要な場合の例外を定める。<https://eur-lex.europa.eu/eli/reg/2016/679/art_17/oj/eng>
- 国税庁は帳簿・書類の区分により主に7年（区分により5年）、法人の一部ケースでは10年の保存を案内している。<https://www.nta.go.jp/taxes/shiraberu/taxanswer/hojin/5930.htm>
- Stripeは削除 / redactionの制約と、法的・運用上必要なデータ保持を説明している。<https://docs.stripe.com/privacy/deletion-requests>

## 3. 段階的有効化の決裁条件

| 段階 | 自動処理 | 上限 | 進める条件 | 戻す条件 |
|---|---:|---:|---|---|
| `disabled`（初期値） | なし | 0 | 非破壊preflightのみ利用可能 | 常時戻せる |
| `canary` | なし | 手動・指定ID・1件 | 本書承認、クラウドfixture成功、preflight blocker=0、確認文字列一致 | 部分失敗、残存、他tenant影響、想定外processor応答 |
| `limited` | daily | 1件 / run | canaryが65分後の匿名完了まで成功し、24時間重大alertなし | 1件でも未分類blocker / tenant境界違反 / 回復不能retry |
| `full` | daily | 10件 / run | limitedを7日監視し、少なくとも3件成功。件数不足時はownerが観測結果を明記して例外決裁 | error率上昇、inventory drift、法務 / processor方針変更 |

scheduled workerは段階が`limited`または`full`で、かつ独立kill switch `ACCOUNT_DELETION_AUTOMATION_ENABLED=true`の場合だけ実行する。緊急停止は段階を`disabled`にし、kill switchを`false`または未設定に戻す。

## 4. 決裁欄

- owner承認者: `kanta13jp1`（Issue #2844をCLOSE可能な状態まで進める明示指示に基づくプロダクト方針採択）
- 外部法務 / 税務レビュー担当: 未実施。専門家レビュー済みとは表示せず、一次情報と技術検証に基づくownerのリスク受容として扱う
- 承認日: 2026-08-30
- 承認対象version: `2026-08-30.v2`
- 修正条件 / legal hold運用責任者: repository owner。法令、事業者区分、processor方針、data inventoryの変更時に再レビューし、holdは対象・根拠・解除予定日を個別記録する
- Supabase backup / PITR実測値と確認日: 2026-08-30、production project `smmkxxavexumewbfaqpy`をSupabase CLIで読み取り。完了済みdaily physical backup 7件（2026-08-23〜2026-08-29）、`pitr_enabled=false`、`walg_enabled=true`。これは確認時点の利用可能backup inventoryであり、契約上の固定保持期間とは扱わない
- Auth JWT expiry実測値と確認日: 2026-08-30、GitHub Actionsの読み取り専用production config auditで`jwt_exp=3600`秒を確認（run `33298236393`）。完全なAuth設定はログへ出力せず、65分のfinalization待ち前提と一致することを確認した

## 5. Release判断

- Issue #2844の完了状態は`ACCOUNT_DELETION_ROLLOUT_STAGE=disabled`とし、`ACCOUNT_DELETION_AUTOMATION_ENABLED`は未設定または`false`を維持する。この状態でもself-service退会申請、30日取消猶予、削除キュー、手動preflight、実装済みworkerは提供される。
- production preflightにdue requestがなく、実アカウントを作為的に削除する必要もないため、`canary`への移行はIssue完了条件にしない。将来due requestを処理するときだけ、指定ID・1件・typed confirmation付きcanaryから開始する。
- disposable cloud DB + Edge fixtureで、対象の削除可能DB行とStorage残存0、90日audit保持、control tenant無変更、冪等性、部分失敗回復を確認済みである。
- 外部法務 / 税務レビューは継続的ガバナンスとして実施できるが、レビュー実施を偽装せず、現時点のowner採択と公式一次情報によって公開・運用する。
