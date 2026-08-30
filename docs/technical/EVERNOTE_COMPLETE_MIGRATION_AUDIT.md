# Evernote 完全移行・機能パリティ監査表

最終更新: 2026-08-31  
対象: Evernote 全データを本サイトへ段階移行し、検証済みバッチだけを元サービスから削除した後、完全監査と明示承認を経てサブスクリプションを解約する。

## 判定

- **実装・クラウド検証済み**: 合成データを用いた自動テストがクラウドCIで成功している。
- **既存機能あり／同等性未証明**: 本サイトに類似機能はあるが、Evernote相当の動作・データ移行・端末間同期をまだ証明していない。
- **未実装**: 完全移行のための実装または検証が残っている。
- **実データ未検証**: 実際のEvernoteアカウントからの移行結果が0件である。

「実装・クラウド検証済み」は本番反映や実データ移行を意味しない。

## クラウド優先実行原則

- 実装はGitHub上の専用ドラフトPRへ直接コミットし、整形、Flutter analyze、対象テスト、使い捨てPostgreSQL契約をGitHub Actionsで実行する。
- ENEXはブラウザからSupabase Storageへ再開可能なストリーミング転送を行い、ローカルディスクへ全件展開しない。解析・検証もEdge Functionまたはクラウドジョブへ段階移管する。
- ローカルPCではEvernote公式アプリによるエクスポート選択、少数件の目視照合、明示承認だけを行う。Flutter/Dartビルド、ブラウザ自動操作、全文OCR、メディア変換、ENEX全件処理は開始しない。
- 実データ移行、Evernote側削除、本番反映、サブスクリプション解約は、それぞれ直前の監査結果とユーザーの明示承認がある別工程とする。

## データ移行監査

