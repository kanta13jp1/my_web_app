---
date: 2026-04-19
from: PS版#4 (競合モニタリング)
to: Win版
status: pending
priority: HIGH
---

# MoneyForward AI Cowork 対抗 — 個人特化財務 AI 機能強化依頼

## 背景・根拠

PS版#4 の 2026-04-19 競合モニタリングで **MoneyForward AI Cowork** の詳細が判明しました。

- **発表**: 2026-04-07 "Money Forward AI Vision 2026"
- **機能**: 経理・AP/AR・給与・HR 管理を自然言語で指示できる自律型バックオフィスエージェント
- **GA**: 2026-07 予定 (早期アクセス受付中)
- **目標**: 2030年に AI 関連 ARR ¥150億

詳細: `docs/competitor-reports/2026-04-19.md` §3 MoneyForward

## 対抗軸 (PHILOSOPHY 原則との整合)

MoneyForward AI Cowork との決定的な差:
- MoneyForward: **法人向け大企業路線** (5,000席以上・バックオフィス特化)
- 自分株式会社: **個人・フリーランス・小規模事業主向け** の「自分株式会社財務部署」AI

PHILOSOPHY 原則との整合:
- 原則 4 (6部署バランス・人事最優先): 財務部署 AI の強化は 6部署バランスに直結 ✅
- 原則 5 (商品=ユーザー価値): 個人の財務管理時間を削減する実用価値 ✅
- 原則 6 (資本=時間): 請求書・支出管理の操作時間最小化 ✅
- 原則 8 (KPI=昨日の自分): 先月比の支出増減を可視化 ✅

**PHILOSOPHY スコア: 4/9 → 実装検討対象**

## 依頼内容 (Win版 migration + EF cleanup 担当)

### Task 1: 財務部署 AI アクション追加 (`ai-hub` または `app-hub`)

既存の `ai-hub` に `finance.personal_summary` アクションを追加:

```typescript
case "finance.personal_summary": {
  // MoneyForward が扱えない個人の支出・収入傾向を AI 分析
  // Supabase の wealth_goals + wealth_struggles テーブルから取得
  // Gemini/Claude で「先月比・改善提案・次のアクション」を生成
}
```

EF 数は増やさず **既存 hub への action 追加** で対応 (Rule 7 準拠)。

### Task 2: Supabase migration — `personal_finance_ai_logs` テーブル

AI 財務アドバイスのログを保存するテーブルを追加:

```sql
CREATE TABLE personal_finance_ai_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  summary_type text NOT NULL DEFAULT 'monthly',  -- monthly / weekly / ad_hoc
  ai_response text NOT NULL,
  model_used text,
  trace_id text,
  created_at timestamptz DEFAULT now()
);
-- RLS: ユーザー自身のみ参照可
ALTER TABLE personal_finance_ai_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_logs" ON personal_finance_ai_logs
  FOR ALL USING (auth.uid() = user_id);
```

### Task 3: LP 訴求文言 (VSCode版と連携)

comparison_page の MoneyForward 行を更新:
「法人バックオフィス AI」vs「個人・フリーランス向け 自分株式会社財務部署 AI」

## スケジュール感

MoneyForward AI Cowork GA は **2026-07**。
**2026-06 末までに個人特化の財務 AI 機能を実装・訴求確立** することが目標。
今から約 2.5 ヶ月あるため、migration → EF action → UI の順で進める余裕あり。
