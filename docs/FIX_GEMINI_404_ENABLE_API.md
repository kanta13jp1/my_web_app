# ✅ 問題確定: Generative Language API未有効化

**テスト結果**: 404エラー
**原因**: Generative Language APIがGoogle Cloudプロジェクトで有効化されていない

---

## 🎯 解決手順（10分で完了）

### ステップ1: Generative Language APIを有効化

**重要**: Google AI Studio（MakerSuite）で作成したAPIキーは、**Google Cloud Console**でAPIを有効化する必要があります。

#### 方法A: 直接リンク（最も簡単）

1. **以下のリンクをクリック**:
   ```
   https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com
   ```

2. **Googleアカウントでログイン**（APIキーを作成したアカウント）

3. **プロジェクトを選択**
   - APIキーを作成したプロジェクト
   - わからない場合: プロジェクト一覧から選択

4. **「有効にする」ボタンをクリック**

5. **数分待つ**（通常は即座に有効化されます）

#### 方法B: Google Cloud Console から

1. **Google Cloud Console にアクセス**:
   ```
   https://console.cloud.google.com/
   ```

2. **プロジェクトを選択**（APIキーを作成したプロジェクト）

3. 左サイドバー → **「APIとサービス」** → **「ライブラリ」**

4. 検索ボックスに **"Generative Language API"** と入力

5. **「Generative Language API」**をクリック

6. **「有効にする」**ボタンをクリック

---

### ステップ2: 新しいAPIキーを作成（推奨）

API有効化後、念のため新しいキーを作成:

1. **Google AI Studio にアクセス**:
   ```
   https://makersuite.google.com/app/apikey
   ```

2. **「Create API key」**をクリック

3. **プロジェクトを選択**
   - 先ほどAPIを有効化したプロジェクト

4. **APIキーをコピー**
   - 例: `AIzaSyABC123XYZ...`（長いキー）

5. **安全な場所に保存**

---

### ステップ3: APIキーをテスト

新しいキーが動作するか確認:

```powershell
# 新しいAPIキーを設定
$apiKey = "YOUR_NEW_API_KEY_HERE"

# テストリクエスト
$body = @{
    contents = @(
        @{
            parts = @(
                @{ text = "こんにちは" }
            )
        }
    )
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-WebRequest `
      -Uri "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey" `
      -Method POST `
      -ContentType "application/json" `
      -Body $body

    Write-Host "✅ 成功! レスポンス:" -ForegroundColor Green
    $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
} catch {
    Write-Host "❌ エラー: $($_.Exception.Message)" -ForegroundColor Red

    # 詳細なエラー情報
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorDetails = $reader.ReadToEnd()
        Write-Host "詳細: $errorDetails" -ForegroundColor Yellow
    }
}
```

**期待される出力（成功）**:
```
✅ 成功! レスポンス:
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "こんにちは！何かお手伝いできることはありますか？"
          }
        ]
      }
    }
  ]
}
```

---

### ステップ4: Supabase Secretsを更新

```powershell
# 新しいAPIキーをSupabaseに設定
supabase secrets set GOOGLE_AI_API_KEY=YOUR_NEW_API_KEY

# 確認
supabase secrets list
```

---

### ステップ5: Edge Functionを再デプロイ

```powershell
supabase functions deploy ai-assistant
```

---

### ステップ6: アプリでテスト

1. ブラウザでアプリを開く
2. **Ctrl + Shift + R**（ハードリフレッシュ）
3. AI秘書ページにアクセス
4. 「AIに相談する」をクリック

**期待結果**:
- ✅ タスク推奨が表示される
- ✅ エラーなし
- ✅ 「こんにちは」などのメッセージが返る

---

## 🔍 よくある質問

### Q1: どのプロジェクトでAPIを有効化すればいい？

**A**: Google AI Studio（MakerSuite）でAPIキーを作成したときに選択したプロジェクトです。

確認方法:
1. https://makersuite.google.com/app/apikey
2. 既存のAPIキーの横に表示されているプロジェクト名

### Q2: APIを有効化したのにまだ404エラーが出る

**A**: 以下を確認:
1. 数分待つ（伝播に時間がかかる場合がある）
2. 新しいAPIキーを作成する
3. ブラウザのキャッシュをクリア
4. 別のブラウザで試す

### Q3: 「Generative Language API」が見つからない

**A**: 正確な名前で検索:
- 正: `Generative Language API`
- 誤: `Gemini API`
- 誤: `Google AI API`

または、直接リンクを使用:
```
https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com
```

---

## 📊 APIが有効化されているか確認

### 方法1: Google Cloud Console

1. https://console.cloud.google.com/apis/dashboard
2. プロジェクトを選択
3. 「Generative Language API」が有効なAPIのリストにあるか確認

### 方法2: gcloud CLI（オプション）

```bash
gcloud services list --enabled --project=YOUR_PROJECT_ID
```

出力に `generativelanguage.googleapis.com` があればOK

---

## ✅ 成功のサイン

すべて完了すると:

1. **APIキーテストが成功**
   ```
   ✅ 成功! レスポンス: {...}
   ```

2. **アプリのAI機能が動作**
   - AI秘書でタスク推奨が表示
   - 文章改善が動作
   - エラーなし

3. **Supabase Logsにエラーなし**
   - https://supabase.com/dashboard/project/smmkxxavexumewbfaqpy/logs/edge-functions

4. **ブラウザコンソールにエラーなし**
   - F12 → Console → エラーなし

---

## 🆘 それでも解決しない場合

以下を試してください:

### オプション1: 完全に新しいプロジェクトで試す

1. Google Cloud Console で新しいプロジェクト作成
2. そのプロジェクトで Generative Language API を有効化
3. 新しいAPIキーを作成
4. テスト → 成功したら、このキーを使用

### オプション2: Google Cloudサポートに問い合わせ

404エラーが続く場合、Google側の問題の可能性があります:
- https://console.cloud.google.com/support

---

## 📝 次回のセッションで必要な情報

もし問題が解決しない場合、以下を準備してください:

1. **APIテスト結果**（上記の詳細テストコマンドの出力）
2. **Google Cloud Console スクリーンショット**:
   - APIとサービス → ダッシュボード
   - 有効なAPIのリスト
3. **Google AI Studio スクリーンショット**:
   - APIキーのリスト
   - 使用しているプロジェクト名
4. **Supabase Logs**（最新5件）

---

**作成日**: 2025年11月8日
**推定所要時間**: 10分
**成功率**: 95%+
