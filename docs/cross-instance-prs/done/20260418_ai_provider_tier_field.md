---
date: 2026-04-18
from: Windowsアプリ版#87
to: VSCode版
status: pending
priority: high
---

# ai_provider_registry に Tier フィールド追加 (Kepion 参考)

## 概要

Kepion (autonomous AI company orchestrator, NotebookLM `819f4e8d-...`) の OpenRouter 4 Tier ルーティング戦略を自分株式会社の AI プロバイダー管理にも導入したい。本 PR はその第一歩として `AiProviderEntry` に `tier` メタデータを追加する。詳細: [docs/architecture/kepion-reference-2026-04-18.md](../architecture/kepion-reference-2026-04-18.md)

## 依頼内容

1. `lib/models/ai_provider_registry.dart` に enum `AiProviderTier { free, budget, performance, premium }` を追加
   - `tier.label` 拡張: 無料 / 低コスト / 標準 / プレミアム
   - `tier.colorValue` 拡張: 0xFF94A3B8 / 0xFF4ADE80 / 0xFFFACC15 / 0xFFFF6B35
2. `AiProviderEntry` クラスに `final AiProviderTier? tier;` フィールド追加 (オプショナル)
3. 既存 84 エントリに **概算 tier 分類** を付与 (推奨マッピング):
   - **Free**: ollama / huggingface / lmsys (無料 OSS)
   - **Budget**: deepseek / minimax (M2.5-Lightning $0.10/1M) / sambanova (Free Tier $5) / arcee_ai (Mini $0.045/$0.15) / qwen / 01ai
   - **Performance**: openai (gpt-4o-mini) / google (gemini-2.5-flash) / mistral (small-latest) / cohere (command-r-plus) / fireworks_ai / together_ai / groq / perplexity / xai
   - **Premium**: anthropic (claude-opus-4-7) / openai (gpt-4o) / google (gemini-2.5-pro) / cognition (devin) / poolside / scale_ai
   - 上記以外は `tier: null` のまま (画像/動画/音声 系はチャット tier 適用外)
4. `lib/pages/ai_provider_status_page.dart` の各エントリ表示に **tier バッジ** を追加 (provider 行右側)
5. `flutter analyze 0エラー` + `dart format` pass を確認

## 関連ファイル

- `lib/models/ai_provider_registry.dart` (84エントリ)
- `lib/pages/ai_provider_status_page.dart` (UI 表示)
- `docs/architecture/kepion-reference-2026-04-18.md` (背景)

## 完了条件

- [ ] `AiProviderTier` enum 追加 + `AiProviderEntry.tier` フィールド追加
- [ ] 既存 84 エントリの概算 tier 分類完了 (上記マッピング参照)
- [ ] ai_provider_status_page に tier バッジ表示
- [ ] flutter analyze 0エラー / dart format pass
- [ ] commit + push (Windows版#87 → VSCode版 連携)

完了後に `done/20260418_ai_provider_tier_field.md` へ移動してください。

PS版へのフォローアップ: `ai-hub:provider.chat` での **自動エスカレーション/ダウングレード** ロジックを別 PR (20260418_ai_hub_auto_tier_routing.md) で依頼予定。
