# Cross-Instance PR: CFO 財務サマリ → AI 役員会議 EF context 注入

**作成**: VSCode版 S25 / 2026-05-03
**FROM**: VSCode版 (CFO Office UI 完了 → EF 改修要求)
**TO**: Codex#2 (EF/Deno 担当)
**優先度**: HIGH
**期限**: 2026-05-10 (1 週間)
**親軸**: #1669 CFOコスト入力台帳 + #1670 CFO財務サマリ → AI役員会議接続

---

## 1. 背景

VSCode版 S25 で `CfoOfficePage` に `BudgetFinancialPlannerPage` を接続完了 (UI 部分 done).

残タスク: **AI役員会議 (`daily-judgment` EF または `ai-hub`) が financial data をコンテキストとして参照できるようにする**.

Issue #1669 受け入れ条件 3:
> 統合AI機能（The Five Emperors）や緊急役員会議の際に、AI役員が財務データをコンテキストとして参照し、コスト面からの意見を生成できること

## 2. 期待する実装 (Codex#2 EF 担当)

### 2.1 CFO 財務サマリ取得 Edge Function (または ai-hub action 追加)

`supabase/functions/ai-hub/` に `cfo.summary` action 追加:

```typescript
// action: 'cfo.summary'
// 認証済ユーザーの直近 1 ヶ月の収支サマリを返す
// 使用テーブル: budget_entries / expense_records / asset_snapshots (既存スキーマ)
{
  "total_income": 350000,
  "total_expense": 280000,
  "net": 70000,
  "categories": [
    { "name": "housing", "amount": 80000 },
    { "name": "food", "amount": 40000 }
  ],
  "savings_rate": 0.2,
  "month": "2026-05"
}
```

### 2.2 daily-judgment EF に CFO context を注入

`supabase/functions/daily-judgment/index.ts` の AI プロンプトに:

```typescript
const cfoSummary = await getCfoSummary(userId);
const systemPrompt = `
  あなたは「自分株式会社」の AI 役員会議の CFO です。
  今月の財務状況: 収入 ${cfoSummary.total_income}円 / 支出 ${cfoSummary.total_expense}円 / 純利益 ${cfoSummary.net}円
  貯蓄率: ${Math.round(cfoSummary.savings_rate * 100)}%
  この財務データを踏まえてコスト最適化の意見を述べてください。
`;
```

### 2.3 Migration (スキーマ確認)

既存テーブル確認:
- `budget_entries` (月次予算)
- `expense_records` (支出記録)
- `asset_snapshots` (資産スナップショット)

上記が不足している場合のみ migration 作成。既存で十分なら EF 側のみ改修。

## 3. 受入基準

- [ ] `ai-hub` に `cfo.summary` action 追加 (認証済ユーザーのみ)
- [ ] `daily-judgment` の AI プロンプトに CFO 財務サマリ context 注入
- [ ] `flutter analyze` 0 issues (既存 Flutter 側の変更なし)
- [ ] CI green (deploy-prod)
- [ ] cross-instance-pr 完了時 `done/` 移動

## 4. 連携

- 前 phase: VSCode版 S25 (CfoOfficePage + BudgetFinancialPlannerPage 接続)
- 後 phase: Issue #1670 (CFO財務サマリ → AI役員会議コンテキスト接続) close
- 関連 Issue: #1669 (P1) / #1670 (P2)

---

*VSCode版 S25 / 2026-05-03 起票 / CFO EF context / VSCode → Codex#2 lane*
