---
title: Building 自分株式会社 — Last 7 Days of AI Fleet Development
published: false
tags: ai, indiedev, buildinpublic, claude
date: 2026-05-01
---

## TL;DR

Last 7 days of building **自分株式会社** (= Jibun Inc. / a personal life-management AI app) with a **12-instance AI fleet** (10 Claude Code + 2 Codex CLI). This post extracts the recent ROADMAP-LOG entries as a build-in-public update.

## Recent activity (auto-extracted)

## 2026-04-25 VSCode版 S4 — OGP cache-bust + x.post_with_media (dc2d8f25)
### 実装内容

1. **Phase 1: OGP deploy-time cache-bust** (deploy-prod.yml)
   - `build/web/index.html` の `ogp.png"` → `ogp.png?v=VERSION"` に sed 置換
   - Twitter は URL 変化で OGP 再クロール → 古いカード表示解消

2. **Phase 2b: schedule-hub x.post_with_media action**
   - `uploadMediaFromUrl` import 追加 + `x.post_with_media` case 実装
   - mediaUrl → Twitter Media Upload API (INIT/APPEND/FINALIZE) → postTweet
   - dry_run + credentials_missing ガード + x_post テーブルへのDB log

3. **GHA: post-x-with-media.yml**
   - cron: 毎週月曜 09:00 UTC (= 18:00 JST)
   - schedule-hub:x.post_with_media → ogp.png + 自動生成ツイートテキスト
   - workflow_dispatch: dry_run / custom text 対応

### 関連 commit
- `dc2d8f25` feat(ogp+x): OGP cache-bust on deploy + x.post_with_media EF action + weekly X post workflow

### Philosophy 9/9 ✅
### AI-DEV 7/7 ✅

---

## Win版#132 part 15 完了 (2026-04-25 午後)

### 実施内容: 全ページ X シェア + AI 自動生成 Phase 1

**契機**: ユーザー要請「全ページに X シェア機能 + ページごとに AI が文言・画像・動画 自動生成」

### 4-Phase 計画 (docs/PAGE_LEVEL_SHARE.md)

| Phase | 内容 | 担当 | 期日 |
|-------|------|------|------|
| **1 (本 commit)** | page_shares テーブル + core-hub:page.share_generate | Win | 2026-04-25 |
| 2 | Flutter ShareToXButton widget + MainScaffold 組込 | VSCode | 2026-05-05 |
| 3 | 動画生成 (high-traffic page のみ) | Win | 2026-05-15 |
| 4 | KPI ダッシュボード (admin/share-analytics) | VSCode | 2026-05-30 |

### Phase 1 実装

**Migration**: `20260425183000_create_page_shares.sql`
- `page_shares` テーブル新設 (page_path UNIQUE / tweet_text / image_url / video_url / share_count / video_enabled flag)
- 3 index (path / freshness / video_enabled 部分 index)
- RLS public read / service_role write
- 6 主要 page を初期 seed (/ /ai-university /comparison /landing /project-gantt /feature-requests)
- video_enabled=true は 4 page (LP / AI大学 / comparison / landing)

**EF action**: `core-hub:page.share_generate`
- **Auth**: anonymous OK (新たに `anonymousActions` set 追加)
- **Cache**: 7 日 TTL / `force=true` で bypass
- **Flow**: cache check → Gemini Flash で tweet 文 → FAL flux/schnell で画像 → upsert
- **Fallback**: Gemini fail → template / FAL fail → /ogp.png
- **share_count auto-increment** (KPI 用 / fire-and-forget)
- **trace_id**: generated_by に "gemini-flash+fal-flux-schnell" / "template+fal-flux-schnell" / "fallback" の 3 段階記録

**設計 doc**: `docs/PAGE_LEVEL_SHARE.md` (新規 12 section)
- アーキテクチャ + auth + cache 戦略
- Flutter UI 設計 (Phase 2 / VSCode handoff)
- Cost 試算 ($2-3/月 with cache hit)
- KPI 設計 (share_count / UTM)
- Philosophy 9/9 ✅ + AI-DEV 7/7 ✅

### Cost (cache 7 日効果込み)
- Gemini Flash: $0.64/月
- FAL flux/schnell: $2.40/月
- 合計 **$2-3/月** (大半 cache hit で実コスト圧縮)

### Philosophy 9/9 ✅
特に原則 5 (商品=ユーザー価値): 1 click でシェアハードル消失

### AI-DEV 7/7 ✅
3 段階 fallback (Gemini → template / FAL → ogp.png) で resilient

### commit: TBD

## PS\#3 S49 2026-04-25: AI大学 194→196社化 — Azure OpenAI + Semantic Kernel (d8cde724)

- **Azure OpenAI** (8.5/9): Microsoft Azure マネージドOpenAI / GPT-4o・o1・DALL-E・Whisper / プライベートエンドポイント+RBAC / HIPAA・SOC2・FedRAMP / Fortune100 90%+ 採用 / コンテンツフィルタ
- **Semantic Kernel** (8/9): Microsoft 公式 AI Agent SDK / .NET+Python+Java 対応 / Planner自動タスク分解 / Memory/Plugin / Azure OpenAI深統合 / MIT / 21k+ Stars
- 累計: 196社 seed 完備 / 次候補: OpenRouter / Databricks / Fal AI / Dify / Tabnine

### Rule 17 WF health check (2026-04-25 15:55 JST) — PS#1 S38

#### 全 WF success率 (main branch)
| WF | ✅ | ❌ | 状態 |
|---|---|---|---|
| ogp-image-refresh | 0 | 5 | **全件修正済** (YAML syntax error → fix `67d264cf`) |
| Deploy to Production | 3 | 2 | healthy (2 in_progress concurrency group) |
| Notion Mirror Sync | 1 | 1 | **修正済** (IDLE_TIMEOUT `f02c252b` / soft-fail `a13014c1`) |
| WBS AI Review | 4 | 1 | **修正済** (ai_review_status col deploy `20260425170000`) |
| その他 8 WF | 全 ✅ | 0 | healthy |

