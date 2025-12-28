// AI Assistant Edge Function with Google Gemini
// 14種のモデル総当たりフォールバック機能付き

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

//  14種のモデル全てを試行リストに追加
// 汎用性が高く高速なものを上位に、特殊的実験的なものを下位に配置しています
const MODELS_TO_TRY = [
  // 1. 軽量高速最新 (Flash系)
  'gemini-3-flash-preview',
  'gemini-2.5-flash-lite',
  'gemini-flash-lite-latest',
  'gemini-2.5-flash-lite-preview-09-2025',
  'gemini-2.5-flash-preview-09-2025',

  // 2. 高性能プロ版 (Pro系)
  'gemini-pro-latest',
  'gemini-3-pro-preview',
  
  // 3. 画像特化 (テキストのみの場合エラーになる可能性あり -> スキップされます)
  'gemini-2.5-flash-image',
  'gemini-2.5-flash-image-preview',
  'gemini-3-pro-image-preview',
  'nano-banana-pro-preview', // 謎のモデルも試行

  // 4. 特殊用途実験的
  'deep-research-pro-preview-12-2025',
  'gemini-2.5-computer-use-preview-10-2025',
  'gemini-robotics-er-1.5-preview'
]

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models'

interface AIRequest {
  action: 'improve' | 'summarize' | 'expand' | 'translate' | 'suggest_title' | 'task_recommendations' | 'analyze_image' | 'analyze_note_text'
  content?: string
  title?: string
  imageBase64?: string
  language?: string
  targetLanguage?: string
  userId?: string
  recentNotes?: Array<{ id: string; title: string; content: string; created_at: string; updated_at: string }>
  userStats?: { current_level: number; total_points: number; current_streak: number; longest_streak: number; notes_created: number }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing authorization header')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    const requestData: AIRequest = await req.json()
    const { action } = requestData

    if (!action) throw new Error('Missing required parameters')
    if (!GEMINI_API_KEY) throw new Error('Google AI API key not configured')

    const requestBody = buildRequestBody(requestData)

    //  総当たり実行ループ
    let finalResult = ''
    let usedModel = ''
    let success = false
    let logMessages: string[] = []

    for (const model of MODELS_TO_TRY) {
      try {
        console.log(`Trying model: ${model}...`)
        const response = await fetch(
          `${BASE_URL}/${model}:generateContent?key=${GEMINI_API_KEY}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(requestBody),
          }
        )

        if (response.ok) {
          const data = await response.json()
          const text = data.candidates?.[0]?.content?.parts?.[0]?.text
          if (text) {
            finalResult = text
            usedModel = model
            success = true
            console.log(` Success with ${model}`)
            break; // 成功！ループを抜ける
          }
        } else {
          // エラー時
          const errorText = await response.text()
          const status = response.status
          logMessages.push(`${model}: ${status}`)
          console.warn(` Model ${model} failed (${status})`)
          
          // APIへの負荷を考慮し、少しだけ待機して次へ
          await new Promise(r => setTimeout(r, 300))
        }
      } catch (e) {
        console.error(`Error with model ${model}:`, e)
        logMessages.push(`${model}: Exception`)
      }
    }

    if (!success) {
      throw new Error(`All 14 models failed. Logs: ${logMessages.join(', ')}`)
    }

    // 結果の整形
    finalResult = parseResult(finalResult, action)

    // ログ保存 (実際に成功したモデル名を記録)
    const inputLength = JSON.stringify(requestBody).length
    const outputLength = finalResult.length
    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: action,
      input_tokens: Math.ceil(inputLength / 4),
      output_tokens: Math.ceil(outputLength / 4),
      total_tokens: Math.ceil((inputLength + outputLength) / 4),
      cost_estimate: 0,
      note: `Model: ${usedModel}` // 成功したモデル名
    })

    return new Response(
      JSON.stringify({ success: true, result: finalResult, used_model: usedModel }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('AI Service Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

function buildRequestBody(data: AIRequest): any {
  const { action, content, title, imageBase64, language, targetLanguage, recentNotes, userStats } = data
  
  let body: any = {
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 2000,
    },
    contents: []
  }

  if (action === 'analyze_image') {
      const promptText = `
        あなたは「断捨離の鬼コーチ」です。ユーザーがアップロードした写真の物体を見て、以下のフォーマットで回答してください。
        口調は少し厳しめで、ユーモアを交えて「捨てるべき理由」を力説してください。

        【物体名】
        （ここに物体名）

        【断捨離判定】
        （「即捨て推奨」または「保留」）

        【鬼コーチの助言】
        （なぜこれを捨てるべきか、過去の執着を断ち切るような短いアドバイス）

        【捨て方ヒント】
        （一般的に何ゴミになるか、どう処分すべきか）
      `;
      body.contents = [{
        parts: [
          { text: promptText },
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
        ]
      }];
  } else if (action === 'analyze_note_text') {
      const promptText = `
        あなたは「デジタルの断捨離鬼コーチ」です。
        ユーザーがため込んだ以下のメモを見て、今後この情報が必要か否かを厳しく判定してください。
        【メモタイトル】: ${title || '(なし)'}
        【メモ内容】: ${content || '(なし)'}
        以下のフォーマットで回答せよ。
        【判定】（「即アーカイブ推奨」または「保留」）
        【鬼コーチの理由】（なぜこの情報が不要か、デジタルゴミになっている理由を痛烈に指摘）
        【助言】（デジタル情報を整理するための短い一言）
      `;
      body.contents = [{ parts: [{ text: promptText }] }];
  } else {
      let prompt = ''
      switch (action) {
        case 'improve': prompt = `文章校正:\n${content}`; break;
        case 'summarize': prompt = `要約:\n${content}`; break;
        case 'expand': prompt = `アイデア展開:\n${content}`; break;
        case 'translate': prompt = `${targetLanguage}へ翻訳:\n${content}`; break;
        case 'suggest_title': prompt = `タイトル案3つ:\n${content}`; break;
        case 'task_recommendations':
          const notesContent = recentNotes!.map((note: any, i: number) => `メモ${i+1}: ${note.title}`).join('\n');
          prompt = `戦略参謀として、以下のユーザー状況に基づきJSONで助言せよ。\nレベル:${userStats.current_level}\nメモ:\n${notesContent}\n出力キー:daily,weekly,monthly,yearly,insights`;
          body.generationConfig.responseMimeType = 'application/json';
          break;
      }
      body.contents = [{ parts: [{ text: prompt }] }];
  }
  return body
}

function parseResult(result: string, action: string): any {
  if (action === 'task_recommendations') {
    try {
      let cleaned = result.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
      const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
      return JSON.parse(jsonMatch ? jsonMatch[0] : cleaned)
    } catch (e) {
      return { daily: ['Error parsing'], insights: '解析エラーが発生しましたが、行動あるのみです。' }
    }
  }
  return result
}
