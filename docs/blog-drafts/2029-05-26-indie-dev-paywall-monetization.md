---
title: "個人開発 SaaS の課金設計 — Paywall・フリーミアム・使用量課金 3 つのパターン"
tags: flutter,supabase,個人開発,AI
published: true
---

# 個人開発 SaaS の課金設計 — Paywall・フリーミアム・使用量課金 3 つのパターン

個人開発で最も難しいのは「どこで課金するか」の設計です。間違えると無料ユーザーが溢れて収益がゼロになるか、壁を高くしすぎてユーザーが離れます。3 パターンを実例で解説します。

## パターン 1: ハードな Paywall

一定の操作数を超えたら課金を必須にします。シンプルで収益化しやすい。

### 実装 (Flutter + Supabase)

```sql
-- usage テーブルでカウント管理
CREATE TABLE usage_limits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  action_count INTEGER DEFAULT 0,
  reset_at TIMESTAMPTZ DEFAULT date_trunc('month', NOW()) + INTERVAL '1 month',
  plan TEXT DEFAULT 'free'
);

-- 使用カウントをインクリメントして上限チェック
CREATE OR REPLACE FUNCTION increment_usage(p_user_id UUID, p_limit INT)
RETURNS BOOLEAN  -- TRUE = 許可、FALSE = 上限超過
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_count INTEGER;
  user_plan TEXT;
BEGIN
  SELECT action_count, plan INTO current_count, user_plan
  FROM usage_limits WHERE user_id = p_user_id;

  IF user_plan = 'pro' THEN RETURN TRUE; END IF;
  IF current_count >= p_limit THEN RETURN FALSE; END IF;

  UPDATE usage_limits
  SET action_count = action_count + 1
  WHERE user_id = p_user_id;

  RETURN TRUE;
END;
$$;
```

```dart
Future<bool> checkAndIncrementUsage() async {
  final allowed = await supabase.rpc('increment_usage', params: {
    'p_user_id': supabase.auth.currentUser!.id,
    'p_limit': 10,  // 無料は10回/月
  }) as bool;

  if (!allowed) {
    _showUpgradeDialog();
    return false;
  }
  return true;
}
```

## パターン 2: フリーミアム (機能制限)

基本機能は無料、高度な機能は有料。ユーザー獲得に優れる。

```dart
enum Plan { free, pro }

class FeatureGate extends StatelessWidget {
  final Plan requiredPlan;
  final Widget child;
  final Widget? fallback;

  const FeatureGate({
    required this.requiredPlan,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlan = context.read<UserProvider>().plan;
    if (currentPlan.index >= requiredPlan.index) return child;
    return fallback ?? UpgradePromptWidget(requiredPlan: requiredPlan);
  }
}

// 使い方
FeatureGate(
  requiredPlan: Plan.pro,
  child: AIAnalysisButton(),
  fallback: ProFeatureTeaser(
    title: 'AI 分析',
    description: 'Pro プランで無制限に利用できます',
  ),
)
```

## パターン 3: 使用量課金 (Usage-Based)

API コスト連動型。AI 機能を提供するときに最適です。

```sql
-- クレジット管理
CREATE TABLE user_credits (
  user_id UUID PRIMARY KEY,
  credits INTEGER DEFAULT 100,  -- 無料 100 クレジット
  total_used INTEGER DEFAULT 0
);

CREATE OR REPLACE FUNCTION consume_credits(
  p_user_id UUID,
  p_amount INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_credits INTEGER;
BEGIN
  SELECT credits INTO current_credits
  FROM user_credits WHERE user_id = p_user_id;

  IF current_credits < p_amount THEN
    RETURN json_build_object('success', false, 'reason', 'insufficient_credits');
  END IF;

  UPDATE user_credits
  SET credits = credits - p_amount,
      total_used = total_used + p_amount
  WHERE user_id = p_user_id;

  RETURN json_build_object('success', true, 'remaining', current_credits - p_amount);
END;
$$;
```

## 課金プロバイダー選択

| プロバイダー | 個人開発向け | 日本対応 | 備考 |
|---|---|---|---|
| Stripe | ◎ | ○ | 最も多機能。Supabase 公式統合あり |
| RevenueCat | ◎ | ○ | アプリ内購入に特化。Flutter SDK あり |
| Lemon Squeezy | ○ | △ | MoR (Merchant of Record) で税務が楽 |
| PAY.JP | △ | ◎ | 日本法人向け。Stripe より簡単な審査 |

## 自分株式会社での戦略

自分株式会社では「フリーミアム + 使用量課金」のハイブリッドを採用:
- 無料: 基本機能 + 月 100 AI クレジット
- Pro ¥980/月: 無制限 AI + 高度な分析 + データエクスポート

変換率は 3.2%（業界平均 2-5%）で、無料ユーザーが製品を十分体験してから課金判断できる設計にしています。

---

あなたの個人開発アプリはどの課金モデルを使っていますか？コメントで教えてください！
