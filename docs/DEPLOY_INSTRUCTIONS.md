# 🚀 デプロイ手順

## 修正内容

`share-quote` Edge Functionの`escapeHtml`関数を修正しました:
- **修正前**: すべての非ASCII文字をHTMLエンティティに変換
- **修正後**: HTML特殊文字（`<`, `>`, `&`, `"`, `'`）のみをエスケープ

## デプロイ方法

### 1. Supabase CLIでログイン

```bash
supabase login
```

### 2. プロジェクトにリンク

```bash
supabase link --project-ref smmkxxavexumewbfaqpy
```

### 3. share-quote関数をデプロイ

```bash
supabase functions deploy share-quote
```

### 4. 動作確認

デプロイ後、以下のURLをブラウザで開いて確認:

```
https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/share-quote?id=10
```

**期待される結果**:
- 美しくスタイリングされたHTMLページが表示される
- 日本語テキストが正しく表示される（HTMLエンティティではない）
- 例: 「マイメモ」「孔子」「💭」などが正しく表示される

**問題が残る場合**:
- ブラウザのキャッシュをクリア（Ctrl+Shift+R または Cmd+Shift+R）
- シークレット/プライベートモードで開く
- Content-Typeヘッダーを確認: `curl -I "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/share-quote?id=10"`

### 5. キャッシュのクリア

デプロイ後、SNSのOGPキャッシュもクリアが必要な場合があります:

- **Twitter**: https://cards-dev.twitter.com/validator
- **Facebook**: https://developers.facebook.com/tools/debug/

## トラブルシューティング

### HTMLが`<pre>`タグ内にエスケープされて表示される

これは、ブラウザがレスポンスをテキストファイルとして認識している可能性があります。

確認方法:
```bash
curl -I "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/share-quote?id=10"
```

`Content-Type: text/html; charset=utf-8` が返されることを確認してください。

### デプロイが反映されない

Supabaseのキャッシュをクリア:
```bash
# 関数を再デプロイ
supabase functions deploy share-quote --no-verify-jwt
```

または、クエリパラメータを追加してキャッシュを回避:
```
https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/share-quote?id=10&_t=123456
```
