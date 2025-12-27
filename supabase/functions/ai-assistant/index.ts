// AI Assistant Edge Function with Google Gemini
// リトライ機能付き (Rate Limit対策) & モデル名修正版 (v2.0)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Gemini API設定
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
// 修正: 現在有効なモデルID (gemini-2.0-flash) を指定
const GEMINI_MODEL = 'gemini-2.0-flash'
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

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

    const { action, content, title, imageBase64, language = 'ja', targetLanguage = 'en', userId, recentNotes, userStats }: AIRequest = await req.json()

    if (!action) throw new Error('Missing required parameters')
    if (!GEMINI_API_KEY) throw new Error('Google AI API key not configured')

    let requestBody: any = {
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 2000,
      }
    };

    // プロンプト構築
    if (action === 'analyze_image') {
      if (!imageBase64) throw new Error('Image data missing')
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
      requestBody.contents = [{
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
      requestBody.contents = [{ parts: [{ text: promptText }] }];
    } else {
      const prompt = buildPrompt(action, content, language, targetLanguage, recentNotes, userStats)
      requestBody.contents = [{ parts: [{ text: prompt }] }];
      if (action === 'task_recommendations') requestBody.generationConfig.responseMimeType = 'application/json';
    }

    //  リトライロジック (最大3回試行)
    let geminiResponse;
    let attempt = 0;
    const maxRetries = 3;
    let lastErrorDetails = '';

    while (attempt < maxRetries) {
      try {
        console.log(`Calling Gemini API (Attempt ${attempt + 1}/${maxRetries}) Model: ${GEMINI_MODEL}...`);
        geminiResponse = await fetch(
          `${GEMINI_API_URL}?key=${GEMINI_API_KEY}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(requestBody),
          }
        );

        // 成功、または429(Rate Limit)以外のエラーならループを抜ける
        if (geminiResponse.ok) break;

        // 404 (Not Found) の場合はモデル名ミスの可能性が高いため、即座にエラーとして終了（リトライしても無駄なので）
        if (geminiResponse.status === 404) {
           lastErrorDetails = await geminiResponse.text();
           throw new Error(`Model not found (404): ${lastErrorDetails}. Check if ${GEMINI_MODEL} is valid.`);
        }

        if (geminiResponse.status !== 429) {
           lastErrorDetails = await geminiResponse.text();
           break; 
        }

        // 429エラーの場合のみリトライ
        console.warn(`Rate limit exceeded. Retrying in ${(attempt + 1) * 2} seconds...`);
        await new Promise(resolve => setTimeout(resolve, 2000 * (attempt + 1))); // 2秒, 4秒...と待機
        attempt++;

      } catch (e) {
        console.error("Network or Model error during fetch:", e);
        if (e.message.includes('Model not found')) throw e;
        attempt++;
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }

    if (!geminiResponse || !geminiResponse.ok) {
       if (geminiResponse?.status === 429) {
          throw new Error('Rate limit exceeded (Busy). Please try again in a minute.');
       }
       throw new Error(`Gemini API error: ${geminiResponse?.status} - ${lastErrorDetails}`);
    }

    const geminiData = await geminiResponse.json()
    let result = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || ''
    if (!result) throw new Error('No valid response text from Gemini API')

    result = parseResult(result, action)

    // Token計算とログ保存
    let inputTokenSource = typeof requestBody.contents[0].parts[0].text === 'string' ? requestBody.contents[0].parts[0].text : JSON.stringify(requestBody.contents);
    const inputTokens = Math.ceil(inputTokenSource.length / 4)
    const outputTokens = Math.ceil((typeof result === 'string' ? result : JSON.stringify(result)).length / 4)

    await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: action,
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      total_tokens: inputTokens + outputTokens,
      cost_estimate: 0,
    })

    return new Response(
      JSON.stringify({ success: true, result: result, action: action }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Error in AI assistant:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

// Helper Functions
function buildPrompt(action: string, content: string | undefined, language: string, targetLanguage: string, recentNotes: any[] | undefined, userStats: any | undefined): string {
  let prompt = ''
  switch (action) {
    case 'improve': prompt = `文章校正:\n${content}`; break;
    case 'summarize': prompt = `要約:\n${content}`; break;
    case 'expand': prompt = `アイデア展開:\n${content}`; break;
    case 'translate': prompt = `${targetLanguage}へ翻訳:\n${content}`; break;
    case 'suggest_title': prompt = `タイトル案3つ:\n${content}`; break;
    case 'task_recommendations':
      const notesContent = recentNotes!.map((note, i) => `メモ${i+1}: ${note.title}`).join('\n');
      prompt = `戦略参謀として、以下のユーザー状況に基づきJSONで助言せよ。\nレベル:${userStats.current_level}\nメモ:\n${notesContent}\n出力キー:daily,weekly,monthly,yearly,insights`;
      break;
    default: throw new Error('Invalid action')
  }
  return prompt
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
