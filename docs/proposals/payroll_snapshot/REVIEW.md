# 給与入金直後スナップショット：保存と根拠取得のレビュー案

更新: 2026-10-15。未適用の設計案。既存の月末機能を有効化せず、過去履歴も削除しない。

## 利用者が確認する変更

給与口座ごとに「給与入金直後の残高」を記録し、同じ口座の前月と比較する。予定給与日・給与明細・現在残高だけでは直後残高を確定しない。比較目標は利用者が任意設定する。

初期実装で自動化するのは、本人が根拠と直後残高を確認した時の保存・重複防止・比較更新まで。未接続の銀行APIや銀行行取込を、既に自動取得できると案内しない。銀行給与行と取引後残高を検証する取込アダプターは別工程であり、初期の本人確認記録を「銀行確認済み」と表示しない。

## 追加する保存単位

| テーブル案 | 主な列 | 制約と用途 |
|---|---|---|
| asset_payroll_accounts | user_id UUID、id UUID、display_label TEXT、target_increase_yen BIGINT NULL、archived BOOL | 所有者と口座IDの複合一意。口座番号は保存しない。目標額NULLは未設定 |
| asset_payroll_balance_observations | user_id、id、account_id、payroll_month DATE、deposit_reference、deposited_at TIMESTAMPTZ、observed_at TIMESTAMPTZ、balance_yen BIGINT、evidence_kind、source_note、request_id、recorded_at | 本人確認の観測を追記保存。入金日時と観測日時を別保持。観測が入金前なら拒否。月は1日正規化。request_idで再送重複防止。所有者・口座・月・IDの複合一意 |
| asset_payroll_balance_selections | user_id、account_id、payroll_month、observation_id、reason | 各月の明示選択済み観測を1件だけ参照。複合FKで別人・別口座・別月の観測を選択不可 |
| asset_payroll_balance_selection_history | user_id、account_id、payroll_month、old_observation_id、new_observation_id、reason、changed_at | 選択の変更履歴。server triggerのみ追記。クライアントによる履歴上書き不可 |

外部キーはownerを含む複合キーにする。account_idだけの照会・参照にしない。accountは本人の給与口座設定であり、他人のcfo_assetsを自由参照する列を設けない。既存workbookの口座に接続する場合も、認可済みownerの設定から選択し、口座名一致で別口座を自動統合しない。

### RLS・GRANT契約

- 全4表でRLSを有効化する。PUBLICとanonへの全権限を剥奪。
- accountsはauthenticatedの本人行だけSELECT/INSERT/UPDATE可能。UPDATEはUSING/WITH CHECK双方でowner固定。
- observationsは本人行のSELECTと指定列INSERTのみ。UPDATE/DELETEは付与せず、訂正は新観測を追加する。recorded_atはserver defaultと列GRANTでクライアント指定不可。
- selectionsは本人行のSELECT/INSERT/UPDATEのみ。変更理由を必須とし、他ownerのIDを入れると複合FKとRLSで拒否。
- historyは本人行のSELECTのみ。変更triggerは空search_pathで対象schemaを完全修飾し、認証ownerを照合する。直接EXECUTEとINSERT/UPDATE/DELETEは全クライアントから剥奪。
- 所有者削除はauth.usersのcascadeで関連観測/履歴も削除。通常のUIでは口座をarchiveにして履歴を保持する。個別削除機能は別途設計・本人選択とする。
- service roleをブラウザへ置かない。新しい公開ビューやRPCによるRLS回避は作らない。

## 根拠取得UI

1. 「給与入金後の残高」カードの未取得月に「入金と直後残高を確認」を設置。
2. 給与口座・給与対象月を選択。予定日の到来だけで確定マークを付けない。
3. 本人が入金日時・その取引の直後残高・観測日時を入力し、どの資料で確認したかを短いメモで記載。現在残高の自動入力・推定補完はしない。
4. 「後日の残高ではなく、給与が入った直後の残高である」を明示確認。入金後の出金が既にあり直後値不明なら「入金確認済み・直後残高未取得」のままキャンセル/保留。
5. 保存前に口座・月・日時・残高・根拠・記録種別「本人確認」をまとめて表示。これによって収入や現在残高を追加更新しないことを案内。
6. 同じrequest_idの応答不明時は既存履歴を読み取り、同じ内容なら完了とする。異なる内容なら自動更新せず競合表示。
7. 訂正は旧観測を保持したまま新観測を追加し、理由付きで月の選択を変更。競合時に最大値/最新値を勝手に選ばない。

「自動保存」は今後、検証済み給与入金行とその取引後残高を得た時だけ上記契約を呼ぶ。銀行取込アダプターが未接続の間は「自動取得未対応」と表示し、固定日のcronで代用しない。

## 受入試験と未完了ゲート

| 対象 | 必須検証 |
|---|---|
| 2利用者 | AはBの口座/観測/選択/履歴を読めず、A所有IDをBへ変更できない |
| 未ログイン | 4表の読取・書込が全て拒否される |
| 訂正監査 | 観測UPDATE/DELETEとhistoryへの直接書込が拒否され、理由付き選択変更だけ履歴が追記される |
| 再送 | 同request_idの同内容は1件、異なる内容は確認待ち。保存応答タイムアウト後の再登録なし |
| 時点 | 入金前観測・予定日・給与額一致・現在最大残高では確定不可。入金後の出金があっても直後値を復元しない |
| 月比較 | 前月欠落と0を区別し、同口座の前月のみ比較。12月→1月と口座変更を確認 |
| 金融不変 | cfo_assets/flows/給与入金実績を増減させず、元収入を二重計上しない |
| UI | 320px/拡大文字/desktop、空・取得中・失敗・復旧・訂正・再読込 |

純粋比較のPR5787は上記の比較部分のみ。保存DDL・RLS・SQL試験・UIはまだ実装前。次はこの案から適用されないdraft SQL差分と、使い捨てPostgresでの2利用者試験を作る。本人の具体確認前にmigration適用・本番書込・新しい自動取得は行わない。

## 根拠

- 既存 `asset_month_end_snapshot_service.dart` / `20261015171000_asset_month_end_balance_snapshots.sql`: cfo_assets最終観測による月末保存で、給与入金後の証拠ではない。
- [Supabase RLS公式資料](https://supabase.com/docs/guides/database/postgres/row-level-security): exposed表のRLS、最小GRANT、操作別policyと試験。
- 2026-10-15に公式changelogを確認。新規SDKや拡張を追加する設計ではない。TLS変更は最新ブラウザ経路に関係し、この保存契約の方式変更は不要。
