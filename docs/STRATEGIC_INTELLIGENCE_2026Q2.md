# Strategic Intelligence 2026 Q2 — 自分株式会社 Fleet 戦略反映

> **Win版#132 part 159 (2026-05-07)**: NotebookLM 戦略系 5 本を蒸留し、2-instance fleet + 21 competitor 戦略に反映.
>
> **ソース notebooks** (= NotebookLM `jibun-master-brain`):
> - `f167dcc3-...` Competitive AI Intelligence Report: The Multi-Agent Convergence
> - `c60da02b-...` Strategic Intelligence Scoreboard: May 2026 Competitive Analysis Summary
> - `17cd45cd-...` Competitive Intelligence Report: 2026 AI Infrastructure and Marketplace Trends
> - `0829f536-...` Google I/O 2026: Strategic Defense and Competitive Analysis Briefing
> - `b74e9ada-...` Code with Claude 開会の基調講演 (Anthropic 公式)
>
> **位置づけ**: `docs/AI_FLEET_SYNERGY_PLAYBOOK.md` の実装判断根拠 + `docs/MULTI_INSTANCE_FLEET.md` Q2-Q3 roadmap の上位戦略.

---

## 1. Multi-Agent Convergence — fleet への示唆

### 業界トレンド (2026 Q2)

