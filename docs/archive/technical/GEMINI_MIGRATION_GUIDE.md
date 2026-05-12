# Google Gemini APIへの移行ガイド [Archive]

**作成日**: 2025年11月8日
**目的**: OpenAI APIからGoogle Gemini APIへ移行し、レート制限問題を解決
**ステータス**: 実装待ち

---

## 📌 なぜGemini?

### OpenAI APIの問題点
- **厳しいレート制限**: 無料枠で3 RPM、200 RPD
- **コスト**: 有料プランでも$5/月〜
- **頻繁な429エラー**: ユーザー体験の低下

### Gemini APIの利点
- ✅ **豊富な無料枠**: 15 RPM、1,500 RPD（5倍以上）
- ✅ **完全無料**: APIキーのみで利用可能
- ✅ **高品質な日本語**: OpenAI と同等以上
- ✅ **低レイテンシ**: Googleのインフラで高速
- ✅ **長期的にスケール可能**: 有料プランも合理的

---

## 🚀 移行手順

### ステップ1: Google AI APIキーの取得

1. **Google AI Studioにアクセス**
   - URL: https://makersuite.google.com/app/apikey
   - Googleアカウントでログイン

2. **新しいAPIキーを作成**
   - 「Create API key」をクリック
   - プロジェクトを選択（または新規作成）
   - APIキーが生成される

3. **APIキーを安全に保存**
   ```bash
   # 環境変数として保存（ローカルテスト用）
   export GOOGLE_AI_API_KEY=your_api_key_here
   ```

### ステップ2: Supabase シークレットに設定

```bash
# Supabase CLIを使用
supabase secrets set GOOGLE_AI_API_KEY=your_api_key_here

# 確認
supabase secrets list
```

または、Supabase Dashboardから設定:
1. Project Settings → Edge Functions → Secrets
2. 「Add new secret」をクリック
3. Name: `GOOGLE_AI_API_KEY`
4. Value: `your_api_key_here`

### ステップ3: ai-assistant Edge Function の更新

**ファイル**: `supabase/functions/ai-assistant/index.ts`

<details>
<summary>📝 完全な実装コード（クリックして展開）</summary>

```typescript
// AI Assistant Edge Function with Google Gemini
// メモ作成支援、文章改善、要約生成などのAI機能を提供

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Gemini API設定
const GEMINI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')
const GEMINI_MODEL = 'gemini-flash-latest' // 高速・無料モデル
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

interface AIRequest {
  action: 'improve' | 'summarize' | 'expand' | 'translate' | 'suggest_title' | 'task_recommendations'
  content?: string
  language?: string
  targetLanguage?: string
  userId?: string
  recentNotes?: Array<{ id: string; title: string; content: string; created_at: string; updated_at: string }>
  userStats?: { level: number; points: number; streak_days: number }
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify authorization
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    // Verify user authentication
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      throw new Error('Unauthorized')
    }

    // Parse request body
    const { action, content, language = 'ja', targetLanguage = 'en', userId, recentNotes, userStats }: AIRequest = await req.json()

    if (!action) {
      throw new Error('Missing required parameters')
    }

    // Validate parameters based on action
    if (action === 'task_recommendations') {
      if (!recentNotes || !userStats) {
        throw new Error('Missing required parameters for task recommendations')
      }
    } else if (!content) {
      throw new Error('Missing content parameter')
    }

    // Check API key
    if (!GEMINI_API_KEY) {
      throw new Error('Google AI API key not configured')
    }

    // Build prompt
    const prompt = buildPrompt(action, content, language, targetLanguage, recentNotes, userStats)

    // Call Gemini API
    const geminiResponse = await fetch(
      `${GEMINI_API_URL}?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [{ text: prompt }]
          }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 2000,
            topK: 40,
            topP: 0.95,
          },
          safetySettings: [
            {
              category: 'HARM_CATEGORY_HARASSMENT',
              threshold: 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              category: 'HARM_CATEGORY_HATE_SPEECH',
              threshold: 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      }
    )

    if (!geminiResponse.ok) {
      const errorData = await geminiResponse.text()
      console.error('Gemini API error:', errorData)

      // Handle rate limit errors
      if (geminiResponse.status === 429) {
        const retryAfter = geminiResponse.headers.get('retry-after') || '60'
        const error = new Error('Rate limit exceeded')
        ;(error as any).statusCode = 429
        ;(error as any).retryAfter = retryAfter
        ;(error as any).errorType = 'RATE_LIMIT'
        throw error
      }

      throw new Error(`Gemini API error: ${geminiResponse.status}`)
    }

    const geminiData = await geminiResponse.json()

    // Extract result from Gemini response
    let result = geminiData.candidates[0]?.content?.parts[0]?.text || ''

    if (!result) {
      throw new Error('No response from Gemini API')
    }

    // Parse result based on action
    result = parseResult(result, action)

    // Estimate token usage (Gemini doesn't provide exact counts)
    const inputTokens = estimateTokens(prompt)
    const outputTokens = estimateTokens(result.toString())
    const totalTokens = inputTokens + outputTokens

    // Track AI usage in database
    const { error: insertError } = await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: action,
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      total_tokens: totalTokens,
      cost_estimate: 0, // Gemini free tier - no cost
      created_at: new Date().toISOString(),
    })

    if (insertError) {
      console.error('Error logging AI usage:', insertError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        result: result,
        action: action,
        usage: {
          prompt_tokens: inputTokens,
          completion_tokens: outputTokens,
          total_tokens: totalTokens
        },
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error in AI assistant:', error)

    const statusCode = (error as any).statusCode || 400
    const errorResponse: any = {
      success: false,
      error: error.message,
    }

    if ((error as any).errorType === 'RATE_LIMIT') {
      errorResponse.errorType = 'RATE_LIMIT'
      errorResponse.retryAfter = (error as any).retryAfter
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: statusCode,
      }
    )
  }
})