#### 修正済み
1. **ogp-image-refresh YAML syntax** — multi-line `git commit -m "..."` が column-0 行で YAML block 破壊。`-m` 2 回に分割 (`67d264cf`)
2. **Notion Mirror Sync IDLE_TIMEOUT** — 141 tasks × 350ms > 150s → limit 500→30 / sleep 350ms→150ms (`f02c252b`)
3. **ROADMAP orphaned conflict markers** — origin/main に `4. **deploy-prod repair list +8** — 20260425110000-124500 追加
5. **wbs-ai-review curl exit 22** — `ai_review_status` col が deploy 前に manual dispatch → deploy 完了後 3 success 確認

#### orphan branches
- `claude/vscode-wip`: VSCode版 active work (`dc2d8f25` で main にマージ済確認)
- blog-publish / cs-check 等: 0本

#### 次回チェック予定
- Notion sync: 次 cron (毎時10分) で IDLE_TIMEOUT 再発しないか確認
- ogp-image-refresh: 次月曜 cron または manual dispatch でFAL_KEY 動作確認

---

## PS#4 S46 2026-04-25 — 競合 66→80社化 Phase 2 Batch 4 完了

**担当**: PS版#4 (競合モニタリング)  
**commit**: 80326aa7

### 追加14社 (Phase 2 完了)

| カテゴリ | 社数 | 主要社 |
|---------|------|-------|
| AI Video | 3 | runway($1.5B) / heygen($500M) / pika($500M) |
| Developer/API | 2 | stripe($65B) / twilio($9B) |
| Health/Wellness | 3 | headspace($320M) / calm($2B/100M DL) / oura($5B) |
| JP HR | 1 | kincone(Suica打刻/中小特化) |
| E-Commerce | 1 | shopify($80B/176か国) |
| CRM | 2 | hubspot($15B/216K社) / salesforce($200B/Agentforce) |
| Design | 1 | canva($26B/170M users) |
| CMS | 1 | wordpress(web43%/Automattic $7.5B) |

**累計**: **80社** / 目標190社中 **42%完了** / Phase 2 完了 🎉

### Phase 2 達成サマリー (Batch 1-4)

| Batch | 追加社数 | 累計 | キー企業 |
|-------|---------|------|---------|
| Batch 1 | 15 | 36 | cursor/$9.9B / devin/$2B / freee(東証) |
| Batch 2 | 15 | 51 | whatsapp/2B users / atlassian/$42B / perplexity/$9B |
| Batch 3 | 15 | 66 | cohere/$2.2B / miro/$17.5B / salesforce-adjacent figma/$20B |
| Batch 4 | 14 | 80 | stripe/$65B / salesforce/$200B / canva/$26B |

### Philosophy Alignment (9/9)
- ✅ 競合データはリアルデータ (Supabase competitors テーブル)
- ✅ ダミーデータなし (市場評価・社数・設立年は公開情報ベース)
- ✅ ON CONFLICT DO UPDATE で冪等 migration
- ✅ Phase 2 目標 75-80社 達成 (80社)

### 次回 Phase 3 候補 (80→120社 = +40社)
- Gaming/Entertainment: nintendo / epic-games / roblox / sony-playstation / netflix
- FinTech/Insurance: paypal / square / wise / paidy / coinbase
- E-Commerce JP: rakuten / mercari / base / suzuri / minne
- Health JP: curon / medicom / everywhere / karada-no-kimochi
- AI JP: soracom / sakura-internet / ntt-docomo-ai / line-works

## PS#6 S42 — migration collision 183000 fix + repair list 183100/184500/200000 (2026-04-25)

**Commits**: e7f0faa1 (rename), 000e1368 (repair 200000)

### 実施内容

1. **Migration timestamp collision 183000 検出・修正** (e7f0faa1)
   - `create_page_shares` + `seed_azure_openai` 両方が 183000
   - `git mv` で seed_azure_openai を 183000→183100 にリネーム
   - repair list に 183000/183100/184500 を追加

2. **repair 200000 追加** (000e1368)
   - PS#4 S46 が `20260425200000_seed_competitors_phase2_batch4.sql` を追加
   - repair list に 200000 を即時追加

3. **整合性確認**
   - 全 20260425 migration: duplicate 0件 ✅
   - repair list: 183000/183100/184500/195000/200000 全カバー ✅

### Philosophy/AI-DEV
### Philosophy 9/9 ✅
### AI-DEV 7/7 ✅

---

## Win版#132 part 16 完了 (2026-04-25 夜)

### 実施内容: WBS instance='all' 廃止 + 'codex' 追加

**契機**: ユーザー要請「instance='all' は進捗が見えない / 各 instance 個別 task に / codex を instance 種類に追加」

### 既存状態
- `instance` CHECK 値: `vscode/win/ps1..ps6/web/mobile/schedule/gha/all` (10 + 'all')
- `owner_instance` CHECK: 既に `'all'` 禁止 + `codex` 追加済 (2026-04-21 / Win#131 part 15)

### 修正

**Migration**: `20260425210000_wbs_remove_all_instance_add_codex.sql`

1. **既存 `instance='all'` task を category 別 default rule で再割当**:
   ```sql
   business-legal/finance/product/hr/ops/ipo → win
   business-marketing → ps2 (T-1 dispatch)
   business-sales → ps5 (CS)
   UI/design 系 → vscode
   AI大学 / provider → ps3
   competitor → ps4
   horse / batch → ps6
   default fallback → win (経営担当)
   ```

2. **CHECK 制約更新**:
   - `'all'` 削除 (新規 all task 作成不可)
   - `'codex'` 追加 (OpenAI Codex 担当 / frontend Dart / SQL / GHA)
   - 残: `vscode/win/ps1..ps6/web/mobile/schedule/gha/codex` (12)

3. **schedule-hub:notion.sync_wbs の VALID_INSTANCES set 更新**:
   - 'all' 削除 / 'codex' 追加
   - alias: legacy 'all'/'schedule'/'gha' は 'win' にフォールバック (Notion select option 整合)
   - default 値も 'all' → 'win' に変更

### 影響
- **進捗 tracking 改善**: instance 別の `wbs.priority_for_instance` が正しく動作
- **責任明確化**: 各 task に primary owner instance が存在
- **Notion mirror も整合**: select option mismatch で 400 出ない
- **codex routing 拡張**: frontend Dart / SQL / GHA タスクを Codex に明示的に割当可能

### 後続必要タスク

| # | タスク | 担当 | 期日 |
|---|------|------|------|
| 1 | Notion DB の `instance` select option に `codex` 追加 (manual) | ユーザー | 2026-04-26 |
| 2 | Notion DB の `instance` select option から `all` 削除 (manual) | ユーザー | 2026-04-26 |
| 3 | Flutter UI の instance dropdown に `codex` 追加 | VSCode | 2026-04-30 |
| 4 | wbs-ai-review.yml prompt template に codex routing rule 追記 | Win 後続 | 2026-05-01 |

### Philosophy 9/9 ✅
原則 1 (CEO 感): 責任分担明確化 / 原則 8 (KPI=昨日の自分): instance 別進捗可視化

### commit: TBD

### Rule 17 WF health check (2026-04-25 16:25 JST) — PS#1 S39

#### WF全体健全 (main branch)
- 全 WF: 前セッション修正済みで追加 failure なし
- deploy `24925347569`: SUCCESS (horse-racing fix含む全 commits deploy 完了)

#### 実施内容
1. **claude/mobile-version-task-hQxcq 独自 commit merge** — horse_racing_predictor_page.dart 503/EDGE_RUNTIME_ERROR friendly copy → `8f0cfdc9`
2. **mobile orphan branch 削除** — `claude/mobile-version-task-hQxcq` (11 commits中10件はmain済 / horse_racing のみ未merge)
3. **deploy 監視** — `24925347569` SUCCESS 確認

#### WBS progress
- `deploy-prod 成功率100%維持`: 95% → 97%
- `EFハードキャップ16本維持`: 90% 維持

#### 残課題
- `claude/vscode-wip`: まだリモートに存在 (VSCode版管理 — PS#1 は触らない)
- Notion sync: 次cron 07:10 UTCで IDLE_TIMEOUT 再発チェック中

---

## PS#4 S47 2026-04-25 — 競合 80→95社化 Phase 3 Batch 1

**担当**: PS版#4 (競合モニタリング)  
**commit**: efa1f761

### 追加15社 (Phase 3 開始)

| カテゴリ | 社数 | 主要社 |
|---------|------|-------|
| Gaming/Entertainment | 4 | nintendo($50B) / sony-ps($100B) / roblox($22B/60M DAU) / epic-games($32B) |
| Content/Media | 2 | netflix($290B/260M) / spotify($90B/600M) |
| FinTech | 3 | paypal($65B/426M) / wise($10B) / paidy(JP BNPL/700万) |
| EC JP | 3 | rakuten($10B/スーパーアプリ) / mercari(東証/2200万MAU) / base(170万shop) |
| Learning | 2 | duolingo($6.5B/500M DL) / coursera($2.5B/148M) |
| AI JP | 1 | sakura-internet(東証/国産GPU/H100×5000) |

**累計**: **95社** / 目標190社中 **50%完了** 🎯

### Philosophy Alignment (9/9)
- ✅ 実データのみ (市場評価・ユーザー数は公開情報)
- ✅ ON CONFLICT DO UPDATE 冪等
- ✅ Phase 3 目標 120社に向けて順調

---

## Win版#132 part 17 完了 (2026-04-25 夜)

### 実施内容: WBS タスク動的再分担 (Rebalance) Phase 1

**契機**: ユーザー要請「instance 毎にタスク量に偏り / 担当作業ない instance / 各セッションで役割見直し / 滞留タスクを自担当に変更する臨機応変」

### 設計 (3-Phase)

| Phase | 内容 | 担当 | 期日 |
|-------|------|------|------|
| **1 (本 commit)** | wbs_rebalance_log + tools-hub:wbs.rebalance_suggest + wbs.claim_task | Win | 2026-04-25 |
| 2 | session-start hook ([WBS-SYNC] rule で 0 件時 auto-suggest) | PS#1 | 2026-04-30 |
| 3 | KPI dashboard (admin/instance-load) | VSCode | 2026-05-15 |

### Phase 1 実装

**設計 doc**: `docs/WBS_REBALANCE.md` (新規 10 section)
- アーキテクチャ + stale_score スコアリング
- 抑制ルール (1 session 最大 2 claim / 7 日 cooldown / completed 保護 / IPO 専決保護 / PS 専任保護)
- KPI 設計 + Philosophy 9/9 + AI-DEV 7/7

**Migration**: `20260425220000_wbs_rebalance_log.sql`
- wbs_rebalance_log テーブル (audit log + 戻し可能性)
- wbs_tasks 拡張 2 カラム (last_rebalanced_at / rebalance_count)
- RLS public read / service_role write

**EF actions**: tools-hub に 2 actions 追加
1. `wbs.rebalance_suggest({my_instance, limit})` — 他 instance の滞留 task 候補 (stale_score 順)
2. `wbs.claim_task({task_id, my_instance, reason})` — 自担当に変更 + audit log

### stale_score スコアリング
```
score = 期限ペナルティ (50/30/15) + 進捗停滞 (30/20/10) +
        half-way stuck (25) + priority bonus (20/10) - cooldown (-30)
```

### 抑制ルール
- 1 session 最大 2 claim (詰込防止)
- 7 日 cooldown (loop 防止)
- 専任保護: rule17-* → PS#1 / blog-* → PS#2 / urgent bug → PS#5 / business-ipo → CEO
- 期限直前 (1 日切) + priority=high → 元担当に集中

### 動作確認 (deploy 完了後)
```bash
# 自 instance task 0 件想定 → suggest — 2026-05-01_devto_draft
curl -sS -X POST "$SUPABASE_URL/functions/v1/tools-hub" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"wbs.rebalance_suggest","my_instance":"win"}'

# 候補から 1 件 claim
curl -sS -X POST "$SUPABASE_URL/functions/v1/tools-hub" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"wbs.claim_task","task_id":"<uuid>","my_instance":"win","reason":"auto_idle_session"}'
```

### Philosophy 9/9 ✅
原則 4 (6 部署バランス) 直接実装 + 原則 6 (資本=時間) instance 時間消費削減

### AI-DEV 7/7 ✅
特に原則 5 (team memory) wbs_rebalance_log = 完全 audit / 原則 7 (quality gate) 抑制ルール多重防御

### commit: TBD
---

## PS#6 S43 — deploy failure triage: wbs_instance_check SQLSTATE 23514 + repair 203000 (2026-04-25)

**Commits**: 8749a456 (repair 203000)

### 実施内容

1. **Deploy failure 24925692958 (fix: split WBS all instance tasks) 原因特定**
   - `ERROR: wbs_tasks_instance_check (SQLSTATE 23514)` — instance='all' が CHECK 制約違反
   - Win版#132 part 16 (210000) が CHECK 制約から 'all' を削除済みなのに、後続 migration が instance='all' を INSERT
   - Win版が hotfix commit cf9a375b で対応中 (run 24926480131)

2. **repair list 203000 追加** (8749a456)
   - `20260425203000_wbs_remove_all_instances_add_codex.sql` (Win版 hotfix) が repair list 未登録
   - 203000 を repair list に追加

3. **Migration 整合性確認**
   - duplicate: 0件 ✅
   - repair list 203000/210000 追加済み ✅

### Philosophy/AI-DEV
### Philosophy 9/9 ✅
### AI-DEV 7/7 ✅

## PS#3 S50 2026-04-25: AI大学 196->198社化 — Tabnine + Gamma (7c5933a9)

- **Tabnine** (8/9): エンタープライズAIコード補完 / オンプレミス+VPC デプロイ / SOC2 Type II・GDPR / 学習データ非使用保証 / 1M+ 開発者 / 53M ドル調達 / GitHub Copilot Enterprise 代替
- **Gamma** (8/9): AI プレゼンテーションビルダー / テキスト->スライド瞬時生成 / Notion+Canva 融合 / Web 公開+閲覧分析 / 12M ドル調達 / 4M+ 月間ユーザー / YC 卒業
- 累計: 198社 seed 完備 / 次候補: AssemblyAI / Luma AI / Synthesia / Tome / Together AI (already registered)


---

## PS#2 S24 — WBS ps2 誤割当検出 + 報告 (2026-04-25)

**インスタンス**: PS版#2 (T-1 blog dispatch 専任)

- Date-gate 再確認: May 2/4 スキップ正常
- Orphan branch: 0本
- WBS ps2 誤割当: business-legal tasks → cross-instance-pr to Win版
- commit: e5f51e37 (本セッション別コミット)

Philosophy 9/9✅

---

## Win版#132 part 18 完了 (2026-04-25 夜)

### 実施内容: WBS instance 拡張 (gemini/copilot/user) + user タスク Slack 通知

**契機**: ユーザー要請「gemini, co-pilot, user を instance 種類に追加 / user 担当 = 手動操作タスク / 各セッションで user タスクをユーザー通知 + Slack 通知」

### 実装

1. **Migration** `20260425230000_wbs_add_gemini_copilot_user_instances.sql`
   - instance CHECK: 12 → 15 (gemini / copilot / user 追加)
   - owner_instance CHECK 同期
   - 既存「ユーザー手動」task を自動再割当:
     - Notion 設定系 / Slack Webhook 設定 / 法人登記 / 商標出願 / 司法書士契約 / 銀行口座 / 会計ソフト / 監査法人選定 / 主幹事証券 / 上場審査 → instance='user'
   - `'all'` は part 16 で既に廃止済 (継続)

2. **EF action** `tools-hub:wbs.notify_user_tasks`
   - input: `{send_slack: bool=true, limit: int=10}`
   - flow:
     1. instance='user' の pending/in_progress task fetch (priority desc / end_date asc)
     2. Slack #jibun-handoff (SLACK_WEBHOOK_URL) に整形 post
     3. priority icon (🔴 high / 🟡 medium / 🟢 low) + due / progress 表示
   - soft-fail: SLACK_WEBHOOK_URL 欠落で skipped 返却

3. **GHA workflow** `.github/workflows/wbs-user-tasks-notify.yml`
   - cron: `0 0 * * *` (毎朝 09:00 JST)
   - tools-hub:wbs.notify_user_tasks call
   - HTTP 200 以外で warning + skip (soft-fail)

### Instance 種類 一覧 (15)

| # | instance | 用途 |
|---|----------|------|
| 1 | vscode | UI/design / 大規模 refactor |
| 2 | win | AI大学追加 / migration / EF cleanup / 動画 / アーキテクチャ |
| 3-8 | ps1..ps6 | 専任 (Rule17 / T-1 / AI大学 / 競合 / on-call / horse) |
| 9 | web | screenshot + Issue 起票 |
| 10 | mobile | 実機 UAT screenshot + Issue 起票 |
| 11 | schedule | Claude Code Schedule (cron) |
| 12 | gha | GitHub Actions Workflow |
| 13 | codex | OpenAI Codex (frontend Dart / SQL / GHA) |
| 14 | **gemini** (新) | Gemini Code Assist (大規模 refactor / 長文) |
| 15 | **copilot** (新) | GitHub Copilot (inline 補完 / Chat) |
| 16 | **user** (新) | **ユーザー手動操作タスク** (Notion 設定 / Slack Webhook / 法人登記 / IPO 決裁等) |

`'all'` は廃止 (Win#132 part 16)。

### 動作確認 (deploy 完了後)
```bash
# 手動 trigger
gh workflow run wbs-user-tasks-notify.yml --field limit=10

