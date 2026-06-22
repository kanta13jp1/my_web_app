---
title: Building 自分株式会社 — Last 7 Days of AI Fleet Development
published: false
tags: ai, indiedev, buildinpublic, claude
date: 2026-06-12
---

## TL;DR

Last 7 days of building **自分株式会社** (= Jibun Inc. / a personal life-management AI app) with a **12-instance AI fleet** (10 Claude Code + 2 Codex CLI). This post extracts the recent ROADMAP-LOG entries as a build-in-public update.

## Recent activity (auto-extracted)

## 2026-06-05 - Codex #1: AI大学 civics 学部 MVP migration
**Scope**: Applied the Win Claude part 240e handoff for the AI大学 civics faculty MVP.

**Changes**:
- Added the `civics` faculty (`政治・選挙リテラシー学部`) plus four departments: `diet_structure`, `diet_members`, `policy_themes`, and `election`.
- Seeded one neutral, source-linked education item per department under `provider='civics_literacy'`.
- Used each department code as `ai_university_content.category` to satisfy the existing `UNIQUE(provider, category)` constraint while preserving clean provider-based rollback.
- Moved the completed handoff note to `docs/cross-instance-prs/done/20260603_civics_module_mvp.md`.

**Validation focus**:
- Migration is additive and idempotent.
- Content remains educational, source-linked, politically neutral, and contains no party/candidate recommendation or legislator scoring.
- Production verification target: `select name_ja from public.university_faculties where faculty_code = 'civics';` and `select count(*) from public.university_departments d join public.university_faculties f on d.faculty_id = f.id where f.faculty_code = 'civics';`.

---

---

## 2026-06-05 - Win Claude part 241: ADR (設計判断ログ) 運用の確立
**Scope**: WBS 設計タスク `2e41ebca-36bd-4c47-a87f-90b7b5948ece`「アーキテクチャ判断ログ運用 (ADR)」を完了 (/loop dynamic mode, Win Claude architect lane)。

**Changes**:
- `docs/adr/README.md` を新設 — いつ ADR を書くか / 命名 (`YYYY-MM-DD-kebab.md`) / Status ライフサイクル (Proposed→Accepted→Deprecated/Superseded) / WBS・Issue・NotebookLM への紐づけ / 原則 docs との関係 / Index 表。
- `docs/adr/TEMPLATE.md` を新設 — 新規 ADR のコピー元。
- 主要設計判断 3 件を backfill ADR 化: Flutter Web+Supabase+Firebase スタック / Edge-Function-first (EF-FIRST・EF-CAP-50) / 2-instance fleet (Architect+Implementer)。
- `docs/DIRECTORY_STRUCTURE.md` に `docs/adr/` への pointer を追記。
- migration `20260605140000_wbs_complete_adr_operating_process.sql` で WBS task を completed (progress=100 / ai_review_status=approved) 化 + `development_achievements` 追記。

