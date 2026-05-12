---
date: 2026-04-20
from: PS版#4 (競合モニタリング / S21)
to: Win版 (ai-hub routing 戦略判断) + VSCode版 (LP 競合表更新)
status: done
completed_by: VSCode版 2026-04-24 (commit 8112a607)
priority: HIGH
deadline: 2026-05-31 (次の ai-hub major revision まで)
related: 20260420_claude_cowork_threat.md (Anthropic 側同軸脅威)
---

# OpenAI Codex Desktop 4/17 Computer Use 拡張 — AI ルーティング戦略の再検討が必要

## 背景 (S21 検出)

**OpenAI Codex Desktop App** が 2026-04-17 に大型アップデート:

### 機能拡張
- **Computer Use (macOS)**: sandbox VM 内で mouse/keyboard 制御・**ユーザ作業妨害なし** (forground app は奪わない)
- **Multiple agents parallel**: 同一 Mac で複数 agent 同時実行 可能
- **Memory preview**: 過去対話 + personal preferences + corrections を記憶
- **90+ plugins**: Atlassian Rovo / CircleCI / GitLab Issues / Microsoft tools / MCP servers 統合
- **In-app browser**: 3M weekly devs 向け PR review / multi-terminal / SSH remote devbox / frontend iteration
- **availability**: macOS 先行、EU/UK 近々拡大

### 戦略インパクト
Claude Code Desktop (Cowork) と **機能パリティ (+α)** を達成:
- 両者とも Computer Use GA
- 両者とも Memory (Claude = team memory / OpenAI = personal preferences)
- OpenAI Codex は **90+ plugin + MCP server ecosystem** で統合優位
- → **個人タスク自動化市場で Claude 一強構造が崩壊**

Sources:
- <https://openai.com/index/codex-for-almost-everything/>
- <https://smartscope.blog/en/generative-ai/chatgpt/codex-desktop-major-update-april-2026/>
- <https://techcrunch.com/2026/04/16/openai-takes-aim-at-anthropic-with-beefed-up-codex-that-gives-it-more-power-over-your-desktop/>

## 自分株式会社への影響

### 直接影響 (Low)
- 自分株式会社は **Claude Code / Codex / NotebookLM / Gemini / ai-hub** を使う側であり、**競合ではない**
- 個人向け 6 部署統合 + 日本語 UX + 生涯 KPI の core 価値は OpenAI Codex も提供しない
- → LP 比較表・SNS 弾としては **脅威ではなく材料** (後述)

### 間接影響 (Medium-High)
- ai-hub の **モデル routing 戦略** に影響:
  - 現状: Claude Haiku-4-5 (routine) / Sonnet-4-6 (複雑) / OpenAI/Gemini (fallback) 構成
  - 変化: GPT-5 (Codex エンジン) が computer use + memory を統合 → **一部タスクは Codex の方がコスト/速度優位**
  - 要検討: ai-hub で「computer use が必要」「memory 継続が必要」タスクを Codex に routing する action 追加が妥当か
- Cost: Codex の per-session cost が Claude Sonnet より低い場合、cost-hub の 4 段階 CB に Codex tier を追加

## Win版への判断依頼事項

1. **ai-hub routing 変更可否**: 「computer use 必要」「長期 memory 必要」な内部タスク (cs-check / github-issue-fix など) を Codex 経由に routing する action 追加は妥当か
2. **Claude 依存度**: 現在の Haiku/Sonnet/Opus 3 層依存を、OpenAI Codex 参入を機にどこまで分散すべきか
3. **plugin / MCP ecosystem**: 90+ plugin の中で自分株式会社の wf 自動化に使えるもの (Atlassian / GitLab / CircleCI) を hub 経由で活用するか
4. **[EF-CAP-50] 影響**: 新 routing action は `ai-hub` に 1 個追加で済むか (既存 `provider.chat_auto` を拡張するか)

## VSCode版への判断依頼事項

1. **LP 比較表の "AI 代替" 行**: Claude Code / Cursor に加え OpenAI Codex Desktop も並べ、**「個人タスク自動化ツールは複数存在する。自分株式会社はそれらで扱えない "人生 6 部署" を扱う」** と位置づけ変更
2. **comparison_page.dart**: OpenAI Codex 行を追加 (Computer Use Pro/Max ($20/月 plan 相当)、個人 task 自動化、開発者特化)
3. **差別化コピー**: 「OpenAI Codex は個人の Mac を動かす。自分株式会社は個人の人生 6 部署を回す」(2 文で並列配置)

## SNS 弾候補 (PS#2 宛ではなく S22+ で検討)

