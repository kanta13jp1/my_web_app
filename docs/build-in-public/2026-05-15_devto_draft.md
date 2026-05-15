---
title: Building 自分株式会社 — Last 7 Days of AI Fleet Development
published: false
tags: ai, indiedev, buildinpublic, claude
date: 2026-05-15
---

## TL;DR

Last 7 days of building **自分株式会社** (= Jibun Inc. / a personal life-management AI app) with a **12-instance AI fleet** (10 Claude Code + 2 Codex CLI). This post extracts the recent ROADMAP-LOG entries as a build-in-public update.

## Recent activity (auto-extracted)

## 2026-05-08 — Win版#132 part 178 / Issue #1750 Faceless YouTube + Design-Agent 2 本蒸留 ship
### Summary

- 同日 18 part 連続 (= 2026-05-07 part 161 → 2026-05-08 part 178 cross-day / cap_24part_v2 残 6 part)
- 107 part 連続 dogfood (= part 75 → 178 / 2 month +)
- 日付 cross 確認: JST 2026-05-08 00:22 で part 178 開始 (= cap reset 候補日付だが same-session continuation として扱い)
- Issue #1750 (P2 / NotebookLM 2 本蒸留 / 2026-05-03 起票) を着地:
  - **Faceless AI YouTube Automation** (`bc91fac9`) → `docs/AI_VIDEO_PRINCIPLES.md` Faceless Channel 運用パターン章追加 (= 6 原則の応用例 / 7 工程 / 月次 KPI / Codex hand-off 5 task)
  - **Design-Agent Convergence** (`0fc0b6cf`) → `docs/STRATEGIC_INTELLIGENCE_2026Q2.md` 第 6 章追加 (= VSCode dormant scope stub / Q2-Q3 4 アクション)
- Issue #1757 (`bc91fac9` 同源単独 issue) は本章で内容吸収済 → close 候補として #1750 コメント
- Issue #1724 (= 5 secrets 設定 / P1) と相互リンク (= F6 publish 公開化の前提)

### Pattern

