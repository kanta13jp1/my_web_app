# Gemini API 404エラーのトラブルシューティング

**状況**:
- ✅ GOOGLE_AI_API_KEYはSupabase Secretsに設定済み
- ✅ Edge Functionはデプロイ済み
- ❌ 依然として `Gemini API error: 404` が発生

---

## 🔍 診断手順

### ステップ1: APIキーをテストする

PowerShellで以下を実行してAPIキーが有効か確認:

```powershell
# APIキーを変数に設定（YOUR_API_KEY_HEREを実際のキーに置き換える）
$apiKey = "YOUR_API_KEY_HERE"

# Gemini APIにテストリクエスト
$body = @{
    contents = @(
        @{
            parts = @(
                @{ text = "Hello, test" }
            )
        }
    )
} | ConvertTo-Json -Depth 10

Invoke-WebRequest `
  -Uri "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey" `
  -Method POST `
  -ContentType "application/json" `
  -Body $body
```

**期待される結果**:
- ✅ **成功**: JSON レスポンスが返る（テキストが生成される）
- ❌ **404エラー**: APIキーが無効、またはモデルへのアクセスがない
- ❌ **403エラー**: APIキーが無効

---

### ステップ2: Supabase Logsを確認

1. **Supabase Dashboardにアクセス**:
   ```
   https://supabase.com/dashboard/project/smmkxxavexumewbfaqpy/logs/edge-functions
   ```

2. **ai-assistant のログをフィルター**

3. **最新のエラーログを確認**:
   - `Google AI API key not configured` → Secretが読み込まれていない
   - `Gemini API error: 404` → APIキーまたはエンドポイントの問題
   - 詳細なエラーメッセージを確認

---

### ステップ3: Secret名を再確認

```powershell
# Secretsリストを表示
supabase secrets list
```

**確認ポイント**:
- ✅ `GOOGLE_AI_API_KEY` という名前で存在するか（スペル完全一致）
- ❌ `Google_AI_API_KEY` （小文字が含まれている）
- ❌ `GEMINI_API_KEY` （違う名前）
- ❌ `GOOGLE_API_KEY` （AI が抜けている）

**正しい名前**: `GOOGLE_AI_API_KEY` （全て大文字、アンダースコア2つ）

---

### ステップ4: APIキーを再作成

現在のAPIキーが無効な可能性があります。新しいキーを作成:

1. **Google AI Studioにアクセス**:
   ```
   https://makersuite.google.com/app/apikey
   ```

2. **既存のキーを確認**:
   - 既存のキーがあれば、それを使用
   - なければ新しいキーを作成

3. **重要**: プロジェクトに「Generative Language API」が有効になっているか確認

4. **新しいキーでSupabase Secretsを更新**:
   ```powershell
   supabase secrets set GOOGLE_AI_API_KEY=NEW_API_KEY_HERE
   ```

5. **Edge Functionを再デプロイ**:
   ```powershell
   supabase functions deploy ai-assistant
   ```

---

## 🔧 よくある原因と解決策

### 原因1: Generative Language APIが有効化されていない

**症状**: 404エラー

**解決策**:
1. Google Cloud Consoleにアクセス
   ```
   https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com
   ```
2. 「有効にする」をクリック
3. 数分待つ
4. 新しいAPIキーを作成
5. Supabase Secretsを更新

---

### 原因2: APIキーに権限がない

**症状**: 403 または 404エラー

**解決策**:
1. Google AI Studioで新しいAPIキーを作成
2. **重要**: 作成時に正しいプロジェクトを選択
3. 古いキーを削除
4. 新しいキーをSupabase Secretsに設定

---

### 原因3: Secretが読み込まれていない

**症状**: `Google AI API key not configured` のログ

**解決策**:
1. Secret名を確認（大文字小文字、スペル）
2. 再デプロイ:
   ```powershell
   supabase functions deploy ai-assistant
   ```

---

### 原因4: Gemini APIのエンドポイントが変更された

**症状**: 404エラー（APIキーは有効）

**確認**:
現在のエンドポイント（index.tsから）:
```
https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent
```

**最新のドキュメント**:
https://ai.google.dev/api/rest/v1beta/models/generateContent

もしエンドポイントが変更されていたら、index.tsを更新する必要があります。

---

## 📊 詳細デバッグ

### Edge Function Logsの詳細確認

1. **Supabase Dashboard → Logs → Edge Functions**

2. **以下のログを探す**:
   ```
   Gemini API error: 404
   ```

3. **その前後のログを確認**:
   - リクエストボディ
   - APIエンドポイントURL
   - レスポンスの詳細

4. **スクリーンショットを撮る**（サポート時に役立つ）

---

### APIキーのテスト（curlバージョン）

```bash
# Linux/Mac/Windows (Git Bash)
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}'
```

**成功のレスポンス例**:
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "Hello! How can I help you today?"
          }
        ]
      }
    }
  ]
}
```

**失敗のレスポンス例（404）**:
```json
{
  "error": {
    "code": 404,
    "message": "models/gemini-1.5-flash is not found",
    "status": "NOT_FOUND"
  }
}
```

---

## ✅ 解決後のチェックリスト

- [ ] APIキーが有効であることを確認（上記テスト）
- [ ] Supabase Secretsに正しく設定されている
- [ ] Secret名が `GOOGLE_AI_API_KEY` で完全一致
- [ ] Edge Functionを再デプロイした
- [ ] Supabase Logsにエラーがない
- [ ] アプリでAI機能が動作する

---

## 🆘 それでも解決しない場合

以下の情報を収集してください:

1. **APIキーテスト結果**:
   - PowerShellコマンドの出力（全文）
   - 成功 or エラーコード

2. **Supabase Logs**:
   - Edge Functions → ai-assistant の最新ログ
   - エラーメッセージの全文
   - スクリーンショット

3. **Secrets確認**:
   ```powershell
   supabase secrets list
   ```
   - 出力結果（キーの値は隠してOK）

4. **APIキー情報**:
   - Google AI Studioでキーを作成した日時
   - 使用しているプロジェクト名
   - キーの最初の5文字（例: `AIzaS...`）

5. **ブラウザコンソール**:
   - F12 → Console
   - エラーメッセージの全文

この情報を次のClaude Codeセッションで共有してください。

---

## 💡 代替案（一時的）

Gemini APIの問題が解決するまで、以下の代替案も検討できます:

### オプション1: OpenAI APIに戻す（一時的）
- コスト: 有料（$5-10/月）
- レート制限: 厳しい（3 RPM）
- すぐに動作

### オプション2: Claude APIを試す
- コスト: 有料
- 日本語品質: 優秀
- レート制限: 中程度

**ただし、Gemini APIが最適な選択肢なので、まず上記のトラブルシューティングを試してください。**

---

**作成日**: 2025年11月8日
**最終更新**: 2025年11月8日
