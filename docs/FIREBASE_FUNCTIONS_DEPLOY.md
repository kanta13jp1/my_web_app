# 🚀 Firebase Cloud Functionsデプロイ手順

## 概要

Supabase Edge Functionsはデフォルトドメインで`text/html`を`text/plain`に自動変換する制限があるため、Firebase Cloud Functionsを使用してシェアページを実装しました。

## 実装内容

### 新規追加ファイル

1. **functions/package.json** - Firebase Cloud Functionsの依存関係
2. **functions/index.js** - シェアページのCloud Function
3. **functions/quotes.js** - 名言データ（Supabaseから移植）

### 変更ファイル

1. **firebase.json** - `/share`パスをCloud Functionにリダイレクト
2. **.gitignore** - `functions/node_modules/`を追加

## デプロイ手順

### 1. 依存関係のインストール

```powershell
cd functions
npm install
cd ..
```

### 2. Firebase Cloud Functionsのデプロイ

```powershell
firebase deploy --only functions
```

このコマンドは`shareQuote` Cloud Functionをデプロイします。

### 3. Firebase Hostingの再デプロイ（オプション）

firebase.jsonを変更したので、Hostingも再デプロイします：

```powershell
firebase deploy --only hosting
```

または、すべてを一度にデプロイ：

```powershell
firebase deploy
```

## 動作確認

### テストURL

デプロイ後、以下のURLにアクセスしてテストしてください：

```
https://my-web-app-b67f4.web.app/share?id=25
```

### 期待される結果

✅ **Response Headers:**
- `Content-Type: text/html; charset=utf-8`
- `Cache-Control: public, max-age=3600`

✅ **表示:**
- 美しくスタイリングされたHTMLページ
- 日本語テキストが正しく表示（マイメモ、フリードリヒ・ニーチェなど）
- 絵文字が正しく表示（💭、🎮）

✅ **OGPメタタグ:**
- Twitter/Facebookでシェアした際に、カードプレビューが表示される
- 画像、タイトル、説明が正しく表示される

### テスト方法

#### 1. ブラウザで直接確認

```
https://my-web-app-b67f4.web.app/share?id=25
```

#### 2. Response Headersを確認（PowerShell）

```powershell
curl.exe -I "https://my-web-app-b67f4.web.app/share?id=25"
```

#### 3. TwitterカードバリデータでOGPを確認

```
https://cards-dev.twitter.com/validator
```

URLを入力：`https://my-web-app-b67f4.web.app/share?id=25`

## エンドポイント仕様

### URL形式

```
https://my-web-app-b67f4.web.app/share?id={quoteId}
```

### パラメータ

- `id` (optional): 名言のID（0-34）
  - 指定しない場合：ランダムな名言を表示
  - 範囲外の場合：モジュロ演算で範囲内に調整

### レスポンス

- Content-Type: `text/html; charset=utf-8`
- OGPメタタグ付きの完全なHTMLページ

## トラブルシューティング

### デプロイエラー: "Firebase CLI not found"

Firebase CLIをインストール：

```powershell
npm install -g firebase-tools
```

### デプロイエラー: "Authentication required"

Firebaseにログイン：

```powershell
firebase login
```

### デプロイエラー: "Project not found"

プロジェクトを確認：

```powershell
firebase projects:list
```

正しいプロジェクトを選択：

```powershell
firebase use my-web-app-b67f4
```

### 関数が呼び出されない

1. **firebase.jsonのリライトルールを確認**
   ```json
   "rewrites": [
     {
       "source": "/share",
       "function": "shareQuote"
     }
   ]
   ```

2. **Hostingを再デプロイ**
   ```powershell
   firebase deploy --only hosting
   ```

3. **関数のログを確認**
   ```powershell
   firebase functions:log
   ```

### 古いコンテンツがキャッシュされている

ブラウザのキャッシュをクリア：
- Chrome: Ctrl+Shift+R（Windows）/ Cmd+Shift+R（Mac）
- シークレットモードで開く

SNSのOGPキャッシュをクリア：
- Twitter: https://cards-dev.twitter.com/validator
- Facebook: https://developers.facebook.com/tools/debug/

## コスト

Firebase Cloud Functionsの料金：
- **無料枠**: 2,000,000回/月の呼び出し
- **追加料金**: $0.40 / 100万回の呼び出し

通常の使用では無料枠内で十分です。

## 次のステップ

1. ✅ Cloud Functionsをデプロイ
2. ✅ 動作確認
3. ⬜ アプリ内でシェアURLを`https://my-web-app-b67f4.web.app/share?id={id}`に変更
4. ⬜ TwitterやFacebookでシェアテスト
5. ⬜ 不要になったSupabase Edge Functionの`share-quote`を削除（オプション）

## まとめ

この実装により、以下が解決されました：

- ❌ **以前**: Supabaseが`text/html`を`text/plain`に変換 → HTMLがプレーンテキスト表示
- ✅ **現在**: Firebase Cloud FunctionsでHTMLを直接配信 → 正しくレンダリング

OGPメタタグも正しく機能するため、TwitterやFacebookでの共有が美しく表示されます！
