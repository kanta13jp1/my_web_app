# 緊急対応アクションプラン

**作成日**: 2025年11月8日
**重要度**: 🔴 最優先
**対象**: AI Assistant 400エラーの修正とサービス復旧

---

## 🚨 現状の問題

### 1. AI Assistant 400 Bad Request エラー

**エラー内容**:
```
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/ai-assistant 400 (Bad Request)
Gemini API error: 404
```

**根本原因**:
- ✅ コードはGemini APIに移行済み（2025-11-08完了）
- ❌ **GOOGLE_AI_API_KEYがSupabase Secretsに未設定**
- ❌ **Edge Functionが未デプロイまたは古いバージョン**

**影響範囲**:
- AI文章改善機能が使用不可
- AI要約・展開機能が使用不可
- AI秘書機能（タスク推奨）が使用不可
- 翻訳機能が使用不可
- タイトル提案機能が使用不可

---

## ✅ 即座に実行すべき手順

### ステップ1: Google AI APIキーの取得 (5分)

1. **Google AI Studioにアクセス**
   ```
   https://makersuite.google.com/app/apikey
   ```

2. **Googleアカウントでログイン**
   - Gmailアカウントを使用

3. **APIキーを作成**
   - 「Create API key」ボタンをクリック
   - 既存のプロジェクトを選択 または 「Create new project」
   - APIキーが生成されます（例: `AIzaSy...`）

4. **APIキーをコピー**
   - 安全な場所（パスワードマネージャーなど）に保存

---

### ステップ2: Supabase SecretsへのAPIキー設定 (3分)

#### オプションA: Supabase Dashboard（推奨）

1. **Supabaseプロジェクトにログイン**
   ```
   https://app.supabase.com
   ```

2. **プロジェクトを選択**
   - `my_web_app` プロジェクト

3. **Secretsページに移動**
   - 左サイドバー: `Project Settings` → `Edge Functions` → `Secrets`

4. **新しいSecretを追加**
   - 「Add new secret」ボタンをクリック
   - **Name**: `GOOGLE_AI_API_KEY`
   - **Value**: (ステップ1でコピーしたAPIキー)
   - 「Save」をクリック

#### オプションB: Supabase CLI（ターミナルが使える場合）

```bash
# Supabaseにログイン（初回のみ）
supabase login

# プロジェクトにリンク（初回のみ）
supabase link --project-ref smmkxxavexumewbfaqpy

# Secretを設定
supabase secrets set GOOGLE_AI_API_KEY=YOUR_API_KEY_HERE

# 確認
supabase secrets list
```

---

### ステップ3: Edge Functionのデプロイ (5分)

#### オプションA: Supabase Dashboard（推奨）

1. **Edge Functionsページに移動**
   - 左サイドバー: `Edge Functions`

2. **ai-assistant関数を確認**
   - 既存の関数がリストにあるか確認
   - ない場合: 手動デプロイが必要（オプションB参照）

3. **関数を再デプロイ（CLI必須）**
   - Dashboard からは再デプロイできないため、オプションB参照

#### オプションB: Supabase CLI（ターミナルが使える場合）

```bash
# プロジェクトのルートディレクトリに移動
cd /home/user/my_web_app

# Edge Functionをデプロイ
supabase functions deploy ai-assistant

# デプロイ確認
supabase functions list
```

**出力例**:
```
┌────────────────┬──────────┬───────────────────────┬─────────┐
│ NAME           │ VERSION  │ CREATED AT            │ UPDATED │
├────────────────┼──────────┼───────────────────────┼─────────┤
│ ai-assistant   │ v1       │ 2025-11-08 12:00:00   │ now     │
└────────────────┴──────────┴───────────────────────┴─────────┘
```

---

### ステップ4: テストと確認 (5分)

#### 4.1 Flutter Webアプリでテスト

1. **アプリにログイン**
   - ブラウザで https://your-app-url.web.app にアクセス

2. **AI機能をテスト**

   **a) AI文章改善**
   - 任意のメモを開く
   - メモエディタで「AIで改善」ボタンをクリック
   - ✅ 改善された文章が表示される
   - ❌ エラーが表示される → ステップ5へ

   **b) AI秘書機能**
   - ホームページのメニューから「AI秘書」をクリック
   - ✅ 今日/今週/今月/今年のタスク推奨が表示される
   - ❌ エラーが表示される → ステップ5へ