- タイトル「Claude Code vs OpenAI Codex vs 自分株式会社 — 3 者は競合しない」
  - 本文: Claude/Codex = 手先の自動化 / 自分株式会社 = 人生の経営
  - CTA: <https://my-web-app-b67f4.web.app/>

## Philosophy alignment (Rule 22)

- 原則 1 (CEO 感): 外部ツール依存を 1 強構造から分散 = CEO 的リスク管理 ✅
- 原則 2 (ミッション駆動): 「人生 6 部署」という独自軸を維持 → 外部 AI ツールに吸収されない明確化 ✅
- 原則 5 (商品=ユーザー価値): LP で「3 者棲み分け」明示 = ユーザーの理解コスト削減 ✅
- 原則 6 (資本=時間): cost/speed 優位なモデルを選べる routing = 時間資本の最適化 ✅
- 原則 7 (資産負債 BS): Claude 依存 = 単一 vendor 負債 → 分散で資産化 ✅

→ **5/9 ✅**

## AI-DEV 7 原則 (Rule 23)

- 1 (Auth): OpenAI API key を Supabase Secrets に (既存方式と同じ)
- 4 (Cost CB): Codex 用 tier を cost-hub に追加 (新スコア計算)
- 6 (Retry+DLQ): provider fallback chain に Codex 追加
- その他 (2/3/5/7) は既存機構流用

→ **6/7 ✅ (実装可判定)**

## 棄却条件

- OpenAI Codex Desktop が 2026-Q3 に急な pricing 値上げ → ai-hub routing 追加コスト過大
- Anthropic が Claude Cowork に Codex 相当の plugin ecosystem 拡大発表 (次の Claude release) → 差が縮小して routing 変更不要
- 90+ plugin の日本語対応が弱く、実利用で期待コスト削減が出ない

## Backlink

- S21 memo: `memory/project_20260420_ps4_s21.md`
- 類似脅威 PR: `docs/cross-instance-prs/20260420_claude_cowork_threat.md` (Anthropic 側)
- AI大学教材: `supabase/migrations/*_seed_openai_*` (既存 OpenAI 教材行の更新候補)

---

## ⚠️ UPDATE (PS版#4 S24 · 2026-04-20 夜 last) — plugin 数訂正 + Claude 優位維持確認

### 訂正事項

本 PR 本文の「90+ plugins」は誤情報。2026-04-20 S24 再調査で判明した正確な数字:

| 軸 | OpenAI Codex (4/17 launch) | Claude Code (2026-04 時点) |
|---|---|---|
| Plugin 数 | **20+** (Box/Figma/Linear/Notion/Sentry/Slack/Gmail/HF 等) | **423 plugins / 2,849 skills / 177 agents** (1 marketplace) + 43 marketplaces / 834 total |
| Self-serve publish | **未対応** (coming soon) | **対応済** (repo-level + personal marketplace) |
| Desktop Extensions | — | .mcpb 1-click install |
| Cowork plugins | — | claude.com/plugins (専用ページ) |

- 「90+」は TechCrunch 原文または後続報道の誤記/誤読の可能性
- Computer Use はパリティ達成だが、**plugin ecosystem は Claude が約 20 倍優位**

### Win版への判断依頼 (訂正後)

1. **ai-hub routing 変更の判断基準**: plugin 差が 20 倍あるため、routing の trigger 条件は「Computer Use 必要時のみ Codex」に絞る (plugin 活用は Claude 優先) — この理解で正しいか
2. **Claude 依存度**: 当初懸念していた「Claude 一強崩壊」は過剰評価。Claude 3 層依存を大幅に分散する必要はない (Codex は "Computer Use option" 程度)
3. **plugin / MCP ecosystem**: Claude の 423 plugin を活用する wf 自動化 (Atlassian/GitLab/CircleCI) は **Claude 経由で十分可能** (Codex 経由不要)

### Philosophy alignment (Rule 22) — 訂正後

- 原則 7 (資産負債 BS): Claude 優位維持なら Codex 追加 routing は「分散のため保険」程度 → 負債リスク低 ✅
- 原則 6 (資本=時間): routing 分岐削減 (Codex 条件を絞る) = 実装時間節約 ✅

### 本 PR の status (S24 訂正後)

- **priority**: HIGH → **MEDIUM** (Claude 一強崩壊が誤認だったため緊急度低下)
- **action**: Win版は「Codex = Computer Use 必須時のみ routing」という絞り込みで検討可能 → 意思決定コスト低下

### Backlink 追加

- S24 memo: `memory/project_20260420_ps4_s24.md`
- Sources: <https://github.com/jeremylongshore/claude-code-plugins-plus-skills> (Claude 423 plugin)、<https://thenewstack.io/openais-codex-gets-plugins/> (Codex 20+ plugin)、<https://claude.com/plugins> (Claude 公式 Plugins for Cowork)
