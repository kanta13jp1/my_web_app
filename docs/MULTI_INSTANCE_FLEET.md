# 2-Instance Fleet Manifest — 自分株式会社 開発体制

> **2026-05-04 (Win版#132 part 130) 更新**: 開発環境のメモリ / token 制約により、**12 instance fleet (旧体制)** から **2 instance 制 (Claude Code Win版 + Codex CLI Win版)** に縮小. 旧 10 instance は **dormant** (= archive / 物理削除しない / 将来制限解除時に reactivation 可能).
>
> このドキュメントは 自分株式会社 の開発体制を構成する **2 instance** の **canonical (唯一の正規) ロスター** である.
>
> **位置づけ**: CLAUDE.md `[WORKDIR-ISOLATION]` rule + `[INSTANCE-ROLES]` rule の運用台帳.
> **運用憲章 (5 正本 + 6 AI 役割 + 監査)**: [`docs/OPERATIONS_CHARTER.md`](./OPERATIONS_CHARTER.md) を併せて参照.
> **移行ログ**: [`docs/FLEET_2_INSTANCE_TRANSITION.md`](./FLEET_2_INSTANCE_TRANSITION.md).

## 2026-05-07 AI Tool Update Overlay (#1706)

- Keep the active fleet at exactly two local app instances: **Claude Code #1 (Windows app)** for architecture/review/docs triage and **Codex #1 (Windows app)** for scoped implementation PRs, CI, merge, and cleanup.
- Treat Claude fullscreen/TUI rendering, remote notifications, Codex memory, Gemini fallback models, and GitHub Copilot agent updates as **verify-first capabilities**. Enable or document them only after checking the official source links recorded in [`AI_FALLBACK_RUNBOOK.md`](./AI_FALLBACK_RUNBOOK.md).
- Smartphone/push handoff is an escalation channel, not a third active instance. It may notify the human owner or surface UAT context, but implementation still returns to Claude Code #1 + Codex #1.
- `scripts/check_versions.py --web` is the lightweight session-start evidence command for this overlay. It prints official URLs and detects Codex instruction/memory pointers without starting dev servers or large local processes.

---

## 現行 2 instance (= active)

| スロット | worktree path | branch | 推奨モデル / モード | 主担当領域 |
| --- | --- | --- | --- | --- |
| **Win版 (Claude Code)** | `C:/Users/kanta/GitHub/my_web_app` (= main / + ad-hoc worktree) | `claude/<part-name>` (= part 毎自動 worktree) | claude-opus-4-7 (1M ctx) / claude-sonnet-4-6 / claude-haiku-4-5 (Auto Mode) | **architect / 設計 / docs / memory / UI design / Rule17 WF health / triage / blog dispatch / AI 大学 / 競合モニタリング / mobile UAT / 動画 pipeline** |
| **Win版 (Codex CLI)** | `C:/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-codex` (= 推奨) | `codex/<task-name>` (= task 毎 worktree) | OpenAI Codex CLI 0.128.0+ (= Memory GA 機能利用) | **実装 / 修正PR / SQL・migration / EF Deno / GHA workflow / EF整理 / stale移行 / 競馬モデル / horizontal 調査 / wiki Compile cycle** |

### 役割分担 cheat-sheet

| task | 担当 |
| --- | --- |
| 設計判断 / アーキテクチャ / ADR | Win版 (Claude Code) |
| 文書 / docs / memory / cross-instance-pr | Win版 (Claude Code) |
| Flutter UI 設計 / DESIGN.md / design-skills | Win版 (Claude Code) |
| Rule17 WF health / Issues triage | Win版 (Claude Code) |
| AI 大学コンテンツ追加 / 競合モニタリング | Win版 (Claude Code) |
| Mobile UAT triage / GitHub MCP | Win版 (Claude Code) |
| 動画 pipeline (= NotebookLM → ffmpeg → YouTube) | Win版 (Claude Code) |
| Schedule Tasks (= cs-check / ai-tool-watch / etc) | GHA cron (Claude 非依存設計済) |
| 実装 / 修正 PR / 横断調査 | Win版 (Codex CLI) |
| SQL / migration レビュー / Supabase schema | Win版 (Codex CLI) |
| Edge Function (Deno) 実装 / 修正 | Win版 (Codex CLI) |
| GHA workflow yml 修正 / CI auto-fix | Win版 (Codex CLI) |
| stale EF 整理 / anon-guard / bulk 修正 | Win版 (Codex CLI) |
| T-1 ブログ dispatch (= dev.to / Qiita) | Win版 (Codex CLI) (= scripts/t1-dispatch.sh 実行) |
| 競馬予想モデル / ML harness | Win版 (Codex CLI) |
| Karpathy 4 サイクル の Compile/Lint cycle | Win版 (Codex CLI) |

---

## 並列性は失われない

「2 instance になったら並列性 0」と誤解しがちだが、**GHA cron infra が並列性を維持**する:

| cron | 周期 | 担当 |
| --- | --- | --- |
| `ai-tool-watch.yml` | daily 06:15 JST | Claude API + Gemini fallback |
| `codex-session-safety-cron.yml` | daily 07:00 JST | scripts/codex_session_check.py |
| `session-residuals-sync.yml` | daily 02:30 JST | scripts/session_residuals_to_issue.py |
| `notebooklm-issue-crosscheck.yml` | daily 04:00 JST | scripts/notebooklm_issue_crosscheck.py |
| `knowledge-vault-lint.yml` | weekly | scripts/knowledge_vault_lint.py |
| `cs-check.yml` | hourly | EF + Slack |
| `infra-health-check.yml` | hourly | EF |
| `ai-university-update.yml` | daily | RSS only (Claude 非依存) |
| `competitor-monitoring.yml` | daily | EF + WebSearch |
| `competitor-discovery.yml` | weekly | EF |
| `quota-monitor.yml` | hourly | gh API |
| (= 他 30+ workflow) | various | various |

= **fleet 並列性は workflow 経由で維持**. 2 instance はあくまで「同時稼働する人間判断 instance」の数.

---

## 旧 12 instance (= dormant / 2026-05-04 retired)

| 旧 instance | 旧 worktree path | 統合先 | dormant 状態 |
| --- | --- | --- | --- |
| **PS版#1** | `.claude/worktrees/instance-ps1` | Win版 (Claude Code) → Rule17 WF health 担当 | worktree 残存 / 新作業停止 |
| **PS版#2** | `.claude/worktrees/instance-ps2` | Win版 (Codex CLI) → T-1 dispatch | worktree 残存 / 新作業停止 |
| **PS版#3** | `.claude/worktrees/instance-ps3` | Win版 (Claude Code) → AI 大学 | worktree 残存 / 新作業停止 |
| **PS版#4** | `.claude/worktrees/instance-ps4` | Win版 (Claude Code) → 競合モニタリング | worktree 残存 / 新作業停止 |
| **PS版#5** | `.claude/worktrees/instance-ps5` | Win版 (Codex CLI) → EF 整理 | worktree 残存 / 新作業停止 |
| **PS版#6** | `.claude/worktrees/instance-ps6` | Win版 (Codex CLI) → 競馬モデル | worktree 残存 / 新作業停止 |
| **VSCode版** | `.claude/worktrees/instance-vscode` | Win版 (Claude Code) → UI design + Flutter 編集 | worktree 残存 / 新作業停止 |
| **WEB版** | (worktree なし / GitHub MCP のみ) | Win版 (Claude Code) → リモート PR / Issue 管理 | 機能継承 |
| **📱 スマホ版** | (worktree なし) | Win版 (Claude Code) → 実機 UAT triage (= GitHub MCP 経由) | 機能継承 |
| **Codex#1** | `.claude/worktrees/instance-codex1` | Win版 (Codex CLI) → 横断調査 | worktree 残存 / 新作業停止 |
| **Codex#2** | `.claude/worktrees/instance-codex2` | Win版 (Codex CLI) → CI / EF / GHA | worktree 残存 / 新作業停止 |
| Codex ad-hoc (codex1-codex8 等) | `.claude/worktrees/codex*-*` | Win版 (Codex CLI) → 順次 main へ merge or 削除 | 残存 87 worktree が lazy cleanup 対象 |

---

## 再起動条件 (= reactivation triggers)

以下のいずれかが発生したら、対応する旧 instance を re-activate する:

1. **メモリ / token 制約解除** (= Claude Pro / Codex CLI quota の余裕回復)
2. **並列作業需要発生** (= 同時に 3+ 領域で大規模変更が必要)
3. **特定 instance 専門スキル必要** (= 例: Mobile UAT で大量実機 testing → スマホ版 reactivation)

reactivation 手順:
1. 該当 worktree の `git pull --rebase origin main` で最新化
2. `~/.claude/hooks/inject-rules.txt` の `[INSTANCE]` rule に対象 instance を再追加
3. `docs/MULTI_INSTANCE_FLEET.md` の本ドキュメントの「現行 active」表に該当行を移動
4. cross-instance-pr で fleet 全体 (= 当時 active な instance) に reactivation 通知

---

## 関連 docs

- [`docs/FLEET_2_INSTANCE_TRANSITION.md`](./FLEET_2_INSTANCE_TRANSITION.md) — 移行ログ
- [`docs/AI_FLEET_SYNERGY_PLAYBOOK.md`](./AI_FLEET_SYNERGY_PLAYBOOK.md) — fleet 運用 7 原則 (= 2 instance に縮小しても妥当)
- [`docs/AI_FALLBACK_RUNBOOK.md`](./AI_FALLBACK_RUNBOOK.md) — quota 超過時 fallback
- [`docs/OPERATIONS_CHARTER.md`](./OPERATIONS_CHARTER.md) — 運用憲章 (5 正本 + 6 AI 役割)
- [`docs/CODEX_MEMORY_AUTOMATIONS.md`](./CODEX_MEMORY_AUTOMATIONS.md) — Karpathy 4 サイクル + cron infra
- `~/.claude/hooks/inject-rules.txt` — 毎ターン inject される rule (= `[INSTANCE]` `[WORKDIR-ISOLATION]` `[INSTANCE-ROLES]`)

---

## Q2-Q3 Fleet Roadmap (2026-05-07〜2026-09-30)

> **ソース**: `docs/STRATEGIC_INTELLIGENCE_2026Q2.md` — 5 NotebookLM 戦略系蒸留より導出 (= Win版#132 part 159).

### Win Claude (architect) Q2-Q3 優先テーマ

| 期限 | テーマ | Issue / 成果物 | 優先 |
|------|--------|---------------|------|
| 2026-05-30 | **Mobile presence 確立** (= Google I/O 攻勢前) | Issue #1495 設計 spec ship → Codex hand off | P0 |
| 2026-06-30 | **Memory architecture 深化** | PreCompact hook (Issue #1564) + Agent SDK 移行検討 | P1 |
| 2026-07-31 | **Competitive intelligence pipeline** | 月次 5 本蒸留 → fleet 戦略文書更新 (本 doc 改訂サイクル) | P1 |
| 2026-09-30 | **MCP エコシステム固有機能深化** | claude mcp serve + SubagentStart/Stop hooks 活用 | P2 |

### Win Codex (worker) Q2-Q3 優先テーマ

| 期限 | テーマ | Issue / 成果物 | 優先 |
|------|--------|---------------|------|
| 2026-05-18 | **Codex in-app browser E2E 視覚検証** | Issue #1563 | P1 |
| 2026-05-17 | **claude mcp serve エージェント統合** | Issue #1568 | P1 |
| 2026-06-30 | **Karpathy Compile/Lint cycle 継続** | weekly wiki-compile + wiki-lint | P2 |
| 2026-07-31 | **iOS/Android 自動配布 CI** | Issue #1495 実装 phase | P0 |

### 12-month fleet 方向性 (2026 Q3-Q4)

```
現状 (Q2):  Win Claude (architect) + Win Codex (worker) = 2 active instance
           + 30+ GHA cron workflow (並列性維持)

Q3 検討:   モデル upgrade (claude-opus-4-7 GA → Sonnet 4.6 cost 最適化)
           Agent SDK 移行 (tools-hub EF → native Agent orchestration)

Q4 検討:   reactivation トリガー確認 (= メモリ制約解除 or 並列需要)
           mobile (実機) UAT 専任 instance 復活候補 (= 旧スマホ版)
```

**reactivation criteria (変更なし)**: 上記「再起動条件」セクション参照.

---

## 改訂履歴

| 日付 | 変更 | 担当 |
| --- | --- | --- |
| 2026-04-28 | 初版 (10 Claude + 2 Codex = 12 スロット fleet manifest) | Win版#132 part 44 |
| 2026-05-04 | **12 → 2 instance 制縮小** (= Win Claude + Win Codex / 旧 10 dormant) | Win版#132 part 130 |
| 2026-05-07 | **Q2-Q3 fleet roadmap 追加** (= STRATEGIC_INTELLIGENCE_2026Q2.md 蒸留) | Win版#132 part 159 |
