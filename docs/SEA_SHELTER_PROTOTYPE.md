# 潮灯のシェルター：ローカル試作の実装記録

2026-10-30。以下はローカル検証時点の記録。後続でユーザーがcommit/push・PR・mainマージ・本番デプロイを許可したため、公開工程へ移行。CI/公開の最終結果はPRとリリース報告を参照。

独立branch `codex/sea-shelter-20261030`。起点はローカルの `origin/main`。既存作業ツリーの7件の変更を保護するため、`C:\Users\kanta\Documents\Codex\2026-10-30\task\sea-shelter` のsparse worktreeで実装。fetch、commit、push、PR、merge、deploy、DB操作なし。

## 方針と実装

引継ぎ元が実画像を確認して確定した独自仕様を採用。Windowsの画像取得互換性問題を再試行せず、参考ゲームの固有名・文章・素材は使っていない。

既存FlowCity等の `web/labs` とconditional web/stub surface方式を踏襲。Flutterの `/sea-shelter`、ホームのpersonal一覧、機能ラベル、route一覧を追加。共通のURL同期ルートを利用。Web以外には説明文を表示。surfaceは別ルートで覆われたときとdispose時にiframeをabout:blankへ遷移して破棄し、戻ると保存から再表示する。

- 回収で木材・金属・EXPを獲得。維持費や放置報酬はなし。
- 5×5盤面の上下左右に隣接して床・住居・菜園を建設。施設解放はEXP。建て替えを可能にして全区画埋めても進行できるようにした。必要な住居の削減は拒否する。
- 住民3人ごとに回収木材増加。3件の独自依頼と一度だけの報酬。
- 名前、独自記号アイコン、枠、吹き出し、進行による称号の解放。
- 専用localStorageキーで操作後に自動保存。保存拒否・破損時は画面で説明。リセットは確認とキャンセルあり。他機能の保存データを操作しない。
- 通常幅・390px・320px対応、操作対象44px以上、主要操作48px以上、キーボード、状態通知、文字による状態表示。ゲーム以外の外枠・パネル・主CTAはDESIGN.mdの黒/濃灰/オレンジ系。海面・施設・プロフィール枠の色はゲーム盤面の表現として分離した。

ステージ/クルー編成、デイリー/成長任務、貿易の帰還タイマー、BGM/SE設定は後段候補。課金・戦闘・マルチプレイ・外部APIは実装していない。

## 実施した検証

- 再開前メモリ78.2%、空き6.9GiB、ディスク空き32.72GiB。ブラウザ検証前は76.5%、空き7.45GiB。
- Nodeモデルテスト8/8成功。3依頼の完走、保存往復、資材不足、ロック、隣接、重複建設/報告、定員、25区画、破損データ、プロフィール、施設変更と住居保護を確認。
- `node --check app.mjs` 成功。
- Deno fmt 8ファイル、Deno lint 6ファイル成功（対象は新しいゲームのHTML/CSS/JSとE2E）。既存ファイル全体を再整形していない。
- Dart formatter対象6ファイル、再確認0変更。依存未導入worktreeのためflutter_lints解決警告はあり、これはanalyze成功を意味しない。
- Playwright 6/6成功、7.4秒。1440×1000と390×844のタッチ環境で、回収から3件完走、資材不足・不正位置、重複クリック、再読込、プロフィール全項目と保存、reset cancel/confirm、破損/保存拒否を確認。320pxで横スクロールなし・盤面44px以上・キーボード回収を追加確認。
- 390pxの完走スクリーンショットを目視確認。通常幅も同じE2Eで画像を取得。
- 初回のブラウザ失敗は、既定Playwrightが求めるbrowser1217未導入。その後既存browser1208を明示して隔離headlessで実行。追加インストールなし。最新版の公式browser組合せやiOS Safari実機検証の代わりにはならない。
- Windowsの標準Pythonサーバーは.mjsをtext/plain配信し初期化失敗したため、専用serve.pyでMIMEを補正。以後UIテスト成功。selectのラベルもテストで見つかった曖昧さを修正。
- `git diff --check` 成功。元作業ツリーの差分は開始時と同じ7件。

## 残る検証

AGENTSのcloud-firstに従い、Flutter依存導入・analyze・widget test・Web buildとビルド済みFlutter経由のroute/lifecycle E2Eはローカル実行していない。`.github/workflows/sea-shelter-checks.yml` に既存方式の専用gateを準備。公開操作は許可されていないためpush/dispatchせず、CIは未実行。実画面の戻る/閉じる/再入場のFlutter統合検証は未実施で、対応テストは追加済み。Designプラグインによる正式なアクセシビリティ再監査とiPhone Safari実機も未実施。

## 起動

worktreeルートで:

```powershell
python web/labs/sea-shelter/serve.py
```

`http://127.0.0.1:8765/labs/sea-shelter/index.html` を開く。単体版はFlutterビルド不要。今回の検証サーバーも同じlocalhostのみ。iPhoneからこのlocalhostへは接続できず、公開URLはまだ存在しない。Flutter統合ビルド後の入口は `/sea-shelter`。詳細は `web/labs/sea-shelter/README.md`。

## 検証ファイル

この端末のローカルUI検証設定はworktree外 `../sea-shelter-local.config.cjs`。既存Playwrightを `NODE_PATH=C:\Users\kanta\GitHub\my_web_app\node_modules` で使用。headless実行はユーザーのChromeプロファイルへ接続せず、閉じる操作もしていない。

成功時画面は `../sea-shelter-validation/sea_shelter-complete-the-l-aad02-without-horizontal-overflow-{desktop,iphone-size}/sea-shelter-complete.png`。初期失敗ログは `../sea-shelter-initial-checks/` に保管し、製品ツリーには混ぜていない。

## 公開前の追加確認

プロフィール不正入力をダイアログ内で通知するよう修正。6件のUIテストを再実行し成功（10.5秒）。console/page error、request failure、HTTP 5xxを監視して0件。animation settlingと各画面3枚の低FPSフレームを追加。正式Designプラグインは未使用であり、アクセシビリティ完全準拠の主張はしない。
