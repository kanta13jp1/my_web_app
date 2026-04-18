---
date: 2026-04-18
from: Windowsアプリ版#87
to: PowerShell版
status: pending
priority: high
---

# ai-hub provider.chat 自動 Tier ルーティング (Kepion 参考)

## 概要

Kepion の OpenRouter 4 Tier ルーティング (Free/Budget/Performance/Premium) を `ai-hub:provider.chat` に導入し、**運用コスト 80〜85% 削減** を狙う。背景: [docs/architecture/kepion-reference-2026-04-18.md](../architecture/kepion-reference-2026-04-18.md)。

VSCode版へ別 PR で `AiProviderEntry.tier` フィールド追加を依頼済み (`20260418_ai_provider_tier_field.md`)。本 PR はそれを前提とした **EF 側のルーティングロジック実装**。

## 依頼内容

1. `supabase/functions/ai-hub/index.ts` の `provider.chat` ハンドラを拡張
2. **新アクション** `provider.chat_auto` を追加 (既存 `provider.chat` は明示指定用に維持):
   ```ts
   case "provider.chat_auto": {
     // body: { tier?: 'budget' | 'performance' | 'premium', message, ... }
     // tier 省略時は body.budget = 0.001 USD など予算ベースで自動選択
   }
   ```
3. **Tier → Provider マッピング表** (PROVIDER_CONFIGS と並列で定義):
   ```ts
   const TIER_PROVIDERS: Record<Tier, string[]> = {
     free: ['ollama', 'huggingface'],
     budget: ['minimax', 'arcee_ai', 'sambanova', 'deepseek'],
     performance: ['groq', 'openai', 'google', 'mistral', 'cohere'],
     premium: ['anthropic', 'openai-gpt5', 'google-pro'],
   };
   ```
4. **自動エスカレーション**: 指定 tier で provider が応答失敗 (5xx / quota / rate_limit) → 同 tier 内次プロバイダー試行 → 全滅で **1 階級上の tier** へ自動切替
5. **自動ダウングレード**: 同一ユーザーの直近 N 回連続成功 (例: 5回) → 次回は **1 階級下の tier** で試行 (Supabase `ai_quota_usage` テーブルに記録 / 失敗で復元)
6. **コスト記録**: 各呼び出し後 `ai_quota_usage` に `provider, tier, success, estimated_cost_usd` を INSERT (既存テーブル拡張)
7. **deno lint clean** 確認 + Supabase Edge Function deploy ワークフローでテスト

## 関連ファイル

- `supabase/functions/ai-hub/index.ts` (provider.chat ハンドラ・PROVIDER_CONFIGS)
- `supabase/migrations/` (ai_quota_usage テーブル拡張用 migration が必要)
- `lib/models/ai_provider_registry.dart` (VSCode版 が tier フィールド追加後に参照)
- `docs/architecture/kepion-reference-2026-04-18.md` (背景)

## 完了条件

- [ ] `provider.chat_auto` アクション実装 (Tier ベースルーティング)
- [ ] Tier → Provider マッピング定義
- [ ] 自動エスカレーション (失敗 → 上位 tier)
- [ ] 自動ダウングレード (連続成功 → 下位 tier 試行)
- [ ] `ai_quota_usage` への cost ログ INSERT
- [ ] migration: `ALTER TABLE ai_quota_usage ADD COLUMN tier text, success bool, estimated_cost_usd numeric;`
- [ ] deno lint clean / deploy-prod success
- [ ] Flutter 側からは VSCode版 が `provider.chat_auto` 呼び出しに切替

完了後に `done/20260418_ai_hub_auto_tier_routing.md` へ移動してください。

依存関係: VSCode版 `20260418_ai_provider_tier_field.md` 完了後に着手すると testing しやすい (registry の tier 情報を確認しながら実装可能)。
