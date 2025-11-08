# Supabase Edge Functions デプロイ手順

このドキュメントでは、動的OGP画像生成のためのSupabase Edge Functionsをデプロイする手順を説明します。

## 📋 前提条件

- Supabaseプロジェクトが作成済みであること
- Supabase CLI がインストールされていること

## 🚀 デプロイ手順

### 1. Supabase CLI のインストール

まだインストールしていない場合、以下のコマンドでインストールしてください：

```bash
# macOS / Linux (Homebrew)
brew install supabase/tap/supabase

# Windows (Scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# NPM
npm install -g supabase
```

### 2. Supabase にログイン

```bash
supabase login
```

ブラウザが開き、Supabaseアカウントでの認証が求められます。

### 3. プロジェクトにリンク

```bash
supabase link --project-ref smmkxxavexumewbfaqpy
```

プロジェクトIDは `lib/main.dart` の Supabase URL から確認できます：
```
https://smmkxxavexumewbfaqpy.supabase.co
         ^^^^^^^^^^^^^^^^^^^^
         これがプロジェクトID
```

### 4. Edge Functions をデプロイ

#### すべての関数を一度にデプロイ

```bash
supabase functions deploy
```

#### 個別にデプロイする場合

```bash
# share-quote 関数（HTML + OGP メタタグを生成）
supabase functions deploy share-quote

# generate-quote-image 関数（OGP画像を生成）
supabase functions deploy generate-quote-image
```

### 5. デプロイの確認

デプロイが成功すると、以下のようなメッセージが表示されます：

```
Deployed Function share-quote on project smmkxxavexumewbfaqpy
Deployed Function generate-quote-image on project smmkxxavexumewbfaqpy
```

### 6. 動作確認

#### share-quote 関数をテスト

```bash
curl https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/share-quote?id=0
```

HTMLが返ってくれば成功です。

#### generate-quote-image 関数をテスト

```bash
curl https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/generate-quote-image?id=0 --output test.svg
```

SVG画像が保存されれば成功です。

ブラウザで直接アクセスして確認：
```
https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/share-quote?id=0
https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/generate-quote-image?id=0
```

## 🔍 トラブルシューティング

### デプロイがエラーになる

1. **ログインを確認**
   ```bash
   supabase projects list
   ```
   プロジェクト一覧が表示されるか確認

2. **リンクを確認**
   ```bash
   supabase status
   ```
   正しいプロジェクトにリンクされているか確認

3. **関数のログを確認**
   ```bash
   supabase functions logs share-quote
   supabase functions logs generate-quote-image
   ```

### OGP画像が表示されない

1. **キャッシュをクリア**
   SNS（Twitter、Facebook）はOGP画像をキャッシュします。

   - Twitter: https://cards-dev.twitter.com/validator
   - Facebook: https://developers.facebook.com/tools/debug/

   上記のツールでURLを入力して、キャッシュをクリアしてください。

2. **SVG形式の対応**
   一部のSNSではSVG画像がサポートされていない場合があります。
   その場合は、PNG変換が必要になります。

## 📝 環境変数の設定

Edge Functions で環境変数を使用する場合：

```bash
supabase secrets set MY_SECRET=value
```

現在の実装では環境変数は使用していませんが、将来的に必要になる可能性があります。

## 🔄 更新手順

関数を更新した場合は、再度デプロイするだけです：

```bash
supabase functions deploy share-quote
supabase functions deploy generate-quote-image
```

## 🌐 本番環境での使用

デプロイ後、以下のURLでアクセスできます：

- **シェアページ**: `https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/share-quote?id=[0-32]`
- **OGP画像**: `https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/generate-quote-image?id=[0-32]`

`id` パラメータは 0 から 32 の間の数値で、33種類の哲学者の名言に対応しています。
パラメータを省略するとランダムに選択されます。

## 📊 使用例

### Twitter でシェア

```dart
await AppShareService.shareToTwitterWithDynamicOgp(
  level: userLevel,
  totalPoints: userPoints,
  currentStreak: userStreak,
);
```

### Facebook でシェア

```dart
await AppShareService.shareToFacebookWithDynamicOgp();
```

### LINE でシェア

```dart
await AppShareService.shareToLineWithDynamicOgp(
  level: userLevel,
  totalPoints: userPoints,
  currentStreak: userStreak,
);
```

## 🎨 カスタマイズ

### 名言を追加する

`supabase/functions/_shared/quotes.ts` に新しい名言を追加してください：

```typescript
{
  quote: "新しい名言",
  author: "著者名",
  imageUrl: "https://images.unsplash.com/...",
  authorDescription: "著者の説明"
}
```

その後、再デプロイします：

```bash
supabase functions deploy share-quote
supabase functions deploy generate-quote-image
```

### スタイルを変更する

- **share-quote/index.ts**: HTMLとCSSをカスタマイズ
- **generate-quote-image/index.ts**: SVG画像のデザインをカスタマイズ

## 📚 参考資料

- [Supabase Edge Functions ドキュメント](https://supabase.com/docs/guides/functions)
- [Supabase CLI リファレンス](https://supabase.com/docs/reference/cli/introduction)
- [Deno ドキュメント](https://deno.land/)

---

作成日: 2025-11-06
最終更新: 2025-11-06
