---
title: Building 自分株式会社 — Last 7 Days of AI Fleet Development
published: false
tags: ai, indiedev, buildinpublic, claude
date: 2026-06-05
---

## TL;DR

Last 7 days of building **自分株式会社** (= Jibun Inc. / a personal life-management AI app) with a **12-instance AI fleet** (10 Claude Code + 2 Codex CLI). This post extracts the recent ROADMAP-LOG entries as a build-in-public update.

## Recent activity (auto-extracted)

## 2026-05-29 23:24 JST 金 — Win版#132 part 237 (= stale-premise 是正 + scoped hygiene)
**Instance**: Win版 (Claude Code) #132 / part 237 (= 部 236 継続 5/25 → 部 237 5/29 = +4day gap resume / branch `claude/part-237-roadmap-wbs-sync` off fresh main)

**stale-premise 是正 第 1 例** (= prompt 前提を verify-first で cross-check → 5 件 false 検出):
1. date = part 236 継続 (5/25) 想定 → 実 **2026-05-29 23:24 金** (= +4day gap)
2. C: 23.68 GB DISK-WARN 第 4 連続候補 → 実 **C: 92 GB free** (= 圧縮 layer v27-29 / disk Tier 2 = moot / skip)
3. RAM 96.08% v24 SS 第 20 break 期待 → 実 **RAM 80%** (= no breach)
4. PR #2975+#2976 = canonical 6+7 連続 SUCCESS verify → 実 **#2975 BEHIND / #2976 CONFLICTING** (= gate 未到達 / branch 330 behind main)
5. #1495 = web-only リブランディング公開 messaging (Option D unilateral) → 実 **[P0][Mobile] iOS/Android 同時リリース準備** (= label priority:high / 5/18 以降 11 day stale / outward-facing → 無断 trigger せず)

**AskUserQuestion → user 選択 = Scoped hygiene + 1 task** (= 8-step full burst / verify-only / stop の 4 択提示)

