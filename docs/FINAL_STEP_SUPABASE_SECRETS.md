# 🚨 最終ステップ: Supabase Secrets設定

**現状**: Edge Functionはデプロイ済み ✅
**問題**: GOOGLE_AI_API_KEYが未設定 ❌

エラー: `Gemini API error: 404`

---

## ✅ 解決方法（5分で完了）

### オプション1: Supabase Dashboard（推奨・簡単）

1. **Supabase Dashboardにアクセス**
   ```
   https://supabase.com/dashboard/project/smmkxxavexumewbfaqpy
   ```

2. **左サイドバーから「Project Settings」をクリック**

3. **「Edge Functions」をクリック**

4. **「Secrets」タブをクリック**

5. **「Add new secret」ボタンをクリック**

6. **以下を入力**:
   - **Name**: `GOOGLE_AI_API_KEY`（正確に入力！）
   - **Value**: （Google AI Studioで取得したAPIキー）

7. **「Save」をクリック**

---

### オプション2: Supabase CLI（PowerShellから）

```powershell
# Secretを設定
supabase secrets set GOOGLE_AI_API_KEY=YOUR_API_KEY_HERE

# 確認
supabase secrets list
```

**出力例**:
```
NAME                   | DIGEST
-----------------------|--------
GOOGLE_AI_API_KEY      | abc123...
```

---

## 📝 Google AI APIキーの取得（まだの場合）

1. **Google AI Studioにアクセス**
   ```
   https://makersuite.google.com/app/apikey
   ```

2. **Googleアカウントでログイン**

3. **「Create API key」をクリック**

4. **プロジェクトを選択**（既存 or 新規作成）

5. **APIキーをコピー**
   - 例: `AIzaSyABC123...` （長いキー）

---

## 🔄 設定後の確認

### 1. Secretが設定されたか確認

**Dashboard**: Project Settings → Edge Functions → Secrets
- `GOOGLE_AI_API_KEY` が表示されていればOK

**CLI**:
```powershell
supabase secrets list
```

### 2. Edge Functionを再デプロイ（重要！）

```powershell
supabase functions deploy ai-assistant
```

**理由**: Secretを設定した後は再デプロイが必要

### 3. アプリでテスト

1. ブラウザでアプリを開く
2. **ページをリロード**（F5キー）
3. AI秘書ページにアクセス
4. 「AIに相談する」ボタンをクリック

**期待結果**:
- ✅ タスク推奨が表示される
- ✅ 404エラーが消える
- ✅ ブラウザコンソールにエラーなし

---

## 🐛 トラブルシューティング

### まだ404エラーが出る場合

**原因1: APIキーが無効**
```
解決策:
1. Google AI Studioで新しいAPIキーを作成
2. Supabase Secretsを更新
3. Edge Functionを再デプロイ
```

**原因2: Secret名のスペルミス**
```
正しい名前: GOOGLE_AI_API_KEY（全て大文字）

よくある間違い:
- Google_AI_API_KEY
- GOOGLE_AI_KEY
- GEMINI_API_KEY
```

**原因3: 再デプロイを忘れた**
```
解決策:
supabase functions deploy ai-assistant
```

### APIキーの確認方法

**テストリクエスト**:
```powershell
# APIキーが有効か確認
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_API_KEY" `
  -H "Content-Type: application/json" `
  -d '{\"contents\":[{\"parts\":[{\"text\":\"Hello\"}]}]}'
```

**成功**: JSON レスポンスが返る
**失敗**: 404 または 403 エラー → APIキーが無効

---

## ✅ 成功の確認

すべて完了すると:

1. **AI秘書機能が動作**
   - 今日/今週/今月/今年のタスク表示
   - AIからのインサイト表示

2. **他のAI機能も動作**
   - 文章改善
   - 要約
   - 翻訳
   - タイトル提案

3. **エラーなし**
   - ブラウザコンソールにエラーなし
   - Supabase Logsにエラーなし

---

## 📞 サポートが必要な場合

**確認すべき情報**:
1. Supabase Dashboard のスクリーンショット（Secrets画面）
2. `supabase secrets list` の出力
3. ブラウザコンソールのエラーメッセージ
4. Google AI APIキーの最初の5文字（例: `AIzaS...`）

次のClaude Codeセッションで上記を共有してください。

---

**作成日**: 2025年11月8日
**推定所要時間**: 5分
**重要度**: 🔴 最優先
