import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, referralCode, newUserId } = body;
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // リファラルコードから紹介元ユーザーを特定
    const { data: referrer } = await supabaseAdmin
      .from('user_profiles')
      .select('id, total_referrals, successful_referrals')
      .eq('referral_code', referralCode)
      .single();

    if (!referrer) throw new Error("Invalid referral code");

    if (action === 'click') {
      // 単なるリンククリック（PV増加）
      await supabaseAdmin.rpc('increment_referral_clicks', { target_user_id: referrer.id });
      
      return new Response(JSON.stringify({ success: true, message: "Click recorded" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    } 
    
    if (action === 'signup') {
      // 新規登録が発生した（コンバージョン）
      
      // 1. 紹介元の実績を更新
      await supabaseAdmin
        .from('user_profiles')
        .update({ 
          successful_referrals: (referrer.successful_referrals || 0) + 1 
        })
        .eq('id', referrer.id);

      // 2. 招待元ユーザーにゲーム内通貨（Stock）や経験値（XP）を大量付与
      await supabaseAdmin.from('user_rewards').insert({
        user_id: referrer.id,
        reward_type: 'viral_referral_bonus',
        amount: 5000, // 圧倒的な報酬でさらなるシェアを促す
        description: 'バイラル広告からの新規役員（ユーザー）獲得ボーナス'
      });

      // 3. 招待された側（新規ユーザー）にも初期ブーストを付与
      if (newUserId) {
        await supabaseAdmin.from('user_rewards').insert({
          user_id: newUserId,
          reward_type: 'invited_start_dash',
          amount: 1000,
          description: '招待リンクからのスタートダッシュ・ボーナス'
        });
      }

      // 4. K要因（バイラル係数）の再計算ログ（Growth Command Center用）
      await supabaseAdmin.from('growth_metrics_log').insert({
        event_type: 'viral_conversion',
        referrer_id: referrer.id,
        new_user_id: newUserId,
        created_at: new Date().toISOString()
      });

      return new Response(JSON.stringify({ 
        success: true, 
        message: "Signup recorded and rewards distributed!" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    throw new Error("Invalid action type");
  } catch (error: any) {
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});