**Deliverable** (= 本 PR):
1. **3 stuck WBS migration を main へ landing** (= #2976 の real content / #3003 payslip + #3006 salary-spending + #3007 disposable-balance / 全 additive idempotent `ON CONFLICT DO NOTHING` / origin/main 欠落確認済)
2. **ROADMAP backfill 235 + 236** (= Hybrid Option C / PR #2975 + #2976 supersede)
3. **PR #2975 + #2976 close superseded** (= dangling resolve 第 2 連続例)

**Hybrid Option C 適用拡張 第 1 例** = ROADMAP-only stub だけでなく #2976 の genuinely-missing real migration も carry (= 330-behind branch rebase ~1.5h 回避 / fresh branch cherry-pick ~20min)

**skip** (= scoped 判断 / NO-SCOPE-CREEP): 30-50 issue burst / 全 WBS reschedule / NotebookLM 抽出 / v27-29 圧縮 layer (= 全 false-premise or compaction-risk under FATIGUE)

**Philosophy Alignment** (= 5/9 scoped-hygiene):
- 原則 1 (CEO 感) ✅ stale prompt を verify-first で是正 = data-driven 判断
- 原則 4 (mentor) ✅ 8-step full burst を FATIGUE 下で scoped 化 = user 保護
- 原則 6 (商品=価値) ✅ 3 stuck WBS migration landing = 資産機能計画を main 反映
- 原則 7 (資本=時間) ✅ Hybrid Option C ~20min vs 330-rebase ~1.5h
- 原則 8 (KPI) ✅ C: 92GB / RAM 80% snapshot 正確記録

**教訓 (= 部 237)**:
1. **stale-prompt verify-first pattern 第 1 例** = session prompt 前提を盲信せず system date / KPI / git / PR / issue で cross-check → 5 件 false 検出 (= disk/RAM emergency 不在 / #1495 mismatch / PR blocked)
2. **Hybrid Option C real-content 拡張 第 1 例** = dangling PR が docs-only でなく real migration 含む時は close-superseded ではなく fresh branch carry
3. **330-behind branch 検出** = `claude/part-236-defer-handoff` 長期 stale / 次セッション以降 fresh main branch 厳守

---

## 2026-05-30 09:11 JST 土 — Win版#132 part 238 (= part 237 deferred PR landing + ROADMAP truncation 復旧 incident)
**Instance**: Win版 (Claude Code) #132 / part 238 (= 部 237 5/29 23:24 → 部 238 5/30 09:11 = ~10h gap / 06:00+ qualified / FATIGUE 維持 scoped)

**stale-prompt verify-first 第 2 例** (= prompt 前提 cross-check):
1. date = 2026-05-30 09:11 JST 土 (= 06:00+ ✅ / zone 02-06 外)
2. C: ~92GB (部 237 figure) → 実 **77.6 GB free** (= -14GB drift / no emergency)
3. RAM → 実 **92-96%** v24 SS zone (= FATIGUE → scoped)
4. branch fresh off main 期待 → 実 **`claude/part-236-defer-handoff` 369 behind / 253 staged files** (= 現 checkout stale)
5. PR #3046 green verify → 実 **12/12 checks pass + ultrareview skip (opt-in) / MERGEABLE / BEHIND 40**

**Deliverable**:
1. **PR #3046 MERGED** ✅ (= 部 237 work landing / 3 stuck WBS migration #3003/#3006/#3007 + ROADMAP backfill 235-237 + #2975/#2976 close superseded / mergeCommit `578160fec`)
   - BEHIND 40 → `gh pr update-branch` → CI 12/12 再 green → squash merge (= auto-merge repo-disabled → manual gate-poll)
   - part-237 worktree + remote/local branch cleanup
2. 🔴 **ROADMAP truncation incident 復旧 第 1 例** (= 本 PR core):
   - **`988febd07` "自動: ロードマップ セッション記録 2026-05-30 (Claude Schedule)" が ROADMAP を 31,323 行 → 5 行 (header のみ) に破壊** (= 1 insertion / 31,318 deletions)
   - 発生 09:22:50 JST = 私の #3046 merge (09:21:58) の **52 秒後** → automated Claude Schedule commit が full content を読めず destructive overwrite
   - **復旧 = `578160fec:docs/GROWTH_STRATEGY_ROADMAP.md` から full restore** (= last-good / part 237 entry 含む 31,323 行)
   - 5/29 `ca88c5fe4` 同名 task は schedule-log 書込のみ (= benign) → destructive 化は 5/30 第 1 例
3. **ROADMAP part 238 entry** (= 本エントリ)
4. **Issue 起票** = 再発防止 (= push-to-main regression guard + append-only discipline / Codex impl 振分)

**#1495**: mobile / priority:high / 5/18 stale 確認 (= status comment defer = redundant / mentor 自制)

**skip** (= NO-SCOPE-CREEP / FATIGUE): WBS task 実装 (= MCP unavailable / impl=Codex) / 競合 monitor (= cron / 5/31 解禁) / worktree sprawl ~50 件 cleanup (= 別 task)

**Philosophy Alignment** (= 6/9 incident-recovery):
- 原則 1 (CEO 感) ✅ data-loss incident を verify-first で検出 → 即復旧
- 原則 4 (mentor) ✅ FATIGUE 下 scoped / #1495 redundant comment 自制
- 原則 6 (商品=価値) ✅ 3 WBS migration main 反映 + 成長戦略 31k 行資産 復旧
- 原則 7 (資本=時間) ✅ git restore ~5min vs 手再構築 不能
- 原則 8 (KPI) ✅ C: 77.6GB / RAM 92-96% snapshot 正確記録
- 原則 9 (IPO) ✅ 再発防止 issue = systemic prevention

**教訓 (= 部 238)**:
1. **ROADMAP truncation incident 第 1 例** = automated Claude Schedule "ロードマップ更新" agent が 31k 行 file を full-overwrite で truncate / merge 直後 52 秒の race / restore = git last-good commit
2. **deferred-handoff PR landing pattern 第 1 例** = part 237 PR 作成 → part 238 verify+merge = session 跨ぎ clean handoff
3. **auto-merge repo-disabled + branch protection "require up to date"** = BEHIND branch は update-branch → CI 再走 → manual merge (= `--admin` bypass 不要)
4. **再発防止候補** = (a) push-to-main regression guard (ROADMAP 大量削除 reject / 既存 regression guard pattern 踏襲) (b) scheduled agent prompt = append-only Edit 強制 / full Write 禁止 (c) ROADMAP 巨大化 (31k 行) archive/split 検討

---

---

## 2026-05-30 12:00 UTC 土 — Win版#132 part 239 (= scheduled `daily-development` cron / autonomous / no user attention)
**Instance**: Win版 (Claude Code) #132 / part 239 (= 部 238 5/30 09:11 manual → 部 239 5/30 cron / 同日 2nd session = autonomous-safe triad / FATIGUE 維持 scoped)

**stale-prompt verify-first 第 3 例** (= prompt 前提 cross-check / 部 237→238→239 連続適用):
1. date = 2026-05-30 (= cron run / 06:00+ ✅ / zone 02-06 外)
2. C: 77.65 GB free / RAM 87% (= hook KPI / no emergency / < 90% v24 SS 回避)
3. branch 期待 fresh → 実 **`claude/part-236-defer-handoff` が MERGE IN PROGRESS + 386 behind main + 2 conflict (competitor-reports)** = dead orphan (PR #3046 merged 済 / no PR) → **触らず fresh worktree off origin/main で作業** (= WORKDIR-ISOLATION)
4. `git merge --abort` 試行 → **`lib/pages/asset_management_page.dart` uncommitted で abort refuse** = git が real work 保護 → **強制せず main dir そのまま flag** (= clobber 回避 / 部 237 verify-first 精神)
5. 最新 ROADMAP part = 238 / 最新 cron seed on main = part225 (part238/239 seed は worktree 内 uncommitted で未 land) → 衝突なし part239 採番

**Deliverable** (= autonomous-safe triad / 部 219+225 pattern 踏襲 / docs-only / no `.dart`):
1. **Blog draft pair (JA+EN)** = 「scheduled-agent append-only discipline + verify-first detection」(= `docs/blog-drafts/2026-05-30-scheduled-agent-append-only-guard.md` / -en.md / published:false) — 部 238 ROADMAP truncation incident **real-event 蒸留** (= fabrication 回避 / 実 incident のみ題材)
2. **Idempotent seed** = `20260530120000_seed_achievements_scheduled_daily_part239.sql` (= INSERT...WHERE NOT EXISTS)
3. **ROADMAP part 239 entry** (= 本エントリ / **append-only Edit = 31,364 行 1 行も full-read せず末尾 unique anchor 追記** = 部 238 教訓を本 session で dogfood)

**flag (= 次 session / Codex 候補)**:
- 🔴 main dir `claude/part-236-defer-handoff` = MERGE IN PROGRESS + uncommitted `lib/pages/asset_management_page.dart` 放置 (= abort refuse / 手動 resolve or 意図確認 要)
- worktree sprawl ~50+ 件 + dup blog-publish PR 4 件 (#3045/#3039/#3024/#3009 同一 draft) = cleanup 別 task

**skip** (= NO-SCOPE-CREEP / FATIGUE / autonomous): WBS 実装 (= impl=Codex / MCP unavailable) / 競合 monitor (= cron / 5/31 解禁) / broken merge 強制 resolve (= clobber risk)

**Philosophy Alignment** (= 6/9 autonomous-scoped):
- 原則 1 (CEO 感) ✅ dead branch / broken merge を verify-first 検知 → 触らず isolate
- 原則 4 (mentor) ✅ FATIGUE + autonomous 下 triad のみ / 強制 abort 自制
- 原則 6 (商品=価値) ✅ 実 incident 蒸留 blog = 再発防止知見の資産化
- 原則 7 (資本=時間) ✅ append-only Edit で 31k 行 file を安全更新 (= truncation 再発 0)
- 原則 8 (KPI) ✅ C:77.65GB / RAM 87% snapshot 正確記録
- 原則 9 (IPO) ✅ append-only 規律 + regression guard = systemic prevention 横展開

**教訓 (= 部 239)**:
1. **append-only Edit dogfood 第 1 例** = 部 238 truncation 教訓を即 session で実践 (= 31,364 行 file を unique-anchor 追記 / full Write 禁止を自ら遵守)
2. **dead-branch isolate pattern 第 1 例** = MERGE IN PROGRESS + 386 behind + uncommitted の orphan branch は abort 強制せず fresh worktree off main で迂回 (= clobber 回避)
3. **autonomous-cron triad safe 第 3 例** = 部 219 + 部 225 + 部 239 (= FATIGUE 下 docs-only triad = 再 compaction / scope creep 回避の安全形)

---

## 📋 part 240d (2026-06-03) — AI 駆動開発 運用モデル v1 + 3 レーン再定義 + WBS SDLC 工程 + stale doc 削除

**instance**: Win版 (Claude Code) = L3 設計レーン / **session**: part 240d (2026-06-03 / interactive / user 大型運用依頼)

**サマリ**:
- **3 レーン体制再定義** (user 指示): L1 Antigravity+Gemini 探索 / L2 VSCode+Codex 実装 / L3 VSCode+Claude 設計。canonical [`docs/AI_DRIVEN_DEV_OPERATING_MODEL.md`](AI_DRIVEN_DEV_OPERATING_MODEL.md) 新設 + `MULTI_INSTANCE_FLEET.md` + `CLAUDE.md` overlay repoint。
- **SDLC 7 工程タクソノミ** 定義 (企画/設計/実装/テスト/リリース/運用/保守) + WBS `phase` 列 migration を Codex へ handoff ([`cross-instance-prs/20260603_wbs_sdlc_phase.md`](cross-instance-prs/20260603_wbs_sdlc_phase.md) / Architect-Implementer ③)。
- **ベストプラクティス取得機構 (現実版)**: 24 社 full-read/session は非現実 → per-task context7/公式 fetch verify-first + 週次 vendor-digest routine 新設。
- **stale doc 削除 (verify-first)**: MULTI_INSTANCE_COORDINATION / INSTANCE_CONFIG / multi-ai-fallback / multi-ai-resilience + archive 重複 1 (AUTO_SAVE) = 5 件。archive 4 件は DIFFER 検出で誤削除回避。`DOCS_KNOWLEDGE_HUB.md` dead link 同時修正。
- **セッション儀式確立**: 1 WBS タスク/session + best-practice verify + commit→push→main merge。

**commit**: 本 PR / **follow-up**: WBS phase migration (Codex 適用) / `inject-rules.txt` `[INSTANCE]` 3 レーン更新 / `COMPRESSED_PROMPT_V3.md` stale 精査。

**Philosophy Alignment**: 原則 4 (mentor=verify-first/honest scope) ✅ / 原則 6 (商品=価値=運用モデル) ✅ / 原則 7 (資本=時間=stale 削除) ✅ / 原則 8 (KPI) ✅ / 原則 9 (IPO=systemic process) ✅ = **5/9**

---

## 📋 part 240e (2026-06-03) — AI大学 公民モジュール (kokkaimap.jp 相当) 設計

**instance**: Win版 (Claude Code) = L3 設計レーン / **session**: part 240e (2026-06-03 / interactive / user 依頼「kokkaimap.jp 相当機能の取り込み可否」)

**サマリ**:
- **feasibility verify-first**: kokkaimap.jp = 国会議員マップ (712議員地図 + 発言/投票 + Claude Haiku AI要約 + 投票マッチング / 源=国会会議録検索システム)。技術적には取り込み可だが core mission と別軸 + 政治コンテンツ固有リスク (中立性/名誉毀損) → **AI大学の「学び」に接続** = `civics` 学部として教育先行で取り込む方針を user 確定。
- **AI大学 構造 verify**: 学部→学科→content のデータ駆動階層 → **学部行追加で UI 自動表示 (Flutter 変更不要)**。AI要約は `ai-hub` EF `summarize.text` 再利用 (EF~15≪50 / 新規EF不要)。
- **段階設計** ([`docs/AI_UNIVERSITY_CIVICS_MODULE.md`](AI_UNIVERSITY_CIVICS_MODULE.md)): Phase1-2 (civics学部+4学科+教材seed / 低リスク MVP) → Phase3 (地図UI/郵便番号/AI要約 / 要GO) → Phase4 (国会会議録 live同期 / 🔴中立性ポリシー必須)。**v1=教材のみ**で議員評点を持たず名誉毀損リスクを構造回避。
- **Codex handoff** ([`cross-instance-prs/20260603_civics_module_mvp.md`](cross-instance-prs/20260603_civics_module_mvp.md)): Phase1-2 migration 完全SQL (idempotent / スキーマ準拠 / 中立ガード)。Issue 起票。
- データ源 = [国会会議録 API](https://kokkai.ndl.go.jp/api.html) (登録不要/JSON/**高頻度禁止→数秒間隔+キャッシュ必須**)。

**commit**: 本 PR / **follow-up**: Phase1-2 migration (Codex 適用) / Phase3-4 は別 Issue + 中立性ポリシー策定後。

**Philosophy Alignment**: 原則 1 (CEO感=mission整合へ reframe) ✅ / 原則 2 (ミッション=学びへ接続) ✅ / 原則 4 (mentor=feasibility verify+リスク明示) ✅ / 原則 6 (商品=価値=civic教育) ✅ / 原則 8 (KPI) ✅ = **5/9**

---

---

## 2026-06-04 - Codex #1: WBS SDLC 7工程 phase migration
**Scope**: Applied the Win Claude part 240d handoff for a schema-only WBS SDLC axis.

**Changes**:
- Added `public.wbs_tasks.phase` with the seven allowed values: `planning`, `design`, `impl`, `test`, `release`, `ops`, `maintenance`.
- Backfilled only production-confirmed WBS categories where phase mapping is unambiguous.
- Seeded one or more durable WBS tasks for every SDLC phase so planning through maintenance is visible in the backlog.
- Moved the completed handoff note to `docs/cross-instance-prs/done/20260603_wbs_sdlc_phase.md`.

**Validation focus**:
- Migration is additive and idempotent.
- Existing ambiguous WBS categories remain `NULL` for later manual/UI classification.
- Production verification target: `select phase, count(*) from public.wbs_tasks group by phase order by phase;`.

---

---

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


## Stack

- Frontend: Flutter Web (Dart)
- Backend: Supabase (PostgreSQL + Edge Functions / Deno)
- Hosting: Firebase Hosting
- AI: Claude Code (10 instances) + Codex CLI (2 instances)

Auto-generated by `scripts/build_in_public_extract.py` (= INDIE_DEV_VELOCITY #7 Community Engagement Discipline dogfood).