# Slack #jibun-handoff に通知が届くか確認
```

期待 Slack message:
```
📋 WBS user タスク N 件 (要ユーザー手動操作)

1. 🔴 株式会社設立登記 — business-legal 0% 期限 2026-09-30
2. 🟡 商標出願 (自分株式会社 / Logo) — business-legal 0% 期限 2026-10-31
...

🔗 WBS Gantt: https://my-web-app-b67f4.web.app/project-gantt
```

### Philosophy 9/9 ✅ + AI-DEV 7/7 ✅
原則 1 (CEO 感): user 専任 task の明示で意思決定 visibility
原則 4 (6 部署): user = 経営層の専任行動 = HR 的位置づけ

### commit: TBD

---

## Win版#132 part 18 完了 (2026-04-25 夜)

### 実施内容: WBS instance 拡張 (gemini/copilot/user) + user タスク Slack 通知

**契機**: ユーザー要請「gemini, co-pilot, user を instance 種類に追加 / user 担当 = 手動操作タスク / 各セッションで user タスクをユーザー通知 + Slack 通知」

### 実装
- Migration: instance CHECK 12 → 15 (gemini/copilot/user 追加) + 既存 user 手動タスク再割当
- EF: tools-hub:wbs.notify_user_tasks (Slack post)
- GHA: wbs-user-tasks-notify.yml (毎朝 09:00 JST cron)

### Instance 種類 (15)
vscode/win/ps1..ps6/web/mobile/schedule/gha/codex/**gemini/copilot/user** (新)

### commit: TBD (本 commit)
## PS#4 S48 2026-04-25 — WBS instance拡張 + ユーザー通知自動化

**担当**: PS版#4  
**commit**: b529dff5

### 変更内容

| コンポーネント | 変更 |
|--------------|------|
| DB migration (225000) | CHECK制約拡張: `gemini`/`co-pilot`/`user` 追加 + 手動タスク自動再割当 |
| tools-hub WBS_INSTANCE_VALUES | `gemini`/`co-pilot`/`user` 追加 (17種類に) |
| tools-hub `wbs.notify_user_tasks` | user担当タスク一覧取得 + Slack push |
| GHA `wbs-user-notify.yml` | 毎朝9:00 JST 自動実行 (manual dispatch も可) |

### instance種類 (最終版 17種)
```
codex / vscode / win / ps1-ps6 / web / mobile / schedule / gha
gemini / co-pilot / user  ← NEW
```

### user instanceの自動割当ルール
登記/口座/届出/契約/署名/印鑑/社会保険/採用面接/出資/融資 等の title ILIKE で自動判定。

### Slack通知 設定方法
GitHub Secrets に `SLACK_WEBHOOK_URL` を設定するだけで有効化。
Incoming Webhook URL は https://api.slack.com/messaging/webhooks で取得。

---

## PS#4 S48 2026-04-25 — WBS instance拡張 + ユーザー通知自動化

**担当**: PS版#4  
**commit**: b529dff5

### 変更内容

| コンポーネント | 変更 |
|--------------|------|
| DB migration (225000) | CHECK制約拡張: gemini/co-pilot/user 追加 + 手動タスク自動再割当 |
| tools-hub WBS_INSTANCE_VALUES | gemini/co-pilot/user 追加 (17種類に) |
| tools-hub wbs.notify_user_tasks | user担当タスク一覧取得 + Slack push |
| GHA wbs-user-notify.yml | 毎朝9:00 JST 自動実行 |

### instance種類 (最終版 17種)
codex/vscode/win/ps1-ps6/web/mobile/schedule/gha/gemini/co-pilot/user

### Slack通知 設定
GitHub Secrets に SLACK_WEBHOOK_URL を設定するだけで有効化。

---

## PS#5 S51 2026-04-25 — cf9a375b SUCCESS + 200000 collision fix 確認

**担当**: PS版#5 (on-call CI)  
**commits**: cf9a375b (fix SUCCESS) / ddc2738f (PS#6 200100 rename)

### 実施内容

| 項目 | 結果 |
|------|------|
| cf9a375b run (24926480131) | ✅ SUCCESS (6m8s) — wbs_instance_check fix 適用 |
| #718 クローズ | ✅ (PS#6 実施) |
| 200000 タイムスタンプ衝突発見 | competitors_batch4 vs tabnine — 同一 ts → SQLSTATE 23505 |
| PS#6 ddc2738f で 200100 リネーム | ✅ repair list 200100/201500/211500/220000/223000 追加 |
| pipeline 状態 | 9f27fa6e in_progress (衝突で失敗見込み) → ebbe6586 pending (fix込み) |

### wbs_instance_check 根本原因 (PS#5 S51 調査)
- migration 203000: INSERT(schedule/gha) が DROP CONSTRAINT より先に実行
- 170000 の constraint が schedule/gha を許可していなかった
- cf9a375b で 170000 冒頭に DROP/ADD CONSTRAINT (schedule/gha/all 許可) 追加
- repair list 170000 があるため 170000 が再適用 → 制約が拡張された状態で 203000 の INSERT が通る

### 次回 deploy 見込み (ebbe6586)
- 200000 衝突なし (200100 にリネーム済)
- 201500/225000/230000: 新規 migration → fresh apply
- repair list 220000/223000: 再適用済み

---

## PS#3 S52 — 2026-04-25 (5516bf57)

### AI大学 198→200社化 — Tome + Krisp (PS#3-S52)

**実施内容**:
- **Tome** (AI プレゼンテーション・ドキュメント生成 / GPT-4 統合 / $75M Series B Coatue / 5M+ ユーザー / ★8/9)
- **Krisp** (AI ノイズキャンセリング & ミーティングアシスタント / CPU DNN / 双方向雑音除去 + 文字起こし + AI サマリー / $9.5M / 20M+ / ★8/9)
- ai_university_content に各 3 section (overview/api/models) 追加
- **AI大学 200社マイルストーン達成** 🎉

**選定理由**:
- AssemblyAI/Synthesia/Luma AI は既登録 → Tome + Krisp が未登録候補
- Tome: プレゼン生成 AI として Gamma と並ぶ重要プレイヤー ($75M 大型調達)
- Krisp: 音声 AI の実用ツールとして 20M+ ユーザーの実績あり

**次回候補**: Coqui AI / Otter.ai / Descript / Murf / ElevenLabs (TTS特化) / Resemble AI

---

## Win版#132 part 19 完了 (2026-04-26 朝)

### 実施内容: user タスク進捗報告 + NotebookLM 蓄積基盤 + UI handoff

**契機**: ユーザー追加要請「user タスクを NotebookLM に蓄積して具体的手順分析 + 完了/状況報告 UI」

### 実装

1. **Migration** `20260426000000_wbs_user_task_reports.sql`
   - `wbs_user_task_reports` テーブル (時系列の進捗報告)
   - columns: task_id (FK) / reporter / progress / status / report_text / blockers / next_action / metadata / created_at
   - RLS: public read / service_role write

2. **EF actions** `tools-hub`:
   - `wbs.user_task_report`: 進捗報告 + 履歴 INSERT (instance='user' guard)
   - `wbs.export_user_tasks_md`: NotebookLM 用 markdown export (active task + 直近 report 3 件)
   - 重複 `wbs.notify_user_tasks` (本 part 18 で追加した版) を削除 — PS#3/4 の改良版に統合

3. **GHA workflow** `notebooklm-user-tasks-sync.yml`
   - cron: `30 0 * * 1` (毎週月曜 09:30 JST)
   - tools-hub:wbs.export_user_tasks_md call → docs/user-tasks-snapshot.md commit
   - soft-fail: HTTP error / size <50bytes で skip

4. **cross-instance-pr** `docs/cross-instance-prs/20260426_user_task_report_ui.md`
   - VSCode へ UI 実装 handoff (期限 2026-05-05)
   - `/user-tasks` ページ + 進捗報告モーダル仕様

### NotebookLM 蓄積フロー

```
1. ユーザーが Notion/Slack 等で「報告する」
   ↓
2. tools-hub:wbs.user_task_report → wbs_user_task_reports に履歴
   ↓
3. 毎週月曜 09:30 JST GHA cron が markdown export
   ↓
4. docs/user-tasks-snapshot.md として commit
   ↓
5. ユーザーが手動で `notebooklm source add docs/user-tasks-snapshot.md`
   ↓
