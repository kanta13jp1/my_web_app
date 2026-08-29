# アカウント保持・削除設計（Issue #2844）

更新日: 2026-08-29
実装ポリシー: `2026-08-29.v1`
状態: 実装済み / production 適用前に owner・法務レビュー必須

## 1. 決定事項

- サブスクリプション解約とアカウント退会を分離する。解約だけではデータを削除せず、Free アカウントとして保持する。
- 退会申請は直近15分以内の再ログインと確認文入力を要求する。
- 既存の公開ポリシーに合わせ、申請から30日を取消猶予とする。有料期間の終了がそれより後なら、削除予定日は有料期間終了後とする。
- 自動 worker は daily で due request を1件ずつ claim し、重複実行を `FOR UPDATE SKIP LOCKED` で防ぐ。
- データ inventory が不完全なら何も削除せず停止する。完了は残存検査が0件の場合だけ記録する。
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
| `public` の user 所有列 | `pg_catalog` で UUID の `user_id`, `*_user_id`, `owner_id`, `*_owner_id`, `author_id`, `created_by`, `updated_by`, `requested_by` を毎回列挙 | `auth.users` への `ON DELETE CASCADE` / `SET NULL` のみ自動許可 | populated な未分類 / RESTRICT / NO ACTION 列が0 |
| Supabase Storage | `storage.objects` の `owner_id` / `owner`、既存規約の `{user_id}/...`、service生成画像の `openai/{user_id}/...` を service-role RPC で列挙 | bucket ごとに Storage API `remove`、1,000件単位 | 対象 object が0 |
| Supabase Auth | `auth.admin.deleteUser(user_id)` | Storage / Stripe 成功後に hard delete | user が不存在（再試行時の404も成功扱い） |
| billing tables | `billing_subscriptions.user_id` FK | Auth delete の cascade | user 紐付き row が0 |
| Stripe | `billing_subscriptions.stripe_customer_id` | Customer DELETE（既に不存在なら冪等成功） | Customer が deleted / resource missing |
| Paddle | repository / migration / function の利用有無 | 現在は対象なし。導入時は processor registry と削除 adapter を追加 | 未導入を確認 |
| 監査証跡 | `account_deletion_requests` | 完了時に `user_id` と error を除去 | 個人識別子なし |
| database backup | Supabase plan / PITR 設定 | 通常系から隔離し期限失効。restore runbook で削除を再適用 | 保持期限経過または再削除済み |

対象列の命名が inventory pattern から外れる新規 migration は、同じ変更で inventory pattern または明示 adapter を更新する。`account_deletion_dependency_inventory()` の結果に populated blocker がある場合、worker は `failed` として24時間後に再試行し、Storage / Stripe / Auth を変更しない。

## 4. 処理シーケンス

1. Flutter が user JWT で `account-lifecycle:status` を取得する。
2. 退会申請時、Edge Function が Auth の `last_sign_in_at` を検査し、15分超なら Google OAuth 再ログインを要求する。
3. active subscription が `cancel_at_period_end=false` なら申請を拒否し、billing portal を案内する。
4. `scheduled_for = max(requested_at + 30 days, current_period_end)` として request を作る。同一 user の active request は1件に制限する。
5. 期限までは user が self-service で cancel できる。
6. daily worker が due request を atomic claim する。
7. DB inventory の populated blocker が0か検査する。
8. Stripe Customer、Storage object、Auth user / cascade data の順で削除する。
9. DB inventory を再検査し、残存0なら request の `user_id` を消して completed にする。
10. 各段階の失敗は safe error code と retry time だけを記録し、最大10回まで冪等再試行する。

## 5. 部分失敗と復旧

- Stripe 削除後の失敗: Customer DELETE の resource missing を成功扱いし、次回 Storage から継続する。
- Storage の途中失敗: 次回は残存 object だけが列挙される。
- Auth 削除後の応答消失: user not found を成功扱いし、残存検査と完了記録を再実行する。
- inventory blocker: 自動削除を開始しない。対象 table / column の保持根拠を決め、CASCADE、SET NULL、匿名化 adapter のいずれかを migration で追加する。
- 10回失敗: 自動 claim 対象外となる。operator が原因を修正し、attempt / retry state を明示的に回復する。

## 6. production 適用前ゲート

- [ ] owner / 法務が30日取消猶予、90日アクセスログ、決済 / 税務 / 不正防止の保持例外を承認
- [ ] Supabase Dashboard の実プランと daily backup / PITR retention を確認し、公開ポリシーの「最大30日」と一致
- [ ] staging fixture で inventory blocker 0、tenant 境界、二重申請、取消、worker 冪等性、途中失敗 retry を検証
- [ ] Storage 各 bucket の owner metadata と削除件数を staging で検証
- [ ] Stripe test mode Customer で削除 / resource missing / active subscription guard を検証
- [ ] `account-lifecycle` Edge Function と daily workflow を同一 release で配備
- [ ] backup restore runbook に、通常公開前の削除 request 再適用手順を追加
- [ ] プライバシーポリシー公開とアプリ導線の同時反映を確認

法務承認前に production migration、function deploy、scheduled worker の有効化を行わない。
