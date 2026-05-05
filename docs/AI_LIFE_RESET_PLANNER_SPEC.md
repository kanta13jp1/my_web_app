# AI 生活リセット プランナー 設計 spec (= #768 / part 156)

> **Issue**: [#768 [追加要望] Gemini整理術を応用したAI生活リセットプランナー](https://github.com/kanta13jp1/my_web_app/issues/768)
> **NotebookLM**: `579bd686-f17e-414a-894f-822f29b5c11e` (= 8 Gemini Tips for Organizing Your Space and Life)
> **Spec 種別**: 通常 (= 非 sensitive)
> **担当**: Win Codex hand off (= UI + EF action 追加 / 推定 8h)
> **EF**: `lifestyle-hub` 既存 hub action 追加 [EF-CAP-50] 遵守

---

## §1. 思想

Gemini 整理術の核は **「圧倒される目標を 15 分タスクへ分解」**.
本 spec は自分株式会社の既存ライフマネジメント (= life_goals / habit_tracker / daily_habits / kanban_board / WBS) を **AI が横断 read → 「今日の最小一手」を生成** する planner として定義.

### 「リセット」の定義 (= 命名注意)

「生活リセット」 = 既存タスクを破棄して新規開始 では **ない**. 既存目標を保ったまま「次の最小ステップ」を提案する **gentle restart**. 破壊的 restart は CEO 感を毀損する (= PHILOSOPHY 原則 #1).

---

## §2. 受け入れ条件 mapping (= Issue #768)

| # | 受入条件 | 実装方針 |
|---|---|---|
| 1 | ユーザー現状から AI が生活リセット計画を生成 | `lifestyle-hub.life_reset.generate_plan` action (= 既存データ集約 + LLM call) |
| 2 | 生成結果に KGI / CSF / KPI / 今日の最小タスク を含む | EF 出力 schema 4 field 必須 + Flutter UI で 4 section 表示 |
| 3 | 継続系タスクは 1 つずつ習慣化 | 「new_habit_count: 1」 を hard cap で LLM prompt に明示 |
| 4 | 生成タスクを WBS or 日次タスクに登録できる | UI に 「WBS 登録」「日次タスクへ追加」 button + EF 経由で `wbs_tasks` / `daily_habits` 行追加 |

---

## §3. NOT to do (= 失敗 pattern 7 件)

1. ❌ 既存目標を上書き / 破棄 する (= 「リセット」の名で破壊しない)
2. ❌ 同時に 2+ 個の継続系タスクを開始させる (= 習慣化失敗の主因 / CEO 感毀損)
3. ❌ 15 分超の最小タスクを「最小タスク」と称する (= Gemini 原則違反)
4. ❌ ユーザー入力なし で全 LLM 提案を即 WBS 登録 (= [DYNAMIC-CLAIM] 違反 / scope creep)
5. ❌ NotebookLM `579bd686` 以外の出典で「Gemini」 と表示 (= 出典詐称)
6. ❌ KGI なし で KPI を提示 (= 階層欠落 / 目的不明)
7. ❌ 既存 `lifestyle-hub` 110 action と重複命名 (= 例: `meal.plan` の隣に `lifestyle.plan` は混乱)

---

## §4. MUST do (= 必須要件 9 項)

1. ✅ EF action 名: `life_reset.generate_plan` (= namespace 衝突回避)
2. ✅ EF 入力: `{ user_id, scope: 'time'|'money'|'health'|'study'|'work', max_minutes_per_task: 15 }` 必須
3. ✅ EF 出力 schema:
   ```json
   {
     "kgi": "string (= 3-6 month 大目標)",
     "csf": ["string (= 必勝条件 / 2-3 件)"],
     "kpi": [{ "label": "string", "target": number, "unit": "string" }],
     "today_min_task": { "title": "string", "minutes": "number ≤ 15" },
     "this_week_avoid": ["string (= やらないこと / 1-2 件)"],
     "new_habit_count": "number (= ≤ 1)"
   }
   ```
4. ✅ LLM prompt 内に「Gemini Tips for Organizing Space and Life」由来の 8 原則を inline (= NotebookLM `579bd686` 引用 / hallucination 防止)
5. ✅ 既存 read 対象: `life_goals` / `kgi_csf_kpi` / `daily_habits` / `habit_tracker` / `wbs_tasks` (= user 担当のみ) / `health_metrics` (= optional)
6. ✅ Flutter UI: `life_reset_plan_page.dart` 新規 (= 表示+操作のみ / [EF-FIRST] 遵守) または `life_goals_page.dart` 内 tab 追加
7. ✅ 「WBS 登録」 button 押下時: `wbs_tasks` row 追加 (= owner_instance = user / status = 'pending' / category = 'life-reset')
8. ✅ 「日次タスクへ追加」 button 押下時: `daily_habits` row 追加 (= max 1 件 / 受入条件 #3)
9. ✅ 生成 plan は `life_reset_plans` table へ save (= 履歴 / 1 user / 1 day cap = 1 件)

---

## §5. EF 既存基盤確認 (= [EF-FIRST] / [EF-CAP-50])

### 既存活用

- `lifestyle-hub` (= 110 action / 残枠あり)
- `ai-hub.provider.chat` (= LLM call backbone / Gemini / Claude / OpenAI fallback)
- `wbs_tasks` table (= 既存 / WBS 登録先)
- `daily_habits` table (= 既存 / 日次タスク登録先)

### 新規追加

- **EF action**: `lifestyle-hub.life_reset.generate_plan` (= 1 action / hub 内追加 / 新 EF 不要 ✅)
- **table**: `life_reset_plans` (= 履歴 / id / user_id / scope / generated_at / payload jsonb / wbs_task_ids[] / habit_task_ids[])
- **migration**: `YYYYMMDDHHMMSS_create_life_reset_plans.sql` (= RLS user own only)

### EF 数

| 項目 | 数 | 状態 |
|---|---|---|
| 現在 EF | 50 | [EF-CAP-50] 上限 |
| 本 spec 追加 | 0 | hub action のみ |
| 残枠 | 0 | 維持 |

---

## §6. UI 設計

### 配置先 (= 2 案 / Codex 判断)

#### 案 A (= 推奨): `life_goals_page.dart` 内に「リセット plan」 tab 追加
- 既存 ライフ目標管理に統合 / 学習コスト最小
- tab `🔄 Reset Plan` 新規

#### 案 B: 独立 `life_reset_plan_page.dart`
- ナビ独立 / 機能性高い
- 学習コスト中

### UI flow (= 案 A 採用前提)

1. user が tab 「🔄 Reset Plan」 を開く
2. scope 選択 (= time / money / health / study / work / 全部)
3. 「生成」 button → `lifestyle-hub.life_reset.generate_plan` call (= ローディング 5-10s)
4. 結果 4 section 表示:
   - 🎯 **KGI** (= 1 行 / 3-6 month 大目標)
   - 📌 **CSF** (= 2-3 件 / bullet)
   - 📊 **KPI** (= 2-4 件 / progress bar 付)
   - ⚡ **今日の最小タスク** (= 1 件 / 15 min タイマー連動)
5. action button:
   - 「WBS 登録」→ wbs_tasks へ
   - 「日次タスクへ追加」→ daily_habits へ (= max 1 件)
   - 「再生成」→ 別 plan 提案 (= 1 day cap 内なら再 LLM call / 超過なら confirm dialog)
6. 「やらないこと」 section (= 折りたたみ / 受入条件 #3 補強)

---

## §7. 9 原則 alignment

### PHILOSOPHY-22 (= 9 原則 / 7+/9 ✅必要)

| # | 原則 | 適用 |
|---|---|---|
| 1 | CEO 感 | ✅ user が自分で plan 採否決定 |
| 2 | ミッション | ✅ 浪費削減 6 軸 (時間/金/健康/体力/知能/集中) と直結 |
| 3 | mentor | ✅ AI が next step を提案 / 失敗解説 |
| 4 | 6 部署 | ✅ ライフマネジメント部 担当 |
| 5 | 商品=価値 | ✅ 生成 plan が即 WBS/日次タスク化可 |
| 6 | 資本=時間 | ✅ 15 min cap で時間資本 protect |
| 7 | 資産負債 | ✅ 既存 KGI/CSF/KPI 階層を活用 (= 資産再活用) |
| 8 | KPI | ✅ 出力 schema に KPI 必須 |
| 9 | IPO | ⏸ 直接関連弱 |

**8/9 ✅** (= [PHILOSOPHY-22] 7+/9 達成)

### AI-DEV-23 (= 7 原則 / 6+/7 ✅必要)

| # | 原則 | 適用 |
|---|---|---|
| 1 | Auth | ✅ user 認証必須 / RLS user own only |
| 2 | deny-by-default | ✅ scope 未指定 = 全部 拒否 / explicit only |
| 3 | trace_id | ✅ EF 内 trace_id 生成 / `life_reset_plans.trace_id` |
| 4 | circuit-breaker | ✅ 1 user / 1 day cap = 1 plan 生成 (= rate limit) |
| 5 | memory | ✅ NotebookLM `579bd686` 引用 / 履歴 `life_reset_plans` |
| 6 | DLQ | ✅ LLM call fail → `life_reset_plans.status = 'failed'` |
| 7 | quality-gate | ✅ schema validation (= KGI 1 行 / KPI 2-4 件 / today_min_task ≤ 15 min) |

**7/7 ✅**

### IMBUE-25 (= 7 パターン / 6+/7 ✅推奨)

| # | パターン | 適用 |
|---|---|---|
| 1 | 過程透明性 | ✅ LLM prompt + 引用 NotebookLM ID 表示可 (= debug toggle) |
| 2 | 細粒度コントロール | ✅ scope 5 種 + max_minutes 調整可 |
| 3 | やり直し容易性 | ✅ 「再生成」button + 履歴比較 |
| 4 | 失敗時の人間 fallback | ✅ LLM fail 時は「手動 plan 入力」 form 表示 |
| 5 | 学習統合 | ✅ 採用 plan の達成率を `life_reset_plans.outcome_metrics` で蓄積 |
| 6 | 操作性の安心感 | ✅ 「やらないこと」 section で過剰生成 (= overwhelm) 防止 |
| 7 | 段階的開示 | ✅ 4 section を accordion 表示 (= KGI のみ→詳細展開) |

**7/7 ✅**

### COLLAB-26 (= 7 パターン / 6+/7 ✅推奨)

| # | パターン | 適用 |
|---|---|---|
| 1 | Tinker | ✅ 「再生成」+ scope 切替 で AI と協調探索 |
| 2 | Co-Reasoning | ✅ user が plan 1 件 ずつ 採否判断 / AI 提案理由表示 |
| 3 | Red-Team | ⏸ 自己批判 mode 未実装 |
| 4 | Trail | ✅ 履歴で plan 比較可 |
| 5 | Reciprocal teaching | ⏸ 未実装 |
| 6 | Negotiation | ✅ scope / max_minutes で AI と交渉 |
| 7 | Trust calibration | ✅ NotebookLM 引用表示で信頼度可視化 |

**5/7 ✅** (= 6+/7 推奨に -1 / Win Codex hand off で red-team mode 検討余地)

---

## §8. Win Codex hand off

### scope (= 推定 8h)

| 項目 | 工数 |
|---|---|
| migration `create_life_reset_plans.sql` (= table + RLS + index) | 1h |
| `lifestyle-hub.life_reset.generate_plan` action (= LLM prompt + ai-hub call + schema validation) | 3h |
| `life_goals_page.dart` tab 追加 (= 案 A) + 4 section UI + 3 action button | 3h |
| dart format + flutter analyze + 動作確認 | 0.5h |
| migration apply + EF deploy + 本番 smoke test | 0.5h |

### Codex 振分 5 質問 (= [INSTANCE-ROLES])

| Q | 内容 | 答 |
|---|---|---|
| Q1 | UI 設計 / docs 更新? | YES (= UI + spec) |
| Q2 | architect / triage? | YES (= 設計判断複数) |
| Q3 | AI 機能 設計? | YES (= LLM 生成 plan) |
| Q4 | mobile UAT / 動画? | NO |
| Q5 | sensitive design? | NO (= 通常 spec) |

3 YES → **Win Claude territory ✅** (= spec ship 本 part / 実装 = Win Codex hand off)

---

## §9. NotebookLM 蓄積予定

本 spec ship 後、`docs/notebooklm-intake/jibun-master-brain-spec-template-seed.md` に下記 entry 追加:

```yaml
- id: 579bd686-f17e-414a-894f-822f29b5c11e
  title: 8 Gemini Tips for Organizing Your Space and Life
  spec: docs/AI_LIFE_RESET_PLANNER_SPEC.md
  ship_part: 156
  type: normal
  pattern: existing_hub_extension
```

---

## §10. 関連

- [Issue #768](https://github.com/kanta13jp1/my_web_app/issues/768)
- 既存統合: `lib/pages/life_goals_page.dart` / `lib/pages/life_goals_kpi_page.dart` / `lib/pages/daily_habits_page.dart` / `supabase/functions/lifestyle-hub/`
- 関連 spec: `docs/DESIGN_SPEC_TEMPLATE.md` (= meta) / `docs/DESIGN_SPEC_PATTERNS.md` (= 抽象化 layer)
- NotebookLM: `579bd686-f17e-414a-894f-822f29b5c11e`
