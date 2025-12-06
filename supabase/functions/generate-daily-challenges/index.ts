import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// CORSヘッダー
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Gemini API設定
const GEMINI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')
const GEMINI_MODEL = 'gemini-1.5-flash' // 高速でコスト効率の良いモデル
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

Deno.serve(async (req) => {
    // 1. CORS Preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const { date } = await req.json()
        const targetDate = date || new Date().toISOString().split('T')[0]

        console.log(`Generating challenges for: ${targetDate} using Gemini`)

        if (!GEMINI_API_KEY) {
            throw new Error('GOOGLE_AI_API_KEY is not set')
        }

        const prompt = `
    あなたはゲーミフィケーションメモアプリのAIゲームマスターです。
    日付「${targetDate}」のためのデイリーチャレンジを3つ生成してください。
    
    以下のJSONフォーマットの配列のみを出力してください（Markdownのコードブロックは不要です）:
    [
      {
        "challenge_title": "タイトル (20文字以内)",
        "challenge_description": "説明 (60文字以内)",
        "challenge_type": "create_notes" または "share_notes",
        "target_value": 数値 (例: 1, 3, 100),
        "reward_points": 数値 (例: 30, 50, 100)
      }
    ]
    
    条件:
    1. 初心者でも達成可能な難易度にすること。
    2. 3つの内訳は「create_notes(メモ作成)」と「share_notes(シェア)」を混ぜること。
    3. JSON以外の文字列は含めないでください。
    `

        // 4. Gemini API呼び出し
        const geminiResponse = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
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
                    // JSONモードを強制（Gemini 1.5以降で有効）
                    responseMimeType: "application/json"
                }
            }),
        })

        if (!geminiResponse.ok) {
            const errorText = await geminiResponse.text()
            throw new Error(`Gemini API Error: ${geminiResponse.status} ${errorText}`)
        }

        const geminiData = await geminiResponse.json()

        // レスポンスの抽出
        const contentText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text

        if (!contentText) {
            throw new Error('Failed to generate challenges from Gemini')
        }

        // JSONパース (Markdown記法が含まれている場合に備えてクリーニング)
        const cleanJson = contentText.replace(/```json/g, '').replace(/```/g, '').trim()
        const challenges = JSON.parse(cleanJson)

        // 5. DBへの保存データの整形
        const insertData = challenges.map((item: any) => ({
            challenge_date: targetDate,
            challenge_type: item.challenge_type,
            challenge_title: item.challenge_title,
            challenge_description: item.challenge_description,
            target_value: item.target_value,
            reward_points: item.reward_points,
            is_active: true
        }))

        // 6. DBへ保存
        const { error } = await supabaseClient
            .from('daily_challenges')
            .upsert(insertData, { onConflict: 'challenge_date, challenge_type, target_value' })

        if (error) throw error

        return new Response(
            JSON.stringify({ success: true, message: `Created ${insertData.length} challenges for ${targetDate} via Gemini` }),
            {
                headers: { ...corsHeaders, "Content-Type": "application/json" }
            },
        )

    } catch (error) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                status: 500,
                headers: { ...corsHeaders, "Content-Type": "application/json" }
            },
        )
    }
})