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
const GEMINI_MODEL = 'gemini-2.0-flash' // 最新の高速・無料モデル (2024年12月リリース)
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

interface AIRequest {
  action: 'improve' | 'summarize' | 'expand' | 'translate' | 'suggest_title' | 'task_recommendations'
  content?: string
  language?: string
  targetLanguage?: string
  userId?: string
  recentNotes?: Array<{ id: string; title: string; content: string; created_at: string; updated_at: string }>
  userStats?: { current_level: number; total_points: number; current_streak: number; longest_streak: number; notes_created: number }
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
- レベル: ${userStats!.current_level}
- ポイント: ${userStats!.total_points}
- 連続ログイン: ${userStats!.current_streak}日
- 作成したメモ数: ${userStats!.notes_created}

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
