// AI Tag Suggestion Edge Function
// メモの内容から自動的にタグとカテゴリを提案

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SuggestRequest {
  content: string
  title?: string
  existingCategories?: string[]
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
    const { content, title = '', existingCategories = [] }: SuggestRequest = await req.json()

    if (!content) {
      throw new Error('Content is required')
    }

    // Get OpenAI API key from environment
    const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiApiKey) {
      throw new Error('OpenAI API key not configured')
    }

    // Fetch user's existing categories from database
    const { data: userCategories } = await supabaseClient
      .from('categories')
      .select('name')
      .eq('user_id', user.id)

    const existingCategoryNames = userCategories?.map(c => c.name) || []
    const allExistingCategories = [...new Set([...existingCategoryNames, ...existingCategories])]

    // Prepare prompt
    const systemPrompt = `あなたはメモやノートの整理の専門家です。ユーザーのメモ内容を分析し、適切なタグとカテゴリを提案してください。

既存のカテゴリ: ${allExistingCategories.length > 0 ? allExistingCategories.join(', ') : 'なし'}

以下のJSON形式で回答してください:
{
  "suggestedTags": ["タグ1", "タグ2", "タグ3"],
  "suggestedCategory": "カテゴリ名",
  "reason": "提案理由"
}

注意:
- タグは3〜5個程度提案してください
- 既存のカテゴリがある場合は、可能な限りそれを使用してください
- 新しいカテゴリを提案する場合は、簡潔でわかりやすい名前にしてください
- 日本語で回答してください`

    const userPrompt = `タイトル: ${title}\n\n内容:\n${content}`

    // Call OpenAI API
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.5,
        max_tokens: 500,
        response_format: { type: 'json_object' },
      }),
    })

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.text()
      console.error('OpenAI API error:', errorData)
      throw new Error(`OpenAI API error: ${openaiResponse.status}`)
    }

    const openaiData = await openaiResponse.json()
    const resultText = openaiData.choices[0]?.message?.content || '{}'
    const result = JSON.parse(resultText)

    // Track AI usage in database
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: 'suggest_tags',
      input_tokens: openaiData.usage?.prompt_tokens || 0,
      output_tokens: openaiData.usage?.completion_tokens || 0,
      total_tokens: openaiData.usage?.total_tokens || 0,
      cost_estimate: (openaiData.usage?.total_tokens || 0) * 0.00001,
      created_at: new Date().toISOString(),
    })

    return new Response(
      JSON.stringify({
        success: true,
        suggestions: {
          tags: result.suggestedTags || [],
          category: result.suggestedCategory || '',
          reason: result.reason || '',
        },
        usage: openaiData.usage,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error in AI tag suggestion:', error)
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
