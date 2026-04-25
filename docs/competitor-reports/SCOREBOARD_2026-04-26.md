# 競合スコアボード 2026-04-26

*生成: PS版#4 S59 / 2026-04-26*

---

## 新規競合: Poolside AI (コーディングAI特化 LLM)

### 概要
- **正式名称**: Poolside AI (旧 Mutable AI)
- **設立**: 2023年 / 本社: サンフランシスコ
- **調達**: $500M+ (Softbank Vision Fund 2024, ServiceNow, NVIDIA)
- **評価額**: 約 $3B (2024年12月)
- **主力製品**: Malibu — コーディング専用 LLM + IDE統合
- **主な機能**: コード生成・補完、コンテキスト理解（大規模リポジトリ対応）、デプロイメント自動化

### 当プロジェクトへの脅威評価: 🟡 LOW (開発ツール競合・直接競合ではない)
Poolside / Devin は **コーディングAIアシスタント** カテゴリ。自分株式会社の本質的な競合は
Notion/Evernote/MoneyForward 等の **ライフマネジメント** サービスであり、直接競合ではない。

ただし **Claude Code の競合** として開発ワークフローへの影響は中程度。

### Multi-AI アーキテクチャ差別化点 (Issue #762 対応)
| 観点 | Poolside/Devin | 自分株式会社 |
|------|---------------|-------------|
| エージェント数 | 単一エージェント | 4-10 インスタンス並行 |
| 専門化 | コーディング特化 | ドメイン別役割分担 (WBS/競合/AI大学/CI) |
| メモリ持続性 | セッション単位 | 3 層: L1(SQLite) + L2(md) + L3(NotebookLM) |
| コスト最適化 | 一社依存 | マルチベンダー (Claude/Gemini/Copilot/Codex) |

**結論**: Poolside が単一エージェント型の限界 (コンテキスト消失・専門化不足) を持つのに対し、
インスタンス分担+記憶永続化は明確な差別化優位。

---

## 今週の主要競合動向 (2026-04-21〜26)

### 🔴 脅威度HIGH

#### 1. Notion Custom Agents (最大脅威) — 継続監視
- **動向**: Notion AI の Custom Agent 機能 β公開拡大中 (issue #PS#4 S42)
- **Japan DC**: 2026年5月開設予定 → 日本市場本格参入
- **対策**: 自分株式会社のマルチインスタンス協調 + WBS統合 = 差別化継続

#### 2. OpenAI GPT-5.5 API — paid拡大中
- API 一般公開範囲拡大。コスト競争力強化
- **対策**: ai-hub でのベンダーニュートラル routing = 影響最小化

### 🟡 脅威度MEDIUM

#### 3. Google I/O 2026 (2026-05-20 予定)
- Gemini 4 / Project Astra の発表が予想される
- ARC-AGI2 84.6% (現在最高) → 追加発表で競争激化可能性
- **対応**: I/O 後に即スコアボード更新予定

#### 4. Poolside AI Malibu — 新規発見
上記参照。直接競合ではないが開発ツール競争に注目継続。

---

## 競合フィーチャーマトリクス進捗 (PS#4 S58)

competitor_features テーブルへ 21社×10機能 = 210行 seed 完了。

| 機能 | notion | evernote | slack | MS | Google | jibun |
|------|--------|----------|-------|-----|--------|-------|
| notes | ✅ | ✅ | partial | ✅ | ✅ | done |
| task_management | ✅ | partial | ✅ | ✅ | partial | done |
| calendar | ✅ | ❌ | ✅ | ✅ | ✅ | partial |
| finance | ❌ | ❌ | ❌ | partial | partial | done |
| ai_assistant | ✅ | partial | ✅ | ✅ | ✅ | done |
| messaging | partial | ❌ | ✅ | ✅ | partial | done |
| code_assistant | partial | ❌ | partial | ✅ | ✅ | partial |
| collaboration | ✅ | partial | ✅ | ✅ | ✅ | partial |

**自分株式会社の優位点**: finance_tracking (競合20/21社が弱い) + multi-AI統合。

---

## 次回モニタリング優先事項 (2026-04-28)

1. **Google I/O**: 2026-05-20 Gemini 4 発表 → 翌日即スコアボード更新
2. **Notion Japan DC**: 5月開設情報確認
3. **competitor_features Phase 2**: 190社 → feature data 拡充
4. **Poolside Malibu**: Claude Code 代替テスト記事・ベンチマーク追跡

---

*Sources: TechCrunch, ProductHunt, GitHub Issues #760/#761/#762*
*commit: 81e6bd72 (S58完了後)*
