// Daily Judgment Edge Function
// 毎晩実行され、アウトプットがないユーザーのストリークをリセットし、ペナルティを与える

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// サービスロールキー（管理者権限）が必要
// Supabase Dashboard > Settings > API から取得可能ですが、
// Edge Runtime内では Deno.env.get('SERVICE_ROLE_KEY') で取得できる場合があります。
// できない場合は Secrets に設定してください。
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Admin権限でクライアント作成（RLSを無視して全ユーザーをチェックするため）
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

        // 1. ストリークを持っていて、かつ24時間以上アウトプットがないユーザーを抽出
        // （本来はユーザーのタイムゾーンを考慮すべきですが、まずはUTC基準で厳格に判定します）
        const thresholdDate = new Date()
        thresholdDate.setHours(thresholdDate.getHours() - 24) // 24時間前

        const { data: stagnantUsers, error: fetchError } = await supabaseAdmin
            .from('user_stats')
            .select('user_id, current_streak, last_output_at')
            .gt('current_streak', 0) // ストリークがある人だけ
            .lt('last_output_at', thresholdDate.toISOString()) // 24時間以上更新がない

        if (fetchError) throw fetchError

        console.log(`Found ${stagnantUsers?.length ?? 0} stagnant users.`)

        const results = []

        // 2. ペナルティ執行ループ
        for (const user of stagnantUsers || []) {
            // ストリークを0にリセット
            const { error: updateError } = await supabaseAdmin
                .from('user_stats')
                .update({
                    current_streak: 0,
                    updated_at: new Date().toISOString()
                })
                .eq('user_id', user.user_id)

            if (updateError) {
                console.error(`Failed to punish user ${user.user_id}:`, updateError)
                continue
            }

            // ペナルティログを記録
            await supabaseAdmin
                .from('penalty_logs')
                .insert({
                    user_id: user.user_id,
                    penalty_type: 'streak_reset',
                    reason: '24時間以上のアウトプット不在による強制リセット',
                    amount_lost: user.current_streak // 失ったストリーク数を記録
                })

            results.push({ user_id: user.user_id, lost_streak: user.current_streak })
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

    } catch (error) {
        console.error('Judgment error:', error)
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})