| データ種別 | 現状 | 証拠・制約 | Evernote側削除条件 |
| --- | --- | --- | --- |
| ノート本文・タイトル | 実装・クラウド検証済み | ENEXをノート単位でストリーム解析し、ENML原文と編集用Markdownを保持 | 件数、本文ハッシュ、復元表示を照合 |
| 作成・更新日時 | 実装・クラウド検証済み | ENEX日時をUTCで保存し、検証RPCで照合 | 全件一致 |
| タグ | 実装・クラウド検証済み／実データ未検証 | ENEXタグ配列に加え、ENEX外の親子階層を別棚卸しJSONからowner-scoped表へ保存。タグ・親辺・ノート割当ごとのSHA-256、RLS、循環拒否、冪等再実行、明示的ゼロ件棚卸し、不変原本保護を備える | タグ名集合、親子辺、各ノート割当、項目別・スナップショットSHA-256を全件照合 |
| 添付ファイル | 実装・クラウド検証済み | 非公開Storageへ保存し、SHA-256・件数・存在を検証 | 全添付の件数、サイズ、MIME、SHA-256一致 |
| OCR/recoIndex | 部分実装 | 有効なrecognition XMLを保存。壊れたXMLは原文を残す | OCR文字列照合と、欠損分のクラウドOCR再生成完了 |
| ノートリンク・属性 | 部分実装 | source_metadataへ原情報を保存 | 内部リンクの再接続と全属性の対応表確認 |
| ノートブック | 実装・クラウド検証済み | owner-scoped階層へ正式割当し、検証RPCでnotebook種別を確認 | 全ノートの割当と名称を実データ照合 |
| スタック | 実装・クラウド検証済み | ENEX外の構造を移行画面で入力し、Space配下へ冪等復元 | 実アカウントのスタック棚卸しと全件照合 |
| Space | 実装・クラウド検証済み | ENEX外のSpace名を入力し、owner-scopedツリーへ冪等復元 | Space・権限・所属ノートを実データ照合 |
| ノート履歴 | 部分実装・削除阻止 | 移行画面で履歴件数を棚卸しし、個別ENEXをストリーム取込。ENML・添付・SHA-256・日時を保持し、未確認ならDBがEvernote側削除を拒否 | 必要な履歴版を個別エクスポート・照合し、または履歴なしを明示確認 |
| タスク・リマインダー | 部分実装・UI/削除阻止をクラウド検証済み | 構造化Task、複数Taskリマインダー、ノート・リマインダーをowner-scopedネイティブ表へ原子的に保存。ノート内UIで作成・編集・完了切替・期限・RRULE・複数リマインダー・単一担当者を操作できる。担当メールが本サイト利用者と一致すれば自動関連付けし、担当者はTaskとTaskリマインダーの閲覧・完了切替だけが可能。元メモ本文は自動共有しない。ENEX担当者原本は決定的Task SHA-256と不変source_assigneeへ保存する。担当割当時はリンク済み担当者のアプリ内受信箱へ即時通知し、Task/ノートリマインダーは受信者別RLS、既読・非表示RPC、再割当時の旧受信者削除、完了時の配信停止を備える。対応端末では将来時刻をローカル通知へ登録し、Webは安全にアプリ内通知へフォールバックする。通知は移行原本とは別の再生成可能な派生状態である。全ノート横断Taskセンターは全件ページング、タスク/メモ名/担当者検索、未完了・期限切れ・今日・今後・完了・全件フィルター、完了切替、共有済み元メモ導線を備える。未一致ならDBがEvernote側削除状態を拒否。移行原本は削除完了までDBとUIの双方で保護。en-todoはMarkdownチェックボックス化 | 実データ通知・端末間照合を完了。公式仕様で確認できない招待受諾フローは作らず、Evernote同様の即時割当を照合 |
| 共有・権限 | 既存機能あり／同等性未証明 | チーム共有機能はあるがEvernote共有モデルとの差分が残る | 所有者、共有相手、権限、共有リンクを全件確認 |
| 保存済み検索 | 実装・クラウド検証済み／実データ未検証 | ENEX外のアカウント棚卸しJSONから検索名・検索条件原文・項目別SHA-256をowner-scoped表へ保存。端末間同期されるネイティブCRUD、検索画面への導線、明示的ゼロ件確認、検証RPCを備える。AND/OR/NOT/括弧、any:、除外、引用句、末尾ワイルドカード、intitle:/notebook:/stack:/tag:/created:/updated:/reminderTime:/resource:/source:/todo:/contains:/encryption:を決定的に実行する。添付MIME、source属性、チェック欄、Task、暗号化印、内容種別はowner-scoped保存証拠から導出し、未知の演算子は絞り込みを止めて画面に明示する | 件数、名称、検索条件原文と各演算子を実データで全件照合 |
| ショートカット | 実装・クラウド検証済み／実データ未検証 | ノート、ノートブック、スタック、タグ、保存済み検索の全対象型と順序をowner-scoped表へ保存。1〜9番位置、追加・削除・並び替え・対象画面への導線、未解決対象の検出、RLS、原本不変保護を備える。保存済み検索／ショートカット棚卸しが未検証ならDBが全ノートのEvernote側削除状態を拒否 | 別棚卸しJSONを固定し、件数、順序、各対象の実動作を全件照合 |
| カレンダー連携 | 既存機能あり／同等性未証明 | カレンダーページはあるが外部連携移行は未証明 | Google/Microsoft連携とイベント参照を確認 |
| ゴミ箱内データ | 未監査 | 通常エクスポート対象外の可能性がある | 必要データの復元または不要判断を明示 |
| アカウント設定 | 未監査 | 端末、2FA、連携、メール転送設定など | 設定棚卸しを保存し、代替設定を確認 |

## 機能パリティ監査

