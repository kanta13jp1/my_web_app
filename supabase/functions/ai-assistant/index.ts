// AI Assistant Edge Function with Google Gemini
// メモ作成支援、文章改善、要約生成、および画像テキスト断捨離判定機能を提供

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Gemini API設定
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
// ユーザー指定のモデルを使用
const GEMINI_MODEL = 'gemini-flash-latest'
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

interface AIRequest {
  action: 'improve' | 'summarize' | 'expand' | 'translate' | 'suggest_title' | 'task_recommendations' | 'analyze_image' | 'analyze_note_text'
  content?: string
  title?: string // メモ判定用に追加
  imageBase64?: string
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
    const { action, content, title, imageBase64, language = 'ja', targetLanguage = 'en', userId, recentNotes, userStats }: AIRequest = await req.json()

    if (!action) {
      throw new Error('Missing required parameters')
    }

    // Check API key
    if (!GEMINI_API_KEY) {
      throw new Error('Google AI API key not configured')
    }

    // リクエストボディの構築
    let requestBody: any = {
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 2000,
      }
    };

    // ============================================
    // アクションに応じた処理分岐
    // ============================================

    // --- 画像認識（リアル断捨離）モード ---
    if (action === 'analyze_image') {
      if (!imageBase64) {
        throw new Error('Image data missing for analyze_image action')
      }

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
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: imageBase64
            }
          }
        ]
      }];

    // --- テキストメモ判定（デジタル断捨離）モード ---
    } else if (action === 'analyze_note_text') {
      if (!content && !title) {
        throw new Error('Note content or title missing for analyze_note_text action')
      }

      const promptText = `
        あなたは「デジタルの断捨離鬼コーチ」です。
        ユーザーがため込んだ以下のメモを見て、今後この情報が必要か否かを厳しく判定してください。
        口調は厳しめで、情報が古いか、行動に繋がっていないか、ただの執着かを指摘してください。

        【メモタイトル】: ${title || '(なし)'}
        【メモ内容】: ${content || '(なし)'}

        以下のフォーマットで回答せよ。

        【判定】
        （「即アーカイブ推奨」または「保留」）

        【鬼コーチの理由】
        （なぜこの情報が不要か、デジタルゴミになっている理由を痛烈に指摘）

        【助言】
        （デジタル情報を整理するための短い一言）
      `;
      
      requestBody.contents = [{
        parts: [{ text: promptText }]
      }];

    // --- その他のテキスト処理モード ---
    } else {
      if (action === 'task_recommendations' && (!recentNotes || !userStats)) {
        throw new Error('Missing required parameters for task recommendations')
      } else if (action !== 'task_recommendations' && !content) {
        throw new Error('Missing content parameter')
      }

      const prompt = buildPrompt(action, content, language, targetLanguage, recentNotes, userStats)
      
      requestBody.contents = [{
        parts: [{ text: prompt }]
      }];

      // JSONレスポンスが必要な場合の設定
      if (action === 'task_recommendations') {
        requestBody.generationConfig.responseMimeType = 'application/json';
      }
    }

    // Call Gemini API
    console.log(`Calling Gemini API (${GEMINI_MODEL}) for action: ${action}...`)

    const geminiResponse = await fetch(
      `${GEMINI_API_URL}?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      }
    )

    if (!geminiResponse.ok) {
      const errorData = await geminiResponse.text()
      console.error('Gemini API error details:', errorData)

      if (geminiResponse.status === 429) {
        throw new Error('Rate limit exceeded')
      }
      throw new Error(`Gemini API error: ${geminiResponse.status} - ${errorData}`)
    }

    const geminiData = await geminiResponse.json()

    // Extract result
    let result = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || ''

    if (!result) {
      console.error('Unexpected Gemini response:', JSON.stringify(geminiData))
      throw new Error('No valid response text from Gemini API')
    }

    // Parse result based on action (JSON parsing if needed)
    result = parseResult(result, action)

    // Estimate token usage (簡易計算: 画像は計算に含まない)
    let inputTokenSource = typeof requestBody.contents[0].parts[0].text === 'string' ? requestBody.contents[0].parts[0].text : JSON.stringify(requestBody.contents);
    const inputTokens = estimateTokens(inputTokenSource)
    const outputTokens = estimateTokens(typeof result === 'string' ? result : JSON.stringify(result))
    const totalTokens = inputTokens + outputTokens

    // Track AI usage in database
    const { error: insertError } = await supabaseClient.from('ai_usage_log').insert({
      user_id: user.id,
      action: action,
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      total_tokens: totalTokens,
      cost_estimate: 0,
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

      prompt = `あなたは単なるスケジュール管理を行う秘書ではありません。
ユーザーの人生と事業を劇的に成長させる、冷徹かつ情熱的な**「戦略参謀（Strategic Advisor）」**です。

以下の【コンテキスト】を分析し、ユーザーに対して【戦略的提言】を行ってください。

【ユーザーのコンテキスト】
- 現在のレベル: ${userStats!.current_level}
- 最近の活動状況: ${userStats!.current_streak}日連続ログイン
- 作成したメモ（直近の思考ログ）:
${notesContent}

【思考プロセス】
1. **現状分析**: ユーザーのメモから、現在「何に逃げているか（安易な作業やインプットに没頭していないか）」を見抜いてください。
2. **ボトルネック特定**: ユーザーの目標達成を阻害している「真のボトルネック」を特定してください。
3. **ハイレバレッジな行動の抽出**: ユーザーが少し恐怖を感じるかもしれないが、実行すれば最もリターンが大きい（ハイレバレッジな）行動を**たった1つ**見つけ出してください。

【出力フォーマット (JSON)】
以下のJSON形式のみを出力してください。余計なマークダウン( \`\`\`json 等)や説明は不要です。

{
  "daily": ["今日やるべきたった1つのクレイジーな行動 (例: 未完成のままアプリを友人に送り、辛辣な感想をもらう)"],
  "weekly": ["今週の戦略的フォーカス (例: 機能追加を全停止し、営業活動に100%リソースを割く)"],
  "monthly": ["今月のマイルストーン (恐怖を克服した先にある成果)"],
  "yearly": ["今年のビジョン (現状の延長線上にはない飛躍的な目標)"],
  "insights": "戦略参謀からのメッセージ (150文字程度)。ユーザーに媚びず、本質を突く厳しいが愛のある言葉で、なぜ上記の『クレイジーな行動』が必要なのかを説いてください。"
}

注意:
- ToDoリストは出力しないでください。
- 「daily」は要素を**1つだけ**に絞り込んでください。`
      break

    default:
      throw new Error('Invalid action')
  }

  return prompt
}

function parseResult(result: string, action: string): any {
  if (action === 'task_recommendations') {
    try {
      let cleaned = result.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
      const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        cleaned = jsonMatch[0]
      }
      return JSON.parse(cleaned)
    } catch (e) {
      console.error('Error parsing JSON:', e)
      return {
        daily: ['戦略を見直す時間を確保する'],
        weekly: ['ボトルネックを特定する'],
        monthly: ['コンフォートゾーンから抜け出す'],
        yearly: ['圧倒的な成果を定義する'],
        insights: '申し訳ありません。解析に失敗しましたが、立ち止まって考えることこそが重要です。'
      }
    }
  }
  return result
}

function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4)
}