- 「NotebookLM 2 本蒸留 → 2 docs 同時更新」pattern 第 1 例 (= 1 親 issue × 2 sub-source × 2 受入 docs)
- 「dup-issue identify + close 候補 marking」pattern 第 1 例 (= #1750 vs #1757 同 notebook source)
- 「VSCode dormant scope stub 化」pattern 第 1 例 (= 復活 trigger + 将来 Win Claude UI role 拡張時の参照点として保留)
- 「6 原則の応用例 = 新原則ではなく章追加」pattern 第 1 例 (= AI-VIDEO-29 baseline 2.0/6 維持)

### Philosophy Alignment

| 原則 | ✅ | 根拠 |
|------|----|------|
| CEO 感 | ✅ | channel 運用 + design pipeline 戦略を docs 化 |
| ミッション駆動 | ✅ | Faceless = 月次 X 本 publish で AI 大学拡張 |
| 優しい mentor | ✅ | 顔出し YouTuber と Faceless 比較表で意思決定支援 |
| 6 部署バランス | ✅ | R&D (pipeline) + マーケ (channel) + 財務 (KPI) + 人事 (Codex hand-off) 網羅 |
| 商品 = 価値 | ✅ | publish 本数 + watch hour KPI が直接価値指標 |
| 資本 = 時間 | ✅ | 顔出し 5-15h → Faceless 30-60min (= 90% 時短) |
| 資産 vs 負債 | ✅ | docs 永続資産 / NotebookLM `bc91fac9` + `0fc0b6cf` 蒸留済 |
| KPI = 昨日の自分 | ✅ | Phase 0 → 1 → 2 の月次本数 + subs + watch hour 数値化 |
| IPO / ウェルビーイング | ✅ | 収益化 path (= Phase 2) を spec 化 |

**判定: 9/9 ✅** (= 7+/9 ゲート達成 / 完全達成)

### AI-VIDEO-29 / SYNERGY-30 / BRAIN-32

- **AI-VIDEO-29** = 6/6 必須維持 (= 章追加は応用例 / 原則変更なし)
- **SYNERGY-30** = 7/7 ✅ (= Codex hand-off 5 task 想定 / Plan-Execute-Review 適用)
- **BRAIN-32** = 7/7 ✅ (= NotebookLM 2 notebook → 2 docs 系統化 / Karpathy Compile cycle dogfood)

### Commit

- PR [#2149](https://github.com/kanta13jp1/my_web_app/pull/2149) MERGED `8aff1bef0` (admin squash / part 196 backfill)

---

---

## 2026-05-08 09:55 JST — Win版#132 part 178b (Win Claude / hygiene Tier 1.6 spec ship)
### Summary

User 2026-05-08 ask「**毎回のセッションで必ず** メモリ + HDD 圧縮」要件 v2 → Tier 1.6 SessionStart-integrated stale worktree prune spec ship。

### Ship

- PR [#2156](https://github.com/kanta13jp1/my_web_app/pull/2156) MERGED `a0e51bc572` (admin squash)
- `docs/DISK_HYGIENE_RUNBOOK.md` §12 新設 — Tier 1.6 SessionStart-integrated stale worktree prune (8 節 191 行)
- `docs/cross-instance-prs/20260508_tier16_stale_worktree_prune_codex.md` — Codex hand-off (期限 2026-05-22)
- Issue #1984 [comment 4402365885](https://github.com/kanta13jp1/my_web_app/issues/1984#issuecomment-4402365885) — axis A 強化 status

### 隙間特定

`scripts/worktree_cleanup.py` = weekly cron のみ → 17 worktree / 2.28 GB 蓄積 → SessionStart 統合で漸増 trim 化。

### Philosophy Alignment

- **PHILOSOPHY-22** = 7/9 ✅ (= CEO の物理資産管理 / 時間最適化 / 隠れ負債削減)
- **INDIE-29** = 6/7 ✅ (= 既存 doc 章追加 pattern dogfood / scope creep 回避)
- **OPS-28** = 5 正本 ✅ (= Issues + PR + WBS + worktree+branch + Notion 不変)

### Pattern dogfood

- 「**既存 doc 章追加 pattern**」(= 新規 spec md 増殖回避) 第 3 例 — DISK_HYGIENE_RUNBOOK.md §12 拡張
- 「**Win Claude triage + Codex 実装委譲**」pattern 連続例 ([INSTANCE-ROLES] dogfood)
- 108 part 連続 dogfood / 19 part 連続 cross-day (cap_24part_v2 残 5)

---

---

## 2026-05-08 11:00 JST — Win版#132 part 179 (Win Claude / Codex 自走着地 verify + 3 issue triage)
### Summary

Codex CLI が単独で着地した Issue #1569 (= high-risk PR ultrareview gate) を verify-only で確認 + 5/19 deadline 3 P1 issue を [INSTANCE-ROLES] 5 質問 score で triage + #2152 を Codex hand-off doc ship。

### Ship

- **Codex 自走着地 verify** (= 関与なし): Issue #1569 CLOSED 2026-05-08T01:28:04Z / PR #2155 squash merged commit `36935f38a` / `.github/workflows/claude-agent-review.yml` + `scripts/check_high_risk_ultrareview_gate.py` (+472 lines) / CI 7 checks green
- `docs/cross-instance-prs/20260508_codex_kg_indexer_fix_part179.md` — Codex hand-off (Issue #2152 / 期限 2026-05-19 / 11 day grace)
- Issue [#1586 comment](https://github.com/kanta13jp1/my_web_app/issues/1586#issuecomment-4402664362) — Win Claude defer status (= managed-mcp.json spec ship 別 session)
- Issue [#1598 comment](https://github.com/kanta13jp1/my_web_app/issues/1598#issuecomment-4402664552) — Win Claude defer status (= DeepEval 評価観点 spec ship 別 session)
- Issue [#2152 comment](https://github.com/kanta13jp1/my_web_app/issues/2152#issuecomment-4402664757) — Codex hand-off ack

### Triage matrix ([INSTANCE-ROLES] 5 質問 score)

| Issue | score | 担当 | 着地 |
|---|---|---|---|
| #1569 high-risk ultrareview gate | n/a (already CLOSED by Codex) | Codex | ✅ commit `36935f38a` |
| #1586 managed-mcp.json | 4/5 | Win Claude (architect) | spec ship 別 session |
| #1598 DeepEval/promptfoo | 1/5 (split) | Win Claude design + Codex #2 CI | Win Claude design 別 session |
| #2152 kg-indexer-nightly failure | 0/5 | Codex (GHA fix) | hand-off doc ship |

### Philosophy Alignment

- **PHILOSOPHY-22** = 6/9 ✅ (= CEO triage role + mentor delegation + 商品=価値 = 5 正本同期)
- **OPS-28** = 5 正本 ✅ (= Issues + PR + WBS + worktree+branch + Notion 不変)
- **SYNERGY-30** = 5/7 ✅ (= cross-instance-pr / [INSTANCE-ROLES] dogfood / verify-only pattern 第 1 例)

### Pattern dogfood

- 「**Codex 自走着地 verify-only**」pattern 第 1 例 — Win Claude が hand-off せず Codex が独立着地 → triage 時 commit + Issue close 状態で verify のみ / cap_24 conservation 完璧
- 「**[INSTANCE-ROLES] 5 質問機械的振り分け**」第 2 例 — 3 issue 各 30 sec 以内 score 化 / triage 速度向上
- 109 part 連続 dogfood / 20 part 連続 cross-day (cap_24part_v2 残 4) / 次 session = fresh start 強推奨

### Commit

- PR [#2159](https://github.com/kanta13jp1/my_web_app/pull/2159) MERGED `b710a88ce` (admin squash)

---

---

## 2026-05-08 11:30 JST — Win版#132 part 179 続き (Win Claude / Tier 1.7 spec ship + 5/20-5/22 batch triage)
### Summary

User 第 2 弾 ask (= same session continuation): 「WBS 期限近順 + 2 instance 制反映 + メモリ HDD 圧縮施策」.

新規 audit 発見 = `~/.cache/codex-runtimes` 722 MB + `~/.claude/plugins/marketplaces/thedotmack` 612 MB + VSCode workspaceStorage 249 MB = **計 ~1.6 GB hygiene 非対象 = 隠れ負債**. うち prune 候補 ~860 MB / 残 722 MB は不可 (= Codex 起動 fail risk).

### Ship

- `docs/DISK_HYGIENE_RUNBOOK.md` §13 新設 (= Tier 1.7 disk hog telemetry / 7 節 / 自動 prune なし / safety first)
- `docs/cross-instance-prs/20260508_tier17_disk_hog_telemetry_codex.md` Codex hand-off (期限 2026-05-22)
- Issue [#1984 comment 4402816831](https://github.com/kanta13jp1/my_web_app/issues/1984#issuecomment-4402816831) — axis A 継続強化 status
- Issue [#1962 comment 4402817195](https://github.com/kanta13jp1/my_web_app/issues/1962#issuecomment-4402817195) — VSCode 版 dormant grace 30 day monitor 第 2 例

### 5/20-5/22 batch triage matrix ([INSTANCE-ROLES] 5 質問 score)

| Issue | score | 担当 | 推奨 |
|---|---|---|---|
| #1647 Codex Memory/Thread Automations | 0/5 | Codex | hand-off 別 session |
| #1783 NotebookLM SaaS Operations 蒸留 | 4/5 | Win Claude | spec ship 別 session |
| #1962 VSCode版 開発環境不具合 | n/a (dormant) | dormant grace | 30 day monitor |
| #1124 AI役員GPA 評価 | n/a (= part 103 done) | verify-only | ack only |
| #1558 Secrets/環境変数監査 | 3/5 split | Win Claude design + Codex impl | spec defer |
| #1595 Testcontainers Codex #2 | 0/5 | Codex | 担当案明記 / hand-off 別 session |
| #1719 Pleias UI 視覚検証 | 5/5 | Win Claude | UI/mobile UAT 別 session |
| #1645 Docker MCP Toolkit | 2/5 split | split | spec defer |
| #1741 自己接触トラッカー | 5/5 | Win Claude | UI/mobile/PWA 別 session |

### Philosophy Alignment

- **PHILOSOPHY-22** = 7/9 ✅ (= CEO 物理資産管理 / 時間最適化 / 隠れ負債削減 / mentor delegation)
- **INDIE-29** = 6/7 ✅ (= 既存 doc 章追加 pattern 第 4 例 dogfood / YAGNI 自動 prune 回避)
- **OPS-28** = 5 正本 ✅ (= Issues + PR + WBS + worktree+branch + Notion 不変)

### Pattern dogfood

- 「**既存 doc 章追加 pattern**」第 4 例 — DISK_HYGIENE_RUNBOOK.md §13 追加 (= 第 3 例 §12 連続応用 / 新規 spec md 増殖回避)
- 「**自動 prune 回避 / telemetry only**」pattern 第 1 例 — ~860 MB prune 候補あるが 削除事故 risk → 観測のみ / INDIE-29 YAGNI 直接応用
- 「**[INSTANCE-ROLES] 5 質問機械的振り分け**」第 3 例 — 5/20-5/22 9 issue を 30 sec/issue で score 化
- 109 part 連続 dogfood / 21 part 連続 cross-day (cap_24part_v2 残 3) / 次 session = fresh start STRONGLY 推奨

### Commit

- PR [#2161](https://github.com/kanta13jp1/my_web_app/pull/2161) MERGED `324a49942` (admin squash / part 196 backfill)

---

## 2026-05-09 — Win版#132 part 180 (Win Claude / Claude Code)
### Session Summary
- Codex 自走 verify-only 第 3 例: PR #2154 (daily-report artifact persistence fix) + #2162 (kg-indexer harden)
- **LLM 品質ゲート spec ship** (Issue #1598 / 期限 5/19): `docs/LLM_QUALITY_GATE_SPEC.md` 7軸評価観点 + `eval/fixtures/llm-quality-gate.yaml` 15件 promptfoo テストケース設計
- C: free 71.1 GB (前 session 86.6 GB → -15.5 GB 急減 / 観測継続)

### Philosophy Alignment
- 原則 7 (資産 vs 負債): version 管理 fixtures = テスト資産蓄積
- 原則 5 (商品=ユーザー価値): AI 出力品質保証 → 信頼性向上
- 原則 8 (KPI=昨日の自分): ベースラインスコア比較で回帰検知

### Commit
- `534cdbb47` docs(quality): LLM quality gate spec + promptfoo fixtures (#1598)

---

## 2026-05-09 — Win版#132 part 180b (Win Claude / 続き)
### Session Summary (User v3 ask)
- **User 要望**: 毎セッション必ずメモリ + HDD 圧縮 + WBS 期限近順 triage (2 instance 制反映)
- **隠れ負債 audit**: Temp 8.5 GB + npm 2 GB + pnpm 2.5 GB = 13 GB 取り逃し発見
- **DISK_HYGIENE_RUNBOOK §14 ship**: Tier 1.8 (cache sweep) + 1.9 (Temp 深層) + 2.0 (delta tracking + 警告) + RAM trim Phase 2
- Codex hand-off: 期限 2026-05-23 / [INSTANCE-ROLES] 5 質問 0/5 YES = 完全 Codex 案件

### Philosophy Alignment (Win#132 part 180)
- 主要実装: Tier 1.8/1.9/2.0 mandatory per-session compression + LLM quality gate spec
- 該当原則: #6 (時間最適化) + #7 (資産負債 = 隠れ 13 GB 負債可視化) + #8 (KPI 自分比較 = 7 day median delta) + #5 (商品=価値 = 健全環境 = ユーザー時間保全)
- 整合性スコア: 8/9 ✅ ([PHILOSOPHY-22] gate 通過 / 主要 4 原則体現)
- 理念的貢献: ローカル開発環境の枯渇問題に audit-first で根本対処

### Commit
- `ee27d7110` docs(hygiene): Tier 1.8 / 1.9 / 2.0 mandatory per-session compression spec
- PR #2163 admin squash merged 2026-05-08T03:55:57Z

---

## 2026-05-10 — Win版#132 part 181 (Win Claude / Claude Code)
### Session Summary
- **Issue #1783 spec ship** (NotebookLM 9b8885ef "Automating SaaS Operations" 蒸留)
- `docs/SCHEDULE_TASKS.md` §SaaS Operations Automation Patterns 新設 (= 5 patterns + 15 workflow gap 監査)
- 完全 gap 発見: P2 multi-AI fallback (0/15) + P5 throttle (0/15)
- Codex hand-off ship: 期限 2026-05-24 (= ai_fallback_invoke.sh + 3 recovery workflow + budget_check.sh)
- Codex 自走 PR 新規 0 件 (= 24h 内変化なし)
- C: free 71.1 GB stable (= 漸減 stop / Tier 1.8 待ち)

### Philosophy Alignment (Win#132 part 181)
- 主要実装: SaaS automation patterns spec (= NotebookLM distill)
- 該当原則: #6 (時間最適化 = 自動化 escalation 化) + #7 (資産負債 = self-heal 信頼性資産) + #8 (KPI 7-day median)
- 整合性スコア: 7/9 ✅ ([PHILOSOPHY-22] gate 通過)
- 理念的貢献: 失敗 → 自動修復 → ユーザー介在 0 化 = 時間資本保全

### Commit
- `7dd055355` docs(automation): SaaS automation patterns spec (#1783)

---

## 2026-05-08 — Win版#132 part 182 (Win Claude / Claude Code)
### Session Summary
- **calendar bug fix** — `app-hub` EF `calendar.list` が `{id, metadata, created_at}` 構造を返していて Flutter 側が `ev['start_at']` を読めず全イベント filter 落ち (= 「0件」表示)。`calendar.list` を flatten + `calendar.create` に `color` 永続化追加。
- **WBS dedup Phase 2 spec ship + Step 2.5 拡張** — user 観測「法人銀行口座開設 14 件重複」→ 全 917 行 audit で (A) `(title, instance)` 完全一致重複 700-800 行 + (B) `(github_issue_number, instance)` 重複で title バリエーション違い ~20 ペア (= GitHub Issue sync prefix 違い由来) を発見。Phase 2 spec を Step 2 + 2.5 二段 dedup + UNIQUE INDEX 2 種強制再作成に拡張。Codex hand-off (= 期限 2026-05-22 / Issue #2171)。
- 「user iterative report → spec scope 拡張 → 1 PR で全件解消」pattern 第 1 例
- 「データ品質負債 = 全観測表 audit → spec 拡張」pattern 第 1 例 (= 当初 spec の取りこぼし回避)
- 112 part 連続 dogfood

### Philosophy Alignment (Win#132 part 182)
- 主要実装: calendar EF 修正 + WBS dedup Phase 2 spec
- 該当原則: #2 (= ミッション = 自分株式会社運営の信頼性) + #6 (= 時間最適化 = データ品質負債返済) + #7 (= 資産負債 = WBS データ正確性 = 経営判断資産)
- 整合性スコア: 7/9 ✅ ([PHILOSOPHY-22] gate 通過)
- 理念的貢献: 経営者ダッシュボード (= WBS) のデータ品質を確保 → 意思決定速度の毀損防止

### Commit
- `284001999` fix(calendar): flatten app-hub calendar.list + WBS dedup Phase 2 spec (#2171) — admin squash merge (= 2026-05-08T15:40:40Z / part 183 で gate recovery 後 merge)

---

## 2026-05-09 — Win版#132 part 183 (Win Claude / Claude Code)
### Session Summary
- **PR #2172 dual-gate compliance recovery** (= 前 session carry-over BLOCKED 状態解消)
  - 観測: minimal-e2e gate + high-risk ultrareview gate 同時 FAIL (= EF `supabase/functions/app-hub/index.ts` 変更で 2 gate trigger)
  - body 1654 → 4626 chars 拡充 (= minimal E2E plan + 5 軸 ultrareview evidence + unresolved findings 0)
  - `gh pr edit --body` silent fail 発見 → `gh api -X PATCH repos/.../pulls/2172` 直叩きで update 成功
  - `gh run rerun` ≠ body 反映発見 → empty commit synchronize 必須 (= `7636017cb` push)
  - admin squash merge `284001999` (= 2026-05-08T15:40:40Z) / deploy-prod auto trigger
- **Issue #2171 Codex hand-off ping 判定**: T+1 day = skip / 期限 5/22 残 13 日 / Codex bot PR 0 件
- **memory ship 3 件**: project_20260509_win132_part183 + feedback_correction_20260509_gh_pr_edit_silent_fail + feedback_success_20260509_dual_gate_compliance_pattern

### Philosophy Alignment (Win#132 part 183)
- 主要実装: stuck PR の root cause 特定 + 1 PR 内完結 dual-gate compliance
- 該当原則: #2 (ミッション = 信頼性) + #6 (時間最適化 = 1 PR 完結) + #7 (資産負債 = stuck PR 即返済) + #8 (KPI = MERGED 率)
- 整合性スコア: 7/9 ✅ ([PHILOSOPHY-22] gate 通過)
- 理念的貢献: gate compliance pattern を memory に dogfood 化 = 次回再発時の time-to-recovery 短縮

### Commit
- `8940b70ef` (= PR #2177 merge / docs-only roadmap append for part 183)

---

## 2026-05-09 — Win版#132 part 184 (Win Claude / Claude Code)
### Session Summary
- **CODEX_WORKFLOW.md §8 PR body / synchronize gotchas 常駐記録 ship** (= 前 session 教訓 24h 以内 docs 化)
  - §8.1 `gh pr edit --body` silent fail → `gh api -X PATCH` 直叩き recipe + 検出 (= body length 比較)
  - §8.2 PR body update のみで workflow 再 trigger されない → empty commit synchronize trigger
  - §8.3 minimal-e2e-gate skip label canonical = `docs-only` OR `no-e2e-needed` 完全一致
  - §8.4 適用判断 (= <500 chars `gh pr edit` OK / 1KB+ `gh api -X PATCH` 必須)
- **PR #2180 self-recipe dogfood**: `docs-only` label 即適用 → minimal-e2e + ultrareview gate 即 PASS / empty commit synchronize trigger 即 dogfood
- **Issue #2171 T+1 day verify**: skip 確定 (= 既 part 183 で T+1 status comment 済 / next check 2026-05-12 = T+3)
- **inject-rules.txt KPI finding**: rule count 38 vs expected 37 (= drift なし / 動作影響なし / 別 PR 候補 = `scripts/sync_inject_rules.py:83` `EXPECTED_RULE_COUNT` bump)
- **production smoke**: `/calendar-events` 200 OK / 0.5s (= part 183 deploy 確認)
- **memory ship 1 件**: project_20260509_win132_part184

### Philosophy Alignment (Win#132 part 184)
- 主要実装: individual session memory → fleet shared docs 昇格 (= operational gotcha 24h 以内常駐記録)
- 該当原則: #2 (ミッション = 自分株式会社知識資産化) + #5 (商品 = 価値増大 = Codex も同じ落とし穴避けられる) + #6 (時間最適化 = 24h 内 docs 化) + #7 (資産負債 = memory のみ知識 → docs 資産化) + #8 (KPI = 知識共有率) + #9 (IPO = 全 instance 自走可能性向上)
- 整合性スコア: 8/9 ✅ ([PHILOSOPHY-22] gate 通過)
- 理念的貢献: memory feedback_correction → docs operational section 昇格 model 確立 / 114 part 連続 dogfood

### Commit
- `b89a929eb` PR [#2180](https://github.com/kanta13jp1/my_web_app/pull/2180) — CODEX_WORKFLOW.md §8 PR body / synchronize gotchas (admin squash merge / docs-only)
- `523576cc1` PR [#2181](https://github.com/kanta13jp1/my_web_app/pull/2181) — DISK_HYGIENE_RUNBOOK.md §15 毎セッション圧縮 status verify (admin squash merge / docs-only / self-recipe immediate dogfood 第 1 例)

---


## Stack

- Frontend: Flutter Web (Dart)
- Backend: Supabase (PostgreSQL + Edge Functions / Deno)
- Hosting: Firebase Hosting
- AI: Claude Code (10 instances) + Codex CLI (2 instances)

Auto-generated by `scripts/build_in_public_extract.py` (= INDIE_DEV_VELOCITY #7 Community Engagement Discipline dogfood).