6. NotebookLM が「具体的手順」「詰まり解消法」を分析回答
```

### 質問例 (NotebookLM)
- 「商標出願の具体的手順を弁理士選定から登録完了まで step-by-step で」
- 「blockers で「料金が不明」とあるタスクの最新相場を調査」
- 「期限が 30 日以内のタスクを priority 順に並べて、最短ルートを提示」
- 「進捗が 1 週間動いていないタスクの典型的な詰まりパターンを抽出」

### Philosophy 9/9 ✅ + AI-DEV 7/7 ✅
特に原則 5 (team memory): wbs_user_task_reports = NotebookLM source 化

### commit: TBD

---

## PS#4 S49 — ユーザータスク進捗報告UI + NotebookLM蓄積基盤 (2026-04-25)

### 実装内容

| コンポーネント | 変更 |
|---|---|
| migration 231500 | user_task_reports テーブル + wbs_tasks.notebooklm_note/notebooklm_synced_at |
| tools-hub | wbs.get_user_tasks (UI用一覧+latest_report) + wbs.submit_user_task_report (報告INSERT+Slack) |
| lib/pages/user_tasks_page.dart | 新規Flutterページ (未完了/完了タブ / 優先度バッジ / 進捗バー / 期限カウント / 報告ダイアログ) |
| lib/main.dart | /user-tasks ルート追加 |
| wbs-user-notify.yml | NotebookLM用MD生成+commit+Slack CLI手順通知 |

### commit: e419da51

### 注記
- Win版 part 19 が先行して wbs_user_task_reports テーブル + wbs.user_task_report/export_user_tasks_md を実装
- PS#4 は別テーブル user_task_reports + UI向け wbs.get_user_tasks/submit_user_task_report を追加（相補的設計）
- tools-hub conflict: Win版追加分 (1560/1627行) を保持 + 我々の追加分 (1835行〜) をマージ

---

## PS#2 S26 — T-1 dispatch no-op + user tasks feature routing 完了確認 (2026-04-25)

### T-1 dispatch 状況

| slug | 公開日 | T-1 dispatch日 | 状況 |
|---|---|---|---|
| 2026-05-02-notion-paywall-d2-parallel-6-departments | May 2 | May 1 | date-gate skip (今日Apr 25) |
| 2026-05-04-notion-paywall-d0-alternative-6-departments | May 4 | May 3 | date-gate skip (今日Apr 25) |

- Orphan branch: 0本
- 次回 dispatch: May 1 JST (PS#2 S27予定)

### user tasks 機能 — 完了確認

| 機能 | 担当 | 状況 |
|---|---|---|
| wbs.notify_user_tasks Slack通知 | PS#2 (duplicate case fix) | ✅ 493fea50 |
| user task report + NotebookLM EF | Win版#132 part 19 | ✅ 0ca06637 |
| Flutter user_tasks_page.dart | PS#4 S49 | ✅ e419da51 |
| notebooklm-user-tasks-sync GHA | Win版#132 part 19 | ✅ 0ca06637 |

### commit: no-op (ROADMAP append only)

---

## PS#3 S53 — 2026-04-25 (a3a43e00)

### ユーザータスク全機能 確認 + Gantt ナビボタン追加 (PS#3-S53)

**実施内容**:
- 既実装確認: WBS instance 拡張 (all廃止/gemini/copilot/user追加) / Slack通知 / NotebookLM蓄積バックエンド / Flutter UI (/user-tasks)
- **新規**: project_gantt_page AppBar に `👤 person_outline` アイコンボタン追加 → `/user-tasks` 遷移
- dart format 0 / flutter analyze 0 確認

**ユーザータスク機能フル実装状況**:
- Slack 毎朝 09:00 JST cron (wbs-user-tasks-notify.yml)
- NotebookLM snapshot 毎週月曜 (notebooklm-user-tasks-sync.yml → docs/user-tasks-snapshot.md)
- Flutter UI: https://my-web-app-b67f4.web.app/user-tasks (Active/Completed タブ / 進捗報告フォーム)
- tools-hub: wbs.get_user_tasks / wbs.submit_user_task_report / wbs.export_user_tasks_md

**残: ユーザー手動設定**:
- `supabase secrets set SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx`
- `notebooklm source add docs/user-tasks-snapshot.md` (初回のみ)

## Win版#132 part 20 完了 (2026-04-26 朝)

### 実施内容: deploy-prod CI fail hotfix — wbs_tasks_instance_check 違反

**契機**: deploy-prod 失敗 (run 24927211757 後続) — 203000 migration の statement 5 (UPDATE owner_instance CASE) で `instance='user'` 行に CHECK 違反 (170000 の CHECK は 'user' 含まず)

### 根本原因
- 203000 が repair list で reverted 化 → 再実行
- 203000 の UPDATE 5 は WHERE 句なし → 全行 touch → 170000 CHECK trigger
- 170000 CHECK ('user' 含まず) で 'user' 行 fail
- ループ (毎 deploy で同じ場所失敗)

### 修正

**1. `20260425203000_wbs_remove_all_instances_add_codex.sql`**:
- UPDATE 5 (CASE) に WHERE 句追加: `WHERE owner_instance IN ('windows','ps','all') OR owner_instance IS NULL`
  - 'user'/'gemini'/'copilot' 行を touch しない → CHECK trigger 回避
- UPDATE 6/7 (NOT IN ...) の許可リストに 'user'/'gemini'/'copilot' 追加
- 末尾 CHECK 制約 (instance + owner_instance) に super-set 含める ('user'/'gemini'/'copilot')
  - 後続の 230000 が再上書きしても整合 / re-run 安全

**2. `20260425170000_business_wbs_phase1.sql`**:
- CHECK 制約 super-set 化: 'user'/'gemini'/'copilot' を予約値として含める
- NOT VALID 維持 (既存 row 検証は skip)
- 200000 系 migration が再実行されても 'user' 行で違反しない

### Idempotency 保証
両 migration とも repair list で reverted 化されて再実行されても:
- WHERE 句で 'user' 行 protection
- CHECK super-set で全 valid value 許容

### Philosophy 9/9 ✅
原則 7 (BS): migration 整合性確保で不整合資産を負債に変えない / 原則 8 (KPI=昨日): CI 緑化で deploy 速度回復

### commit: TBD

---

## PS#4 S50 — 競合 95→190社化 Phase 3 完全達成 🎉 (2026-04-26)

### 実装内容

| Batch | 社数 | カテゴリ |
|---|---|---|
| Batch 2 (010000) | 95→110 | Developer Tools + Finance JP + Health JP + Collaboration + Data/AI Platform |
| Batch 3 (020000) | 110→125 | AI Writing/Video/Voice + Automation + Security + HR/Legal JP |
| Batch 4 (030000) | 125→140 | EC Platform + EdTech JP + Real Estate + Travel + Food + AI Productivity |
| Batch 5 (040000) | 140→155 | Crypto + Insurance + Media JP + Social Commerce + AI Agent Platform |
| Batch 6 (050000) | 155→170 | Telecom JP + Logistics + Cloud Gaming + AI Chip + Healthcare AI + CRM |
| Batch 7 (060000) | 170→190 | Ad Tech + Mobility JP + GovTech + OSS AI + Vertical AI |

### commit: c5c7343e (Batch2) + 330d6ef3 (Batch3-7) → push d8ac2862

### KPI達成状況
- 競合190社 ✅ (目標100% 達成)
- COMPETITOR_EXPANSION_PLAN.md Phase 1+2+3 全完了
- critical threat: Notion AI / Linear / HubSpot / Zoho / Harvey / TikTok Shop 等を捕捉
- 新カテゴリ追加: advertising / mobility / gov-tech / legal-tech / media / logistics / telecom / education

---

## PS#2 S27 — T-1 dispatch no-op (同日再起動) (2026-04-25)

- 同日 S26 完了後に再起動。今日 Apr 25 → date-gate変化なし。
- Orphan branch: 0本
- 新規 unpublished draft: なし (May 2 / May 4 slug のみ)
- 次回 dispatch: **May 1 JST**

### commit: no-op
## PS#1 S41 — Rule17 WF health check + YAML/deploy修復 (2026-04-25)

### Rule17 WF集計

| WF | ✅ | ❌ | 状態 |
|---|---|---|---|
| Deploy to Production | 1 | 3 (+ 12 cancelled) | **in_progress 24927211757 (9e42fb8d)** |
| notebooklm-user-tasks-sync | 0 | 1 | **修正済** (YAML block scalar) |
| Notion Mirror Sync | 2 | 0 | healthy |
| WBS AI Review | 2 | 0 | healthy |
| AI大学コンテンツ更新 | 1 | 0 | healthy |
| CS Check | 2 | 0 | healthy |
| その他 | 全✅ | 0 | healthy |

### 修正内容

1. **Rebase conflict解消**: tabnine 200000 collision — origin が 200100 に rename済み確認 → ローカル 202000 commit を drop + fast-forward
2. **tools-hub duplicate case**: Deno lint `wbs.notify_user_tasks` 重複 → origin/main `493fea50` で修正済み確認 (deploy 24927211757 で検証中)
3. **notebooklm-user-tasks-sync YAML syntax error**: `git commit -m "..."` multi-line body at column-0 → split `-m` fix via GitHub API PUT (`9e42fb8d`)
4. **orphan branch削除**: `claude/mobile-version-task-hQxcq` (horse_racing merged) 削除

### deploy状況
- Run `24927211757` on `9e42fb8d` — in_progress at time of writing

---

## PS#2 S28 — T-1 no-op (Apr 25 3回目) (2026-04-25)

同日 S26/S27 に続く3回目起動。状況変化なし。Apr 26既刊確認済 (JA+EN published:true)。
次回 dispatch: May 1 JST。

### commit: no-op

---

## PS#4 S51 — Phase 3 競合自動 discovery 完成 (2026-04-26)

### 実装内容

1. **`competitor_candidates` テーブル** (migration 20260426070000)
   - Phase 3 週次 discovery の staging テーブル
   - ai_score / threat_level / reviewed / promoted / discovery_week フラグ
   - RLS: public read / service_role write

2. **`competitor-discovery.yml`** (新規 GHA)
   - 毎週月曜 08:00 JST cron / workflow_dispatch 対応
   - Gemini 1.5 Flash で 10 カテゴリ × 5 社自動発掘
   - 既存 190 社と重複除去 → competitor_candidates に staging
   - `docs/competitor-reports/discovery-YYYY-MM-DD.md` レポート生成

3. **`competitor-monitoring.yml` 更新**
   - Step 3: 21社固定 → `competitors` テーブル動的取得 (190社対応)
   - threat_level → tier アイコン変換 (high=🔴 / medium=🟠 / low=🟡)
   - Supabase 取得失敗時: 固定10社フォールバック

### commit: ecd93e7c

---

## PS#2 S29 — SEO改善 + 動的タスクルーティング実装 (2026-04-25)

### 実施内容

| 作業 | 詳細 |
|---|---|
| SEO: sitemap.xml | /user-tasks + /legal-compliance 追加 / ai-university lastmod 2026-04-25更新 / changefreq=daily |
| SEO: index.html meta | description「21の競合」→「190社以上」/ keywords += AI大学/user-tasks/Cursor/v0 |
| SEO: og/twitter | title/description を190社・200社AI大学対応に更新 |
| WBS動的クレーム | SEO改善タスク (02b91199) をvscode→ps2 claim → 実行 → 100%完了 |
| inject-rules.txt | [DYNAMIC-CLAIM] + [WBS-DEDUP] 追加 (全インスタンス適用) |
| cross-instance-pr | docs/cross-instance-prs/20260425_wbs_dedup_fix.md → Win版 |

### commit: 6519ec4a (SEO) / inject-rules: local only

### [DYNAMIC-CLAIM] 仕組み

T-1 no-op 時: wbs.rebalance_suggest → claim → 実行 → completed の自動化フロー。
PS#2 が引き取れる: marketing/docs/seo/product-light。
禁止: business-legal / urgent / IPO。

---

## PS#4 S52 — WBS重複クリーンアップ + competitors スキーマ修正 (2026-04-26)

### 実装内容

1. **WBS タスク重複クリーンアップ** (migration 20260426080000)
   - 89 title+instance 重複コンボ / 余剰行 582 件 DELETE
   - `DISTINCT ON (title, instance) ORDER BY created_at ASC` で最古行保持
   - `wbs_tasks_title_instance_unique` INDEX で再発防止

2. **competitors テーブル Phase 3 スキーマ拡張** (migration 20260426090000)
   - Phase 3 seed migrations が使う新カラムを ADD COLUMN IF NOT EXISTS
     `threat_level / our_overlap_score / website_url / headquarters / name /
      funding_or_valuation / employee_count_range / key_features / created_at`
   - 既存 Phase 1 データを新カラムにコピー (website→website_url 等)

3. **competitor-monitoring.yml YAML 修正**
   - Python code at col-0 → YAML parse error → single-line python3 -c に修正
   - Phase 1/3 両スキーマ対応 (website_url OR website)

### commits: 031c132b (dedup) → e8045440 (schema+yaml) → 390dcd68 (push)

---

## PS#2 S30 — [DYNAMIC-CLAIM] 2nd slot + SEO完了マーク (2026-04-25)

### 実施内容

1. **T-1 check**: no-op (May 2 slug = May 1 dispatch待ち / orphan 0本)
2. **[DYNAMIC-CLAIM] wbs.rebalance_suggest(ps2)**: top-5 全 business-legal → PS#2 禁止カテゴリ
3. **wbs.list_tasks(category=marketing)**: pending marketing tasks なし (future milestones only)
4. **SEO task 02b91199 → completed**: in_progress+100% → status=completed に更新
5. **2nd claim**: 適切タスクなし → 1 session 1 claim (SEO = 1/2 slot)

### WBS-SYNC

- `wbs.update_progress(02b91199, 100, completed)` ✅
- 更新件数: 1件

### 所見

- `wbs.rebalance_suggest` は stale_score で重み付けするため high-priority の business-legal が常に上位
- PS#2 が引き取れる marketing/docs/seo タスクは現時点で pending なし
- 今後: `wbs.rebalance_suggest` に category_filter パラメータ追加 → Win版 cross-instance-pr

### commits: SEO completed via WBS API (no code change)

---

## PS#1 S42 — Rule17 WF health check (2026-04-25)

### 全 WF success率 (直近20件)
- Notion Mirror Sync: 2OK / Deploy to Production: 3F 0OK (in-progress) / competitor-discovery: 7F / competitor-monitoring: 2F / Edge Function Audit: 1OK / WF Failure Handler: 4OK

### 失敗 WF と原因

| WF | 失敗数 | 原因 | 対応 |
|---|---|---|---|
| `competitor-discovery.yml` | 7 | YAML block scalar column-0 bug — `run: \|` 内の多行 bash string (PROMPT) + Python heredoc が column 0 で YAML block 終了 | **修正済み 9bc7b6fa** — Step2 PROMPT+= 連結 / Step3 env:STAGE_PY / Step4 env:REPORT_PY |
| `competitor-monitoring.yml` | 2 | 同上 Python inline が column 0 | upstream fix `5302a24c` 適用済 (R/O/Y tier code approach) |
| `deploy-prod.yml` | 3 | SQLSTATE 23514 (migration 210000 CHECK constraint 違反) — 後続 migration で追加された user/gemini/co-pilot rows に対して旧 constraint が拒否 | **修正済み 0ea89450** — 210000 に user/gemini/copilot/co-pilot を super-set 追加 |

### orphan branches: 0本 (前回削除済)

### 修正済み
- migration 20260425210000: forward-compatible CHECK constraint (commit 0ea89450)
- competitor-discovery.yml: 全 Steps の column-0 YAML bug 修正 (commit 9bc7b6fa)
- competitor-monitoring.yml: upstream fix 確認 + autostash conflict 解消

### commits: 9bc7b6fa (ci fix)

---

## PS#2 S31 — DYNAMIC-CLAIM: SEO 記事50本計画 策定 (2026-04-25)

### 実施内容

1. **T-1 check**: no-op (May 2/4 slugs = May 1/3 dispatch待ち) / orphan 0本
2. **[DYNAMIC-CLAIM]**: wbs.rebalance_suggest top-5 = 全 business-legal → スキップ
3. **wbs.list_tasks(ps2, pending)**: 50タスク中 business-marketing「SEO戦略(記事50本計画)」発見
4. **実行**: `docs/seo/50-article-plan.md` 作成 — Phase 1-5 × 各10本 = 50本スケジュール
   - Phase 1: Notion代替シリーズ (5月〜6月)
   - Phase 2: AI開発ツール比較 (7月〜8月)
   - Phase 3: 自分株式会社機能紹介 (9月〜10月)
   - Phase 4: スタートアップ創業 (11月〜1月)
   - Phase 5: 振り返り深掘り (2月〜)
5. **WBS更新**: f294d7b3 → completed ✅
6. **副次発見**: 同タイトルのWBSタスクが16件重複 (PS#4 S52 dedup後も残存)

### 副次発見: WBS重複タスク残存

PS#4 S52 の dedup fix 後も `business-marketing` カテゴリに同タイトル×16件残存。
原因推定: dedup は (title, instance) の `DISTINCT` だが、instance='ps2' のみに絞ると16件全部残る。
Win版 dedup fix (20260425_wbs_dedup_fix.md) で対応予定。

### commits: 675a3eed

## PS#4 S53 2026-04-26: competitor-discovery Python scripts + flutter analyze fix

- competitor-discovery.yml: Python scripts を .github/scripts/ に分離 (col-0 YAML解消)
- .github/scripts/competitor_discover.py: Gemini Flash per-category discovery
- .github/scripts/competitor_stage.py: Supabase competitor_candidates INSERT
- .github/scripts/competitor_report_gen.py: markdown report生成
- lib/pages/user_tasks_page.dart:583 trailing comma fix (flutter analyze)
- PS#1 S42 (9bc7b6fa) との merge conflict 解消

### commits: ae49e27e

## PS#4 S54 2026-04-26: migration スキーマ修正 (AI大学 Tome/Krisp + user_task_reports policy)

- 20260425231600 Tome: provider_id→provider / section→category / content_md→content / title追加
- 20260425233000 Krisp: 同上
- 20260425231500 user_task_reports: DROP POLICY IF EXISTS (SQLSTATE 42710 対策)

### commits: 5fae8a8a
---

## PS#1 S42 補足 — user_task_reports policy 冪等化 (2026-04-25)

- `CREATE POLICY "public_read_user_task_reports"` SQLSTATE 42710 エラー報告受信
- migration 20260425231500 に `DROP POLICY IF EXISTS` 追加 → PS#4 S54 (`5fae8a8a`) で既に同内容修正済み確認
- PS#2 S31 (`0ce32cde`) が deploy-prod.yml repair list で 231500 を reverted→applied に変更 (代替修正)
- flutter analyze: worktree + main repo 両方 exit 0 確認

### commits: no change (upstream already fixed)

---

## PS#2 S32 — deploy fix + X アカウント運用設計 (2026-04-25)

### 実施内容

1. **T-1 check**: no-op (May 2/4 slugs = May 1/3 dispatch待ち) / orphan 0本
2. **deploy fix**: `20260425231500 --status reverted → applied` (policy 42710 エラー修正)
   + `20260426110000_repair_notebooklm_columns.sql` 追加 → `0ce32cde`
3. **[DYNAMIC-CLAIM]**: X 公式アカウント運用設計 (57009177) claim → 実行 → completed
   - `docs/marketing/x-account-strategy.md`: 週次スケジュール/自動化フロー/テンプレート集
   - `docs/cross-instance-prs/20260425_x_blog_announce_ef.md`: Win/VSCode版 handoff
4. **WBS-SYNC**: 57009177 → completed ✅

### commits: 0ce32cde (deploy fix) → bab257fa (X strategy)

### Rule 17 WF health check PS#1 S43 (2026-04-25 11:00)
- issue-to-wbs.yml: 最新run SUCCESS (24929194970) — 前session修正で解消済
- infra-health-check.yml: exit 128 (fatal: not in a git directory)
  - 原因A: 廃止EF3本(development-achievements/get-competitor-features/get-growth-roadmap-progress)が404 → ALL_OK誤判定
  - 原因B: bfffca4f(actions/checkout追加)が10:37 cron trigger前に未push → git dir不在
  - Fix: ENDPOINTS更新 (schedule-hub/tools-hub/admin-hub に置換) / d95e50d6
  - exit 128は次回11:37 cronで自己回復 (checkout済み)
- 全WF healthy残: 0件 (issue-to-wbs ✅ + infra-health-check fix pushed)

### commits: d95e50d6 (infra-health-check endpoint fix)

### Rule 17 追加修正 PS#1 S43b — Tome/Krisp migration SQLSTATE 42601 (2026-04-25 ~11:30)
- deploy-prod 全 run が 20260425231600 (Tome) で失敗継続
  - 原因: 5col 多行VALUES + $md$ タグが "VALUES lists must all be the same length" を引き起こす
  - Git 保存は LF 確認済。Supabase CLI の dollar-quote パーサー or 多行VALUES 非互換
  - Fix: 3本独立 INSERT + $$ タグ + 7cols (source_url/published_at NULL) に書き換え (77cd060c)
  - 同様に 20260425233000 (Krisp) も同パターンで書き換え
- 77cd060c deploy pending → 次回 run で Tome/Krisp data INSERT 完了予定

### commits: 77cd060c (Tome/Krisp migration fix)

### PS#4 S55 — Tome/Krisp title fix + competitor_features Phase 1 準備 (2026-04-25 ~11:15)
- deploy-prod run 24929297325: SQLSTATE 42601 (VALUES lists must all be the same length)
  - 原因: Tome/Krisp migration の api/models rows に title 値が欠落 (PS#3 S52 の 3-col fix 漏れ)
  - Fix: `1025c71c` — api/models rows に title 文字列を追加 (5col 正常化)
- competitor_features seed 準備: `20260426120000_seed_competitor_features_phase1.sql` 作成
  - 21社×10機能キー / jibun_status (done/partial/notYet) / ON CONFLICT UPDATE

### commits: 1025c71c (Tome/Krisp title fix)

### PS#4 S56 — competitors_schema_v2 タイムスタンプ修正 (2026-04-25 ~11:40)
- deploy-prod run 24929615122: SQLSTATE 42703 (column "name" of relation "competitors" does not exist)
  - 原因: 20260426090000_competitors_schema_v2.sql が batch2-7 seeds (010000-060000) より後に実行
  - Fix: git mv → 20260426000500 (batch2 前) + repair 090000 in deploy-prod.yml
  - Tome/Krisp migrations は今回 run で成功 ✅ (231600/233000 passed)
- 24929878401 (PS#1 definitive 7col fix) in_progress / 24930105850 (schema fix) pending

### commits: b7be8511 (competitors_schema_v2 timestamp fix)
### PS#2 S33 — T-1 no-op + WBS completed 更新 (2026-04-25 ~21:15 JST)
- T-1 dispatch: date-gate skip (May 2/4 slugs → T-1 = May 1/3)
  - 未投稿 draft: 2本 (2026-05-02, 2026-05-04)
  - 次回 dispatch: May 1 (T-1 for May 2 slug)
- orphan blog-publish/* branches: 0本
- DYNAMIC-CLAIM: 候補全て business-legal/Flutter UI → PS#2 スコープ外 (skip)
- WBS: SEO 50本計画 + X公式アカウント運用設計 → status=completed 更新
- deploy-prod: runs 24930429740 (in_progress) / 24930630786 (pending) — CI 自己回復中
  - Issue #719 は PS#5 に引き継ぎ (PS#2 は T-1 専任)

### commits: (コード変更なし)

### Philosophy Alignment: PS#2 S33
- CEO感: T-1 routine完遂 (date-gate 判断 = CEO判断) ✅
- ミッション駆動: Notion paywall 記事の May 1/3 予約投稿準備 ✅
- KPI=昨日の自分: WBS 2タスク completed 化 ✅

## PS#4 S57 — 2026-04-25 (競合モニタリング / deploy修復)

**Instance**: PS版#4 | **Commit**: bb1f5afd→b94d502f

### 実装内容
- deploy-prod CI SQLSTATE 23505 修復: `wbs_tasks_title_instance_unique` 重複キーエラー
- 根本原因: `20260425203000_wbs_remove_all_instances_add_codex.sql` の `UPDATE instance='all'→'codex'` が `20260425170000_business_wbs_phase1.sql` で既にseeded された 'codex' 行と衝突
- 修正: `20260425202000_fix_wbs_all_codex_conflict.sql` — 203000実行前に衝突する 'all' 行をDELETE
- deploy-prod.yml に repair entry 追加 (202000)
- 別インスタンス(2363ff66)も203000をDELETE方式に修正 — 両修正が協調して機能

### Philosophy Alignment: PS#4 S57
- CEO感: SQLSTATE根本原因の特定と修正判断 ✅
- KPI=昨日の自分: 連続するCI失敗チェーンを断ち切る ✅
- 資本=時間: 長時間監視から根本修正アプローチに切替 ✅

## Win版 #132 part 29 — 2026-04-25 22:00 JST (deploy修復追加ガード)

**Instance**: Windowsアプリ版 | **Commit**: 73f146e0

### 実装内容
- 並行修正の上塗り: PS#4 S57 + 2363ff66 (Codex) の修正を残しつつ、`20260425203000` と `20260425210000` の他の `UPDATE WHERE instance='X'` パターンにも同様の SQLSTATE 23505 ガード追加
  - 203000: `windows`→`win` / `ps`→`ps1` / `NOT IN (whitelist)`→`codex` の各 UPDATE 前に DELETE 衝突行
  - 210000: business-* category 別 CASE UPDATE all→mapped instance の前に DELETE 衝突行
- 防御的: 将来 repair re-run でも同種衝突発生時に SQLSTATE 23505 が起きないよう全 UPDATE パターンを idempotent 化
- 確認した先行修正:
  - 2363ff66 (Codex): target_instances に `codex` 追加 + `UPDATE all→codex` を `DELETE WHERE instance='all'` に置換 — fan-out で codex 行も生成済なので legacy 'all' 行は単純削除でOK
  - b94d502f (PS#4 S57): pre-cleanup migration 20260425202000 + repair list 追記
- 結果: 203000 と 210000 が複数 UPDATE パターンで再実行に強くなる (5パターン全てに DELETE-then-UPDATE / repair re-run 対応)

### 副作用
- ありません (DELETE は EXISTS 条件付きなので新DBでは no-op、re-run でのみ衝突行を排除)

### Philosophy Alignment: Win版 #132 part 29
- CEO感: 並行修正の重複を排除しつつ、追加防御を加える判断 ✅
- 商品=ユーザー価値: deploy 完走で機能リリース可能 ✅
- 資本=時間: 同種衝突の再発防止 (将来 1 回の deploy ループ削減) ✅
- KPI=昨日の自分: 1パターン → 5パターン全 idempotent 化 ✅


---

## PS版#6 S45 — deploy修復監視 + 根本原因分析 (2026-04-25)

**コミット**: なし (監視・診断のみ)

### 実装内容

deploy-prod 連続失敗の根本原因を特定し、各インスタンスの修正を適切に誘導:

1. **SQLSTATE 23514 (threat_level_check)**: `20260426000500` の CHECK 制約が `'critical'` 非許容 → `7b4e18f6` (Win#132 part 27) で `20260426015000` を追加して修正確認 ✅
2. **flutter analyze error (unnecessary_brace_in_string_interps)**: `home_page.dart:5989-5990` の `${habitDelta}` → `$habitDelta` 修正 — `88d30458` で先行push確認 ✅
3. **SQLSTATE 23505 (wbs_tasks_title_instance_unique)**: `20260425203000` が repair list で `reverted` のため再実行 → UNIQUE INDEX 違反 → PS#4 S57 (`b94d502f`) + Win版 (`73f146e0`) + Codex (`2363ff66`) が修正中

### 修正パターン発見

- `repair --status reverted` = DB から tracking 削除 → db push が再実行する (NOT スキップ)
- idempotent でない INSERT/UPDATE migration を `reverted` にすると UNIQUE violation 連鎖
- 正しい運用: 再実行禁止 migration は `repair --status applied` か migration 自体を idempotent 化

### Philosophy Alignment

- CEO感: 根本原因を他インスタンスに伝達して修正連携 ✅
- KPI=昨日の自分: deploy 緑化プロセスの診断能力向上 ✅

### VSCode版 S5 — FSRS学習システム完全実装 (2026-04-26)
- WBS FSRS学習システム完全実装 (12902e33) → progress=100%
- 実装内容:
  - ai-hub EF: `quiz.fsrs_stats` action追加 (total_cards/due_today/avg_stability/total_reviews/retention_rate)
  - ai_fsrs_service.dart: `FsrsStats` model + `getStats()` method追加
  - gemini_university_v2_page.dart: `_buildFsrsStatsCard` + `_fsrsStatChip` widget追加
    - 復習履歴ありの場合のみ表示 (totalReviews > 0)
    - 「総復習」「安定度」「記憶率」3チップ + 今日の復習バッジ
- instance-vscode worktree rebase (90 commits behind → synced) + 未コミット変更破棄 (main済)

### commits: 4064076a (feat(fsrs): quiz.fsrs_stats EF action + retention/stability metrics UI)

### Philosophy Alignment: VSCode版 S5
- CEO感: WBS優先タスク選択 (FSRS 92% → 完了 = 高ROI) ✅
- ミッション駆動: AI大学の記憶定着機能完成 → ユーザー価値直結 ✅
- 商品=ユーザー価値: 復習メトリクス表示でFSRSの可視性向上 ✅
- KPI=昨日の自分: FSRS完全実装 1タスク completed ✅

## Win版 #132 part 30 — 2026-04-25 22:30 JST (blog-backfill 防御強化)

**Instance**: Windowsアプリ版 | **Commit**: 40da58d0

### 実装内容
- 旧 run 24524644089 (2026-04-16) の GH006 失敗は 71ffa0df で解消済 (push to main → PR ブランチ経由) を確認
- 残存リスクを 3 点で追加防御:
  1. `permissions:` に `pull-requests: write` 追加 — `gh pr create` で必要 (旧設定は contents/actions のみ)
  2. Commit step に `set -euo pipefail` — silent な `git checkout -b` 失敗 (= 元 GH006 の根本原因) を即座に検知
  3. `git switch -c` (modern porcelain) + 明示的 refspec `HEAD:refs/heads/$BRANCH` で `push.default` 設定差異の影響を排除

### Philosophy Alignment: Win版 #132 part 30
- CEO感: 既存修正の上に防御層を加える判断 ✅
- ミッション駆動: ブログ自動投稿が再開可能 ✅
- 商品=ユーザー価値: コンテンツ生成パイプライン健全化 ✅
- 資本=時間: 同種 GH006 の再発時に即発見 (silent failure 排除) ✅
- KPI=昨日の自分: 1 修正 → 3 防御層 ✅


## PS#6 S46 — 2026-04-25 22:40 JST (deploy failure #746-749 診断・確認)

**Instance**: PowerShell版 #6 | **Commit**: d84de3a8 (診断のみ・修正は別インスタンス先行)

### 実装内容
- CI failure issues #746-749 調査: run 24931864982 の "Run Supabase migrations" step failure
- 根本原因特定: `20260425234000_wbs_user_instances_reports.sql` の大型UPDATE に NOT EXISTS ガード不足
  - `wbs_tasks_title_instance_unique` (20260426080000 で作成) が存在する状態で reverted migration 再実行
  - 同一 title で instance='user' が重複 → SQLSTATE 23505
- 修正 `d84de3a8` ("fix(wbs): guard user report reassignment") が先行適用済みを確認
- run `24932142682` で Deploy to Production SUCCESS ✓
- issues #746 / #747 / #748 / #749 auto-closed ✓

### Philosophy Alignment: PS#6 S46
- CEO感: 4件並行 CI failure を単一根本原因に絞り込み ✅
- ミッション駆動: 本番 deploy 正常化 ✅
- 資本=時間: 重複修正を回避 (先行commit確認→stash drop) ✅
- KPI=昨日の自分: migration reverted + UNIQUE INDEX 組合せ = 再発パターン文書化 ✅

## Win版 #132 part 31 — 2026-04-25 22:45 JST (blog-batch-publish 防御強化)

**Instance**: Windowsアプリ版 | **Commit**: 3b7a5a5f

### 実装内容
- 旧 run 24525525768 (2026-04-16) の GH006 失敗は 9ca3e2dc で解消済 (per-run unique branch) を確認
- Win#132 part 30 と同じ三層防御を blog-batch-publish.yml にも適用:
  1. `set -euo pipefail` — silent step failure を即検知
  2. `git switch -c` (modern porcelain) で `git checkout -b` の意味曖昧性を排除
  3. 明示 refspec `HEAD:refs/heads/$BRANCH` で `push.default` 設定差異の影響排除

### Philosophy Alignment: Win版 #132 part 31
- CEO感: blog 自動化系 WF 全体に統一防御を適用 ✅
- ミッション駆動: ブログ一括投稿が再開可能 ✅
- 商品=ユーザー価値: コンテンツ配信パイプライン健全化 ✅
- 資本=時間: 同種失敗の即検知で復旧時間削減 ✅
- KPI=昨日の自分: blog-backfill (part 30) → blog-batch-publish (part 31) 一貫性 ✅


## Win版 #132 part 32 — 2026-04-26 00:30 JST (wbs-user-tasks-notify ANON fallback)

**Instance**: Windowsアプリ版 | **Commit**: c33eaec9

### 実装内容
- 既存 workflow の comment が "hardcoded fallback (anon key は public)" と記述するも実装は skip のみ
- 実装ギャップを修正: `env.SUPABASE_ANON_KEY` 表現に `||` fallback を追加し、`lib/main.dart` line 296 と同じ public anon key を埋め込み
- precheck step では fallback 後も空の場合のみ skip するように防御
- 鍵ローテーション時は `secrets.SUPABASE_ANON_KEY` を repo settings で上書きすれば即適用 (workflow 改修不要)
- ANON key は public 仕様 (RLS で保護 / Flutter Web bundle に同梱済) なので workflow への埋込は client bundle と同等の露出度

### 検証
- 手動 dispatch run 24934140606 SUCCESS — Step 2 `wbs.notify_user_tasks` 200 OK ✅
- 全 step success / soft-fail なし

### Philosophy Alignment: Win版 #132 part 32
- CEO感: comment と実装の乖離を修正する判断 ✅
- ミッション駆動: ユーザータスク Slack 通知が再開可能 ✅
- 商品=ユーザー価値: 毎朝 09:00 JST cron 通知が機能 ✅
- 資本=時間: secret 設定漏れによる silent skip を排除 ✅
- KPI=昨日の自分: 同等の skip パターンが他 workflow にある場合は次回以降テンプレ化 ✅


## PS#6 S47 — 2026-04-26 00:10 JST (定期 cleanup + 監視)

**Instance**: PowerShell版 #6 | **Commit**: なし (cleanup/監視のみ)

### 実施内容
- WBS top-5: business-legal/finance → 禁止カテゴリ → DYNAMIC-CLAIM試行
- issue #719 ([CI失敗]) クローズ — run 24926675860 は後続 deploy で解消済み
- orphan worktree `claude/exciting-wu-3856d1` 削除 (merged to main確認済み)
- remote branches prune (claude/* = vscode-wip 1本のみ残存)
- horse_racing Auto Update: 5/5 success ✓
- cron-batch.yml: workflow_dispatch only (secrets未設定) = 想定通り停止中
- blog-batch-publish.yml: 既にgit switch -c修正済み (Win#132 part 30)
- "Post X with OGP Image": dry_run + secrets空 → exit3 (対処不要)
- 13 failing tests: dart:ui VM非対応 (既知 / VSCode版 handoff済み)
- deploy-prod.yml repair list: 94件 (今後の最適化候補として記録)

### 所見: repair list 過多問題
現在94件のrepair --status revokedエントリが毎deployで実行されている。
全て成功deployで適用済みなので、段階的削除が可能。
→ 次回PS#6: repair list audit & reduction タスク (Win版に cross-instance-pr推奨)

**次回候補**: Coqui AI / Resemble AI / Play.ht / AssemblyAI (音声系で統一) / Deepgram / Speechify

### Rule 17 WF health check PS#1 S44 (2026-04-26 朝)
- 全 WF 健全: last 50 runs で失敗は deploy-prod 1件のみ (esm.sh 522 transient / 自己回復済)
- infra-health-check: 5/5 SUCCESS (11:53 以降の全 cron clean) ✅
- issue-to-wbs: 13/13 SUCCESS ✅
- 前セッション修正確認:
  - d95e50d6 endpoint fix → 11:53 run SUCCESS ✅
  - 77cd060c Tome/Krisp migration → 複数 SUCCESS deploy 確認 ✅
- orphan branches: blog-publish 0 / cs-check 0 / ai-university 0 / claude/vscode-wip 1 (VSCode worktree / 正常)
- deploy-prod 24934867980 in_progress (671f28bf) / CI green / Deploy step実行中

### commits: なし (health check only)
### PS#5 S52 (2026-04-26) — AI大学 FSRS anon 401 flood 修正 (660bbcdd)

**バグ**: `ai_fsrs_service.dart` の `getNextCards()` / `getStats()` に anon ガードなし
→ AI大学ページ TabBarView が 202 プロバイダー分のタブを全ビルドする際に `_buildProviderTab()` → `_loadFsrsStats()` → `ai-hub` を202回呼び出し
→ anon ユーザー全員に 200+ HTTP 401 エラーが発生 (コンソール 193 errors)
→ EF への無駄な負荷 + ページレンダリング遅延

**修正**: `getNextCards` / `getStats` 冒頭に `if (_supabase.auth.currentUser == null) return ...;` ガード追加

**Philosophy Alignment (PS#5)**:
- ✅ CEO感: バグ発見→即修正 (on-call 役割遂行)
- ✅ 商品=ユーザー価値: anon ユーザーの体験改善 (コンソールエラー消去)
- ✅ KPI=昨日の自分: 前セッション同様の品質維持

**commit**: `660bbcdd`
### Philosophy Alignment: PS#6 S47
- CEO感: 現状を正確に把握・不要な変更をしない判断 ✅
- ミッション駆動: 本番安定稼働の確認 ✅
- 資本=時間: 危険な変更より安全な監視優先 ✅
- KPI=昨日の自分: repair list 94件問題を発見・記録 ✅

### PS#2 S34 — T-1 no-op + cross-instance-pr backend tasks (2026-04-26 ~09:15 JST)
- T-1 dispatch: date-gate skip (May 2/4 slugs → T-1 = May 1/3)
  - April 26 BS Framework + April 28 Notion Paywall: scheduled cron が自動publish済
  - 次回 dispatch: May 1 (T-1 for May 2 slug)
- cross-instance-pr `20260425_vscode_to_ps2_backend_assist.md` 処理:
  - Task 1: `post-x-with-media.yml` dry_run test → 失敗 (SUPABASE_DIGEST_URL秘密名間違い)
  - Task 2: Secret確認 → SUPABASE_URL_PROD/SUPABASE_SERVICE_ROLE_KEY が正解
  - Task 3: LP FAQ差別化テキスト → docs/LP_FAQ_DIFFERENTIATION.md 作成 (faq_itemsテーブル不存在)
  - Task 4: core-hub:page.share_generate smoke test → HTTP 200 ✅ (fallback動作確認)
- **Fix**: post-x-with-media.yml secret名修正 (SUPABASE_DIGEST_URL→SUPABASE_URL_PROD/schedule-hub)
- **Fix**: schedule-hub publicActions に x.post_with_media 追加 + userId ?? "gha" fallback
- dry_run再テスト → success ✅ (HTTP 401→200へ改善確認)

### commits: abb16910 (workflow+FAQ fix) / eb85aa39 (schedule-hub auth fix)

### Philosophy Alignment: PS#2 S34
- CEO感: secret名バグを特定・修正 → 自律的問題解決 ✅
- ミッション駆動: X自動投稿インフラ整備 = ユーザー獲得ループ ✅
- KPI=昨日の自分: post-x-with-media 初めてsuccess到達 ✅

### Rule 17 WF health check (2026-04-26 PS#1 S45)
- 全 WF success率: 問題なし (last 30 runs)
- 失敗 WF: Post X with OGP Image (failed:1, success:1) — 2026-04-25T16:27 旧版 `curl -sf` + secrets 未設定で exit 3 → VSCode S4 (9974d8e7) で soft-fail + SUPABASE_URL_PROD に修正済み。最新 run (16:32 UTC) SUCCESS確認
- orphan branches: チェック対象外 (前回 S36-S37 で 75本削除済)
- 修正済み: なし (WF既に健全)
- deploy-prod: 02082735 in_progress / 9bbc80fe queued (通常の concurrency)

---

## 2026-04-26 PS#3 S55: AI大学 202→204社化 — Coqui + Resemble AI 追加
### 実施内容
- **Coqui** (OSS TTS): XTTS-v2 / 3秒ゼロショット声クローン / 16言語 / Apache 2.0 / ローカル実行無料 → ai_university_content 追加
- **Resemble AI**: <50ms リアルタイムWebSocket / Deepfake Detection / 5分声クローン / YC S20 $8M → ai_university_content 追加
- `ai_provider_registry.dart` 204社化 (coqui_ai + resemble_ai エントリ追加)
- Migration: 20260426133000 / 20260426134500

### 次候補 (S56)
Speechify / Play.ht (未確認) / Cartesia / Suno AI / Udio

### Philosophy Alignment: PS#3 S55
- CEO感: Deepgram+PlayHT登録済み発見→即代替選定 ✅
- ミッション駆動: 音声AI特化2社追加で音声カテゴリ充実 ✅
- KPI=昨日の自分: 202→204社 累積継続 ✅

---

## 2026-04-26 PS#3 S56: AI大学 204→206社化 — Speechify + WellSaid Labs 追加
### 実施内容
- **Speechify**: AI 読み上げ & 音声クローン / 20M+ ユーザー / 30+ 言語 / 著名人ボイス / OpenAI Startup Fund / $76M 調達 → ai_university_content 追加
- **WellSaid Labs**: エンタープライズ向け同意ベース声クローン / スタジオ品質 / 50+ AI 音声 / $10M+ 調達 → ai_university_content 追加
- `ai_provider_registry.dart` 206社化 (speechify + wellsaid_labs エントリ追加)
- Migration: 20260426141500 / 20260426143000

### 次候補 (S57)
LOVO (Genny) / Voicemod / Bark (Suno AI OSS TTS) / Replica Studios / AIVA (音楽生成)

### Philosophy Alignment: PS#3 S56
- CEO感: Suno/Udio/Cartesia登録済即確認→Speechify+WellSaid選定 ✅
- ミッション駆動: 音声AI 206社で「聴く AI 大学」構想の基盤拡充 ✅
- KPI=昨日の自分: 204→206社 累積継続 ✅

### PS#5 S53 (2026-04-26) — #764 AI大学シェアダイアログ修正 (02aa3f21)

**バグ**: `_captureAndDownload` の `catch (_)` がサイレント → ユーザーに何も表示されない
**追加**: Dialog の `backgroundColor` 未設定 → ダークテーマで dialog が不可視

**修正**:
1. `_captureAndDownload` catch block → SnackBar (成功/失敗/null別メッセージ) + fallback action
2. Dialog に `backgroundColor: Color(0xFF1E1E1E)` + border 追加

**Philosophy**: ✅商品=ユーザー価値 (エラーフィードバック改善) ✅KPI=昨日の自分

**commit**: `02aa3f21` / Closes #764

### Rule 17 WF health check (2026-04-26 PS#1 S46)
- **deploy-prod 4連続失敗 → 根本修正完了**
  - SQLSTATE 23502: 4件の AI大学 seed migration (Otter.ai/Murf/Coqui/Resemble AI) が旧スキーマ (provider_id, section, content_md) 使用 → provider NOT NULL 違反
  - Fix (commit 4c39f625): 全4件を新スキーマ (provider, category, title, content, source_url, published_at, sort_order) に書き直し + $$ 区切り + ON CONFLICT (provider, category) DO NOTHING
  - 全4タイムスタンプは deploy-prod repair list 登録済 → 次回 deploy で再実行
- **Notion Mirror Sync (hourly) 1件失敗 → soft-fail 追加**
  - Notion API HTTP 429 rate_limited でクラッシュ (既存 soft-fail chain に 429 パターンなし)
  - Fix (commit b8bec666): notion-sync.yml に rate_limited パターン追加 → ::warning:: + exit 0
- **deploy-prod 9b4f7952 pending** (fixes 含む)
- **修正 commit**: 4c39f625 (4migration fix) + b8bec666 (notion-sync 429) + 933d46f8 push

---

## 2026-04-26 PS#2 S35: weekly-sns-draft.yml 作成 (WBS e320edea 完了)
### 実施内容
- **T-1 dispatch**: no-op (date-gate: May 2/4 slugs — May 1 dispatch 予定)
- **weekly-sns-draft.yml**: 毎週月曜 09:00 JST cron / Claude Haiku → Gemini Flash → template 3段階フォールバック
  - `docs/daily-reports/` 直近7日分 + git log を読み込みXドラフト + Zenn記事ネタを生成
  - `docs/weekly-drafts/YYYY-MM-DD-week.md` にコミット→push
  - GitHub Actions workflow ID: 266350526 (active確認 ✅)
- **generate_weekly_sns_draft.py**: scripts/ に新規追加 (blog-draft スクリプトと同パターン)
- **Commits**: 29295430 / 093a1608

### Philosophy Alignment: PS#2 S35
- CEO感: GHA schedule 自動化でSNS運用コスト0化 ✅
- KPI=昨日の自分: WBS e320edea 80%→100% 完了 ✅
- 資本=時間: 手動ドラフト作業を自動化 ✅

---

## 2026-04-26 VSCode版 S6
### 実施内容
- [fix] DESIGN.md全ページ準拠: 9ページにダークモード対応追加 (7e69082c)
  - asset_management_page: AI review box 0xFFF8FAFC→surface2
  - emergency_meeting_page: message card white→surface1
  - morning_briefing_page: 3箇所 0xFFEEF2FF→dark indigo tint
  - money_forward_page: error container pink→dark red
  - wip_limit_page / weekly_slip_report_page / team_chat_page: error container + progress bar + border
  - language_learning_page / agent_org_page: amber/lavender card colors
- WBS 32731c06 (DESIGN.md全ページ準拠) 68%→75% 更新

### Philosophy Alignment: VSCode版 S6
- CEO感: UI品質を段階的に向上 ✅
- KPI=昨日の自分: 9ページ追加で DESIGN.md 準拠率向上 ✅
- 資本=時間: 高トラフィックページ優先で ROI 最大化 ✅

### Rule 17 WF health check (2026-04-26 PS#1 S47)
- **deploy-prod SQLSTATE 23505 (duplicate key schema_migrations_pkey) → 修正完了**
  - 原因: timestamp 20260426133000 + 20260426143000 の2か所で AI大学 seed と wbs_* migration が衝突
  - Fix (commit b4dfa577): seed_coqui 133000→132000 / seed_wellsaid 143000→142000 rename
  - deploy-prod.yml repair list 更新: 132000/142000/143000 追加
  - 666件全 migration の collision scan → 残存 collision ゼロ確認
- **deploy 5d9082e4** in_progress 中 / **38a50027** pending (collision fix 含む)
- **修正 commit**: b4dfa577 / push 23428652

---

## 2026-04-26 PS#3 S57: Speechify/WellSaid スキーマ修正 + AI大学 206→208社化 — LOVO + AIVA
### 実施内容
- **S56修正**: Speechify (141500) + WellSaid Labs (143000) を旧スキーマ→新スキーマに書き直し (PS#1 S46 同様 SQLSTATE 23502 対策)
- **LOVO (Genny)**: AI 音声 + 動画エディタ統合 / 500+ AI 音声 / 100+ 言語 / 14 感情スタイル / 7M USD → ai_university_content 追加
- **AIVA**: 世界初 SACEM 登録 AI 作曲 / ゲーム・映画音楽 / 著作権 100% / MIDI + 楽譜出力 / API / 8/9 → ai_university_content 追加
- `ai_provider_registry.dart` 208社化 (lovo_ai + aiva エントリ追加)
- Migration: 20260426151500 / 20260426153000 (新スキーマ)

### 新スキーマ教訓 (PS#1 S46 学習)
AI大学 seed migration は `provider, category, title, content, source_url, published_at, sort_order` が正しいスキーマ。
`provider_id, section, content_md` は旧スキーマ → NOT NULL 違反 (SQLSTATE 23502)。

### 次候補 (S58)
Voicemod / Replica Studios / Beatoven.ai / Mubert / Soundraw (音声/音楽系続き)

### Philosophy Alignment: PS#3 S57
- CEO感: MEMORY.md でPS#1 S46 修正を即座に発見→S56修正→S57新規追加の優先順位判断 ✅
- ミッション駆動: 旧スキーマ修正で deploy 品質維持 + 208社継続 ✅
- KPI=昨日の自分: 206→208社 + schema fix完了 ✅

---

## 2026-04-26 PS#2 S36: SEO記事 #3 + weekly-sns-draft検証
### 実施内容
- **T-1 dispatch**: no-op (May 2/4 date-gate。May 1 dispatch予定)
- **weekly-sns-draft.yml dry_run 2回**: fallback chain 正常動作確認 (template 1298 chars生成)
- **SEO Phase 1 記事 #3**: `2026-05-09-notion-ai-vs-jibun` JA+EN ドラフト作成
  - tags: 4/4 cap準拠 ✅ / T-1 dispatch予定: 2026-05-08
- **Commits**: 14ea9176 / 1c89071b

### Philosophy Alignment: PS#2 S36
- ミッション駆動: 競合Notion との差別化コンテンツで認知拡大 ✅
- KPI=昨日の自分: SEO 50本計画 2→3本 進捗 ✅
- 資本=時間: GHA weekly-sns-draft 自動化検証 ✅

### PS#5 S54 (2026-04-26) — AI大学 `_fetchContent` null-safe provider fix (38a50027)

**バグ**: `ai_university_content` schema v2 で `provider` カラムが nullable 化 → `_fetchContent` の `row['provider'] as String` がランタイムクラッシュ

**根本原因**: `20260426125000_ai_university_content_schema_v2.sql` が `provider` を nullable にした。新形式 row (Otter.ai/Murf/Coqui/Resemble AI) は `provider=null, provider_id='...'` で返ってくる。Dart の `as String` は null で `TypeError` → AI大学コンテンツタブが白画面

**修正** (`lib/pages/gemini_university_v2_page.dart` `_fetchContent`):
```dart
final provider = (row['provider'] as String?) ??
    (row['provider_id'] as String?);
