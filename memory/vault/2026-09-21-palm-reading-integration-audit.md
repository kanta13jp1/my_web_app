---
title: "手相AI占い 実装保全・統合監査 2026-09-21"
type: implementation-audit
status: released-evidence-correction
date: 2026-09-21
tags: ["palm-reading", "flutter", "supabase", "rls", "privacy", "integration"]
related: ["[[OBSIDIAN_INGEST_PIPELINE]]"]
---

# 手相AI占い 実装保全・統合監査

## 結論

2026-09-21 に [PR #5464](https://github.com/kanta13jp1/my_web_app/pull/5464) はマージされ、本番公開された。以下の実装保全記録は公開前の記録として残す。ただし公開後の「PC・モバイルのスモーク成功」はサイト共通ページの確認であり、手相の同意・鑑定・履歴・比較・削除を本番で通した証拠ではない。公開後E2Eにはレポート消失と失敗終了コード欠落が見つかったため、後述の証拠で訂正する。

手相AI占いの未保存実装は `codex/palm-reading-history-20260823` の隔離作業ツリーで保全した。2026-09-21 の棚卸し時点で `main`、同名のリモートブランチ、手相専用PRには未統合だった。古い `codex/palm-reading-history-20260822` は重複実装と `supabase/.temp` 差分を含むため変更せず残した。

既存5ファイルには改行コード変換による約1万行の見かけ差分があった。手相機能の実質差分だけを抽出して再適用し、他機能の行をコミット対象から除外した。

## 実装範囲

- Flutter: 左右の手の選択、撮影ガイド、カメラ/写真選択、明示同意、鑑定結果、履歴、同じ手の前回比較、削除、ログイン導線、レスポンシブ表示。
- Edge Function: `palm_reading.analyze` / `palm_reading.delete`、認証、UUIDによる冪等化、MIMEマジック検証、オフライン保護、利用量/予算ゲート、安全な構造化出力。
- Database/Storage: 所有者限定履歴、非公開画像バケット、4 MB上限、JPEG/PNG/WebP限定、本人だけのSELECT、サービスロールだけの書き込み。
- 安全表示: 手相を娯楽として明示し、病気・障害・妊娠・寿命・死期・自殺などの断定を出力後にも除外する。

## 証拠

### 2026-08-23 に完了済みの隔離検証

- 対象Flutterテスト: 32件成功。
- `flutter analyze --no-pub`: 問題なし。
- Deno: 7件成功、lint/check成功。
- 隔離Postgres: 新規マイグレーション適用成功、DB lint/advisors問題なし。
- SQL契約テスト: 行履歴と画像の所有者分離、クライアント読み取り専用、サービスロール書き込み、非公開4 MBバケット、索引、所有者パス制約を確認。
- 実Auth/Data API/Storage検証: 所有者RLS、アップロード、本人限定署名URL、後片付け成功。

これらは過去の隔離環境で得た証拠であり、現在の `main` とのマージ結果の証拠ではない。現行統合はGitHub Actionsのマージ参照で再検証する。

### 2026-09-21 の現行監査

- 最新 `origin/main` (`032bd4565`) へリベースし、現行のfail-closed AI action registryへ `palm_reading.analyze` / `palm_reading.delete` を認証必須として登録した。
- ホームの機能カタログに加え、`feature_releases`へ `/palm-reading`を重複防止付きで登録し、「最近追加された機能」から遷移できるようにした。
- 未公開マイグレーションは現在の履歴順に合わせて `20260921041500_create_palm_reading_history.sql` へ改名した。
- Supabaseの2026-04-28破壊的変更を確認。新規 `public` テーブルはData API利用のため明示的GRANTが必要になる。本実装は `authenticated` にSELECT、`service_role` に必要権限を同一マイグレーションで明示している。
- ローカル資源は空きディスク1.63 GiB、空きRAM0.43 GiB、RAM使用97%でクラウド必須。Flutter/Deno/Docker/ブラウザ検証はローカルで再実行しない。
- 実写真の外部AI送信、課金、本番公開は実施していない。

## 公開前の条件（当時の記録）

1. PRのGitHub Actionsが現行 `main` とのマージ参照で成功すること。
2. 認証、Database、RLS、Storage、Edge Functionの差分を人がレビューし承認すること。
3. マージと本番公開は別承認とし、この監査では実行しないこと。
4. 本番利用前に、テスト画像だけで同意・鑑定・履歴・同じ手の比較・削除をステージング確認すること。

## 公開後E2Eの訂正監査

- [本番デプロイ run 35562873881](https://github.com/kanta13jp1/my_web_app/actions/runs/35562873881): 成功、対象SHA `bd5c20308c1f33bffaafc5eaa139410d5ca33b5f`、バージョン `1.0.2016` / build `5577`。
- [公開後E2E run 35564138058](https://github.com/kanta13jp1/my_web_app/actions/runs/35564138058): Actions表示は成功だが、05:20:49 UTCの集計は `Status: FAIL / Total: 12 / Passed: 12 / Failed: 1`。
- 同runのログは公開スモーク15件成功、続く画面証拠12件成功を記録。既存artifact `10622954644` (`minimal-e2e-playwright-report`) には `visual-evidence-results.json` と失敗集計があり、`public-smoke-results.json` は欠落。残存JSONのstatsは expected=12、unexpected=0、flaky=0。
- 原因は両コマンドがHTML出力 `playwright-report/` を共有し、その配下に別々のJSONを保存していたこと。[Playwright v1.63.0 HTML reporter](https://github.com/microsoft/playwright/blob/v1.63.0/packages/playwright/src/reporters/html.ts) は `onEnd` で出力フォルダーを消して再作成するため、後段のHTML作成が先行JSONを削除した。
- 集計スクリプトは欠落を失敗1件として表示するが、非ゼロ終了しなかった。そのためActionsはgreenになった。実テストの失敗を示す証拠ではなく、証拠保存と失敗伝播の不具合。欠落したJSONを再構築した証拠として扱わず、15件成功はログ根拠と明記する。
- 実行時checkoutは `e411f1f42b8d0f201b55660cb7ac8c39c6efa90c` で、配信SHAとは異なる。対象URLは本番だったが、テストコードはworkflow開始時のmainであり、配信SHAそのもののソースを検証したとは報告しない。

### 修正範囲

`minimal-e2e-gate.yml` と `e2e-smoke.yml` でJSON、HTML、テスト添付ファイルをそれぞれスイート別のディレクトリーへ分離する。HTML既定出力もJSONの親を消さない子ディレクトリーにする。集計は実テスト失敗と証拠エラーを分け、欠落・不正JSON・空結果・runner errorを失敗終了にする。失敗時も `if: always()` によりartifactを保存する。公開後workflowは起点deploy runの `head_sha` をcheckoutし、手動実行は実行SHAに固定する。

新しいクラウド回帰テストは実Playwright reporterをブラウザーなしで連続2回動かし、両方のJSON、HTML、添付が残ることと、失敗集計が終了コード1を返すことを検証する。実写真や外部AI呼び出しは不要。

マージ前の対象SHA `90b821ef7b69030b17d43ea2010fbe7dcbcf5baa` で [回帰11件](https://github.com/kanta13jp1/my_web_app/actions/runs/35574185922) が成功し、[修正版の公開スモーク](https://github.com/kanta13jp1/my_web_app/actions/runs/35574267750) は `Total 27 / Passed 27 / Failed 0 / Evidence errors 0`。artifact `10626634215` に両JSONを保存した。これは修正ブランチでの確認であり、マージ後mainでの検証とは区別する。

本番デプロイのpush除外にはCI用スクリプトとPlaywright設定が未登録だったため、対象4ファイルのみ `deploy-prod.yml` へ明示追加した。既存の分類テストで、この修正一式が非デプロイ対象になること、およびアプリ・Edge・migrationや別スクリプトを広く除外しないことを検証する。

[集計修正PR #5470](https://github.com/kanta13jp1/my_web_app/pull/5470) は 07:47:41 UTCに `605ac61d0743bb983928403b902ec6f0bbbf300a` としてマージされた。除外追補の準備中に別の操作でマージされたため、除外変更は独立した後続PRにする。[自動deploy run 35574651872](https://github.com/kanta13jp1/my_web_app/actions/runs/35574651872) は起動したが `deployable=false`、web/edge/migration全てfalseで、Flutter build・Firebase・DB migration・Edge Function・version/tag/release更新は全てskipped。実際のアプリやバックエンドの再公開はない。マージ後mainの [Minimal E2E run 35574701484](https://github.com/kanta13jp1/my_web_app/actions/runs/35574701484) は自動起動済みのため、重複する手動実行は追加しない。

### 実際に確認できた範囲

| 対象 | 証拠・環境 | 限界 |
| --- | --- | --- |
| 公開ページのHTTP/SEO shell | public smoke 5ケース×3回=15件。`/`、`/project-gantt`、`/referral`、登録なし導線 | `/palm-reading` はこのスイートの対象外 |
| PC・モバイルの表示とブラウザーエラー | visual evidence 6ルート×2端末=12件。`/`、`/home`、`/two-factor-auth`、`/project-gantt`、`/agents`、`/tiger-reviewers` | 手相画面もログイン後機能も対象外 |
| 手相ルート公開・バックエンド配備 | 公開時の別HTTP確認で `/palm-reading` 200、migration適用、非公開Storage、所有者RLS、ai-hub ACTIVE v203、未認証実行401を記録 | HTTP 200はSPA shell到達。認証済みUIからの一連操作成功は示さない |
| 写真＋同意後に実行可能、結果表示、履歴/比較表示、ログイン導線 | `test/pages/palm_reading_page_test.dart`。偽repository/pickerと固定鑑定データ | 実カメラ・AI送信・本番保存・実比較生成は未確認 |
| 同意/撮影状態、手の切替、削除時の結果/履歴更新 | `test/view_models/palm_reading_view_model_test.dart`。偽repository/picker | 本番DB行・画像の実削除は未確認 |
| 画像要求・署名URL・MIME拒否 | repositoryテストの注入コールバック、Denoの画像/プロンプト/parser単体テスト | 本番ネットワーク越しの鑑定や権限の総合確認ではない |
| RLS/Storage契約 | 過去の隔離DB/Auth/Storage証拠と現行SQL契約テスト | 本番で他人のデータを操作する試験はしていない |

残る確認は、承認されたテストアカウントと合成画像で同意→鑑定→履歴→同じ手の比較→削除を通す機能E2E。今回のCI集計修正は、その機能E2Eを完了したことにはならない。実写真の外部送信や有料AI呼び出しは実施していない。

未適用migration22件は別バックログとして保全する。この修正で一括適用、履歴repair、手相バックエンドの変更を行わない。

## 用語集

- **RLS (Row Level Security)**: データベース行ごとに「誰が読めるか」を制限する仕組み。本実装では本人の履歴だけを読める。
- **非公開バケット**: URLを知るだけでは画像を取得できないStorage領域。
- **署名URL**: 短時間だけ有効な画像閲覧URL。履歴表示時に本人向けに生成する。
- **Edge Function**: クライアントに秘密鍵を置かず、認証・AI呼び出し・保存を仲介するサーバー処理。
- **冪等性**: 同じ要求を再送しても同じ結果を返し、二重課金や二重保存を避ける性質。
- **MIMEマジック検証**: 拡張子だけでなくファイル先頭バイトを調べ、JPEG/PNG/WebPの実体を確認すること。
- **同じ手の比較**: 左手は左手、右手は右手の直前データだけと比較する方式。
- **マージ参照**: PRの変更を最新 `main` に仮想的に重ねたGitHub上の検証対象。
- **限定コミット**: この機能と監査記録だけを明示的にステージし、他タスクの差分を含めないコミット。

## 参照

- Supabase changelog: https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically

<!-- PR番号とクラウドCI結果は作成後に追記する。 -->
