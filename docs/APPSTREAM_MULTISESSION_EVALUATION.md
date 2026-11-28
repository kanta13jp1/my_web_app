# Amazon AppStream 2.0 マルチセッション機能 Fit/Gap 評価・容量試算仕様 (#2797)

## 1. 現行スタックとの Fit / Gap 評価

`my_web_app` の現行本番構成は **Flutter Web (Firebase Hosting) + Supabase (PostgreSQL / Auth / Edge Functions)** であり、ブラウザ上で直接動作する Web アプリケーションである。

- **Fit**: 将来的に Windows ネイティブ専用ツールや重負荷デスクトップアプリをブラウザ経由で配信する要件が発生した場合、マルチセッションフリートによるインスタンス共有は 1 ユーザーあたりのコンピュート単価削減に有効となり得る。
- **Gap**: 現行の Flutter Web + Supabase 構成では AppStream 2.0 ストリーミング基盤自体が不要（`not-needed`）であり、導入する場合は AWS アカウント・VPC・フリート監視・クライアント UI 側の周辺機器制限案内を新設する必要がある。

## 2. 一次情報の確認状況と未確認事項

- `https://docs.aws.amazon.com/appstream2/latest/developerguide/multi-session-fleets.html` への静的取得は開発者ガイドトップ（SPA）へリダイレクトされたため、以下の AWS 固有仕様は本環境では **未確認** として扱う:
  - Windows Server 2019 / 2022 ベースのマルチセッション対応フリート上限値・`Multiple user sessions` 設定詳細（**未確認**）
  - Web カメラ / 一部 USB 周辺機器の非対応仕様およびクライアント制限詳細（**未確認**）
  - 実 AWS フリートでの複数セッション同時接続負荷検証（**not-run**）

## 3. 容量・コスト試算ツール (`scripts/appstream_capacity_planner.py`)

- CPU ヘッドルームおよびメモリヘッドルーム（例: 各 `0.8` 上限）から、1 インスタンスあたりの安全同時セッション数と単一セッション比のコスト削減率を試算する。
- Web カメラ / ローカル USB 要件が有効な場合、UI 側での事前案内チェックリスト項目を出力する。