if (provider == null) continue;
```

**Philosophy**: ✅KPI=昨日の自分 (schema v2 移行の後始末) ✅商品=ユーザー価値 (白画面解消)

**commit**: `38a50027`


### PS#1 S48 (2026-04-26) — migration 150000/151000 old-schema columns fix (1bd6b6c6)

**バグ**: `20260426150000_fix_arcee_ai_news_rss_fallback.sql` と `20260426151000_fix_nomic_ai_news_rss_fallback.sql` が `provider_id, section, content_md, display_order` カラムを INSERT に含む → `SQLSTATE 42703: column "provider_id" does not exist`

**根本原因**: これらのカラムは `ai_university_content` テーブルに存在しない。`20260426125000_ai_university_content_schema_v2.sql` はのちに no-op (SELECT 1) に変更されたため、スキーマ拡張は実行されなかった。

**修正**: 両ファイルから `provider_id/section/content_md/display_order` を削除し、実在する7カラム `(provider, category, title, content, source_url, published_at, sort_order, is_active)` のみを使用

**repair list**: `150000` / `151000` は PS#4 S58 (commit `433eb2b1`) で既に reverted 登録済み → 次回 deploy で再実行される

**Philosophy**: ✅KPI=昨日の自分 (deploy-prod 継続失敗を解消) ✅商品=ユーザー価値 (AI大学コンテンツ正常適用)

**commit**: `1bd6b6c6`


### PS#4 S58 (2026-04-26) — competitor_features Phase 1 seed + deploy-prod 連続修正 (433eb2b1)

**タスク**: 21社×10機能 Phase 1 seed commit + deploy-prod SQLSTATE 23505/42703 連鎖修正

**実装内容**:
1. `20260426140000_seed_competitor_features_phase1.sql` — 21社×10機能=210行 (130000→140000 リネーム)
2. `20260426125000_ai_university_content_schema_v2.sql` — SELECT 1 no-op (誤ったDROP NOT NULL 撤回)
3. deploy-prod.yml: DUP ハンドラ追加 (schema_migrations_pkey 23505 → repair applied)
4. deploy-prod.yml: 133000 を reverted→applied に変更 (coqui データ既適用)
5. repair list: 100000-153000 全範囲追加

**根本原因**:
- 130000 collision (otter_ai vs competitor_features) → 140000 リネーム
- 133000 (coqui) stuck in schema_migrations: SQL実行済み・INSERT 23505 で追跡失敗
- 125000 の DROP NOT NULL が別インスタンスの seeds を破壊

**Philosophy**: ✅KPI=昨日の自分 (deploy chain 修復) ✅商品=ユーザー価値 (competitor_features DB適用)

**commit**: `433eb2b1`

---

## 2026-04-26 PS#2 S37: SEO記事 #4 Notion database limits
### 実施内容
- **T-1 dispatch**: no-op (May 1 dispatch予定)
- **SEO Phase 1 記事 #4**: `2026-05-16-notion-database-limits-workaround` JA+EN ドラフト作成
  - JA: Notionデータベース7つの限界と回避策 (API rate/block/relation/formula/filter/offline/KPI)
  - EN: "7 Walls Every Notion Power User Hits"
  - tags: JA 4/4 / EN 4/4 ✅
  - T-1 dispatch予定: 2026-05-15 → 2026-05-16投稿
- **Commits**: 32f93cfa → 82780bdd

### Philosophy Alignment: PS#2 S37
- ミッション駆動: Notion の技術的限界を具体的に示して差別化 ✅
- KPI=昨日の自分: SEO 50本計画 3→4本 ✅
- 商品=ユーザー価値: 開発者が実際に使える回避策を提供 ✅

---

## 2026-04-26 PS#3 S58: AI大学 208→210社化 — Mubert + Beatoven.ai 追加
### 実施内容
- **Mubert**: AI BGM ストリーミング生成 / リアルタイム無限ループ / 30+ ムード / React Native SDK / 著作権フリー / ★8/9 → ai_university_content 追加 (154500)
- **Beatoven.ai**: 動画・Podcast 向け AI BGM / シーン感情検出 + BGM マッチング / ノーコード / $3M 調達 / ★7/9 → ai_university_content 追加 (160000)
- `ai_provider_registry.dart` 210社化 (mubert + beatoven_ai エントリ追加)
- タイムスタンプ衝突回避: 154500 / 160000 (PS#1 S47 教訓適用 — 既存 ts 確認後選定)

### タイムスタンプ衝突回避ルール (PS#1 S47 学習)
migration 作成前に `ls supabase/migrations/ | grep YYYYMMDD | sort | tail -20` で確認必須。
WBS migrations が wbs_* タイムスタンプを埋めているため 5分間隔も衝突リスクあり。

### 次候補 (S59)
Voicemod / Replica Studios / Soundraw / Lalal.ai / Moises

### Philosophy Alignment: PS#3 S58
- CEO感: MEMORY.md でPS#1 S47 timestamp collision を発見→衝突回避して選定 ✅
- ミッション駆動: 音楽AI 210社で「AI大学 音楽カテゴリ」充実 ✅
- KPI=昨日の自分: 208→210社 累積継続 ✅

---

## 2026-04-26 PS#6 S48
### 実施内容
- [triage] #759 ([CI失敗] Deploy) 調査 → migration chain診断
- [fix] ai_university_content SQLSTATE 23502 根本原因特定 + 修正連携 (PS#1/PS#4/PS#6 協調)
- [fix] migration timestamp collision 133000/143000 解消 (cd6fffc2)
- [close] issue #759 (run 24937747553 SUCCESS ✓) / horse_racing 5/5 ✓

### Philosophy Alignment: PS#6 S48
- CEO感: 複数インスタンス協調でCI修復 ✅ / KPI: collision診断能力向上 ✅

### PS#5 S55 (2026-04-26) — Deploy SUCCESS + CI issues #759/#775/#776 クローズ

**deploy**: `24937747553` SUCCESS ✅

**根本原因チェーン (全5件修正完了)**:
1. SQLSTATE 23502: Otter.ai/Murf/Coqui/Resemble seed → 旧スキーマ書き直し (PS#1 S46)
2. SQLSTATE 23505: 133000/143000 timestamp collision → リネーム + repair list (PS#1 S47 + PS#4 S58)
3. SQLSTATE 42703: arcee/nomic rss-fallback 非存在カラム → 削除 (PS#1 S48)
4. esm.sh 522 transient: guitar-recording-studio EF → 再実行で自己回復
5. Dart null crash: _fetchContent `as String` → null-safe (PS#5 S54)

**クローズ**: #759 / #775 / #776

**Philosophy**: ✅商品=ユーザー価値 (本番デプロイ回復) ✅CEO感 (deploy chain診断完了)


### PS#1 S49 (2026-04-26) — Rule17 WF health check + deploy queue confirmed healthy

**WF status**: 11/12 WF全件 success (1F = 既知の `1814c392` failure — S48で修正済み)
- 修正済: Deploy to Production `1bd6b6c6` SUCCESS / `479fbd18` SUCCESS (mubert/beatoven)
- 修正済: arcee/nomic migration 150000/151000 の非存在カラム (`provider_id` 等) → schema 修正
- orphan branch: 1本 (`claude/vscode-wip`) — 閾値5本以下 → 対応不要
- open issues: 機能要望のみ / deploy 関連バグなし
- migration collision scan: 671ファイル / collision 0

**Deploy queue**: `479fbd18` SUCCESS (PS#3 Mubert+Beatoven 210社化) / `588597b5` pending → 正常キュー

**Philosophy**: ✅KPI=昨日の自分 (deploy健全性維持) ✅資本=時間 (自動WF監視で品質維持)

---


## Stack

- Frontend: Flutter Web (Dart)
- Backend: Supabase (PostgreSQL + Edge Functions / Deno)
- Hosting: Firebase Hosting
- AI: Claude Code (10 instances) + Codex CLI (2 instances)

Auto-generated by `scripts/build_in_public_extract.py` (= INDIE_DEV_VELOCITY #7 Community Engagement Discipline dogfood).
