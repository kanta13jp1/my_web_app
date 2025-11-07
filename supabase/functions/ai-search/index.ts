// AI Search Edge Function
// 自然言語検索とセマンティックサーチを提供

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SearchRequest {
  query: string
  limit?: number
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
    const { query, limit = 20 }: SearchRequest = await req.json()

    if (!query) {
      throw new Error('Query is required')
    }

    // Get OpenAI API key from environment
    const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiApiKey) {
      throw new Error('OpenAI API key not configured')
    }

    // Step 1: Generate embedding for the query
    const embeddingResponse = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify({
        model: 'text-embedding-3-small',
        input: query,
      }),
    })

    if (!embeddingResponse.ok) {
      const errorData = await embeddingResponse.text()
      console.error('OpenAI Embedding API error:', errorData)
      throw new Error(`OpenAI Embedding API error: ${embeddingResponse.status}`)
    }

    const embeddingData = await embeddingResponse.json()
    const queryEmbedding = embeddingData.data[0]?.embedding

    if (!queryEmbedding) {
      throw new Error('Failed to generate embedding')
    }

    // Step 2: Perform semantic search using pgvector (if available)
    // For now, we'll do a traditional full-text search and AI-enhanced ranking

    // Fetch user's notes
    const { data: notes, error: notesError } = await supabaseClient
      .from('notes')
      .select('id, title, content, tags, category_id, created_at, updated_at')
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .limit(100) // Fetch more notes for AI ranking

    if (notesError) {
      throw notesError
    }

    // Step 3: Use AI to rank and filter results
    const systemPrompt = `あなたは検索エキスパートです。ユーザーの検索クエリに最も関連性の高いメモを見つけてください。

検索クエリ: ${query}

以下のメモリストから、最も関連性の高いメモのIDを順番に並べてください。
関連性が低いものは除外してください。

JSON形式で回答してください:
{
  "rankedIds": ["note_id1", "note_id2", ...],
  "explanation": "ランク付けの理由"
}`

    const notesData = notes?.map(note => ({
      id: note.id,
      title: note.title,
      content: note.content?.substring(0, 500), // First 500 chars
      tags: note.tags,
    })) || []

    const userPrompt = JSON.stringify(notesData, null, 2)

    // Call OpenAI API for ranking
    const rankingResponse = await fetch('https://api.openai.com/v1/chat/completions', {
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
        temperature: 0.3,
        max_tokens: 1000,
        response_format: { type: 'json_object' },
      }),
    })

    if (!rankingResponse.ok) {
      const errorData = await rankingResponse.text()
      console.error('OpenAI Ranking API error:', errorData)
      throw new Error(`OpenAI Ranking API error: ${rankingResponse.status}`)
    }

    const rankingData = await rankingResponse.json()
    const rankingResult = JSON.parse(rankingData.choices[0]?.message?.content || '{}')
    const rankedIds = rankingResult.rankedIds || []

    // Reorder notes based on AI ranking
    const rankedNotes = rankedIds
      .map((id: string) => notes?.find(note => note.id === id))
      .filter((note: any) => note !== undefined)
      .slice(0, limit)

    // Track AI usage in database
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: 'search',
      input_tokens: (embeddingData.usage?.total_tokens || 0) + (rankingData.usage?.prompt_tokens || 0),
      output_tokens: rankingData.usage?.completion_tokens || 0,
      total_tokens: (embeddingData.usage?.total_tokens || 0) + (rankingData.usage?.total_tokens || 0),
      cost_estimate: ((embeddingData.usage?.total_tokens || 0) + (rankingData.usage?.total_tokens || 0)) * 0.00001,
      created_at: new Date().toISOString(),
    })

    return new Response(
      JSON.stringify({
        success: true,
        results: rankedNotes,
        totalResults: rankedNotes.length,
        explanation: rankingResult.explanation || '',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error in AI search:', error)
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
