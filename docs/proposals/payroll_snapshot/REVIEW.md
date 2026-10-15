# 給与入金直後スナップショット：保存と根拠取得のレビュー案

更新: 2026-10-15。未適用の設計案。既存の月末機能を有効化せず、過去履歴も削除しない。

## 利用者が確認する変更

給与口座ごとに「給与入金直後の残高」を記録し、同じ口座の前月と比較する。予定給与日・給与明細・現在残高だけでは直後残高を確定しない。比較目標は利用者が任意設定する。

初期実装で自動化するのは、本人が根拠と直後残高を確認した時の保存・重複防止・比較更新まで。未接続の銀行APIや銀行行取込を、既に自動取得できると案内しない。銀行給与行と取引後残高を検証する取込アダプターは別工程であり、初期の本人確認記録を「銀行確認済み」と表示しない。

## 追加する保存単位

| テーブル案 | 主な列 | 制約と用途 |
|---|---|---|
| asset_payroll_accounts | user_id UUID、id UUID、display_label TEXT、target_increase_yen BIGINT NULL、archived BOOL | 所有者と口座IDの複合一意。口座番号は保存しない。目標額NULLは未設定 |
| asset_payroll_balance_observations | user_id、id、account_id、payroll_month DATE、deposit_reference、deposit_date DATE、date_precision、deposited_at/observed_at TIMESTAMPTZ NULL、balance_yen BIGINT、evidence_kind、source_note、request_id、recorded_at、expected_previous_id、selection_reason | 本人確認の観測を追記保存。CSVはday精度で時刻NULL、時刻が分かる時だけinstant精度。時刻観測が入金前なら拒否。月は1日正規化。request_idで再送重複防止。所有者・口座・月・IDの複合一意 |
| asset_payroll_balance_selections | user_id、account_id、payroll_month、observation_id、reason | 各月の明示選択済み観測を1件だけ参照。複合FKで別人・別口座・別月の観測を選択不可 |
| asset_payroll_balance_selection_history | user_id、account_id、payroll_month、old_observation_id、new_observation_id、reason、changed_at | 選択の変更履歴。server triggerのみ追記。クライアントによる履歴上書き不可 |

外部キーはownerを含む複合キーにする。account_idだけの照会・参照にしない。accountは本人の給与口座設定であり、他人のcfo_assetsを自由参照する列を設けない。既存workbookの口座に接続する場合も、認可済みownerの設定から選択し、口座名一致で別口座を自動統合しない。

### RLS・GRANT契約

- 全4表でRLSを有効化する。PUBLICとanonへの全権限を剥奪。
- accountsはauthenticatedの本人行だけSELECT/INSERT/UPDATE可能。UPDATEはUSING/WITH CHECK双方でowner固定。
- observationsは本人行のSELECTのみ。クライアントの直接INSERT/UPDATE/DELETEをGRANTとpolicy双方で禁止する。訂正は限定RPCが新観測を追加し、recorded_atもserverで設定する。
- selectionsは本人行のSELECTのみ。直接INSERT/UPDATE/DELETEは禁止。変更理由と期待する旧選択を必須とする限定RPCだけが訂正を行い、他ownerのIDはowner照合と複合FKで拒否する。
- historyは本人行のSELECTのみ。変更triggerは空search_pathで対象schemaを完全修飾し、認証ownerを照合する。直接EXECUTEとINSERT/UPDATE/DELETEは全クライアントから剥奪。
- 所有者削除はauth.usersのcascadeで関連観測/履歴も削除。通常のUIでは口座をarchiveにして履歴を保持する。個別削除機能は別途設計・本人選択とする。
- service roleをブラウザへ置かない。publicにはinvoker wrapperだけを公開し、非公開schemaの限定definer実装でauth.uidを取り、全SQLにownerを固定する。authenticatedには当該関数のEXECUTEとschema USAGEだけを追加し、他private関数の直接EXECUTEは剥奪する。直接DMLで確認・再送・競合契約を回避する経路を作らない。

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

純粋比較のPR5787は上記の比較部分のみ。本フォルダのDRAFT_PAYROLL_SCHEMA.sqlは本番適用されない保存案で、migrationフォルダへ置かない。contract.sqlとconcurrency.pyは使い捨てpayroll_contract DBだけで2利用者・自己昇格拒否・再送・訂正競合・監査atomicを検証する。SQL試験は改修head 1a3e9d001619205ea0be8e1b0ef183e32cd73756の[隔離Postgres試験](https://github.com/kanta13jp1/my_web_app/actions/runs/38742020218)で成功。直接DMLによる明示確認回避・旧選択上書きの拒否、2利用者の分離、同内容再送、同時訂正の片方拒否と監査atomicを確認済み。UIは未実装で、以下は保存前の具体プレビュー。本人の具体確認前にmigration適用・本番書込・新しい自動取得は行わない。

## 既存銀行取込との接続調査

SmbcCsvImportServiceは各入金行にbalanceとimportKeyを保持する。本人が給与行と確認した行の取引後残高を使えるため、後日のlatestBalanceから復元する必要はない。PR5791で残高の符号保持・無効日付拒否・日精度の候補と本人確認アダプターを準備している。CSVを再度金融flowへ登録するのではなく、既存取込元と選択行を参照する。32bit短縮importKeyだけをグローバル一意証明とせず、owner・口座・取込元（ファイル内容の強いダイジェスト等）・行を保存層で結びつける。銀行APIの自動巡回はまだ存在しない。

## 根拠

- 既存 `asset_month_end_snapshot_service.dart` / `20261015171000_asset_month_end_balance_snapshots.sql`: cfo_assets最終観測による月末保存で、給与入金後の証拠ではない。
- [Supabase RLS公式資料](https://supabase.com/docs/guides/database/postgres/row-level-security): exposed表のRLS、最小GRANT、操作別policyと試験。
- 2026-10-15に公式changelogを確認。新規SDKや拡張を追加する設計ではない。TLS変更は最新ブラウザ経路に関係し、この保存契約の方式変更は不要。

## 保存前画面の具体プレビュー（合成データ・未実装）

> **給与入金直後の残高を記録**  
> 口座：給与口座A（口座番号は保存しません）  
> 給与対象月：2026年9月  
> 入金日：2026年9月25日 ／ 日単位（時刻は未取得）  
> その給与入金取引の直後残高：120,000円  
> 確認資料メモ：銀行明細の給与入金行を本人が確認  
> 記録種別：本人確認（銀行による検証済みではありません）  
> □ 後日の現在残高ではなく、給与入金取引の直後残高を確認しました  
> **［保留する］ ［確認して保存］**

チェック未選択では保存不可。資料メモは短文テキストのみで、PDF・画像・口座番号はこの保存操作では送信しない。保存対象は本人の口座設定・この観測・月の選択・訂正履歴で、本人だけが閲覧できる。既存残高・収入・支出・振替は変更しない。銀行への自動接続・自動取得は行わない。

既存記録を訂正する場合は、旧記録を並べて「訂正理由」を必須表示し、旧選択が変わっていたら保存せず再確認する。直後残高が分からない場合は保留し、推定値を確定保存しない。本番適用・実画面の実装は具体本人確認後の工程。