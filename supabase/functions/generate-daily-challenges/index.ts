// 1行目の serve インポートは削除します
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// OpenAI APIキーの設定が必要です
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')

// serve(...) ではなく Deno.serve(...) を使用します
Deno.serve(async (req) => {
  try {
    // 1. Supabaseクライアントの作成
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. リクエストから日付を取得
    const { date } = await req.json()
    const targetDate = date || new Date().toISOString().split('T')[0]

    console.log(`Generating challenges for: ${targetDate}`)

    // 3. AIへのプロンプト作成
    const prompt = `
    あなたはゲーミフィケーションメモアプリのAIゲームマスターです。
    日付「${targetDate}」のためのデイリーチャレンジを3つ生成してください。
    
    出力は以下のJSONフォーマットのみにしてください:
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

    // 4. OpenAI API呼び出し
    const aiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini', 
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.7,
      }),
    })

    const aiData = await aiResponse.json()
    
    if (!aiData.choices) {
      throw new Error('Failed to generate challenges from OpenAI')
    }

    const content = aiData.choices[0].message.content
    
    // JSONのパース
    const cleanJson = content.replace(/```json/g, '').replace(/```/g, '').trim()
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
      JSON.stringify({ success: true, message: `Created ${insertData.length} challenges for ${targetDate}` }),
      { headers: { "Content-Type": "application/json" } },
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    )
  }
})