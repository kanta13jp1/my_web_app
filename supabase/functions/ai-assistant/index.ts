// AI Assistant Edge Function
// メモ作成支援、文章改善、要約生成などのAI機能を提供

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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

    // Get OpenAI API key from environment
    const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiApiKey) {
      throw new Error('OpenAI API key not configured')
    }

    // Prepare prompt based on action
    let systemPrompt = ''
    let userPrompt = ''

    switch (action) {
      case 'improve':
        systemPrompt = 'あなたは優秀な文章校正アシスタントです。ユーザーの文章をより明確で、読みやすく、魅力的に改善してください。文法やスペルミスを修正し、より適切な表現を提案してください。'
        userPrompt = `以下の文章を改善してください:\n\n${content}`
        break

      case 'summarize':
        systemPrompt = 'あなたは要約の専門家です。ユーザーの長い文章を簡潔に要約し、重要なポイントを抽出してください。'
        userPrompt = `以下の文章を簡潔に要約してください:\n\n${content}`
        break

      case 'expand':
        systemPrompt = 'あなたは創造的なライティングアシスタントです。ユーザーの短い文章やアイデアを詳細に展開し、より充実した内容にしてください。'
        userPrompt = `以下の文章を詳しく展開してください:\n\n${content}`
        break

      case 'translate':
        systemPrompt = `あなたは優秀な翻訳者です。ユーザーの文章を${targetLanguage === 'en' ? '英語' : targetLanguage === 'ja' ? '日本語' : targetLanguage}に正確に翻訳してください。`
        userPrompt = `以下の文章を${targetLanguage === 'en' ? '英語' : targetLanguage === 'ja' ? '日本語' : targetLanguage}に翻訳してください:\n\n${content}`
        break

      case 'suggest_title':
        systemPrompt = 'あなたはクリエイティブなタイトル作成の専門家です。ユーザーの文章内容から、魅力的で適切なタイトルを3つ提案してください。'
        userPrompt = `以下の文章に最適なタイトルを3つ提案してください:\n\n${content}`
        break

      case 'task_recommendations':
        systemPrompt = `あなたはAI秘書です。ユーザーのメモやタスクを分析し、今日/今週/今月/今年やるべきことを提案してください。

        提案は以下の形式で返してください（JSON形式）：
        {
          "daily": ["今日のタスク1", "今日のタスク2", "今日のタスク3"],
          "weekly": ["今週のタスク1", "今週のタスク2", "今週のタスク3"],
          "monthly": ["今月のタスク1", "今月のタスク2", "今月のタスク3"],
          "yearly": ["今年の目標1", "今年の目標2", "今年の目標3"],
          "insights": "ユーザーの活動パターンや傾向に基づくインサイト（2-3文）"
        }

        重要：
        - 各期間ごとに3-5個のタスクを提案してください
        - ユーザーのメモ内容と目標に基づいて、具体的で実行可能なタスクを提案してください
        - insightsには、ユーザーの習慣や傾向、改善提案を含めてください
        - 必ずJSON形式で返してください（他のテキストは含めない）`

        const notesContent = recentNotes!.map((note, index) =>
          `メモ${index + 1}:\nタイトル: ${note.title}\n内容: ${note.content.substring(0, 500)}...\n`
        ).join('\n')

        userPrompt = `以下はユーザーの情報です：

【ユーザー統計】
- レベル: ${userStats!.level}
- ポイント: ${userStats!.points}
- 連続ログイン: ${userStats!.streak_days}日

【最近のメモ（${recentNotes!.length}件）】
${notesContent}

上記の情報を分析して、今日/今週/今月/今年やるべきことを提案してください。`
        break

      default:
        throw new Error('Invalid action')
    }

    // Call OpenAI API
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini', // Using the faster and cheaper model
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.7,
        max_tokens: 2000,
      }),
    })

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.text()
      console.error('OpenAI API error:', errorData)

      // Handle rate limit errors specifically
      if (openaiResponse.status === 429) {
        const retryAfter = openaiResponse.headers.get('retry-after') || '60'
        const error = new Error('Rate limit exceeded')
        ;(error as any).statusCode = 429
        ;(error as any).retryAfter = retryAfter
        ;(error as any).errorType = 'RATE_LIMIT'
        throw error
      }

      throw new Error(`OpenAI API error: ${openaiResponse.status}`)
    }

    const openaiData = await openaiResponse.json()
    let result = openaiData.choices[0]?.message?.content || ''

    // For task_recommendations, parse JSON result
    if (action === 'task_recommendations') {
      try {
        // Remove markdown code blocks if present
        result = result.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
        const parsedResult = JSON.parse(result)
        result = parsedResult
      } catch (e) {
        console.error('Error parsing task recommendations JSON:', e)
        // Return a default structure if parsing fails
        result = {
          daily: ['メモを確認する', '優先タスクを完了する', '進捗を記録する'],
          weekly: ['目標を見直す', '長期タスクに取り組む', '新しいアイデアを考える'],
          monthly: ['月次レビューを行う', '新しいスキルを学ぶ', '成果を振り返る'],
          yearly: ['年間目標を設定する', '大きな挑戦をする', '成長を実感する'],
          insights: 'メモを定期的に確認し、タスクを整理することで、生産性を向上させましょう。'
        }
      }
    }

    // Track AI usage in database
    const { error: insertError } = await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: action,
      input_tokens: openaiData.usage?.prompt_tokens || 0,
      output_tokens: openaiData.usage?.completion_tokens || 0,
      total_tokens: openaiData.usage?.total_tokens || 0,
      cost_estimate: (openaiData.usage?.total_tokens || 0) * 0.00001, // Rough estimate
      created_at: new Date().toISOString(),
    })

    // Log error but don't fail the request if usage tracking fails
    if (insertError) {
      console.error('Error logging AI usage:', insertError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        result: result,
        action: action,
        usage: openaiData.usage,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error in AI assistant:', error)

    // Return appropriate status code and details based on error type
    const statusCode = (error as any).statusCode || 400
    const errorResponse: any = {
      success: false,
      error: error.message,
    }

    // Add additional details for rate limit errors
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
