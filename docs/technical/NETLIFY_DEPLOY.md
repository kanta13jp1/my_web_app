# 🚀 Netlify デプロイ手順（SNSシェア機能）

## 📌 概要

このプロジェクトでは、**SNSシェア機能**に **Netlify Functions** を使用しています。

### なぜNetlify？

- ✅ **完全無料** - クレジットカード不要
- ✅ **無料枠が豊富** - 125,000リクエスト/月、100GB帯域幅/月
- ✅ **簡単デプロイ** - GitHubと連携するだけ
- ✅ **高速** - CDN配信で世界中どこでも高速

### 他のプラットフォームとの比較

| プラットフォーム | 無料プラン | クレカ必要 | 備考 |
|:---|:---|:---|:---|
| **Netlify** | ✅ 125K req/月 | ❌ 不要 | ⭐ 採用 |
| Firebase Functions | ✅ 2M req/月 | ✅ 必要 | Blazeプラン要 |
| Supabase | ✅ | ❌ 不要 | `text/html`→`text/plain`変換問題 |
| Vercel | ✅ 100GB/月 | ❌ 不要 | 代替案 |

## 📂 実装ファイル

```
netlify/
├── functions/
│   ├── share-quote.js         # シェアページHTML生成
│   ├── generate-quote-image.js # OGP画像（SVG）生成
│   └── quotes.js               # 名言データ（35件）
└── netlify.toml                # Netlify設定ファイル
```

## 🚀 デプロイ手順

### ステップ 1: GitHubにプッシュ

```bash
git add .
git commit -m "Add Netlify Functions for SNS share feature"
git push origin claude/implement-sns-share-feature-011CUuhygDoLPGW9eCdRr973
```

### ステップ 2: Netlifyアカウント作成

1. https://app.netlify.com/signup にアクセス
2. **GitHub** でサインアップ（推奨）
3. 必要な権限を付与

### ステップ 3: 新しいサイトをインポート

1. Netlifyダッシュボードで **"Add new site"** → **"Import an existing project"**
2. **"Deploy with GitHub"** を選択
3. リポジトリを検索: **my_web_app**
4. ブランチを選択: `claude/implement-sns-share-feature-011CUuhygDoLPGW9eCdRr973`

### ステップ 4: ビルド設定

**Build settings:**
- **Branch to deploy**: `claude/implement-sns-share-feature-011CUuhygDoLPGW9eCdRr973`
- **Build command**: （空白）
- **Publish directory**: `build/web`
- **Functions directory**: `netlify/functions`

※ `netlify.toml`に設定があるため、自動的に読み込まれます。

### ステップ 5: デプロイ

**"Deploy site"** をクリック

デプロイには2〜3分かかります。完了すると以下のようなURLが生成されます：
```
https://random-name-12345.netlify.app
```

### ステップ 6: ⚠️ 重要 - app_share_service.dartを更新

デプロイ後、生成されたNetlify URLを `lib/services/app_share_service.dart` に設定してください：

```dart
// Before
static const String netlifyBaseUrl = 'https://your-site-name.netlify.app';

// After（実際のNetlify URLに置き換え）
static const String netlifyBaseUrl = 'https://random-name-12345.netlify.app';
```

その後、Flutterアプリを再ビルド＆デプロイ：

```bash
flutter build web
firebase deploy --only hosting
```

### ステップ 7: カスタムドメイン設定（オプション）

無料でカスタムサブドメインを設定できます：

1. **Site settings** → **Domain management**
2. **"Add custom domain"** をクリック
3. 任意のサブドメインを設定: `my-web-app-share.netlify.app`

## 🧪 動作確認

### テストURL

デプロイ後、以下のURLでテスト：

1. **シェアページ**
   ```
   https://[your-site-name].netlify.app/share?id=0
   ```

2. **OGP画像**
   ```
   https://[your-site-name].netlify.app/api/quote-image?id=0
   ```

### 期待される結果

✅ **シェアページ:**
- 美しくスタイリングされたHTMLページ
- 日本語が正しく表示（例: 「マイメモ」「孔子」）
- 絵文字が正しく表示（💭）