| Evernote機能 | 本サイトの現状 | 完了条件 |
| --- | --- | --- |
| ノート作成・編集・検索 | 既存機能あり／同等性未証明 | 書式、チェックリスト、添付、検索演算子をE2E検証 |
| ノートブック・スタック・Space | 移行データ構造はクラウド検証済み／管理UI未実装 | 階層の作成、移動、並び替え、検索、権限UIを実装 |
| タグ・高度な検索 | 構文・階層データモデル・削除ゲートはクラウド検証済み／属性検索・管理UIはActions検証対象 | 大文字のAND/OR/NOTと括弧、any:、除外、引用句、末尾ワイルドカード、resource:/source:/todo:/contains:/encryption:を保存証拠から評価する。階層タグはowner-scoped CRUD/RLS/循環拒否/移行証拠に加え、狭幅/広幅管理UI、原本ロック、子タグ包含/除外フィルターを備える。人物等の証拠不足カテゴリは推測で肯定しない |
| タスク | ノート内・全ノート横断ネイティブUI、担当者、保存、削除ゲートはクラウド検証済み | ENEX構造化Taskの期限、繰り返し、完了状態、複数リマインダー、単一担当者をノート内で操作でき、全ノート横断でタスク/メモ/担当者検索・期限/状態絞り込み・完了切替が可能。担当者は元メモを自動共有されず、Task完了だけを変更できる。原本ハッシュと担当者証跡を検証済み。担当割当・Task/ノートリマインダーのアプリ内通知、既読・非表示、再割当時の権限剥奪、対応端末のローカル通知を実装し、クラウドCI検証済み。実端末で通知時刻と端末間既読状態を照合。招待受諾は公式仕様で確認できないため即時割当を正として照合 |
| カレンダー | 既存機能あり／同等性未証明 | 外部Google/Microsoftカレンダー接続を検証 |
| テンプレート | 既存機能あり／同等性未証明 | テンプレート作成・適用・再編集を検証 |
| オフライン利用 | 未実装相当 | ノートブック単位の安全なオフライン同期・競合解決を実装 |
| Web Clipper | 未実装 | 記事、簡易記事、ページ全体、ブックマーク、スクリーンショットを実装 |
| メールからノート作成 | 未実装 | 件名構文を含む受信、認証、添付保存、迷惑メール対策を実装 |
| PDF/HTML/ENEX相当の輸出 | 部分実装 | 全データの再エクスポートと再インポートによる復旧試験 |
| AI Assistant・AI編集 | 既存機能あり／同等性未証明 | 権限境界、データ保持、主要操作を検証 |
| セマンティック検索 | 既存機能あり／同等性未証明 | 実データ索引、添付OCR、関連度、削除反映を検証 |
| AI文字起こし・Meeting Notes | 未実装 | 音声・会議の文字起こし、要約、話者、データ保持を実装 |
| ノート内暗号化 | 未実装 | 選択範囲暗号化、復号、鍵回復方針を実装 |
| 共有・Shared with Me | 部分実装 | 招待、権限、失効、公開リンク、受信一覧をE2E検証 |
| 2FA・端末管理 | 部分実装／未監査 | Supabase Auth設定と端末セッション失効を本番で確認 |
| MCP・外部連携 | 部分実装 | 必要なGoogle/Microsoft/Slack等の用途を棚卸しして代替 |
| ノート履歴・復元 | 履歴棚卸し・個別ENEX取込UIをクラウド検証済み／復元UI・実データ未検証 | 実履歴の保全、一覧・プレビュー・復元試験を完了 |

## 段階移行の削除ゲート

各バッチは次の状態機械を通る。後戻りできないEvernote側削除は、すべての検証が成功し、そのバッチに対する**新しい明示承認**を得るまで実行しない。

```text
未棚卸し
  ↓
エクスポート済み
  ↓  ENEX SHA-256・件数固定
非公開クラウド保管済み
  ↓  復旧コピーSHA-256一致
本サイト取込済み
  ↓  本文・日時・タグ・添付・OCR・階層・履歴・Task・リマインダーを照合
アカウント状態棚卸し済み
  ↓  保存済み検索・ショートカット・階層タグの件数・原文・順序・親子辺・ノート割当を照合
検証済み
  ↓  ユーザーが対象バッチを明示承認
Evernote側削除中
  ↓  削除対象と件数を再照合
Evernote側削除済み
```

### バッチを「検証済み」にする必須証拠

1. 元ENEXと復旧コピーのSHA-256一致。
2. 元ノート数、取込数、対象ノートIDの一致。
3. 本文、タイトル、作成・更新日時、タグの一致。
4. 添付の件数、サイズ、MIME、SHA-256の一致。
5. OCR/recognition情報または再OCR結果の確認。
6. ノートブック、スタック、Spaceの対応付け。
7. タスク、リマインダー、保存済み検索、ショートカット、階層タグとノート割当、共有、内部リンクの移行確認。
8. 必要なノート履歴の個別保全と復元確認。
9. 本サイトからの再エクスポートと復旧テスト。
10. 対象バッチ名・件数を示したユーザーの明示承認。

## サブスクリプション解約ゲート

次をすべて証明した後に限り、解約画面へ進む直前にユーザーへ最終承認を求める。

