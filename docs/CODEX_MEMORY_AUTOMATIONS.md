# Codex Memory + Thread Automations 定常タスク完全自律化

> **背景** (Issue [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647)):
> Codex 公式が Automations を「Issue triage / alert monitoring / CI/CD を常時稼働で拾う機能」と説明.
> NotebookLM 適用確認でも、Memory / long-running state を Codex#1 / #2 と WBS / Issue に接続する改善が未完了として挙がった.
>
> **現行運用**: 2026-05-08 時点の active fleet は **Claude Code #1 + Codex #1** の 2 instance 制.
> 旧 Codex#2 / PS#1-#6 / VSCode / WEB / mobile lane は履歴上の ownership mapping として残し、現行実装・CI lane は Codex #1 が吸収する.
>
> **目的**: 定常タスクを「人が忘れたら止まる」状態から「自走する」状態に移行.
> daily / weekly / monthly の自動化タスクと所有者 (Claude Code #1 / Codex #1 / GHA) を本ドキュメントで明示.
>
> **成果物**: 受け入れ条件を満たす GHA 自動化群 =
> `.github/workflows/codex-session-safety-cron.yml` + `.github/workflows/session-residuals-sync.yml`.

---

## 1. 自動化タスク早見表 (= ownership matrix)

| 周期 | タスク | 所有者 | 実装手段 | 出力先 | Issue/WBS 接続 |
| --- | --- | --- | --- | --- | --- |
| **daily** | AI tool changelog 監視 (Claude Code + Codex) | GHA `ai-tool-watch.yml` | `scripts/ai_tool_watch.py` | comment to Issue [#1422](https://github.com/kanta13jp1/my_web_app/issues/1422) | ✅ comment_mode=important で重要時のみ通知 |
| **daily** | infra-health-check (Supabase EF / Firebase / Storage) | GHA `infra-health-check.yml` | `scripts/infra_health.py` | `docs/incident-reports/` + Slack | ✅ 失敗時 Issue 自動作成 |
| **daily** | cs-check (未返信ticket triage) | GHA `cs-check.yml` | `scripts/cs_check.py` | `docs/cs-notes/` + Slack | ✅ Issue 自動作成 (= bug label) |
| **daily** | competitor monitoring (21 社 + Cursor + Devin) | GHA `competitor-monitoring.yml` | EF `admin-hub:competitor.check` + WebSearch | `docs/competitor-reports/` | ✅ 大変動時 Issue 自動作成 |
| **daily** | dependency audit (= npm audit + dart pub outdated) | GHA `dependency-audit.yml` | `scripts/dep_audit.py` | `docs/security-audit/` | ✅ CRITICAL/HIGH で Issue 自動作成 |
| **daily** | blog draft (T-1 dispatch dev.to + Qiita) | PS版#2 (manual) + GHA `blog-publish.yml` | `scripts/dispatch_blog.py` | `docs/blog-drafts/` | ⚠️ 手動 dispatch 必要 (= 自動化候補) |
| **daily** | AI 大学 content update (provider 追加 + content seed) | GHA `ai-university-update.yml` + PS版#3 (semi-manual) | `scripts/ai_university_*.py` | `supabase/migrations/` | ⚠️ 半手動 (= 自動化候補) |
| **daily** | daily-report (= 前日 KPI + 進捗) | Claude Code Schedule (= AI 役員会議) | EF `schedule-hub:digest.run` | `docs/daily-reports/` | — (= 報告のみ) |
| **daily** | **NEW** Codex session safety cron | GHA `codex-session-safety-cron.yml` (= 本セッション追加) | `scripts/codex_session_check.py --json` | comment to Issue [#1422](https://github.com/kanta13jp1/my_web_app/issues/1422) | ✅ warning 時 Issue 自動作成 |
| **weekly** | AI tool changelog summarize → Issue (= deep) | GHA `ai-tool-changelog-watch.yml` | `scripts/ai_tool_changelog_to_issues.py` | Issue label `ai-tool-update` | ✅ Issue 自動作成 (= 月次) |
| **weekly** | edge-function-audit (= EF 未接続検出) | GHA `edge-function-audit.yml` | EF coverage scanner | Issue label `edge-function` | ✅ Issue 自動作成 |
| **weekly** | wbs-staleness-audit (= 60 日未更新検出) | GHA `wbs-staleness-audit.yml` | EF `tools-hub:wbs.audit` | cross-instance-pr 自動作成 | ✅ md ファイル自動作成 |
| **weekly** | knowledge-vault-lint (= memory/ + docs/ orphan + broken link) | GHA `knowledge-vault-lint.yml` | `scripts/knowledge_vault_lint.py` | `docs/vault-health/health-YYYY-MM-DD.json` | ⚠️ Issue 接続未実装 (= 自動化候補) |
| **weekly** | build-in-public extract (= ROADMAP-LOG → dev.to draft) | GHA `build-in-public-extract.yml` | `scripts/build_in_public_extract.py` | `docs/build-in-public/YYYY-MM-DD_devto_draft.md` | — (= manual review 必要) |
| **monthly** | instance-role-audit (= 12 instance 役割妥当性) | GHA `instance-role-audit.yml` | `scripts/instance_role_audit.py` | `docs/instance-audit/audit-YYYY-MM.md` | ⚠️ Issue 接続未実装 (= 自動化候補) |
| **monthly** | hook-rule-audit (= inject-rules.txt の rot/重複検出) | manual (= `/hook-rule-audit` skill) | hook-rule-audit skill | inject-rules.txt 整理 commit | ❌ 手動 only (= 自動化候補) |
| **monthly** | consolidate-memory (= memory/ duplicate merge) | manual (= `/consolidate-memory` skill) | consolidate-memory skill | memory/ 整理 commit | ❌ 手動 only (= 自動化候補) |
| **monthly** | quota-monitor dashboard refresh | GHA `quota-monitor.yml` | gh API + Slack | Slack notification | ✅ Slack 通知 |
| **on-event** | workflow-failure-handler (= GHA 失敗 → Issue → cs-check) | GHA `workflow-failure-handler.yml` | gh CLI | Issue label `workflow-failure` | ✅ Message Bus pattern |
| **on-event** | feedback-issue-resolved (= Issue close → 通知メール) | GHA `feedback-issue-resolved.yml` | gh CLI + Resend | email | ✅ 通知のみ |
| **on-event** | github-issue-fix (= Issue → Claude Code 自動修正 PR) | GHA `github-issue-fix.yml` | Anthropic API | PR | ✅ Claude が自動 PR |
| **on-event** | ci-auto-fix (= CI 失敗 → Claude 修正 PR) | GHA `ci-auto-fix.yml` | Anthropic API | PR | ✅ Claude が自動 PR |
| **on-event** | claude-agent-review (= PR open → Claude / Gemini レビュー) | GHA `claude-agent-review.yml` | Anthropic API + Gemini API | PR comment | ✅ 自動レビュー |

凡例: ✅ Issue/WBS 自動接続済 / ⚠️ 半自動 (= 自動化候補) / ❌ 手動 only (= 自動化候補) / — = 接続不要

---

## 2. 2 instance active routing + legacy ownership map (= 上表 cross-cut)

現行の運用判断では、旧 12 instance fleet の担当名は履歴・設計由来の分類として扱う。新規セッションで起動するのは Claude Code #1 と Codex #1 のみ。

| Active owner | 吸収する旧 lane | 主な責務 |
| --- | --- | --- |
| **Claude Code #1** | Win / VSCode / PS#1 / PS#3 / PS#4 / WEB / mobile | architecture, triage, docs/spec, UX判断, cross-instance hand-off 設計 |
| **Codex #1** | Codex#1 / Codex#2 / PS#2 / PS#5 / PS#6 | implementation, CI, GHA, scripts, sync, scoped PR |
| **GHA / Automation** | schedule / monitor / sync jobs | 定常実行、Issue/WBS 接続、artifact / comment 出力 |

下表は既存 automation の historical ownership map。現行では必要に応じて上表の 2 instance owner へ読み替える。

| Instance | daily 自走責任 | weekly 自走責任 | monthly 自走責任 | 主な non-cron 責任 |
| --- | --- | --- | --- | --- |
| **Claude Code Win版** | (= 監視のみ) | (= triage) | hook-rule-audit / consolidate-memory / instance-role-audit | architect 判断 / memory 管理 / cross-instance-pr / 動画 pipeline |
| **VSCode版** | (= 監視のみ) | (= UI verify) | (= デザインレビュー) | Flutter UI + EF 編集 |
| **PS版#1** | rule17-wf-health | (= GHA orphan branch 削除) | (= concurrency 設定棚卸し) | Rule 17 wf-health / instance config oversight |
| **PS版#2** | t1-blog-dispatch | (= dev.to + Qiita 投稿確認) | (= 投稿頻度棚卸し) | T-1 dispatch / dev.to + Qiita |
| **PS版#3** | ai-university-update | (= AI 大学 content rebalance) | (= AI 大学 provider 棚卸し) | AI 大学 content seed |
| **PS版#4** | (= 競合 21 社 watch) | (= 競合追加判断) | (= 競合棚卸し) | 競合追加 |
| **PS版#5** | (= EF 未接続 audit) | (= EF 統合 PR レビュー) | (= EF 棚卸し) | EF 整理 + ci-auto-fix |
| **PS版#6** | (= confidence terms 追加) | (= horse-race ML harness) | (= ML harness 棚卸し) | 競馬 prediction model |
| **WEB版** | cs-check log read | (= ticket cache verify) | (= cache freshness 確認) | sandbox 内 read-only 監視 |
| **スマホ版** | (= 実機 UAT) | (= mobile UI verify) | (= PWA / iOS Safari 棚卸し) | mobile bug triage |
| **Codex#1** | (= 横断調査 / 修正 PR) | (= SQL レビュー) | (= migration 棚卸し) | 横断調査 / 修正 PR / SQL |
| **Codex#2** | (= CI / 同期 / 運用補助) | (= EF coverage 棚卸し) | (= GHA workflow 棚卸し) | EF / GHA / 同期 |

---

## 3. Memory / long-running state 接続戦略

### 3.1 Codex Memory (= 2026-05 GA) で持続化すべき項目

- **Migration 命名則** (= `YYYYMMDDXXXXXX_descriptive_name.sql`)
- **EF deny-by-default 原則** (= 例外は明示 secrets 確認後のみ)
- **WORKDIR-ISOLATION rule** (= main repo 直接編集禁止 + 12 worktree 厳守)
- **AUTO-REPLY rule** (= `author == 自分` で必ず skip)
- **REBASE rule** (= push 前に必ず `git fetch origin main && git log HEAD..origin/main`)
- **CAVEMAN rule** (= 通信は fragments OK / code は normal)

これらは Codex CLI Memory に project convention として登録 → 全 Codex session で再利用 (= CLAUDE.md 毎回 re-load の token 削減).

### 3.2 NotebookLM Master Brain (= L3 memory) で持続化すべき項目

- **アーキテクチャ判断** (= Supabase 選択理由 / EF deny-by-default の意図 / 12 instance fleet 設計理由)
- **過去の失敗 pattern** (= 試して避けるべき approach)
- **設計上の好み** (= dark theme / Orange + Indigo / note-style line-height 2.0)
- **競合 21 社の動向** (= NotebookLM list の 97 notebook 全体)

これらは `notebooklm use jibun-master-brain && notebooklm ask "..."` で 横断検索可能 (= L3 memory).

### 3.3 自作 hooks + memory/ (= L2 memory) で持続化すべき項目

- **セッション横断の成功 / 失敗 pattern** (= memory/feedback_*)
- **本セッション固有の発見** (= memory/project_*)
- **手動 task / unresolved item** (= memory/manual_tasks_*)

これらは git commit + claude-mem index 経由で全 instance が共有.

---

## 4. 数日にまたがるタスクの再開条件 / 上限 / 失敗ハンドオフ

### 4.1 再開条件 (= resume condition)

| Trigger | 再開アクション | 再開所有者 |
| --- | --- | --- |
| GHA workflow failure (= `workflow-failure-handler.yml` 経由) | Issue 自動作成 + cs-check が triage | Codex #1 (= CI 担当) |
| migration collision detected (= part 47 detector) | rename + WIP commit | 検出元 instance |
| WBS task 60 日未更新 (= `wbs-staleness-audit.yml`) | cross-instance-pr 自動作成 | 元 owner_instance |
| Issue close (= bug 修正完了) | feedback メール送信 | (= 自動) |
| AI tool changelog 重要 update (= `ai-tool-watch.yml`) | comment to Issue #1422 + Slack | Claude Code #1 (= triage 担当) |

### 4.2 上限 (= cap)

| カテゴリ | 上限 | 違反時動作 |
| --- | --- | --- |
| AUTO-REPLY (= Qiita / dev.to) | MAX_REPLIES_PER_ARTICLE / RUN | skip + log |
| YouTube upload (= video pipeline) | 6 / rolling 24h (= 10000 unit / day) | Step 0 で fail-fast |
| Issue 自動作成 (= cs-check / dep-audit) | 5 / day / category | dedup check |
| Slack notification | 20 / hour / channel | rate limit + dedup |
| GHA workflow concurrency | per-workflow group | cancel-in-progress=false |

### 4.3 失敗時ハンドオフ (= escalation path)

```text
GHA workflow failure
  ├─ workflow-failure-handler.yml が Issue 自動作成 (label workflow-failure)
  ├─ cs-check が triage (= 重複 / 既知問題判定)
  └─ 未解決 → Claude Code (Win版 / VSCode版) 手動修正
       └─ 手動修正困難 → cross-instance-pr で他 instance に handoff
            └─ 数日経過 → wbs-staleness-audit が再 ping
```

---

## 5. セッション終了時残作業 → Issue/WBS 自動接続

### 5.1 現状 (= 自動化済)

各 instance のセッション終了時:
1. `/wrap-up` skill 実行 (= memory/ 保存 + ROADMAP 追記)
2. `memory/project_*.md` に `## 次回 candidate` / `## 次回タスク候補` / `## 次回アクション候補` を残す
3. `.github/workflows/session-residuals-sync.yml` が daily 02:30 JST に scan
4. `scripts/session_residuals_to_issue.py` が重複除外後、未登録項目を GitHub Issue 化
5. workflow summary を Issue #1647 に comment し、次回 Codex #1 / Claude Code #1 session が `gh issue list` / WBS から拾う

### 5.2 実装済みの自動化

`scripts/session_residuals_to_issue.py`:
- `memory/project_YYYYMMDD_*.md` の `## 次回 candidate` セクションを parse
- 既存 open Issue と diff を取って未登録項目のみ Issue 自動作成
- 重複 check + label 自動付与 (= 追加要望 / instance 別)
- link-only / narrative meta line を skip
- `--limit` safety cap で 1 run の Issue 作成数を制限

`.github/workflows/session-residuals-sync.yml`:
- schedule: daily 02:30 JST
- dispatch default: dry-run (`apply=false`) for manual safety
- cron default: apply (`apply=true`)
- comments report back to Issue #1647

検証済み run:
- initial dry-run: `25276920888`
- apply: `25286317156`, `25334866200`, `25393385510`, `25452355648`, `25513384254`

---

## 6. 受け入れ条件 vs 達成状況 (Issue #1647)

| 条件 | 状況 | 根拠 |
| --- | --- | --- |
| 1. 日次/週次で自動化すべきタスク一覧と担当 (Claude Code #1 / Codex #1 / GHA) が docs に反映 | ✅ | 本ドキュメント §1 §2 |
| 2. 少なくとも 1 つの Codex Automation または GitHub Actions 代替が作成 | ✅ | `.github/workflows/codex-session-safety-cron.yml` + `.github/workflows/session-residuals-sync.yml` |
| 3. セッション終了時の残作業が自動で Issue/WBS へ残る導線が検証 | ✅ | `scripts/session_residuals_to_issue.py`; successful runs `25276920888`, `25286317156`, `25334866200`, `25393385510`, `25452355648`, `25513384254` |

---

## 関連

- Issue [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) (= 本ドキュメントが解決ターゲット)
- Issue [#1706](https://github.com/kanta13jp1/my_web_app/issues/1706) (= AI tool 2026-05 fleet 反映)
- Issue [#1422](https://github.com/kanta13jp1/my_web_app/issues/1422) (= AI tool watch tracking issue)
- `docs/AI_FALLBACK_RUNBOOK.md` (= AI quota 超過時 fallback)
- `docs/AI_FLEET_SYNERGY_PLAYBOOK.md` (= bc58b50b 蒸留 / 7 原則)
- `docs/SCHEDULE_TASKS.md` (= cron 詳細)
- `docs/MULTI_INSTANCE_FLEET.md` (= 12 instance canonical)

(Win版#132 part 117-118 / Codex #1 close-out update 2026-05-08 / Issue #1647 着地)