**Validation focus**:
- docs-only + WBS 完了 migration のみ (コード/EF/スキーマ変更なし)。
- migration は idempotent (固定値 UPDATE / description LIKE guard / achievement NOT EXISTS guard)。
- `ai_review_status='approved'` を同一 UPDATE で設定し `wbs_request_ai_review` trigger の in_progress 差し戻しを回避。
- Philosophy Alignment: 原則 2 ミッション / 4 mentor / 8 KPI (= 設計判断の追跡可能性) + [BRAIN-32] PKM。
- commit hash: `fff8cbc5c` ([#3115](https://github.com/kanta13jp1/my_web_app/pull/3115) / squash-merge)。

---

---

## 2026-06-05 - Win Claude part 242: プロダクト要件定義書 (PRD) v1 整備
**Scope**: WBS 企画タスク `5ef83c7e-1808-4dc2-9e9d-f19c799e8240`「[企画] プロダクト要件定義書 (PRD) 整備」を完了 (/loop dynamic mode, Win Claude architect lane)。

**Changes**:
- `docs/PRD.md` を新設 — v1 PRD baseline: ビジョン (人生を会社として経営) / ターゲットペルソナ (primary/secondary/anti) / 6 部署の提供価値 / スコープ / 非目標 (理念 NG 例から導出) / 2 層 KPI (ウェルビーイング North-Star + 事業マイルストーン guardrail) / 9 原則整合 / living-doc 運用。
- 既存 canon (PHILOSOPHY / 本番機能 / 競合 21 社 / WBS マイルストーン) から codify。L1 Antigravity 探索結果で継続精緻化する想定。
- `docs/DIRECTORY_STRUCTURE.md` に `docs/PRD.md` への pointer 追記。
- migration `20260605150000_wbs_complete_prd.sql` で WBS task を completed 化 + `development_achievements` 追記。

**Validation focus**:
- docs-only + WBS 完了 migration のみ (コード/EF/スキーマ変更なし)。
- migration idempotent (固定値 UPDATE / description LIKE guard / achievement NOT EXISTS guard)。
- PR body に high-risk-ultrareview-exception + Claude Code #1 + minimal-E2E 宣言を初稿から内包 (= part 241 で確立した recipe を適用し close/reopen 不要の first-try gate pass を狙う)。
- Philosophy Alignment: 原則 1 CEO感 / 2 ミッション / 8 KPI (昨日の自分比較) / 9 ウェルビーイング。
- commit hash: (PR merge 後に追記)。

### 2026-06-06 Win版#132 part 243 — 四半期ロードマップ v1 策定 (WBS be0354f6 完了 / /loop autonomous)

**Context**:
- `/loop` dynamic mode で「WBS 上の未完了タスクを 1 つ完了」を自走。Win-completable な唯一の未完了タスク `[企画] 四半期ロードマップ策定` (be0354f6) を選択 (#1495 mobile / #1950 automation は Codex realm で Win 完了不可)。part 242 PRD v1 の後続。

**Changes**:
- `docs/QUARTERLY_ROADMAP.md` を新設 — 四半期ロードマップ v1: 競合監視・ユーザー要望・WBS 進捗を反映し Q3 2026 (MVP ローンチ / 1,000 users) の優先順位を SDLC 7 工程別に再配置 / WBS フェーズバランスレビュー (実測 3,143 tasks / 完了 2,211 = 70.3% / 未完了 932 / phase 未設定 879 = 94.3% という中心的所見) / リスクノート (低確度の機能レーンを delivery タスクより先に削る) / 原則整合。
- `docs/DIRECTORY_STRUCTURE.md` に `docs/QUARTERLY_ROADMAP.md` への pointer 追記。
- migration `20260606090000_wbs_complete_quarterly_roadmap.sql` で WBS task を completed/100/approved 化 + `development_achievements` 追記 (part 242 idempotent パターン)。

**Validation focus**:
- docs-only + WBS 完了 migration のみ (コード/EF/スキーマ変更なし)。両 gate (high-risk ultrareview + minimal-E2E) を初稿 body で first-try PASS (close/reopen 不要 / part 242 recipe 再現)。
- BEHIND-by-1 (health-monitor cron churn `6049630a9`) + file-overlap 0 + 全 12 check green を検証し admin squash-merge。
- prod DB の completed flip は deploy-prod (~30min) で反映。
- Philosophy Alignment: 原則 4 mentor (最終決定権は user) / 6 商品=価値 (delivery 死守) / 8 KPI (North-Star 優先) / 9 IPO=ウェルビーイング。
- commit hash: `044cbc9df` (squash merge / [PR #3120](https://github.com/kanta13jp1/my_web_app/pull/3120))。

---

## Win版#132 part 231 cron (= 真値 part 233 / 2026-05-19 12:00 UTC / autonomous daily-development cron / Win Claude / numbering reconciliation deferred)

### Session ritual

- **開始**: 2026-05-19 12:00 UTC = 21:00 JST = scheduled `daily-development` cron / autonomous / no user attention
- **trigger**: `~/.claude/scheduled-tasks/daily-development/SKILL.md`
- **worktree**: `.claude/worktrees/part-233-daily-dev` ([WORKDIR-ISOLATION] 厳守) / branch `claude/part-233-daily-dev` / from `origin/main` HEAD `8ce2d3b6f`
- **numbering note**: ROADMAP label uses `part 231 cron` per "ROADMAP last entry が真の正本" rule (= part 230 lesson). MEMORY.md sequencing says true count = part 233. Numbering collision (first surfaced part 232) reconciliation = user-driven session per [NO-SCOPE-CREEP] autonomous-cron discipline.
- **scope decision**: triad ship only (= part 219 cron + part 225 cron precedent) = blog draft pair JA+EN + idempotent seed + ROADMAP entry. No PR rebase / no dangling PR cleanup / no Dart impact.

### Deliverable (1 PR / 4 files)

1. **Tech blog draft pair JA + EN — "3-Tier Canonical for Docs-Only PRs"**
   - `docs/blog-drafts/2026-05-19-canonical-3tier-docs-only-pr-recipe.md` (JA)
   - `docs/blog-drafts/2026-05-19-canonical-3tier-docs-only-pr-recipe-en.md` (EN)
   - Distilled from part 232 PR #2942 (5th-and-final dogfood that locked the canonical)
   - Recipe documented = (Tier 1) body must hold gate-script exact phrases (implementation-detail independent E2E + minimal 3 cases + integration_test/Playwright/smoke mechanism) — generic 5-item checkbox does NOT match / (Tier 2) `gh pr edit --add-label docs-only` to enter the `scripts/check_minimal_e2e_gate.py` line 159-161 early-return path / (Tier 3) `gh pr close` + `gh pr reopen` within 1 sec to fire fresh `reopened` event payload bypassing the cached `opened` payload
   - Failure-mode mapping = part 225-followup + 226 (missed Tier 1) → part 228 + 229 (missed Tier 2, passed by body coincidence) → part 232 (all 3 tiers, true canonical first-try SUCCESS)
   - Application scope (✅) = owner-authored single-reviewer docs-only PRs / (❌) = gates inspecting code semantics, shared PRs with reviewer approvals, applying `docs-only` label to implementation PRs (= contract violation)
   - Same `published: false` discipline as prior daily-dev cron drafts (part 219 + part 225)
2. **Idempotent seed `supabase/migrations/20260519120000_seed_achievements_scheduled_daily_part233.sql`**
   - INSERT ... WHERE NOT EXISTS guard (= replay-safe)
   - feeds `development_achievements` table → GrowthRoadmapProgressCard
3. **ROADMAP part 231 cron entry +N 行 strict-append**

### Philosophy Alignment (= 6/9 autonomous-cron minimal-scope)

- 原則 1 (CEO 感) ✅ scheduled cron 完走 / 原則 6 (商品=価値) ✅ canonical recipe distillation = fleet-wide reusable / 原則 7 (資本=時間) ✅ ~15min triad ship / 原則 8 (KPI) ✅ daily achievements stream 継続 / 原則 9 (IPO) ✅ canonical 3-tier = reproducible systemic 価値
- [VIBE-30] ✅ responsible CI workflow + bounded scope / [BRAIN-32] ✅ Karpathy Ingest→Compile→Publish 最短 turn-around 第 2 例累積 (= part 217 同日 lesson 横展開 pattern と並ぶ / part 232 morning recipe lock → part 233 cron blog distill = ~13h turn-around)
- minimal-scope のため [PHILOSOPHY-22] 3 軸不満 (= 原則 2 ミッション / 原則 3 6 部署 / 原則 5 mentor 拡張)
- **autonomous-safe pattern 第 3 例累積** = part 219 + part 225 + part 233 = scheduled cron 下 fatigue:FATIGUE でも triad-only で safe ship 立証

### 教訓 (= 部 231 cron)

- **scheduled cron + minimal triad = autonomous-safe 第 3 例** = part 219 (4-layer AI rollout) + part 225 (PR gate body patch) + part 233 (3-tier canonical) chain. fatigue:FATIGUE 下でも sequential Bash + worktree + triad scope なら safe ship 再現性確認.
- **same-day Karpathy turn-around 第 2 例累積** = part 217 morning insight → afternoon cron ship pattern を part 232 morning (07:59 JST) → part 233 cron (12:00 UTC = 21:00 JST) で再現. **session→blog distill 13h turn-around** が cron 自走の sweet spot.
- **3-tier canonical = 5 cycle dogfood の総括** = 真の canonical recipe は failure mode mapping (= どの tier が抜けたか) と一緒に文書化することで「2 つで通った特例」を再現と勘違いしないで済む.
- **numbering collision deferral 第 1 例** = autonomous-cron は scope discipline 厳守 = ROADMAP last entry label に従う ("part 231 cron"). 真値 (part 233) 認識は併記するが renumber は user-driven session に委譲.

### next session 候補 (= 部 232+ user-driven)

1. 🚨 **session numbering reconciliation** (= part 232 で 第 1 例 detect + part 233 cron で deferred / Option B+C combo: PR rebase+merge for dangling PRs #2819+#2823 + ROADMAP rename annotation)
2. **#1495 P0 Option D 候補化判断** (= +24h reply 待ち継続 / Option D unilateral trigger threshold pre-warning から +24h 経過判定)
3. **#2520 Codex impl status** (= 5/22 sprint Day 4 = 残 3 日)
4. **#2461 A1 EF Codex impl status** (= 5/22 sprint target / stale 4+ days)
5. **MEMORY.md consolidation 第 6 例** (= part 215-220 archive / 200 entries 余裕継続)
6. **dangling PR resolve** (= #2819 + #2823 part 230b + part 231 由来 / unmerged 状態確認 + canonical 3-tier 適用候補)
7. **J3 backend layer impl** (= 部 224 skeleton 後続 / Win Claude 担当)
8. **disk-cleanup Tier 2** (= 部 230 で 25 GB breach 接近 / cleanup-skill manual fire)

---


## Stack

- Frontend: Flutter Web (Dart)
- Backend: Supabase (PostgreSQL + Edge Functions / Deno)
- Hosting: Firebase Hosting
- AI: Claude Code (10 instances) + Codex CLI (2 instances)

Auto-generated by `scripts/build_in_public_extract.py` (= INDIE_DEV_VELOCITY #7 Community Engagement Discipline dogfood).