- 全ノートブック、Space、共有領域、ゴミ箱、履歴の棚卸しが完了。
- すべての移行バッチが検証済みまたは承認済み削除済み。
- 必要なEvernote機能の代替が本番環境で端末横断検証済み。
- 全データの本サイトからの再エクスポートと復旧試験が成功。
- Evernoteの請求日、プラン、解約後のデータ保持条件を当日に再確認。
- ユーザーが解約対象アカウントと最終請求影響を確認して明示承認。

## 現在の証拠

- クラウド優先CI: PR #5125
- ストリーミング移行・階層・履歴棚卸し/取込UI・ネイティブTask/リマインダー保存・ノート内/全ノート横断Task管理UI・担当者RLS/RPC・二重削除ゲート検証: PR #5127
- Task担当者クラウド検証: commit `2b2fe24b5066b17b6cceb4075ae62efe30292089`、GitHub Actions run 33330500832（Dart整形差分なし、Flutter analyze成功、対象89テスト成功、使い捨てPostgreSQL契約成功）
- Task/ノート通知クラウド検証: commit `eadd444d2aff64cfdf64df67cd90b9814c213c9f`、GitHub Actions run 33331856836（Dart整形差分なし、Flutter analyze成功、対象91テスト成功、使い捨てPostgreSQLの通知RLS・既読/非表示・完了停止・再割当権限剥奪契約成功）
- 保存済み検索・ショートカット棚卸し／管理UI／削除ゲートのクラウド検証: commit `60a3771370c38ca018e88a03b9dee6c8804ce2e2`、GitHub Actions run 33333473438（Dart整形差分なし、Flutter analyze成功、対象95テスト成功、使い捨てPostgreSQLの全対象型、順序、項目別SHA-256、冪等再実行、RLS、明示的ゼロ件棚卸し、既存履歴・Taskとの複合削除ゲート契約成功）
- 実データ移行: 0件
- Evernote側削除: 0件
- サブスクリプション解約: 未実施
- 本番デプロイ: 未実施

## 公式仕様の参照先

- Evernoteプラン比較: https://evernote.com/compare-plans
- 検索: https://help.evernote.com/hc/en-us/articles/360040282613-Search-overview
- 高度検索構文: https://help.evernote.com/hc/en-us/articles/208313828-Use-advanced-search-syntax
- Boolean検索: https://help.evernote.com/hc/en-us/articles/4405520390291-Use-Boolean-search-for-targeted-search-results
- 保存済み検索: https://help.evernote.com/hc/en-us/articles/209005267-Saved-searches
- ショートカット: https://help.evernote.com/hc/en-us/articles/209004637-Create-shortcuts
- キーボードショートカット: https://help.evernote.com/hc/en-us/articles/34296687388307-Keyboard-shortcuts
- セマンティック検索: https://help.evernote.com/hc/en-us/articles/45706285591955-Semantic-search
- タスク: https://help.evernote.com/hc/en-us/articles/1500003792141-Tasks-Overview
- 通知: https://help.evernote.com/hc/en-us/articles/360060663654-Enable-notifications-for-Evernote
- ノートリマインダー: https://help.evernote.com/hc/en-us/articles/208314338-Add-a-note-reminder
- タグ: https://help.evernote.com/hc/en-us/articles/39651699994003-Tags-overview
- 階層タグ: https://help.evernote.com/hc/en-us/articles/4412905761299-Nested-tags
- Space: https://help.evernote.com/hc/en-us/articles/36621846528915
- Web Clipper: https://help.evernote.com/hc/en-us/articles/209125827-Clip-formats
- ENEX/HTMLエクスポート: https://help.evernote.com/hc/en-us/articles/209005557-Export-Notes-and-Notebooks-as-ENEX-or-HTML
- ENEXインポート: https://help.evernote.com/hc/en-us/articles/360035153274-How-To-Import-Notes-and-Notebooks
- ノート履歴: https://help.evernote.com/hc/en-us/articles/208313858-Use-note-history-to-view-and-restore-older-versions-of-a-note
- 共有: https://help.evernote.com/hc/en-us/articles/360055131333-How-to-move-and-share-content-with-your-team
- メール転送: https://help.evernote.com/hc/en-us/articles/209005347-Save-emails-into-Evernote
- オフラインノート: https://help.evernote.com/hc/en-us/articles/209005177-Set-up-offline-notes-and-notebooks-on-mobile-devices
