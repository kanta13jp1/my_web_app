# 🚀 Netlifyデプロイ手順

## 概要

Supabase Edge Functionsの制限（`text/html`→`text/plain`変換）を回避するため、Netlify Functionsを使用してシェアページを実装しました。

Netlifyの無料プランで十分に動作します：
- ✅ 100GB帯域幅/月
- ✅ 125,000リクエスト/月
- ✅ クレジットカード不要

## 実装内容

### 新規追加ファイル

1. **netlify.toml** - Netlifyの設定ファイル
2. **netlify/functions/share-quote.js** - シェアページのサーバーレス関数
3. **netlify/functions/quotes.js** - 名言データ

### 変更ファイル

1. **.gitignore** - Netlifyの設定を追加

## デプロイ手順

### ステップ 1: GitHubにプッシュ

```powershell
git add .
git commit -m "Add Netlify Functions for share-quote page"
git push origin claude/debug-share-quote-endpoint-011CUtzmEcos5EVudWJbWBGi
```

### ステップ 2: Netlifyアカウント作成

1. https://app.netlify.com/signup にアクセス
2. **GitHub**アカウントでサインアップ（推奨）
3. Netlifyに必要な権限を付与

### ステップ 3: 新しいサイトをインポート

1. Netlifyダッシュボードで **"Add new site"** → **"Import an existing project"** をクリック
2. **"Deploy with GitHub"** を選択
3. リポジトリを検索: **my_web_app**
4. リポジトリを選択

### ステップ 4: ビルド設定

以下の設定を入力：

**Build settings:**
- **Branch to deploy**: `claude/debug-share-quote-endpoint-011CUtzmEcos5EVudWJbWBGi`
- **Build command**: （空白のまま）
- **Publish directory**: `build/web`
- **Functions directory**: `netlify/functions`

※ netlify.tomlに設定があるため、自動的に読み込まれます。

### ステップ 5: デプロイ

**"Deploy site"** をクリック

デプロイには2〜3分かかります。完了すると以下のようなURLが生成されます：
```
https://random-name-12345.netlify.app
```

### ステップ 6: カスタムドメイン設定（オプション）

無料でカスタムサブドメインを設定できます：

1. **Site settings** → **Domain management**
2. **"Add custom domain"** をクリック
3. 任意のサブドメインを設定: `my-web-app.netlify.app`

## 動作確認

### テストURL

デプロイ後、以下のURLでテスト：

```
https://[your-site-name].netlify.app/share?id=25
```

### 期待される結果

✅ **Response Headers:**
- `Content-Type: text/html; charset=utf-8`
- `Cache-Control: public, max-age=3600`

✅ **表示:**
- 美しくスタイリングされたHTMLページ
- 日本語が正しく表示（マイメモ、フリードリヒ・ニーチェなど）
- 絵文字が正しく表示（💭、🎮）

✅ **OGPメタタグ:**
- Twitter/Facebookでシェアした際にカードプレビューが表示される

### テスト方法

#### 1. ブラウザで直接確認

```
https://[your-site-name].netlify.app/share?id=25
```

#### 2. Response Headersを確認（PowerShell）

```powershell
curl.exe -I "https://[your-site-name].netlify.app/share?id=25"
```

#### 3. TwitterカードバリデータでOGPを確認

```
https://cards-dev.twitter.com/validator
```

## エンドポイント仕様

### URL形式

```
https://[your-site-name].netlify.app/share?id={quoteId}
```

### パラメータ

- `id` (optional): 名言のID（0-34）
  - 指定しない場合：ランダムな名言を表示
  - 範囲外の場合：モジュロ演算で範囲内に調整

### レスポンス

- Content-Type: `text/html; charset=utf-8`
- OGPメタタグ付きの完全なHTMLページ

## 自動デプロイの設定

GitHubにプッシュすると自動的にデプロイされます：

1. コードをコミット＆プッシュ
2. Netlifyが自動的にビルド＆デプロイ
3. 数分後に本番環境に反映

## トラブルシューティング

### デプロイエラー: "Function failed to load"

1. **Netlify Functions Logを確認**
   - Netlify Dashboard → Functions → Logs

2. **ローカルでテスト**
   ```powershell
   npm install -g netlify-cli
   netlify dev
   ```

### HTMLがプレーンテキストで表示される

Response Headersを確認：
```powershell
curl.exe -I "https://[your-site-name].netlify.app/share?id=25"
```

`Content-Type: text/html; charset=utf-8` が含まれているか確認。

### 関数が見つからない（404エラー）

1. **netlify.tomlのリダイレクトルールを確認**
   ```toml
   [[redirects]]
     from = "/share"
     to = "/.netlify/functions/share-quote"
     status = 200
     force = true
   ```

2. **Functions directoryが正しいか確認**
   - Netlify Dashboard → Site settings → Build & deploy → Functions
   - Directory: `netlify/functions`

### キャッシュ問題

ブラウザキャッシュをクリア：
- Chrome: Ctrl+Shift+R（Windows）/ Cmd+Shift+R（Mac）
- シークレットモードで開く

SNSのOGPキャッシュをクリア：
- Twitter: https://cards-dev.twitter.com/validator
- Facebook: https://developers.facebook.com/tools/debug/

## コスト

Netlify無料プラン：
- ✅ **帯域幅**: 100GB/月
- ✅ **ビルド時間**: 300分/月
- ✅ **関数実行**: 125,000リクエスト/月
- ✅ **関数実行時間**: 100時間/月

通常の使用では無料枠で十分です。

## 環境変数の設定（必要な場合）

Netlify Dashboard → Site settings → Build & deploy → Environment variables

現時点では不要ですが、将来的にSupabaseのAPIキーなどを追加する場合はここで設定します。

## カスタムドメインの設定（オプション）

独自ドメインを使用する場合：

1. Netlify Dashboard → Domain settings
2. **"Add custom domain"** をクリック
3. ドメインを入力（例: share.my-web-app.com）
4. DNSレコードを設定（Netlifyが指示を表示）

Netlifyは自動的にSSL証明書（Let's Encrypt）を発行します。

## 次のステップ

1. ✅ Netlifyにデプロイ
2. ✅ 動作確認
3. ⬜ アプリ内でシェアURLを更新
4. ⬜ TwitterやFacebookでシェアテスト
5. ⬜ カスタムドメインの設定（オプション）

## まとめ

この実装により、以下が解決されました：

- ❌ **以前**: Supabaseが`text/html`を`text/plain`に変換
- ✅ **現在**: Netlify FunctionsでHTMLを直接配信

メリット：
- ✅ 完全無料（クレジットカード不要）
- ✅ GitHubと自動連携
- ✅ 高速なCDN
- ✅ 自動SSL証明書
- ✅ 簡単なデプロイ

OGPメタタグも正しく機能するため、TwitterやFacebookでの共有が美しく表示されます！
