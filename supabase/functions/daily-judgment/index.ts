// Daily Judgment Edge Function
// 毎晩実行され、アウトプットがないユーザーのストリークをリセットし、ペナルティを与え、監視役に通報する

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') // メール送信サービスのAPIキー（設定推奨）

interface UserProfile {
    display_name: string | null
    trust_score: number | null
}

interface StagnantUser {
    user_id: string
    current_streak: number
    last_output_at: string | null
    user_profiles: UserProfile[] | UserProfile | null
}

interface SendAlertEmailParams {
    apiKey: string
    to: string
    supporterName?: string | null
    userName: string
    newTrustScore: number
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseAdmin = createClient(
            SUPABASE_URL,
            SUPABASE_SERVICE_ROLE_KEY,
            {
                auth: {
                    autoRefreshToken: false,
                    persistSession: false,
                },
            }
        )

        // 1. 24時間以上アウトプットがないユーザーを抽出
        // ユーザー名を取得するために user_profiles を結合（外部キー設定が必要）
        // 設定がない場合はループ内で個別取得も可能ですが、ここでは効率のため結合を試みます
        const thresholdDate = new Date()
        thresholdDate.setHours(thresholdDate.getHours() - 24)

        const { data: stagnantUsers, error: fetchError } = await supabaseAdmin
            .from('user_stats')
            .select(`
                user_id, 
                current_streak, 
                last_output_at,
                user_profiles:user_id ( display_name, trust_score )
            `)
            .gt('current_streak', 0)
            .lt('last_output_at', thresholdDate.toISOString())

        if (fetchError) throw fetchError

        console.log(`Found ${stagnantUsers?.length ?? 0} stagnant users.`)

        const results = []

        // 2. ペナルティ＆通報執行ループ
        for (const user of (stagnantUsers as StagnantUser[] | null) || []) {
            const userId = user.user_id
            const profile = Array.isArray(user.user_profiles) ? user.user_profiles[0] : user.user_profiles
            const userName = profile?.display_name ?? 'Unknown user'
            const currentTrustScore = profile?.trust_score ?? 100

            // --- A. ストリークリセット（既存処理） ---
            const { error: updateError } = await supabaseAdmin
                .from('user_stats')
                .update({
                    current_streak: 0,
                    updated_at: new Date().toISOString()
                })
                .eq('user_id', userId)

            if (updateError) {
                console.error(`Failed to punish user ${userId}:`, updateError)
                continue
            }

            // --- B. ペナルティログ記録（既存処理） ---
            await supabaseAdmin
                .from('penalty_logs')
                .insert({
                    user_id: userId,
                    penalty_type: 'streak_reset',
                    reason: '24時間以上のアウトプット不在による強制リセット',
                    amount_lost: user.current_streak
                })

            // --- C. サポーター監視モード処理（新規追加） ---
            
            // 監視役を取得
            const { data: supporters } = await supabaseAdmin
                .from('user_supporters')
                .select('*')
                .eq('user_id', userId)
                .eq('is_active', true)

            let notifiedCount = 0

            if (supporters && supporters.length > 0) {
                // 1. 信用スコアの減算 (10点没収)
                // ※並列処理の競合を防ぐならRPC推奨ですが、ここではシンプルにUpdate
                const newScore = Math.max(0, currentTrustScore - 10)
                await supabaseAdmin
                    .from('user_profiles')
                    .update({ trust_score: newScore })
                    .eq('user_id', userId)

                // 2. 各サポーターに通報メール送信
                for (const supporter of supporters) {
                    // 通報履歴の保存
                    await supabaseAdmin
                        .from('commitment_failures')
                        .insert({
                            user_id: userId,
                            supporter_id: supporter.id,
                            task_title: '日次アウトプット（ストリーク維持）',
                            failure_reason: '24時間放置による自動判定',
                            notified_at: new Date().toISOString()
                        })

                    // メール送信（Resend APIなどを想定）
                    if (RESEND_API_KEY) {
                        await sendAlertEmail({
                            apiKey: RESEND_API_KEY,
                            to: supporter.supporter_email,
                            supporterName: supporter.supporter_name,
                            userName: userName,
                            newTrustScore: newScore
                        })
                    } else {
                        console.log(`[SIMULATION] Email to ${supporter.supporter_email}: ${userName} failed. Score: ${newScore}`)
                    }
                    notifiedCount++
                }
            }

            results.push({ 
                user_id: userId, 
                lost_streak: user.current_streak,
                trust_score_updated: supporters && supporters.length > 0,
                supporters_notified: notifiedCount
            })
        }

        return new Response(
            JSON.stringify({
                success: true,
                punished_count: results.length,
                details: results
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : String(error)
        console.error('Judgment error:', error)
        return new Response(
            JSON.stringify({ success: false, error: errorMessage }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})

// ヘルパー関数: 通報メール送信 (Resend API使用例)
async function sendAlertEmail({ apiKey, to, supporterName, userName, newTrustScore }: SendAlertEmailParams) {
    const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify({
            from: 'App Guardian <noreply@your-app-domain.com>', // ご自身のドメインに変更してください
            to: [to],
            subject: `【警告】${userName}様が本日の誓約を破りました`,
            html: `
                <p>${supporterName || 'サポーター'} 様</p>
                <p>本アプリの監視システムです。<br>
                以下のユーザーが、本日行うべきアウトプットを実行せず、逃避しましたことをご報告いたします。</p>
                
                <div style="border: 1px solid #d1d5db; padding: 16px; margin: 16px 0; border-radius: 8px; background-color: #f9fafb;">
                    <p><strong>対象ユーザー:</strong> ${userName}</p>
                    <p><strong>違反内容:</strong> 日次ストリークの放置（24時間経過）</p>
                    <p><strong>現在の信用スコア:</strong> <span style="color: #ef4444; font-weight: bold; font-size: 1.2em;">${newTrustScore}点</span> (前回比 -10)</p>
                </div>

                <p>次回面談時に、この件について厳しく追求をお願いいたします。<br>
                人は痛みによってのみ、真に変わることができます。</p>
            `
        })
    })

    if (!res.ok) {
        const errorText = await res.text()
        console.error('Failed to send email:', errorText)
    }
}
