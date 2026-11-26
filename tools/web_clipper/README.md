# 自分株式会社 Web Clipper (Chrome / Edge Manifest V3)

Web ページの記事本文・選択テキスト・URL ブックマークを Markdown 化し、自分株式会社（`my_web_app`）の `notes`（`capture_status: 'inbox'`, `capture_source: 'web_clipper'`）へ 1 クリックで保存するブラウザ拡張機能です。

## 採用 OSS（商用安全ライセンス）

- [`@mozilla/readability`](https://github.com/mozilla/readability) (`Apache-2.0`): 記事本文のノイズ除去・抽出
- [`turndown`](https://github.com/mixmark-io/turndown) (`MIT`): 抽出済み HTML の Markdown 変換

## セットアップ手順

### 1. 依存パッケージをバンドルする（推奨）

```bash
cd tools/web_clipper
npm install
npm run build
npm test
```

`npm run build` により `vendor/Readability.js` と `vendor/turndown.js` が生成されます。
未ビルド状態でも内蔵のセマンティック DOM 抽出フォールバックで動作します。

### 2. Chrome / Edge に読み込む

1. `chrome://extensions`（Edge の場合は `edge://extensions`）を開く
2. 右上の **デベロッパー モード** を ON にする
3. **パッケージ化されていない拡張機能を読み込む** をクリックし、`tools/web_clipper` フォルダを選択する

### 3. API キーを発行して設定する

1. 自分株式会社の `/jibun-api` ページを開く
2. スコープに **`notes.write`** を含めて自分API キー（`jibun_sk_...`）を発行する
3. 拡張機能ポップアップの「APIキー設定」に貼り付けて「接続テスト」→「キーを保存」を押す

## プライバシーと権限方針

- `<all_urls>` 権限は要求しません（`activeTab` + `scripting` + `storage` + Supabase Functions エンドポイントのみ）。
- API キーは `chrome.storage.local` にのみ保存され、クリップ操作時以外は通信しません。