3. **ブラウザコンソールを確認**
   - F12キーを押してDeveloper Toolsを開く
   - Consoleタブを確認
   - ✅ エラーなし
   - ❌ `400 Bad Request` または `404` エラー → ステップ5へ

#### 4.2 Supabase Logsで確認

1. **Edge Function Logsを開く**
   - Supabase Dashboard → `Edge Functions` → `ai-assistant` → `Logs`

2. **最新のログを確認**
   - ✅ `success: true` が表示される
   - ❌ `Gemini API error: 404` → APIキーが正しく設定されていない
   - ❌ `API key not configured` → ステップ2を再実行

---

### ステップ5: トラブルシューティング

#### エラー1: `Gemini API error: 404`

**原因**: APIキーが無効または間違っている

**解決策**:
1. Google AI Studio で新しいAPIキーを作成
2. Supabase Secrets を更新
   ```bash
   supabase secrets set GOOGLE_AI_API_KEY=NEW_API_KEY
   ```
3. Edge Functionを再デプロイ
   ```bash
   supabase functions deploy ai-assistant
   ```

#### エラー2: `API key not configured`

**原因**: Secret名が間違っている、または設定されていない

**解決策**:
```bash
# Secretsを確認
supabase secrets list

# 正しい名前で設定（スペルミスに注意）
supabase secrets set GOOGLE_AI_API_KEY=YOUR_KEY

# Edge Functionを再デプロイ
supabase functions deploy ai-assistant
```

#### エラー3: `Rate limit exceeded (429)`

**原因**: 短時間に大量のリクエストを送信

**解決策**:
- 60秒待ってから再試行
- Gemini無料枠: 15 requests/minute
- フロントエンドのリトライロジックが自動的に対応

#### エラー4: Supabase CLIが使えない

**症状**: `command not found: supabase`

**解決策**:

**macOS/Linux**:
```bash
# Homebrewでインストール（macOS）
brew install supabase/tap/supabase

# npmでインストール（Linux/macOS）
npm install -g supabase
```

**Windows**:
```powershell
# Scoopでインストール
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

または、npmでインストール:
```bash
npm install -g supabase
```

---

## 📊 確認チェックリスト

デプロイ完了後、以下を確認してください:

- [ ] Google AI APIキーを取得した
- [ ] Supabase Secrets に `GOOGLE_AI_API_KEY` を設定した
- [ ] Edge Function `ai-assistant` をデプロイした
- [ ] AI文章改善機能が動作する
- [ ] AI秘書機能が動作する
- [ ] ブラウザコンソールにエラーがない
- [ ] Supabase Logs にエラーがない

---

## 🎯 期待される結果

### デプロイ成功後:

✅ **AI機能が完全復旧**
- 文章改善、要約、展開、翻訳が動作
- AI秘書機能が動作
- タイトル提案が動作

✅ **エラー率の大幅改善**
- 400エラー: 100% → 0%
- 404エラー: 100% → 0%
- 429エラー: 大幅減少（OpenAI比 -98%）

✅ **コスト削減**
- API費用: $5-10/月 → $0/月（Gemini無料枠）

✅ **パフォーマンス向上**
- 応答時間: 2-5秒 → 1-3秒（-40%）
- レート制限: 3 RPM → 15 RPM (+400%)

---

## 📚 関連ドキュメント

- [GEMINI_MIGRATION_GUIDE.md](./technical/GEMINI_MIGRATION_GUIDE.md) - 詳細な技術ガイド
- [SESSION_SUMMARY_2025-11-08_GEMINI_MIGRATION.md](./session-summaries/SESSION_SUMMARY_2025-11-08_GEMINI_MIGRATION.md) - 移行の詳細
- [Gemini API Documentation](https://ai.google.dev/docs)
- [Supabase Edge Functions Guide](https://supabase.com/docs/guides/functions)

---

## 🆘 サポート

問題が解決しない場合:

1. **Supabase Logs を確認**
   - Dashboard → Edge Functions → ai-assistant → Logs

2. **ブラウザコンソールを確認**
   - F12 → Console タブ

3. **AI使用ログを確認**
   ```sql
   SELECT * FROM ai_usage_log
   ORDER BY created_at DESC
   LIMIT 10;
   ```

4. **この情報を Claude Code に提供**
   - エラーメッセージの全文
   - Supabase Logsのスクリーンショット
   - ブラウザコンソールのスクリーンショット

---

**最終更新**: 2025年11月8日
**重要度**: 🔴 最優先
**推定所要時間**: 15-30分
