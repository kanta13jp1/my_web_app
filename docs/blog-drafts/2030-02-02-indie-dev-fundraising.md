---
title: "インディー SaaS の資金調達戦略 — ブートストラップ・クラファン・MRR ローンの選び方"
tags: flutter,dart,個人開発,AI
published: true
---

## はじめに

「資金調達が必要か？」はインディー SaaS 開発者が避けられない問いだ。VC から資金を取ることがゴールではなく、**自分のビジネスに合った資金調達手段を選ぶこと**が本質だ。本稿では、ブートストラップから始まり、クラファン・MRR ベースファイナンス・エクイティフリー投資まで、選び方の判断基準と実装パターンを整理する。

---

## 1. ブートストラップ vs 外部資金の判断基準

まず「今の段階で外部資金が必要か？」を問い直す。

| 観点 | ブートストラップ向き | 外部資金向き |
|------|-------------------|-----------  |
| コントロール | プロダクト方針を自分で決めたい | 大きな市場を速く取りたい |
| 成長速度 | 有機成長・口コミで十分 | 競合が激しく速攻で広げないといけない |
| 収益化 | PMF 前から収益モデルが見えている | 初期は赤字でも拡大が先 |
| Exit | バイアウトや Micro-SaaS 売却を視野 | IPO / 大型 M&A |

インディー SaaS の多くは MRR $1,000〜$10,000 まではブートストラップで十分到達できる。この段階で外部資金を入れると**コントロールと機動力を失うリスク**の方が大きい。

---

## 2. Kickstarter / Campfire でのクラファン準備

クラファンは「先払いで需要を検証する」最も低リスクな手段だ。

**成功するクラファンの準備チェックリスト**:

1. **ティザーリスト構築**: キャンペーン前に 500〜1,000 人のメールリストを用意する
2. **動画 3 分以内**: 問題→解決策→Why Now を明確に。日本語なら Campfire が親和性高い
3. **Early Bird 価格**: 最初の 48 時間に全体の 30% を売るのが Kickstarter アルゴリズムの鍵
4. **ストレッチゴール**: 基本目標の 150%・200% 達成時に追加機能を約束

Supabase で先行登録者を管理する例:

```sql
CREATE TABLE campaign_waitlist (
  id         BIGSERIAL PRIMARY KEY,
  email      TEXT UNIQUE NOT NULL,
  tier       TEXT NOT NULL DEFAULT 'standard',  -- 'earlybird' | 'standard' | 'pro'
  referrer   TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 登録数と tier 別集計
SELECT tier, COUNT(*) as count
FROM campaign_waitlist
GROUP BY tier;
```

---

## 3. Pipe / Clearco などの MRR ベース レベニューファイナンス

MRR が $5,000〜$10,000 を超えたら、株式を手放さずに資金調達できる **レベニューファイナンス** が選択肢に入る。

| サービス | 仕組み | 調達額の目安 | 返済 |
|---------|--------|------------|------|
| **Pipe** | 年間 ARR の先払い | ARR の最大 100% | 月次収益から自動返済 |
| **Clearco** | ARR の数ヶ月分 | $10K〜$10M | 収益の 1〜10% を返済に充当 |
| **Capchase** | 年間契約の前払い | ARR × 倍率 | 月次引き落とし |

レベニューファイナンスの最大のメリットは**エクイティ希薄化なし**。デメリットは MRR が安定していないと審査を通らない点と、有効年利が高い場合がある点だ。

Supabase で MRR を自動集計して融資審査書類を作る:

```sql
-- 月次 MRR 推移ビュー
CREATE VIEW mrr_monthly AS
SELECT
  DATE_TRUNC('month', created_at) AS month,
  SUM(amount_cents) / 100.0 AS mrr_usd,
  COUNT(DISTINCT user_id) AS active_subscribers
FROM subscriptions
WHERE status = 'active'
GROUP BY 1
ORDER BY 1 DESC;
```

---

## 4. YC / Indie.vc などのエクイティフリー・軽量エクイティ

### YC Safe (Simple Agreement for Future Equity)

YC の SAFE ノートは転換社債ではなく将来の株式に転換する権利だ。現在は Post-Money SAFE が標準。個人開発者でも YC Startup School 経由で $500K SAFE を狙える。

### Indie.vc / Earnest Capital

「VC 的な成長」を求めず、**創業者に優先還元**する構造が特徴。

- Earnest Capital: SHARED EARNINGS AGREEMENT — 投資額を利益から返済した後は株式は移転しない
- Tiny Capital: 完全な利益を出すブートストラップ SaaS を丸ごと買収（Exit 先としても選択肢）

---

## 5. SaaS 特化 キャッシュフロー管理の実装例（Supabase billing テーブル）

資金調達の前提は **キャッシュフローの可視化**だ。Supabase で billing ダッシュボードを作る。

```sql
CREATE TABLE billing_transactions (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID REFERENCES auth.users(id),
  amount_cents    INTEGER NOT NULL,
  currency        TEXT NOT NULL DEFAULT 'jpy',
  transaction_type TEXT NOT NULL,  -- 'subscription' | 'one_time' | 'refund'
  stripe_charge_id TEXT UNIQUE,
  processed_at    TIMESTAMPTZ DEFAULT NOW()
);

-- MRR・ARR・Churn を一発で取得する EF クエリ
SELECT
  SUM(CASE WHEN transaction_type = 'subscription' THEN amount_cents ELSE 0 END) / 100.0 AS mrr,
  SUM(CASE WHEN transaction_type = 'subscription' THEN amount_cents ELSE 0 END) / 100.0 * 12 AS arr,
  SUM(CASE WHEN transaction_type = 'refund' THEN ABS(amount_cents) ELSE 0 END) / 100.0 AS churn_amount
FROM billing_transactions
WHERE processed_at >= DATE_TRUNC('month', NOW());
```

---

## まとめ

資金調達は「早いほど良い」ではなく「**必要になったときに最適な手段で取る**」が正解だ。

1. MRR $0〜$5K → ブートストラップ徹底・クラファンで初期需要検証
2. MRR $5K〜$30K → レベニューファイナンスで成長加速（エクイティ非希薄）
3. MRR $30K 超 → YC/Earnest/VC の選択肢が現実的になる

キャッシュフローを Supabase でリアルタイムに可視化し、数字を武器に交渉できる状態を常に保つことが最強の準備だ。
