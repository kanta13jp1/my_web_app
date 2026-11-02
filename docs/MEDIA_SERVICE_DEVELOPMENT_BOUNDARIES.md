# 第4段階：既存メディアサービスの開発境界

2026-10-18。PR5842の独立ビルド試作に続き、既存の配信単位を調べた。
対象ソースはmainのPR5842マージc5a73087。READMEの配信手順は、現在の稼働・費用・配信成功の証明には使わない。

## 採用する小さな改善

新しいサービスは作らず、既存video-worker-controllerのテストを専用CIへ接続する。
Node 20は既存Dockerfileに合わせ、外部パッケージのインストールやFlutter起動を必要としない。
既存の純関数5件にHTTP境界5件を加え、実クラウドに接続せず確認する。
サービス本体・API契約・認証設定・DB・配信設定は変更しない。

## 既存単位の比較

| 対象 | 既存の境界と検証 | 障害時・運用の制約 | 今回の判断 |
| --- | --- | --- | --- |
| caption-transcoder | Node/ffmpegの独立Dockerfile。POST /burn、GET /file、GET /healthz。ci.ymlのcaption判定でtest.jsを実行 | 一時ファイルは同一インスタンスとTTLに依存。呼出元は失敗時に元動画へ戻る設計。現行配信・設定値・費用は未確認 | 既存パス別テストを維持。画像/動画実処理と配信の統合試験は別途必要 |
| video-worker-controller | Nodeのみ。POST /wakeはジョブUUID、GET /healthz。Computeの状態確認/起動を担当し動画を生成しない | 固定された対象VMと専用トークンに依存。HTTP503は起動失敗を表す。新しいモデル提供者へ自動転送しない | 専用CIと合成HTTP契約テストを追加 |
| video-inference-worker | GPU用の独立Dockerfile、固定モデル/ソース版。専用video-worker-contract.ymlあり | 既存READMEはリース更新・出力検証・アイドル停止を規定。GPU負荷・費用は実測未取得 | 既存契約CIを維持。モデル更新やGPU実行は今回対象外 |

## 開発と確認

変更が`services/video-worker-controller/**`または専用workflowの場合だけ
`Video Worker Controller Contract`を実行する。共通CIの必須集約は維持する。
このディレクトリは既存`classify_ci_changes.py`のFlutter/Web対象に含まれないため、
サービスだけの修正でFlutterの全体テスト・Webビルドを起動する必要はない。
実際のクラウド実行時間をPRへ記録し、従来との短縮率は比較試料がそろうまで断定しない。

クラウドでの独立検証コマンド：

```sh
cd services/video-worker-controller
node --check server.js
node --test server.test.js http.test.js
```

HTTP試験はループバックの一時ポートを使い、終了時に接続とサーバーを閉じる。
クラウド側fetchは注入した合成応答だけで、実GPU・課金API・秘密情報を使用しない。
200/404、401、400、202、503の入出力と、不正な要求がクラウド呼出へ進まないことを確認する。
コンテナ起動、実Compute権限、実キュー/Storage、ffmpeg描画や本番可用性の証明とは区別する。

## 配信・費用・戻し方の残件

独立配信は既存Dockerfile単位で可能な構成だが、今回デプロイしていない。
現行Cloud Run/VMの版・負荷・請求・起動頻度を取得するまで、新規分割の費用対効果は未確定。
実配信を変更する場合は、稼働版を固定し、呼出元との契約試験と切戻し先のイメージ/設定を先に記録する。
今回のCI/テスト/文書はこのPR単位で戻せる。データ移行や本番設定の切戻しは発生しない。
バックエンドの独立検証はFlutterのコンパイル短縮を直接意味しない。