✅ **OGP画像:**
- SVG形式の画像（1200x630px）
- グラデーション背景（青→紫）
- 名言テキストと著者名が表示

✅ **Twitter/Facebookシェア:**
- カードプレビューが表示される
- 画像、タイトル、説明が正しく表示される

### テスト方法

#### 1. ブラウザで直接確認

```
https://[your-site-name].netlify.app/share?id=25
```

#### 2. Response Headersを確認

```bash
curl -I "https://[your-site-name].netlify.app/share?id=25"
```

期待されるヘッダー:
```
Content-Type: text/html; charset=utf-8
Cache-Control: public, max-age=3600
```

#### 3. TwitterカードバリデータでOGPを確認

https://cards-dev.twitter.com/validator

URLを入力：`https://[your-site-name].netlify.app/share?id=25`

## 📊 エンドポイント仕様

### 1. シェアページ (`/share`)

**URL形式:**
```
https://[your-site-name].netlify.app/share?id={quoteId}
```

**パラメータ:**
- `id` (optional): 名言のID（0-34）
  - 指定しない場合：ランダムな名言を表示
  - 範囲外の場合：モジュロ演算で範囲内に調整

**レスポンス:**
- Content-Type: `text/html; charset=utf-8`
- OGPメタタグ付きの完全なHTMLページ

### 2. OGP画像 (`/api/quote-image`)

**URL形式:**
```
https://[your-site-name].netlify.app/api/quote-image?id={quoteId}
```

**パラメータ:**
- `id` (optional): 名言のID（0-34）

**レスポンス:**
- Content-Type: `image/svg+xml; charset=utf-8`
- SVG画像（1200x630px）

## 🔧 トラブルシューティング

### デプロイエラー: "Function failed to load"

1. **Netlify Functions Logを確認**
   - Netlify Dashboard → Functions → Logs

2. **ローカルでテスト**
   ```bash
   npm install -g netlify-cli
   netlify dev
   ```

### HTMLがプレーンテキストで表示される

Response Headersを確認：
```bash
curl -I "https://[your-site-name].netlify.app/share?id=25"
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

## 💰 コスト

### Netlify無料プラン

- ✅ **帯域幅**: 100GB/月
- ✅ **ビルド時間**: 300分/月
- ✅ **関数実行**: 125,000リクエスト/月
- ✅ **関数実行時間**: 100時間/月
- ✅ **同時実行**: 1,000

**通常の使用では無料枠で十分です。**

### 無料枠を超えた場合

Netlifyは自動的にサイトを停止しません。有料プランへの自動アップグレードもありません。
必要に応じて、Netlify Proプラン（$19/月）にアップグレードできます。

## 🔄 自動デプロイ

GitHubにプッシュすると自動的にデプロイされます：

1. コードをコミット＆プッシュ
2. Netlifyが自動的にビルド＆デプロイ
3. 数分後に本番環境に反映

## 📚 関連ドキュメント

- [GROWTH_STRATEGY_ROADMAP.md](./GROWTH_STRATEGY_ROADMAP.md) - SNSシェア機能の戦略
- [IMPROVEMENTS.md](./IMPROVEMENTS.md) - 実装履歴
- [SUPABASE_EDGE_FUNCTIONS_DEPLOY.md](./SUPABASE_EDGE_FUNCTIONS_DEPLOY.md) - AI機能（Supabase）

## 📝 名言データについて

名言データは `netlify/functions/quotes.js` に35件格納されています。

新しい名言を追加する場合：
1. `quotes.js` に追加
2. GitHubにプッシュ
3. Netlifyが自動デプロイ

## 🎉 まとめ

この実装により、以下が実現されました：

- ✅ **完全無料** でSNSシェア機能を実装
- ✅ **動的OGP画像** で魅力的なシェアカード
- ✅ **高速配信** でユーザー体験向上
- ✅ **自動デプロイ** で開発効率向上

---

**作成日**: 2025-11-08
**最終更新**: 2025-11-08
