# 自分株式会社 — Claude Code 設定

> **Win版#132 part 133 (2026-05-05)**: Karpathy 80 行 KPI 達成 (= 旧 463 行 → 80 行).
> 詳細は `docs/` (= 12 軸 principle + 12 運用) に分散. 本ファイルは pointer hub.

## 必読 docs (= 12 軸 principle / 設計判断前に参照)

- [`docs/PHILOSOPHY.md`](docs/PHILOSOPHY.md) — 9 原則 (CEO 感 / ミッション / mentor / 6 部署 / 商品=価値 / 資本=時間 / 資産負債 / KPI / IPO)
- [`docs/AI_DEV_PRINCIPLES.md`](docs/AI_DEV_PRINCIPLES.md) — 7 原則 (Auth / deny-by-default / trace_id / circuit-breaker / memory / DLQ / quality-gate)
- [`docs/AI_CHARACTER_PRINCIPLES.md`](docs/AI_CHARACTER_PRINCIPLES.md) — 8 原則 (人格 / 倫理)
- [`docs/IMBUE_PATTERNS.md`](docs/IMBUE_PATTERNS.md) — 7 パターン (UX / AI 体験設計)
- [`docs/COLLAB_AI_PATTERNS.md`](docs/COLLAB_AI_PATTERNS.md) — 7 パターン (Tinker / Co-Reasoning / Red-Team)
- [`docs/AI_VIDEO_PRINCIPLES.md`](docs/AI_VIDEO_PRINCIPLES.md) — 動画 pipeline
- [`docs/VIBE_CODING_PRINCIPLES.md`](docs/VIBE_CODING_PRINCIPLES.md) — 責任ある AI コーディング
- [`docs/PLATFORM_EVOLUTION_PRINCIPLES.md`](docs/PLATFORM_EVOLUTION_PRINCIPLES.md) — 成長戦略
- [`docs/SECOND_BRAIN_PRINCIPLES.md`](docs/SECOND_BRAIN_PRINCIPLES.md) — Karpathy 4 サイクル
- [`docs/INDIE_DEV_VELOCITY_PRINCIPLES.md`](docs/INDIE_DEV_VELOCITY_PRINCIPLES.md) — indie 7 原則
- [`docs/AI_FLEET_SYNERGY_PLAYBOOK.md`](docs/AI_FLEET_SYNERGY_PLAYBOOK.md) — fleet 7 原則
- [`docs/MCP_AUTH_SECURITY_PRINCIPLES.md`](docs/MCP_AUTH_SECURITY_PRINCIPLES.md) — MCP 10 原則

## 運用 docs