// ============================================
// Helper Functions
// ============================================

function buildPrompt(
  action: string,
  content: string | undefined,
  language: string,
  targetLanguage: string,
  recentNotes: any[] | undefined,
  userStats: any | undefined
): string {
  let prompt = ''

  switch (action) {
    case 'improve':
      prompt = `あなたは優秀な文章校正アシスタントです。以下の文章をより明確で、読みやすく、魅力的に改善してください。文法やスペルミスを修正し、より適切な表現を提案してください。

文章:
${content}

改善後の文章を出力してください（説明は不要、改善後の文章のみ）:`
      break

    case 'summarize':
      prompt = `あなたは要約の専門家です。以下の文章を簡潔に要約し、重要なポイントを抽出してください。

文章:
${content}

要約を出力してください（説明は不要、要約のみ）:`
      break

    case 'expand':
      prompt = `あなたは創造的なライティングアシスタントです。以下の短い文章やアイデアを詳細に展開し、より充実した内容にしてください。

文章:
${content}

展開後の文章を出力してください（説明は不要、展開後の文章のみ）:`
      break

    case 'translate':
      const targetLangName = targetLanguage === 'en' ? '英語' : targetLanguage === 'ja' ? '日本語' : targetLanguage
      prompt = `あなたは優秀な翻訳者です。以下の文章を${targetLangName}に正確に翻訳してください。

文章:
${content}

翻訳を出力してください（説明は不要、翻訳のみ）:`
      break

    case 'suggest_title':
      prompt = `あなたはクリエイティブなタイトル作成の専門家です。以下の文章内容から、魅力的で適切なタイトルを3つ提案してください。

文章:
${content}

タイトルを以下の形式で出力してください（各タイトルを改行で区切る）:
1. タイトル1
2. タイトル2
3. タイトル3`
      break

    case 'task_recommendations':
      const notesContent = recentNotes!.map((note, index) =>
        `メモ${index + 1}:\nタイトル: ${note.title}\n内容: ${note.content.substring(0, 500)}...\n`
      ).join('\n')

      prompt = `あなたはAI秘書です。ユーザーのメモやタスクを分析し、今日/今週/今月/今年やるべきことを提案してください。

ユーザー情報:
- レベル: ${userStats!.level}
- ポイント: ${userStats!.points}
- 連続ログイン: ${userStats!.streak_days}日

最近のメモ（${recentNotes!.length}件）:
${notesContent}

以下のJSON形式で提案を出力してください（他のテキストは含めない）:
{
  "daily": ["今日のタスク1", "今日のタスク2", "今日のタスク3"],
  "weekly": ["今週のタスク1", "今週のタスク2", "今週のタスク3"],
  "monthly": ["今月のタスク1", "今月のタスク2", "今月のタスク3"],
  "yearly": ["今年の目標1", "今年の目標2", "今年の目標3"],
  "insights": "ユーザーの活動パターンや傾向に基づくインサイト（2-3文）"
}`
      break

    default:
      throw new Error('Invalid action')
  }

  return prompt
}

