// AI Assistant Edge Function with Google Gemini
// メモ作成支援、文章改善、要約生成などのAI機能を提供

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Gemini API設定
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') // 環境変数名をGEMINI_API_KEYに統一
const GEMINI_MODEL = 'gemini-1.5-flash' // モデル名を正確なIDに変更 (gemini-flash-latest等はエイリアス)
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
            temperature: 0.7, // 少し創造性を高める
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
    const outputTokens = estimateTokens(JSON.stringify(result)) // resultがオブジェクトの場合に対応
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
        `メモ${index + 1} (更新: ${note.updated_at}):\nタイトル: ${note.title}\n内容: ${note.content.substring(0, 500)}...\n`
      ).join('\n')

      // 🔥 溝口勇児氏視点の戦略参謀プロンプトに更新
      prompt = `あなたは単なるスケジュール管理を行う秘書ではありません。
ユーザーの人生と事業を劇的に成長させる、冷徹かつ情熱的な**「戦略参謀（Strategic Advisor）」**です。

以下の【コンテキスト】を分析し、ユーザーに対して【戦略的提言】を行ってください。

【ユーザーのコンテキスト】
- 現在のレベル: ${userStats!.current_level} (成長度合い)
- 最近の活動状況: ${userStats!.current_streak}日連続ログイン
- 作成したメモ（直近の思考ログ）:
${notesContent}

【思考プロセス】
1. **現状分析**: ユーザーのメモから、現在「何に逃げているか（安易な作業やインプットに没頭していないか）」を見抜いてください。
2. **ボトルネック特定**: ユーザーの目標達成（レベルアップや事業成長）を阻害している「真のボトルネック」を特定してください。表面的なタスクではなく、心理的な恐怖（失敗への恐れ、批判への恐れ）を探り当ててください。
3. **ハイレバレッジな行動の抽出**: ユーザーが少し恐怖を感じるかもしれないが、実行すれば最もリターンが大きい（ハイレバレッジな）行動を**たった1つ**見つけ出してください。

【出力フォーマット (JSON)】
以下のJSON形式のみを出力してください。余計なマークダウンや説明は不要です。

{
  "daily": ["今日やるべき・たった1つのクレイジーな行動 (例: 未完成のままアプリを友人に送り、辛辣な感想をもらう)"],
  "weekly": ["今週の戦略的フォーカス (例: 機能追加を全停止し、営業活動に100%リソースを割く)"],
  "monthly": ["今月のマイルストーン (恐怖を克服した先にある成果)"],
  "yearly": ["今年のビジョン (現状の延長線上にはない飛躍的な目標)"],
  "insights": "戦略参謀からのメッセージ (150文字程度)。ユーザーに媚びず、本質を突く厳しいが愛のある言葉で、なぜ上記の『クレイジーな行動』が必要なのかを説いてください。「その作業は、本当にあなたの人生を変えますか？」と問いかけてください。"
}

注意:
- ToDoリスト（牛乳を買う、メールを返す等）は絶対に出力しないでください。
- 「daily」は配列ですが、要素は**1つだけ**に絞り込んでください。選択と集中を促すためです。
- 言葉遣いは丁寧ですが、内容は妥協のないプロフェッショナルなトーンでお願いします。`
      break

    default:
      throw new Error('Invalid action')
  }

  return prompt
}

function parseResult(result: string, action: string): any {
  if (action === 'task_recommendations') {
    try {
      // Remove markdown code blocks if present (JSONのパースエラー防止)
      let cleaned = result.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()

      // Try to extract JSON from the response
      const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        cleaned = jsonMatch[0]
      }

      const parsed = JSON.parse(cleaned)
      
      // dailyが空の場合のフォールバック
      if (!parsed.daily || parsed.daily.length === 0) {
        parsed.daily = ['まずは1つ、恐怖を感じる行動を選んで実行してください']
      }
      
      return parsed
    } catch (e) {
      console.error('Error parsing task recommendations JSON:', e)
      console.error('Raw result:', result)
      // Return fallback structure with Strategic Advisor tone
      return {
        daily: ['戦略を見直す時間を確保する'],
        weekly: ['ボトルネックを特定する'],
        monthly: ['コンフォートゾーンから抜け出す'],
        yearly: ['圧倒的な成果を定義する'],
        insights: '申し訳ありません。現在、戦略的分析データが不足しています。しかし、立ち止まって考えることこそが重要です。目の前の作業が本当に未来を変えるのか、自問自答してください。'
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