| 動向 | 内容 | 自分株式会社への影響 |
|------|------|---------------------|
| **Orchestration layer 台頭** | LangGraph / CrewAI / AutoGen 等が multi-agent coordination を標準化 | Win Claude の `Plan-Execute-Review` pipeline (= SYNERGY 原則 #2) が業界ベストプラクティスと一致 |
| **Specialization vs Generalization** | 汎用 1 AI より専門 multi-AI が benchmark 超越 | Win Claude (architect) + Win Codex (worker) = 専門分化 2 instance が正解アーキテクチャ |
| **Long-context utilization** | Claude 3.7 / Gemini 2.5 の 1M+ ctx → fleet state を 1 context に格納可能 | Win Claude が全 fleet state を保持し、Codex に task を切り出す hub-spoke 構造が最適 |
| **Memory persistence** | cross-session memory (= claude-mem / NotebookLM) が競争優位 | `~/.claude/projects/.../memory/` + NotebookLM `jibun-master-brain` = 業界先行 |
| **Human-in-the-loop 必須化** | 完全自律 AI の hallucination リスクで regulated industry が HITL 義務化へ | `[PHILOSOPHY-22] 原則 1 CEO 感` + `[DYNAMIC-CLAIM] cap 2 件` = 制度準備済 |

### 競合 fleet 比較

| 競合 | fleet 構成 | 弱点 | 自分株式会社の差異化 |
|------|-----------|------|---------------------|
| **Cursor Team** | editor + AI = 1 instance / no separation | 設計 bias + 実装 bias 混在 | Plan→Execute→Review 3 段分離 |
| **Devin (Cognition)** | 完全自律 1 agent | 高コスト / 不透明 / HITL なし | HITL 必須 + cost 最適化 (Codex 安価) |
| **Cline / RooCode** | Claude-based 1 instance | fleet coordination なし | 2 instance 協調 + cross-instance-pr |
| **GitHub Copilot** | enterprise 統合だが 1 LLM | ADR / memory 連続性なし | NotebookLM + claude-mem 永続記憶 |
| **Replit Agent** | scaffold 特化 1 agent | architect layer なし | Win Claude = dedicated architect |

**結論**: 自分株式会社の **Plan(Claude) → Execute(Codex) → Review(Claude)** pipeline は 2026 Q2 時点で競合が未実装の **3 段 bias 分離** を実現しており、fleet 優位性は継続。

---

## 2. 2026 AI Infrastructure & Marketplace Trends

### 技術スタック評価 (自分株式会社 現状)

| 技術 | 業界トレンド方向 | 現状評価 | Q2-Q3 対応 |
|------|----------------|----------|------------|
| **Supabase Edge Functions** | serverless + Deno = 主流化継続 | ✅ EF 50 cap 管理済 | hub action 追加優先維持 |
| **Firebase Hosting** | CDN + JAMstack = 低コスト standard | ✅ deploy-prod 安定 | 変更不要 |
| **Flutter Web** | cross-platform = iOS/Android/Web 1 codebase | ✅ + mobile release 準備中 | Issue #1495 (P0 / 2026-05-30 期限) |
| **MCP (Model Context Protocol)** | Anthropic 主導 = 業界標準化進行 | ✅ MCP-AUTH-27 spec 完成 | tools-hub EF との連携強化 |
| **Vector DB / RAG** | 標準 infra 化 = 差異化要因でなくなる | 🟡 NotebookLM 依存 | pgvector on Supabase 検討 |
| **AI inference cost** | 2026 で -70% (2025 比) / haiku 相当が最安 | ✅ Auto Mode でコスト最適 | GHA cron = Claude 非依存設計維持 |

### marketplace 機会

1. **AI 大学 (= AI University) の差異化強化**: 2026 Q2 は LLM provider 数急増 (50+ 社). 業界が混乱する中で「信頼できる AI 評価・学習プラットフォーム」の価値 UP.
2. **競合モニタリング自動化**: 21 competitor が AI 機能を毎月 update. `competitor-monitoring.yml` daily cron が資産.
3. **NotebookLM × 競合 intelligence**: Q2 に competitor 5 社以上が multi-agent 機能を発表予定. 即 Issue 化 → 対策 spec の pipeline を維持.

---

## 3. Google I/O 2026 — 防衛戦略

### Google の攻勢領域

| Google 発表 | 脅威度 | 防衛アクション |
|------------|--------|---------------|
| **Gemini 2.5 Pro for coding** | 🔴 高 (= Claude Code 直接競合) | Claude Code 4.7 Opus 移行 + MCP エコシステム固有機能活用 |
| **Firebase + Vertex AI 統合** | 🟡 中 (= 既存 Firebase 依存あり) | Supabase primary + Firebase hosting のみ維持 (lock-in 回避) |
| **Flutter 3.X updates** | 🟢 低 (= positive / stack 強化) | Flutter upgrade 対応 = Codex territory |
| **Google Workspace AI** | 🟡 中 (= AI 大学コンテンツ競合) | 個人特化 + 競合としてトラッキング継続 |
| **Project Astra (multi-modal agent)** | 🔴 高 (= 将来の AI ライフコーチ競合) | [AI-CHARACTER-24] 8 原則 + [IMBUE-25] 7 パターン適用 |

### Q2 防衛優先 3 件

1. **iOS/Android 同時リリース** (Issue #1495 / P0 / 2026-05-30): Google の mobile AI 統合加速前に mobile presence 確立.
2. **MCP エコシステム固有機能実装**: Google Vertex AI が追いつけない Claude Code 固有機能 (hooks / memory / PreCompact) を深化.
3. **NotebookLM intelligence pipeline 維持**: Google 自身のサービスを活用して競合 intelligence 取得 (= judo strategy).

---

## 4. Code with Claude — Anthropic 基調講演からの示唆

### Anthropic の方向性 (2026 Q2)

| 発表内容 | fleet への示唆 |
|---------|--------------|
| **Claude Code = platform** (not just chat) | Win Claude の architect role がより重要に (= platform 設計者) |
| **MCP ecosystem = moat** | `[MCP-AUTH-27]` 10 原則実装済 = 早期採用アドバンテージ |
| **Multi-agent orchestration = Anthropic の注力** | Win Claude hub-spoke 構造が Anthropic ロードマップと一致 |
| **Long-context + prompt caching = cost advantage** | `[COMPACTION-RESUME]` + session memory hook = cost 最適化済 |
| **Agent SDK (GA)** | tools-hub EF = 自社 agent SDK の先行実装 |

### Claude Code 固有機能活用計画

```
現在活用中:
  ✅ hooks (SessionStart / SessionEnd / PostToolUse)
  ✅ MCP servers (tools-hub / github / figma / playwright)
  ✅ memory (~/.claude/projects/.../memory/)
  ✅ slash commands (.claude/commands/)
  ✅ skills (.claude/skills/)
  ✅ worktrees (cross-instance 分離)

Q2-Q3 強化候補:
  🟡 Agent SDK (= tools-hub を Claude Agent SDK に移行検討)
  🟡 SubagentStart/Stop hooks (= Issue #1781 実装済 / 活用深化)
  🟡 PreCompact hook (= Issue #1564 spec 済 / Codex 実装待ち)
  🔴 ultrareview 定型化 (= 設計 spec PR に必須化)
```

---

## 5. 2-Instance Fleet Q2 行動指針

### 優先度 matrix (期限 × 影響度)

| # | Issue | 期限 | 担当 | 影響度 | 状態 |
|---|-------|------|------|--------|------|
| 1 | #1495 iOS/Android 同時リリース準備 | 2026-05-30 | Win Claude (spec) / Codex (実装) | P0 | 設計 spec 着手 |
| 2 | #1563 Codex in-app browser E2E | 2026-05-18 | Win Codex | P1 | Codex 振分済 |
| 3 | #1568 claude mcp serve エージェント | 2026-05-17 | Win Codex | P1 | Codex 振分済 |
| 4 | #1628 NotebookLM fleet Multi-Agent反映 (本 Issue) | 2026-05-17 | Win Claude | P1 | 本 PR で完了 |
| 5 | MCP エコシステム固有機能深化 | 2026-06-30 | Win Claude | 中 | Q2 継続 |

### Win Claude Q2 注力 3 テーマ

```
テーマ A: Mobile presence (= Google 攻勢前に確立)
  → Issue #1495 設計 spec ship → Codex hand off

テーマ B: Memory architecture 深化 (= Anthropic MCP moat 活用)
  → PreCompact hook + Agent SDK 移行検討 → BRAIN-32 7/7 維持

テーマ C: Competitive intelligence 継続 (= NotebookLM pipeline)
  → 月次 5 本蒸留 → fleet 戦略文書更新サイクル (本 doc が第 1 例)
```

### Win Codex Q2 注力 3 テーマ

```
テーマ D: E2E automation 強化 (= Devin 対抗 / visual validation)
  → Issue #1563 in-app browser + SYNERGY 原則 #7

テーマ E: MCP server 実装 (= claude mcp serve エージェント)
  → Issue #1568 + MCP-AUTH 10 原則遵守

テーマ F: Karpathy Compile/Lint cycle 維持
  → wiki-compile + wiki-lint weekly cycle
```

---

## PHILOSOPHY-22 9/9 チェック

| 原則 | ✅/❌ | 確認内容 |
|------|------|---------|
| 1. CEO 感 | ✅ | fleet 行動指針はユーザーの最終判断を支援 / 自動化 override なし |
| 2. ミッション駆動 | ✅ | 競合分析 = 自分株式会社の成長ミッションに直結 |
| 3. 優しい mentor | ✅ | strategic intel はプレッシャーでなく意思決定支援 |
| 4. 6 部署バランス | ✅ | R&D (tech stack) + マーケ (competitor) + 人事 (fleet roles) + 財務 (cost) 網羅 |
| 5. 商品 = 価値 | ✅ | fleet 最適化 = ユーザーの開発時間価値増大 |
| 6. 資本 = 時間 | ✅ | 役割分離で総工数最小化 / Codex 安価 task routing |
| 7. 資産 vs 負債 | ✅ | 戦略 intelligence = 知識資産 / stale doc は即 update |
| 8. KPI = 昨日の自分 | ✅ | Q2 指針は Q1 実績 (part 98-158) との比較で設定 |
| 9. IPO / ウェルビーイング | ✅ | mobile release + competitive positioning = IPO 準備 |

**判定: 9/9 ✅ 実装可**

---

## SYNERGY-30 7/7 チェック

| 原則 | 状態 | Q2 対応 |
|------|------|---------|
| #1 Strict Instance Routing | ✅ | 本 doc の Q2 matrix で更新 |
| #2 Plan-Execute-Review | ✅ | 設計 spec → Codex 実装 → Claude review = 継続 |
| #3 Automate Feature Monitoring | 🟡 | ai-tool-changelog-watch.yml 稼働中 |
| #4 Pointer-Based Config | ✅ | 本 doc が pointer / CLAUDE.md ≤ 80 行維持 |
| #5 Memory Continuity | ✅ | SessionStart/End hooks + NotebookLM |
| #6 Deterministic Guardrails | ✅ | dart format + flutter analyze 強制 |
| #7 Visual/GUI Validation | 🟡 | Issue #1563 = Codex 視覚 E2E 強化 |

**判定: 7/7 ✅ (うち 2 件 🟡 = Q2 強化中)**

---

## 6. Design-Agent Convergence — 2026 Q2 trend

> **追加日**: 2026-05-08 / Win版#132 part 178 / Issue [#1750](https://github.com/kanta13jp1/my_web_app/issues/1750) (NotebookLM `0fc0b6cf` 蒸留)
> **ソース**: NotebookLM Notebook [AI Competitive Monitoring Report: The Design-Agent Convergence (`0fc0b6cf-7d34-45d3-bea3-ca843cdf2ee9`)](https://notebooklm.google.com/notebook/0fc0b6cf-7d34-45d3-bea3-ca843cdf2ee9)
> **scope 注意**: VSCode 版 (= UI 担当 / 旧 12 instance) は part 130 で **dormant**. 本章は **将来 VSCode 復活 or Win Claude UI design role 拡張時の参照点** として stub 化.

### 業界 trend (= 2026 Q2)

| 動向 | 内容 | 競合 21 社への波及 |
|------|------|---------------------|
| **Figma + Make / AI 統合** | Figma Make (= 2025 H2 GA) で design → code 直結 | `figma` MCP server で AI agent ↔ Figma 双方向化 (= 自分株式会社既統合) |
| **Anthropic Labs / Claude Design** | SaaS で design handoff bundle 配布 (= 2026 Q1 announcement) | `claude-design-handoff` skill 既設 / Flutter widget skeleton + DESIGN.md 差分生成 |
| **AIDesigner MCP** | URL → brand kit 自動抽出 → variation board 9 枚生成 | `aidesigner` MCP 既統合 / brand kit `cfd7afdc` 等で本番アイコン生成 (part 161-162) |
| **21st Magic** | inspiration → component → refiner pipeline | `magic` MCP 既統合 / UI 競合監視に転用可 |
| **Penpot AI** | Figma 競合 OSS が AI 生成機能追加 | 監視継続 / lock-in 回避層として注視 |
| **Vercel v0 / Bolt.new** | プロンプト → React app full-stack 生成 | Flutter Web では直接競合せず / inspiration 取材源 |

### 自分株式会社 design pipeline 現状 (= 2026-05-08)

| 軸 | tool | 状態 | scope |
| --- | --- | --- | --- |
| design tokens | `docs/DESIGN.md` (Orange+Indigo dark) | ✅ single source of truth | 全 Flutter widget |
| Figma 統合 | `figma` MCP | ✅ read + Code Connect | dormant (= VSCode版 担当) |
| brand kit 生成 | `aidesigner` MCP | ✅ part 161-162 で実証 | Win Claude (= triage / icon ship) |
| handoff | `claude-design-handoff` skill | ✅ 既設 | Win Claude or Codex 実装側 |
| review | `design-skills` agent | ✅ 既設 | Win Claude UI レビュー時 |
| component 生成 | `magic` MCP / `frontend-design` skill | 🟡 未実用化 | 将来 |

### Q2-Q3 アクション (= stub)

1. **dormant scope 維持**: VSCode版 復活 trigger (= mobile UAT 連携 / 月次 UI design review 必要時) を `docs/MULTI_INSTANCE_FLEET.md` 改訂で明示 (= 別 Issue 候補)
2. **Win Claude UI role 拡張時**: `design-workflow` skill (= Figma + AIDesigner + design-skills + DESIGN.md) を 1 session triage routine 化
3. **競合 21 社 design layer 監視**: `competitor-monitoring.yml` daily cron に Figma + Penpot + Bolt 系 changelog 取込 (= Codex hand-off 候補 / 別 Issue)
4. **AI 大学 design module**: 既 AI 大学 4 本 (= 動画) に「design × AI 統合」module 追加 (= Faceless Channel パターン (= `AI_VIDEO_PRINCIPLES.md` Faceless 章) と相互利用)

### 関連 Issue

- [#1750](https://github.com/kanta13jp1/my_web_app/issues/1750) (= 親 / 2 本蒸留): 本章で Design-Agent 半分着地. Faceless 半分は `AI_VIDEO_PRINCIPLES.md` 参照
- [#1704](https://github.com/kanta13jp1/my_web_app/issues/1704) (= 親 spec / 本 doc): part 159 起草 → part 178 で第 6 章追加
- [#1706](https://github.com/kanta13jp1/my_web_app/issues/1706) (= AI tool verify / 関連): design tool 系 update も verify-first 適用

---

*Win版#132 part 159 / 2026-05-07 / Issue #1704 / 5 NotebookLM 戦略系蒸留 → 2-instance fleet Q2 戦略反映 / PHILOSOPHY-22 9/9 ✅ / SYNERGY-30 7/7 ✅ / BRAIN-32 7/7 ✅ / 2026-05-08 part 178 で Design-Agent Convergence 第 6 章追加 (= NotebookLM 0fc0b6cf / Issue #1750)*
