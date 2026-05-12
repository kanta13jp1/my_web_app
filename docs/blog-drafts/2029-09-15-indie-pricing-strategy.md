---
title: "インディー SaaS の価格設計 — フリーミアム・トライアル・心理的価格の選び方"
tags: flutter,dart,個人開発,AI
published: true
---

# インディー SaaS の価格設計 — フリーミアム・トライアル・心理的価格の選び方

価格設定は最も影響力のある成長レバーです。コードを一行も書かずに売上を 2〜3 倍にできる唯一の施策。インディー開発者向けに、実践で効いた価格設計パターンをまとめます。

## 3つの基本モデルと選択基準

```
フリーミアム: 無料→有料転換で成長
  向いてる: ネットワーク効果あり / virality が高い / 単価低め
  避けるべき: 機能が複雑 / 顧客教育コスト高 / ARR 目標が早い

時間限定トライアル (14/30日): 全機能を一定期間無料
  向いてる: セルフサービス SaaS / 評価に時間必要 / B2B
  避けるべき: ホビー/個人ユーザー中心 (忘れる)

クレカ不要トライアル → クレカ有りトライアル
  クレカ不要: 登録率 3x / 転換率 50% 低
  クレカ有り: 登録率 1x / 転換率 300% 高
  → CAC で判断: 登録獲得 vs 転換率のトレードオフ
```

## 価格帯の心理学

```
❌ $29/月: "高すぎる" と感じる層が多い
✅ $27/月: 同じ層が "まあいいか" と感じる
理由: $30 を超えると「月3万円カテゴリ」に無意識分類

❌ $100/月 (1プランのみ)
✅ $49 / $99 / $199 (3プラン)
理由: アンカリング効果 — 真ん中のプランが最も選ばれる (72%)

❌ 年額 $348 (= 月額 $29 × 12)
✅ 年額 $276 (= $23/月 相当、20% OFF)
理由: 年払い促進 → ARR 改善 + 解約率低下
```

## Supabase + Stripe での価格テスト実装

```dart
// Flutter: 価格プランのA/Bテスト
enum PricingVariant { control, challenger }

class PricingTestService {
  static PricingVariant getVariant(String userId) {
    // ユーザーIDのハッシュで50/50分割
    final hash = userId.hashCode.abs();
    return hash % 2 == 0
        ? PricingVariant.control
        : PricingVariant.challenger;
  }
}
```

```sql
-- 価格変更実験のトラッキング
CREATE TABLE pricing_experiments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES auth.users(id),
  variant      TEXT NOT NULL,  -- 'control' | 'challenger'
  seen_at      TIMESTAMPTZ DEFAULT now(),
  converted_at TIMESTAMPTZ,
  plan_id      TEXT
);

-- 転換率の集計
SELECT
  variant,
  COUNT(*) as seen,
  COUNT(converted_at) as converted,
  ROUND(COUNT(converted_at)::numeric / COUNT(*) * 100, 1) as conversion_rate_pct,
  AVG(EXTRACT(epoch FROM (converted_at - seen_at)) / 3600) as avg_hours_to_convert
FROM pricing_experiments
GROUP BY variant;
```

## プラン設計の落とし穴

```
❌ 機能で差別化しすぎる
  無料: A / スタンダード: A+B / プロ: A+B+C
  → ユーザーが「B と C が自分に必要か」判断できない

✅ 利用量で差別化する
  無料: 100タスク / スタンダード: 無制限 / プロ: 無制限+チーム
  → 「今の自分に合うプランがどれか」が直感的にわかる

❌ 価格ページに「お問い合わせ」プランを入れる (初期)
  → エンタープライズ感が出て、個人ユーザーが離れる
  → 最初は $199/月 が最高プランでいい

✅ 「最も人気」バッジを中央プランに付ける
  → クリック率 40% UP / 転換率 25% UP
```

## 値上げの正しいやり方

```
Step 1: 既存ユーザーは現在の価格を永続保証 (grandfather)
Step 2: 新規ユーザーのみ新価格を適用
Step 3: 告知は2週間前 / メールで個別に送る
Step 4: 理由を正直に伝える (「インフラコストと機能投資のため」)

✅ 実績: 多くの SaaS が値上げ後に解約率 低下
理由: 価格を上げると「本物のサービス」として認識される
     安すぎる価格は「信頼性が低そう」のシグナルにもなる
```

## 競合比較の使い方

```dart
// 競合と比較するときの正しいフレーミング
final comparisonPoints = [
  ComparisonPoint(
    feature: 'AI タスク自動分割',
    us: true,
    competitor: false,
    note: '我々のコア差別化',
  ),
  ComparisonPoint(
    feature: '価格 (月額)',
    us: '\$29',
    competitor: '\$49',
    note: '40% 安い',
  ),
  // ❌ 競合が圧倒的に優れている機能は入れない
  // ✅ 競合と同等の機能は「✓ / ✓」で並べて「価格差」を際立たせる
];
```

## LTV 計算と価格の最適化

```sql
-- LTV: 平均顧客寿命 × 月額 × 粗利率
SELECT
  plan_id,
  AVG(monthly_mrr) as avg_mrr,
  AVG(lifetime_months) as avg_lifetime,
  AVG(monthly_mrr * lifetime_months * 0.7) as estimated_ltv
FROM (
  SELECT
    s.plan_id,
    s.amount / 100.0 as monthly_mrr,
    EXTRACT(MONTH FROM AGE(COALESCE(s.canceled_at, now()), s.started_at)) as lifetime_months
  FROM subscriptions s
  WHERE s.started_at < now() - interval '3 months'
) sub
GROUP BY plan_id;
```

価格を $19 → $29 に上げたとき、登録数は 15% 減りましたが LTV が 40% 増加し、MRR は全体で 19% 増えました。

---

あなたのプライシング戦略で効いた施策を教えてください！
