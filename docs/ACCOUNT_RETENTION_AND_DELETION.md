# アカウント保持・削除設計（Issue #2844）

更新日: 2026-08-30
実装ポリシー: `2026-08-30.v2`
状態: production配備済み / owner方針採択済み / scheduled worker停止中 / 外部法務・税務レビュー未実施

## 1. 決定事項

- サブスクリプション解約とアカウント退会を分離する。解約だけではデータを削除せず、Free アカウントとして保持する。
- 退会申請は現在の Auth session が直近15分以内の再ログインで新規作成されていることと、確認文入力を要求する。別端末の `last_sign_in_at` や通常のtoken refreshは再認証として扱わない。
- 既存の公開ポリシーに合わせ、申請から30日を取消猶予とする。有料期間の終了がそれより後なら、削除予定日は有料期間終了後とする。
- 自動 worker は daily で due request を1件ずつ claim し、重複実行を `FOR UPDATE SKIP LOCKED` で防ぐ。
- データ inventory が不完全なら何も削除せず停止する。登録済みの plain `user_id` 所有テーブルは service-role adapter で削除し、新規・曖昧な所有列は fail-closed とする。完了は JWT 失効待ち後の再削除・残存検査が0件の場合だけ記録する。
- 完了証跡は `user_id` を消し、日時・件数・処理結果だけを匿名の運用証跡として残す。

30日は法的な一律要件ではなく、リポジトリの公開ポリシーに既に記載されていたサービス上の取消猶予である。変更する場合は、法務レビュー、ポリシー改訂、migration / Edge Function 定数、テストを同じリリースで更新する。

## 2. 一次情報で確認した境界

- EU Commission の GDPR 解説は、個人データを目的上必要な最短期間だけ保持し、削除または見直しの期限を設けるよう求める。一律の日数は定めていない。<https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/principles-gdpr_en>
- Paddle は buyer と vendor を独立した controller とし、buyer が vendor 側へも別途削除を求める必要があると説明する。また Paddle 自身は一定の取引データを法令対応で5年保持する。現行 repository の課金実装は Stripe であり、Paddle customer data は保持していない。<https://www.paddle.com/help/manage/your-customers/requesting-buyer-data-deletion>
- Stripe は customer 削除でカード情報を除去し、active subscription も終了すると説明する一方、削除済み customer の履歴や法令上必要な取引情報が残り得る。<https://docs.stripe.com/api/customers/delete> <https://docs.stripe.com/privacy/deletion-requests>
- Supabase は Auth user より先に、その user が owner の Storage object を削除する必要がある。既発行 access token は `exp` まで有効になり得るため、本 project の1時間 JWT expiry と RLS / session deletion を併用する。<https://supabase.com/docs/guides/auth/managing-user-data>
- Storage object は SQL で metadata だけを消さず、Storage API で削除する。API の1回上限は1,000 object。<https://supabase.com/docs/guides/storage/management/delete-objects>
- Supabase の daily backup は plan により7 / 14 / 最大30日、PITR は設定した recovery retention に従う。Storage object 本体は database backup に含まれない。<https://supabase.com/docs/guides/platform/backups>

この文書は実装上の判断記録であり、法的助言ではない。

## 3. データ inventory と削除方式

| 対象 | 発見方法 | 処理 | 完了条件 |
|---|---|---|---|
| `public` の user 所有列 | `pg_catalog` で UUID の `user_id`, `*_user_id`, `owner_id`, `*_owner_id`, `author_id`, `created_by`, `updated_by`, `requested_by` を毎回列挙 | `auth.users` への `ON DELETE CASCADE` / `SET NULL` と、`account_deletion_direct_delete_adapters` に登録済みの plain `user_id` を自動許可 | populated な新規・曖昧所有列 / RESTRICT / NO ACTION 列が0。direct delete 後の対象行が0 |
| Supabase Storage | `storage.objects` の `owner_id` / `owner`、既存規約の `{user_id}/...`、service生成画像の `openai/{user_id}/...` を service-role RPC で列挙 | bucket ごとに Storage API `remove`、1,000件単位 | 対象 object が0 |
| Supabase Auth | `auth.admin.deleteUser(user_id)` | Storage / Stripe 成功後に hard delete | user が不存在（再試行時の404も成功扱い） |
| billing tables | `billing_subscriptions.user_id` FK | Auth delete の cascade | user 紐付き row が0 |
| Stripe | `billing_subscriptions.stripe_customer_id` | Customer DELETE（既に不存在なら冪等成功） | Customer が deleted / resource missing |
| Paddle | repository / migration / function の利用有無 | 現在は対象なし。導入時は processor registry と削除 adapter を追加 | 未導入を確認 |
| 監査証跡 | `account_deletion_requests` | 完了時に `user_id` と error を除去 | 個人識別子なし |
| 自分API監査ログ | `user_api_audit_log` | 既存の不正防止方針に従い最大90日保持し、既存purge jobで期限後削除 | account deletionの完了判定から明示除外し、90日超の行がない |
| database backup | Supabase plan / PITR 設定 | 通常系から隔離し期限失効。restore runbook で削除を再適用 | 保持期限経過または再削除済み |