- [`docs/AI_DRIVEN_DEV_OPERATING_MODEL.md`](docs/AI_DRIVEN_DEV_OPERATING_MODEL.md) — **AI 駆動開発 運用モデル v1 (canonical)** = 3 レーン (L1 Antigravity+Gemini 探索 / L2 VSCode+Codex 実装 / L3 VSCode+Claude 設計) + SDLC 7 工程 + セッション儀式
- [`docs/MULTI_INSTANCE_FLEET.md`](docs/MULTI_INSTANCE_FLEET.md) — fleet roster (L2/L3 = Win Codex + Win Claude / L1 Antigravity = user 実行 / 旧 12 dormant)
- [`docs/SUBAGENT_ORCHESTRATION_POLICY.md`](docs/SUBAGENT_ORCHESTRATION_POLICY.md) — guarded child subagents under Claude Code #1 / Codex #1
- [`docs/AI_FALLBACK_RUNBOOK.md`](docs/AI_FALLBACK_RUNBOOK.md) — quota 超過時 fallback
- [`docs/DEV_PROCESS_MULTI_AI.md`](docs/DEV_PROCESS_MULTI_AI.md) — AI 振り分け matrix
- [`docs/SCHEDULE_TASKS.md`](docs/SCHEDULE_TASKS.md) — Schedule cron 自動化
- [`docs/CODEX_MEMORY_AUTOMATIONS.md`](docs/CODEX_MEMORY_AUTOMATIONS.md) — 25 task ownership
- [`docs/OPERATIONS_CHARTER.md`](docs/OPERATIONS_CHARTER.md) — 運用憲章 (5 正本 + 6 AI 役割)
- [`docs/AGENT_COORDINATION_PATTERNS.md`](docs/AGENT_COORDINATION_PATTERNS.md) — 5 協調パターン (= 通信規約軸)
- [`docs/AGENT_ORCHESTRATION_PATTERNS.md`](docs/AGENT_ORCHESTRATION_PATTERNS.md) — 5 編成パターン (= sub-agent 解禁 / 部 221u ship / ① Sub-Agent ② Outcomes Loop ③ Architect-Implementer ④ Memory+Dreaming ⑤ Phased Preamble)
- [`docs/NOTEBOOKLM_GUIDE.md`](docs/NOTEBOOKLM_GUIDE.md) — NotebookLM + DBS + Master Brain
- [`docs/DESIGN.md`](docs/DESIGN.md) — UI design tokens
- [`docs/DIRECTORY_STRUCTURE.md`](docs/DIRECTORY_STRUCTURE.md) — リポジトリ ディレクトリ
- [`docs/EDGE_FUNCTION_LIST.md`](docs/EDGE_FUNCTION_LIST.md) — EF 一覧
- [`docs/DEVELOPMENT_ACHIEVEMENTS_FORMAT.md`](docs/DEVELOPMENT_ACHIEVEMENTS_FORMAT.md) — migration 命名 + seed 形式
- [`docs/FLEET_2_INSTANCE_TRANSITION.md`](docs/FLEET_2_INSTANCE_TRANSITION.md) — 12→2 instance 移行ログ
- [`docs/PROMPT_CACHING_OPUS47_COST_GUIDE.md`](docs/PROMPT_CACHING_OPUS47_COST_GUIDE.md) — Prompt Caching × Opus 4.7 (= 88% コスト削減 / Issue #1756)

## Facts

- 技術: Flutter Web + Supabase (PostgreSQL + Edge Functions / Deno) + Firebase Hosting + GHA
- 本番: <https://my-web-app-b67f4.web.app/>
- 競合 21 社: notion / evernote / moneyforward / slack / chatwork / x / animaworks / claude-code / codex / netkeiba / openclaw / claude-cowork / jobcan / amazon / google / microsoft / discord / line / facebook / liven / github
- migration 命名: `YYYYMMDDHHMMSS_descriptive_name.sql` (= 詳細 [`docs/DEVELOPMENT_ACHIEVEMENTS_FORMAT.md`](docs/DEVELOPMENT_ACHIEVEMENTS_FORMAT.md))
- behavioral rules: `~/.claude/hooks/inject-rules.txt` (= 毎ターン inject / `[INSTANCE]` `[WORKDIR-ISOLATION]` `[INSTANCE-ROLES]` `[PHILOSOPHY-22]` `[AI-DEV-23]` 等)

## Session ritual

- **開始**: `~/.claude/projects/.../memory/MEMORY.md` 参照 + `notebooklm use ea6cff25` (= jibun-master-brain / use は ID prefix のみ) で過去判断確認 (= NotebookLM は **kanta13jp@gmail.com 側** / `NOTEBOOKLM_HOME=~/.notebooklm-gmail` を settings.json env で自動適用。default `~/.notebooklm` = ml-mightylink 側 / 他プロジェクト用。詳細 [`docs/NOTEBOOKLM_GUIDE.md`](docs/NOTEBOOKLM_GUIDE.md))
- **終了**: `/wrap-up` skill (= memory + NotebookLM 蓄積 + 次回 candidate 3-5 件 必須)
- **手動 skill**: `/session-start-check` `/rule17-wf-health` `/blog-publish-cleanup` `/wrap-up`
- **自動化**: 5 daily cron (= ai-tool-watch / safety / residuals / crosscheck / wiki-compile) + 30+ workflow

### Claude Code v2.1.126 session aids

- Run `/recap` when resuming a stale or handed-off session; disable away summaries with `CLAUDE_CODE_ENABLE_AWAY_SUMMARY=0` only when the summary itself is noisy.
- Use `/focus` during parallel fleet work to reduce transcript clutter; keep task state in the issue, PR, or WBS entry so the focus view does not become the source of truth.
- Use mobile push notifications only for actionable remote-control events such as CI completion, blocked secrets, or schedule tasks that need the user's decision.
- Enable gateway model discovery only for an Anthropic-compatible Messages API gateway that implements `/v1/models`: set `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`, then prefer the `/model` picker over hard-coded names. Do not treat discovery as an Azure OpenAI or Bedrock fallback.
- `claude project purge [path]` deletes Claude project state, not the Git worktree. After verifying git status and the pushed branch/PR, preview with `claude project purge --dry-run [path]`, use the interactive confirmation, and perform Git cleanup separately.

## Quota fallback

Claude Code quota 超過 → Codex CLI / Antigravity / GitHub Copilot で継続し、Gemini Code Assist Agent Mode は Standard/Enterprise license 確認時のみ使用. Dart/Flutter widget・async/Isolate 作業は Dart 3.9+ の SDK 内蔵 `dart mcp-server` を `.gemini/settings.json` から接続し、`/mcp` で確認する. PR レビューは Gemini 1.5 Flash 自動 fallback. GHA cron 大半は Claude 非依存設計済 → 影響なし. 詳細: [`docs/AI_FALLBACK_RUNBOOK.md`](docs/AI_FALLBACK_RUNBOOK.md).

## Karpathy 4 サイクル (= 100% dogfood 達成 / part 132)

- **Ingest**: `scripts/memory_ingest.py` (part 111)
- **Compile**: `scripts/wiki_compile.py` (part 132 / `docs/concepts/` + `docs/INDEX.md` 自動生成)
- **Query**: `notebooklm` CLI (= ゼロトークンリサーチ / 詳細 [`docs/NOTEBOOKLM_GUIDE.md`](docs/NOTEBOOKLM_GUIDE.md))
- **Lint**: `scripts/knowledge_vault_lint.py` (part 105)
