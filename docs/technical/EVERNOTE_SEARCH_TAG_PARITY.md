# Evernote 高度検索・階層タグ互換ノート

最終更新: 2026-08-31

## 公式仕様として固定した範囲

- 通常検索はタイトル、本文、タグを対象にし、語を空白で並べるとAND、引用符は完全一致、末尾のアスタリスクは接頭辞ワイルドカードとして扱う。
- Boolean検索は大文字の AND / OR / NOT と括弧を使い、優先順位は括弧、NOT、AND、OR。
- any: は後続する暗黙条件をORとして扱う。
- 主要な属性演算子として intitle:、notebook:、stack:、tag:、created:、updated:、resource:、source:、todo:、encryption:、contains: がある。
- タグは親タグと複数の子タグを持てる。タグ絞り込みでは子タグを含める／除外する選択肢がある。
- ENEXは各ノートのタグ名を保持するが、アカウント全体の親子階層は別棚卸しが必要。

参照:

- https://help.evernote.com/hc/en-us/articles/208313828-Use-advanced-search-syntax
- https://help.evernote.com/hc/en-us/articles/4405520390291-Use-Boolean-search-for-targeted-search-results
- https://help.evernote.com/hc/en-us/articles/360040282613-Search-overview
- https://help.evernote.com/hc/en-us/articles/4412905761299-Nested-tags
- https://help.evernote.com/hc/en-us/articles/39651699994003-Tags-overview

## このスライスの実装境界

| 区分 | 状態 | 動作 |
| --- | --- | --- |
| AND / OR / NOT / 括弧 | 実装 | 公式優先順位で決定的に評価 |
| 暗黙AND / any: | 実装 | 通常は全条件、any:は任意条件 |
| マイナス除外 | 実装 | 語と対応済み属性演算子を反転 |
| 引用句 / 末尾アスタリスク | 実装 | 語単位正規化後に完全句／接頭辞一致 |
| intitle: | 実装 | タイトルだけを評価 |
| notebook: / stack: | 実装 | owner-scoped階層名を評価 |
| tag: / -tag: / tag:* | 実装 | タグ名の完全一致、除外、タグ有無 |
| created: / updated: / reminderTime: | 実装 | YYYYMMDD と day/week/month/year の相対指定 |
| resource: / source: / todo: / contains: / encryption: | 実装 | owner-scoped添付MIME、Evernote source属性、Markdownチェック欄、構造化Task、原本暗号化印、証拠から導出したcontains種別を評価 |
| Booleanと属性演算子の保存済み検索 | 実装 | 対応構文をそのまま再実行し、未知の演算子は原文を損失なく保存したまま明示停止 |
| 階層タグのクラウドデータモデル | 実装 | 親子、ノート割当、owner RLS、循環拒否、ネイティブCRUD |
| 階層タグの管理UI | 実装 | 狭幅/広幅ツリー、ルート/子タグ作成、名前変更、移動、削除、原本ロック、子タグ包含/除外でノートを表示 |

contains: は公式の内容種別だけを受理し、添付・URL・表・リスト・数値・日付・Taskなど、保存済み証拠から決定できる種別だけを肯定する。人物・住所・連絡先・カレンダー予定は推測で肯定しない。

未対応演算子が混在する検索は「それらしい結果」を返さない。結果の欠落を検証済みと誤認させないため、絞り込みを適用せず、未対応演算子名を利用者へ表示する。

## 階層タグ移行証拠

1. Evernoteのタグ一覧と親タグを別棚卸しJSONとして固定する。0件でも空配列を明示する。
2. 入力順に依存しないJSONスナップショットSHA-256を保存する。
3. タグごとに名前・親source keyを含むJSONのSHA-256を保存する。
4. ENEXから既に取り込んだ notes.tags と棚卸しを照合し、未解決タグが1件でもあればトランザクションを拒否する。
5. 各ノート／タグ割当に、ノートsource keyとタグsource keyから決定したSHA-256を保存する。
6. 件数、名称、親子辺、割当をすべて確認したときだけ台帳を verified にする。
7. 台帳が未検証なら、全Evernote移行アイテムの source_deleting / source_deleted 遷移をDBで拒否する。
8. 移行原本は検証後も不変とし、本番データ移行・元データ削除・サブスク解約は別の明示承認工程に残す。

## クラウド検証

- commit `e0ceb2bbae8c44014126e3a8568a3c75cc06f383` をGitHub Actions run 33336463358で検証した。Dart formatは47ファイル・差分0、Flutter analyzeは問題0、対象114テストは全件成功。
- 使い捨てPostgreSQL 17で、RLS、親子循環拒否、正確な再実行、ゼロ件棚卸し、クロスオーナー分離、不変原本、複合削除ゲートを実行する。
- 個人ENEX、添付、OCR、認証情報はGitHubやActions artifactへ送らない。
- ローカルPCではFlutter/Dart build・analyze・test、ブラウザ自動操作、ENEX展開を実行しない。