対象列の命名が inventory pattern から外れる新規 migration は、同じ変更で inventory pattern または明示 adapter を更新する。plain `user_id` も自動承認せず、保持根拠を確認して direct delete registry、匿名化、期限付き保持のいずれかを選ぶ。`account_deletion_dependency_inventory()` の結果に populated blocker がある場合、worker は `failed` として24時間後に再試行し、Storage / Stripe / Auth を変更しない。

## 4. 処理シーケンス

1. Flutter が user JWT で `account-lifecycle:status` を取得する。
2. 退会申請時、Edge Function が検証済みaccess tokenの `session_id` と `auth.sessions` を照合し、現在sessionの作成から15分超ならメールアカウントのパスワードまたは Google OAuth による再ログインを要求する。refresh後も同じsession rowを使うため、token refreshだけでは条件を満たさない。
3. active subscription が `cancel_at_period_end=false` なら申請を拒否し、billing portal を案内する。
4. `scheduled_for = max(requested_at + 30 days, current_period_end)` として request を作る。同一 user の active request は1件に制限する。
5. worker が初回claimするまでは user が self-service で cancel できる。claim後は部分削除が始まり得るため、失敗・再試行待ちを含め取消不可とする。
6. daily worker が due request を atomic claim する。
7. DB inventory の populated blocker が0か検査する。
8. Stripe Customer、plain `user_id` の DB data、Storage object、Auth user / cascade data の順で削除する。
9. Auth user 削除時刻を記録し、本 project の1時間 JWT expiry に5分の安全余裕を加えた65分後まで finalization を延期する。この間は request を匿名化・completed にしない。
10. 失効待ち後に DB direct delete と Storage delete を再実行し、削除前に発行された JWT から再作成された行も除去する。DB inventory の残存が0なら request の `user_id` を消して completed にする。
11. 各段階の失敗は safe error code と retry time、累積 Storage 削除件数、Stripe / Auth 削除済み状態を記録し、最大10回まで冪等再試行する。

## 5. 部分失敗と復旧

- Stripe 削除後の失敗: Customer DELETE の resource missing を成功扱いし、次回 Storage から継続する。
- Storage の途中失敗: 削除済み件数を累積記録し、次回は残存 object だけを列挙する。
- Auth 削除後の応答消失: user not found を成功扱いし、Auth 削除時刻からの JWT 失効待ち、再削除、残存検査、完了記録を再実行する。
- inventory blocker: 自動削除を開始しない。対象 table / column の保持根拠を決め、CASCADE、SET NULL、匿名化 adapter のいずれかを migration で追加する。
- 10回失敗: 自動 claim 対象外となる。operator が原因を修正し、attempt / retry state を明示的に回復する。

## 6. production rolloutゲート

配備済みのcontrol planeは、workerを停止したまま退会申請、取消、inventory、retry状態を保持する。2026-08-29のproduction recovery deployと公開ポリシー / アプリ導線反映は完了済みである。

- [x] [`ACCOUNT_RETENTION_LEGAL_DECISION_RECORD.md`](ACCOUNT_RETENTION_LEGAL_DECISION_RECORD.md)にownerのプロダクト方針採択、外部専門家レビュー未実施、保持例外と再レビュー条件を記録する
- [x] Supabaseのdaily backup / PITR実測値とAuth JWT expiry実測値を決裁記録へ転記する（JWTの読み取り専用cloud audit: GitHub Actions run `33298236393`）
- [x] disposable cloud fixtureで対象の削除可能行 / Auth / Storage残存0、90日audit例外の保持、control tenant無変更を確認する（GitHub Actions run `33296894254`）
- [x] productionで`disabled`の非破壊preflightを実行し、`candidate:null / no_due_request`、破壊処理skipを確認する（GitHub Actions run `33297460725`）
- [x] Issue完了時の段階を`disabled`と決定する。due requestがない状態で実アカウントを作為的に削除せず、将来の初回処理時だけ指定ID・1件・typed confirmation付き`canary`へ進む

workerは`ACCOUNT_DELETION_ROLLOUT_STAGE=disabled`をIssue完了時の承認済みsteady stateとする。scheduled処理は`limited` / `full`かつ`ACCOUNT_DELETION_AUTOMATION_ENABLED=true`の場合だけ動作する。新しいdue requestを初めて処理するときは決裁記録のcanary条件を満たし、実行後の匿名完了と残存0を確認するまでscheduled workerを有効化しない。
