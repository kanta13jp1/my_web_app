# 潮灯のシェルター

独自の小さな海上拠点ゲーム。課金・認証・外部API・データベース操作なし。

## 遊ぶ

リポジトリルートで `python web/labs/sea-shelter/serve.py` を起動し、`http://127.0.0.1:8765/labs/sea-shelter/index.html` を開く。Flutter Web 側の入口は `/sea-shelter` とホーム一覧の「潮灯のシェルター」。静的単体版はFlutterビルド不要。iPhoneからPCのlocalhostには直接接続できない。今回は公開していない。

漂流物を3回回収→依頼を報告→住居を建設→依頼を報告→回収して住民2人を迎える→菜園を建設→最後の依頼を報告。施設は拠点の上下左右に接する海を選んで建設。25区画の上限あり。住民3人ごとに回収木材が増える。既存区画は建設と同じ資材で施設変更できる（返却なし）。船着場と必要な住居を保護。資材維持費なし。

プロフィールで名前・独自の記号アイコン・枠・吹き出し・称号を変更できる。称号はEXP24と依頼3件の達成で追加解放。素材はテキスト記号とCSSのみ。参考作品の画像や固有名、文章は利用していない。

## 保存

`my_web_app.sea_shelter.v1` のlocalStorageだけを利用。同じブラウザ・同じorigin内のみ。別端末や別ポートの配信元とは同期しない。ブラウザデータ削除で消える。保存拒否時はプレイを続け、閉じると消える旨を表示。破損・未対応バージョン・不整合は初期状態へフォールバックして案内し、次の成功操作でゲーム専用保存だけを更新する。リセットは確認してからこのキーの内容のみ初期化する。他タブで同時プレイした場合は最後の保存が優先される。

## 検証

`node --test web/labs/sea-shelter/model.test.mjs`

`node --check web/labs/sea-shelter/app.mjs`

静的サーバー起動後に `E2E_BASE_URL=http://127.0.0.1:8765 npx playwright test test/e2e/sea_shelter.spec.ts --workers=1 --retries=0`（PowerShellでは環境変数を `$env:E2E_BASE_URL='http://127.0.0.1:8765'` で設定）。既存ルート・widget・lifecycleテストも追加。Flutter解析・ビルド・広範囲テストはAGENTSのcloud-first方針に従う。専用workflowは準備しているが、このローカル依頼ではpush/dispatchしていない。

## 後段の拡張候補

ステージ/クルー編成、デイリー/成長任務、貿易の帰還タイマー、BGM/SE設定は未実装。初期版の住民依頼やEXPとは別に、仕様検討・テストを行ってから追加する。