function parseResult(result: string, action: string): any {
  if (action === 'task_recommendations') {
    try {
      // Remove markdown code blocks if present
      let cleaned = result.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()

      // Try to extract JSON from the response
      const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        cleaned = jsonMatch[0]
      }

      return JSON.parse(cleaned)
    } catch (e) {
      console.error('Error parsing task recommendations JSON:', e)
      console.error('Raw result:', result)
      // Return default structure
      return {
        daily: ['メモを確認する', '優先タスクを完了する', '進捗を記録する'],
        weekly: ['目標を見直す', '長期タスクに取り組む', '新しいアイデアを考える'],
        monthly: ['月次レビューを行う', '新しいスキルを学ぶ', '成果を振り返る'],
        yearly: ['年間目標を設定する', '大きな挑戦をする', '成長を実感する'],
        insights: 'メモを定期的に確認し、タスクを整理することで、生産性を向上させましょう。'
      }
    }
  }

  return result
}

function estimateTokens(text: string): number {
  // Rough estimation: 1 token ≈ 4 characters for Japanese
  // 1 token ≈ 4 characters for English
  return Math.ceil(text.length / 4)
}
```

</details>

### ステップ4: デプロイ

```bash
# Supabase Edge Functionをデプロイ
supabase functions deploy ai-assistant

# デプロイ確認
supabase functions list
```

### ステップ5: テスト

#### 5.1 ローカルテスト（オプション）

```bash
# ローカルでEdge Functionを起動
supabase functions serve ai-assistant

# 別のターミナルでテスト
curl -i --location --request POST 'http://localhost:54321/functions/v1/ai-assistant' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"action":"improve","content":"これはテストです。"}'
```

#### 5.2 本番テスト

Flutter アプリから実際にAI機能を使用してテスト:

1. **文章改善機能**
   - メモエディタで「AIで改善」をクリック
   - 応答時間を確認（1-3秒が目安）
   - エラーがないか確認

2. **要約機能**
   - 長文メモで「AIで要約」をクリック
   - 品質を確認

3. **AI秘書機能**
   - AI秘書ページにアクセス
   - タスク推奨が表示されるか確認
   - 429エラーが出ないか確認

### ステップ6: モニタリング

```sql
-- AI使用ログを確認
SELECT
  action,
  COUNT(*) as request_count,
  AVG(total_tokens) as avg_tokens,
  SUM(cost_estimate) as total_cost
FROM ai_usage_log
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY action
ORDER BY request_count DESC;

