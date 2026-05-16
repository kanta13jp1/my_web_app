# AI 実装向け Core / Leaf 境界マップ 設計 spec (= #833 / part 156)

> **Issue**: [#833 [追加要望] AI実装向けコア/リーフ境界マップ](https://github.com/kanta13jp1/my_web_app/issues/833)
> **NotebookLM**: `ddde5a4b-ce1a-405d-8291-a334a9371454` (= Vibe Coding: Responsible Engineering in the Era of AI Agents)
> **Spec 種別**: 通常 (= governance / 非 sensitive ただし [VIBE_SANDBOX_SPEC] と密接 cross-link)
> **担当**: Win Codex hand off (= migration + EF + UI + GHA / 推定 8h)
> **EF**: 既存 hub action 拡張 [EF-CAP-50] 遵守

---

## §1. 思想

Vibe Coding (= NotebookLM `ddde5a4b`) の核は **「AI 任せる範囲は依存少ない leaf へ寄せ、core (= 認証 / DB / 課金 / 外部投稿 / Secrets / 本番) は人間レビュー厚く」**.

本 spec は自分株式会社の主要機能を **`core` / `leaf` / `mixed`** の 3 区分に programmatic 分類 + Issue/WBS に必須記録 + CI 静的検証 + AI 開発原則ページから参照可能化 する **governance 仕組み**.

### [VIBE_SANDBOX_SPEC] との関係 (= 同 NotebookLM 共有 三つ子第 3 例)

| spec | NotebookLM | 役割 |
|---|---|---|
| VIBE_SANDBOX_SPEC (= part 155 / 第 6 sensitive) | `ddde5a4b` | AI 生成 code を runtime sandbox 内で実行 + escape 制御 |
| 本 spec CORE_LEAF_BOUNDARY_MAP (= part 156) | `ddde5a4b` | 機能を core/leaf 分類 + 人間レビュー強度を spec ベース |

両 spec で **「AI に任せられる境界」を runtime + governance 両面で定義** = 完全防御.

---

## §2. 受け入れ条件 mapping (= Issue #833)

| # | 受入条件 | 実装方針 |
|---|---|---|
| 1 | 主要 dir/機能を core/leaf/mixed に分類 | `docs/CORE_LEAF_MAP.md` 新規 (= 分類表) + `core_leaf_classifications` table (= machine-readable) |
| 2 | core 変更時の review 観点明記 | spec §6 で 6 観点 (= 認証/DB/課金/外部投稿/Secrets/rollback) 必須 review checklist |
| 3 | Issue/WBS に境界分類 記録 | `wbs_tasks.boundary_class` enum 追加 / GitHub Issue template 修正 |
| 4 | AI 開発原則ページから参照可 | `lib/pages/ai_dev_principles_page.dart` (= 既存) に「📘 Core/Leaf Map」 button 追加 |
| 5 | テスト/静的検証で分類欠落検出 | GHA workflow `core-leaf-coverage-check.yml` (= 全 lib/pages/*.dart / EF が分類済か検証) |

---

## §3. NOT to do (= 失敗 pattern 7 件)

1. ❌ **core を「絶対に AI 触らせない」と誤解** (= AI が PR draft 書くのは OK / merge には人間レビュー)
2. ❌ **leaf を「テスト不要」と誤解** (= AI 生成 でも test 通過必須 / [VIBE_SANDBOX] の sandbox 経由)
3. ❌ **分類なし で `mixed` 自動付与** (= 「とりあえず mixed」は思考停止 / explicit 分類 必須)
4. ❌ **境界マップ 1 回作成して放置** (= drift / 月次 audit 必須 / cron 化)
5. ❌ **core 6 観点 (認証/DB/課金/外部投稿/Secrets/rollback) を編集可能にする** (= AI が削除 risk / immutable list)
6. ❌ **WBS 既存 task に boundary_class 強制 NOT NULL** (= migration backfill 失敗 risk / nullable + GHA で gap 検知)
7. ❌ **VIBE_SANDBOX_SPEC とコア境界判断を矛盾させる** (= cross-link で同期維持必須)

---

## §4. MUST do (= 必須要件 10 項)

1. ✅ `docs/CORE_LEAF_MAP.md` 新規 — 主要 dir / 機能を 3 区分で表化
   - **core**: `auth / RLS / billing / Stripe / ai-hub LLM key / Supabase service_role / production schema migrations / external posting (Qiita/dev.to/Slack)`
   - **leaf**: `widget catalog / static cards / display formatting / test fixtures / docs / memory/vault entries / 単独 UI tab`
   - **mixed**: `wbs_tasks (= core schema + leaf UI) / lifestyle-hub actions (= 一部 core / 一部 leaf) / blog management (= core publish + leaf draft)`
2. ✅ table `core_leaf_classifications` 追加: `(component_path text PK / boundary_class enum('core','leaf','mixed') / rationale text / last_audited_at timestamptz / audit_trail jsonb)`
3. ✅ migration: `YYYYMMDDHHMMSS_create_core_leaf_classifications.sql` + initial seed (= ~50 path 事前分類)
4. ✅ EF action: `tools-hub.governance.classify_path` (= input: file path / output: boundary_class + rationale + linked review checklist)
5. ✅ `wbs_tasks.boundary_class` 列追加 (= migration / nullable / default null / GHA で gap 検知)
6. ✅ GitHub Issue template (`追加要望.md` / `bug.md`) に `boundary_class` 項目追加 (= dropdown core/leaf/mixed/unknown)
7. ✅ Flutter UI: `lib/pages/ai_dev_principles_page.dart` 拡張 — 「📘 Core/Leaf Map」 button + 新 page `core_leaf_map_page.dart` (= 表 + filter + 検索)
8. ✅ GHA workflow `core-leaf-coverage-check.yml` (= weekly cron + PR check / 全 `lib/pages/*.dart` + EF が分類済か検証 / gap > 5% で fail)
9. ✅ core 変更 PR 検出: PR 本文に `boundary_class: core` あり OR diff に core path 含む → mandatory review checklist comment 自動投稿
10. ✅ [VIBE_SANDBOX_SPEC] cross-link: 本 spec § で双方向参照 + 月次 audit で「AI が触っていい範囲」 整合性検証

---

## §5. EF 既存基盤確認 (= [EF-FIRST] / [EF-CAP-50])

### 既存活用

- `tools-hub` EF (= 既存 / governance hub 化最適)
- `wbs_tasks` table (= 既存 / boundary_class 列追加)
- `ai_dev_principles_page.dart` (= 既存 / button 追加先)
- GitHub Issue templates (= 既存 / 項目追加先)

### 新規追加

- **EF action**: `tools-hub.governance.classify_path` (= 1 action / hub 内追加 / 新 EF 不要 ✅)
- **table**: `core_leaf_classifications` + `wbs_tasks.boundary_class` 列
- **GHA workflow**: `core-leaf-coverage-check.yml`
- **Flutter page**: `core_leaf_map_page.dart`

### EF 数

| 項目 | 数 | 状態 |
|---|---|---|
| 現在 EF | 50 | [EF-CAP-50] 上限 |
| 本 spec 追加 | 0 | hub action のみ |
| 残枠 | 0 | 維持 |

---

## §6. core 変更時 必須 review checklist (= 6 観点 / immutable)

core path への変更 PR 提出時、reviewer は以下 6 観点を **全 ✅** で承認:

| # | 観点 | 内容 |
|---|---|---|
| 1 | **認証** | RLS policy 影響 / auth.uid() 経路維持 / role escalation なし |
| 2 | **DB** | schema 変更が migration で reversible / production data 破壊なし |
| 3 | **課金** | Stripe webhook / billing logic / refund flow 変更影響 |
| 4 | **外部投稿** | Qiita/dev.to/Slack/Discord 投稿 logic / rate limit / token 漏洩なし |
| 5 | **Secrets** | env var / secret rotation / leak audit log |
| 6 | **rollback** | revert 可能性 / 1-commit revert で本番復旧可 |

**この 6 観点リストは immutable** (= AI による削除/変更禁止 / spec lock).

---

## §7. UI 設計

### 配置先 (= 既存 page 拡張)

- `lib/pages/ai_dev_principles_page.dart` に「📘 Core/Leaf Map」 button 追加
- 新 `lib/pages/core_leaf_map_page.dart`: 表 + filter (= core only / leaf only / mixed) + 検索 + 最終 audit 日表示

### Issue template UI

GitHub Issue 起票時の dropdown:
- `boundary_class`: `core` / `leaf` / `mixed` / `unknown`
- `unknown` 選択時は警告: 「24h 以内に triage で確定してください」

### WBS UI (既存 project_gantt_page.dart 拡張)

- task row に `boundary_class` badge 表示 (= 🔴 core / 🟢 leaf / 🟡 mixed / ⚪ unknown)
- filter chip 追加

---

## §8. 9 原則 alignment

### PHILOSOPHY-22 (= 9/9 ✅必要 / 7+/9 で OK)

| # | 原則 | 適用 |
|---|---|---|
| 1 | CEO 感 | ✅ AI に任せる範囲を CEO が定義 |
| 2 | ミッション | ✅ 浪費削減 = governance で破壊的変更回避 |
| 3 | mentor | ✅ AI に「ここは触っちゃダメ」を教える |
| 4 | 6 部署 | ✅ 全部署横断 governance |
| 5 | 商品=価値 | ✅ 信頼性 = 商品価値 |
| 6 | 資本=時間 | ✅ 障害復旧時間最小化 |
| 7 | 資産負債 | ✅ core 資産 protect / leaf experiment 自由 |
| 8 | KPI | ✅ 分類カバレッジ KPI tracked |
| 9 | IPO | ✅ governance 整備 = 外部 due diligence |

**9/9 ✅** (= 全達成 record)

### AI-DEV-23 (= 7/7 ✅必要)

| # | 原則 | 適用 |
|---|---|---|
| 1 | Auth | ✅ core review checklist #1 で auth 必須 |
| 2 | deny-by-default | ✅ unknown 分類は 24h 以内 triage 義務 |
| 3 | trace_id | ✅ governance.classify_path EF で audit_trail |
| 4 | circuit-breaker | ✅ core 変更 PR は GHA で自動 review checklist 投稿 |
| 5 | memory | ✅ classification 履歴 audit_trail jsonb |
| 6 | DLQ | ✅ coverage gap > 5% で GHA fail + Issue auto-create |
| 7 | quality-gate | ✅ weekly audit + drift 検知 |

**7/7 ✅**

### VIBE-30 (= 7/7 推奨 / 4-で CEO レビュー強化)

| # | 原則 | 適用 |
|---|---|---|
| 1 | dry-run | ✅ governance.classify_path に dry-run mode |
| 2 | reversibility | ✅ core review checklist #6 で rollback 必須 |
| 3 | observability | ✅ classification 履歴 visible |
| 4 | rate-limit | ✅ AI が core を 1 commit で大規模変更不可 (= GHA で diff 行数 cap) |
| 5 | sandbox | ✅ [VIBE_SANDBOX_SPEC] cross-link |
| 6 | human-in-loop | ✅ core review checklist 6 観点 全 ✅ 必須 |
| 7 | audit | ✅ weekly audit cron |

**7/7 ✅**

### SYNERGY-30 (= 7/7 推奨)

| # | 原則 | 適用 |
|---|---|---|
| 1 | 5 正本 | ✅ Issues + WBS + docs に boundary_class 同期 |
| 2 | 担当重複なし | ✅ Win Codex 実装 / Win Claude spec |
| 3 | file 競合 検出 | ✅ GHA で path 衝突検知 |
| 4 | schema 競合 | ✅ migration review で確認 |
| 5 | EF 競合 | ✅ tools-hub action 名 unique |
| 6 | workflow 競合 | ✅ core-leaf-coverage-check.yml 単独 |
| 7 | 通知形骸化 | ✅ core 変更 PR で必ず 6 観点 comment |

**7/7 ✅**

---

## §9. Win Codex hand off

### scope (= 推定 8h)

| 項目 | 工数 |
|---|---|
| migration `create_core_leaf_classifications.sql` + initial seed (= ~50 path 分類) | 2h |
| migration `add_wbs_tasks_boundary_class.sql` | 0.5h |
| `tools-hub.governance.classify_path` action | 1.5h |
| GHA workflow `core-leaf-coverage-check.yml` | 1h |
| GitHub Issue template 更新 (= boundary_class dropdown) | 0.5h |
| Flutter UI: `core_leaf_map_page.dart` + ai_dev_principles_page button + project_gantt badge | 2h |
| dart format + flutter analyze + smoke test | 0.5h |

### Codex 振分 5 質問

| Q | 内容 | 答 |
|---|---|---|
| Q1 | UI 設計 / docs 更新? | YES (= UI + docs/CORE_LEAF_MAP.md) |
| Q2 | architect / triage / governance? | YES (= governance 設計) |
| Q3 | AI 機能? | NO (= 静的分類) |
| Q4 | mobile UAT / 動画? | NO |
| Q5 | 部署横断 / 9 原則 cross-check? | YES (= 全部署) |

3 YES → **Win Claude territory ✅**

---

## §10. NotebookLM 蓄積予定

NotebookLM `ddde5a4b` 三つ子完成記録:

| Issue | spec | 役割 | ship part |
|---|---|---|---|
| #839 + #1209 | VIBE_SANDBOX_SPEC | runtime sandbox + AI 生成 code 実行制御 | part 155 (= 統合 spec 第 1 例) |
| #833 | 本 spec CORE_LEAF_BOUNDARY_MAP | governance + 人間レビュー強度 + 分類 programmatic 化 | part 156 |

**1 NotebookLM × 3 issue × 2 spec = 三つ子完結** (= NotebookLM source の最大活用 record).

---

## §11. 関連

- [Issue #833](https://github.com/kanta13jp1/my_web_app/issues/833)
- 関連 spec: [`docs/VIBE_SANDBOX_SPEC.md`](VIBE_SANDBOX_SPEC.md) (= 同 NotebookLM 三つ子第 1+2 / cross-link 必須)
- 関連 spec: [`docs/AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) (= 7 原則 base)
- 既存 page: `lib/pages/ai_dev_principles_page.dart` / `lib/pages/project_gantt_page.dart`
- NotebookLM: `ddde5a4b-ce1a-405d-8291-a334a9371454`
