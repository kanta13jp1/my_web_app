// AI Assistant Edge Function
// メモ作成支援、文章改善、要約生成などのAI機能を提供

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AIRequest {
  action: 'improve' | 'summarize' | 'expand' | 'translate' | 'suggest_title'
  content: string
  language?: string
  targetLanguage?: string
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
    const { action, content, language = 'ja', targetLanguage = 'en' }: AIRequest = await req.json()

    if (!action || !content) {
      throw new Error('Missing required parameters')
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
      throw new Error(`OpenAI API error: ${openaiResponse.status}`)
    }

    const openaiData = await openaiResponse.json()
    const result = openaiData.choices[0]?.message?.content || ''

    // Track AI usage in database
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: action,
      input_tokens: openaiData.usage?.prompt_tokens || 0,
      output_tokens: openaiData.usage?.completion_tokens || 0,
      total_tokens: openaiData.usage?.total_tokens || 0,
      cost_estimate: (openaiData.usage?.total_tokens || 0) * 0.00001, // Rough estimate
      created_at: new Date().toISOString(),
    })

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
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