-- エラー率を確認
SELECT
  DATE(created_at) as date,
  COUNT(*) as total_requests,
  SUM(CASE WHEN error IS NOT NULL THEN 1 ELSE 0 END) as errors,
  ROUND(100.0 * SUM(CASE WHEN error IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) as error_rate
FROM edge_function_logs
WHERE function_name = 'ai-assistant'
  AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

---

## 📊 期待される効果

### パフォーマンス

| 指標 | OpenAI | Gemini | 改善 |
|:-----|-------:|-------:|:-----|
| レート制限 (RPM) | 3 | 15 | +400% |
| レート制限 (RPD) | 200 | 1,500 | +650% |
| 応答時間 | 2-5秒 | 1-3秒 | -40% |
| エラー率 | 50%+ | <1% | -98% |
| 月間コスト | $5-10 | $0 | -100% |

### ユーザー体験

- ✅ AI機能が安定して動作
- ✅ 429エラーの完全解消
- ✅ より高速な応答
- ✅ 同等以上の品質

---

## 🔧 トラブルシューティング

### エラー1: API key not configured

**症状**:
```
Error: Google AI API key not configured
```

**解決策**:
```bash
# APIキーが設定されているか確認
supabase secrets list

# 設定されていない場合
supabase secrets set GOOGLE_AI_API_KEY=your_api_key_here

# Edge Functionを再デプロイ
supabase functions deploy ai-assistant
```

### エラー2: Rate limit exceeded (429)

**症状**:
```json
{
  "success": false,
  "error": "Rate limit exceeded",
  "errorType": "RATE_LIMIT",
  "retryAfter": "60"
}
```

**原因**:
- Geminiの無料枠でも15 RPMの制限がある
- 短時間に大量のリクエストを送信した

**解決策**:
1. フロントエンドのリトライロジックが正しく動作しているか確認
2. ユーザーあたりのレート制限を実装（バックエンド）
3. 有料プランへのアップグレードを検討（60 RPM）

### エラー3: No response from Gemini API

**症状**:
```
Error: No response from Gemini API
```

**原因**:
- Geminiがコンテンツをブロック（安全性フィルター）
- APIの一時的な問題

**解決策**:
```typescript
// safetySettingsを調整（必要に応じて）
safetySettings: [
  {
    category: 'HARM_CATEGORY_HARASSMENT',
    threshold: 'BLOCK_ONLY_HIGH' // より緩い設定
  }
]
```

### エラー4: JSON parse error (task_recommendations)

**症状**:
```
Error parsing task recommendations JSON
```

**原因**:
- Geminiの応答がJSON形式でない
- マークダウンコードブロックが含まれている

**解決策**:
- `parseResult` 関数がすでにフォールバックを実装済み
- プロンプトを改善してJSON形式を明確に指示

---

## 📈 Gemini API の制限と料金

### 無料枠（Free Tier）

| 項目 | 制限 |
|:-----|:-----|
| **RPM** | 15 requests/minute |
| **RPD** | 1,500 requests/day |
| **TPM** | 1,000,000 tokens/minute |
| **料金** | **完全無料** |

### 有料プラン（Pay-as-you-go）

| 項目 | 制限/料金 |
|:-----|:----------|
| **RPM** | 60 requests/minute (デフォルト) |
| **RPD** | 無制限 |
| **TPM** | 4,000,000 tokens/minute |
| **Input料金** | $0.075/1M tokens (Gemini 1.5 Flash) |
| **Output料金** | $0.30/1M tokens (Gemini 1.5 Flash) |

### 推奨プラン

| ユーザー数 | 推奨プラン | 月間コスト |
|:----------|:----------|:----------|
| 0-100 | Free Tier | $0 |
| 100-1,000 | Free Tier | $0 |
| 1,000-10,000 | Pay-as-you-go | $5-20 |
| 10,000+ | Pay-as-you-go | $20-100 |

**注**: 10,000ユーザーでも無料枠で収まる可能性が高い（1日あたり平均1リクエスト/ユーザーの場合、1,500 RPDに収まる）

---

## 🎯 次のステップ

1. **即時**: Google AI Studio でAPIキーを取得
2. **Day 1**: Supabase に設定、Edge Function を更新
3. **Day 2**: テストとデバッグ
4. **Day 3**: 本番デプロイ
5. **Week 1**: モニタリングと最適化

---

## 📚 参考リンク

- [Google AI Studio](https://makersuite.google.com/app/apikey)
- [Gemini API ドキュメント](https://ai.google.dev/docs)
- [Gemini API 料金](https://ai.google.dev/pricing)
- [Supabase Edge Functions ガイド](https://supabase.com/docs/guides/functions)

---

**作成日**: 2025年11月8日
**最終更新**: 2025年11月8日
**ステータス**: 実装待ち
