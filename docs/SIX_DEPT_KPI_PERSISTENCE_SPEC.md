# 6 部門 KPI 外部 DB 永続化 — Architect Spec (#1316 / part 143)

> **status**: 設計 spec / Win版#132 part 143 / 2026-05-05
> **issue**: [#1316](https://github.com/kanta13jp1/my_web_app/issues/1316) [追加要望] 6部門KPIの外部データベース永続化機能の実装
> **scope**: 設計のみ (Win Claude territory) / 実装は Win Codex (= migration + EF Deno + Flutter widget) ハンドオフ
> **NotebookLM source**: `569fcf08` The 3-Layer Design for Bundling AI as a Solo CEO
> **PHILOSOPHY-22 alignment**: #4 (6 部署バランス) + #7 (資産 vs 負債 / AI vendor lock-in 回避 = 資産化)
> **VIBE-30 alignment**: #2 (vendor independence) + #5 (data ownership)

## 1. 6 部門 taxonomy

| dept | 役割 | 主要 KPI 例 | 既存 page |
|---|---|---|---|
| `rnd` | R&D / スキル自己投資 | 学習時間/月 / コース完了数 / 新技術習得数 | `lib/pages/learning_dashboard_page.dart` (推定) |
| `finance` | 財務 / お給料管理 | 月次収支 / 投資残高 / freelance MRR | [budget_financial_planner_page.dart](lib/pages/budget_financial_planner_page.dart) / [cfo_office_page.dart](lib/pages/cfo_office_page.dart) |
| `marketing` | 自分のアピール / 人脈 | dev.to/Qiita 投稿数 / SNS フォロワー / blog DAU | (T-1 dispatch 統合候補) |
| `hr` | 人事 / 心の健康 | 1on1 mood / stress score / 自己肯定感 | [self_touch_tracker_page.dart](lib/pages/self_touch_tracker_page.dart) |
| `health` | 体の健康 (= PHILOSOPHY #4 「最優先」) | 睡眠時間 / 歩数 / 体重 / meal log | [meal_log_page.dart](lib/pages/meal_log_page.dart) |
| `hq` | 本社 / 戦略 / 統合 | OKR 達成率 / 部署横断 KPI / IPO 進捗 | [life_goals_kpi_page.dart](lib/pages/life_goals_kpi_page.dart) |

**注**: PHILOSOPHY.md は「人事=健康」と統合表現するが、KPI 永続化観点では **心 (hr) と体 (health) を分離** することで dashboard 可視化が明瞭化する (= 「人事最優先」の運用が body+mind 両軸で測れる)。

## 2. Schema 設計 (= 1 migration / Win Codex 担当)

### 2.1 中核 table

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_six_dept_kpi_tables.sql

-- enum: 6 部門
CREATE TYPE dept_code AS ENUM ('rnd','finance','marketing','hr','health','hq');

-- KPI 定義 master (= 部門 x KPI 名 / unit / target)
CREATE TABLE public.six_dept_kpi_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dept dept_code NOT NULL,
  kpi_key text NOT NULL,                 -- snake_case (= 'sleep_hours' / 'mrr_jpy')
  display_name text NOT NULL,
  unit text,                             -- 'hours' / '¥' / '回' / null
  target_value numeric,                  -- 月次目標 (= NULL OK)
  is_higher_better boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, dept, kpi_key)
);

-- KPI 観測値 time-series (= 1 行 1 観測)
CREATE TABLE public.six_dept_kpi_observations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kpi_id uuid NOT NULL REFERENCES public.six_dept_kpi_definitions(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  value numeric NOT NULL,
  source text NOT NULL DEFAULT 'manual'
    CHECK (source IN ('manual','ai_extract','sync_external','wearable')),
  ai_session_id text,                    -- AI 抽出時の trace_id ([AI-DEV-23] #3)
  raw_text text,                         -- AI 抽出前の元発話 (= 監査用)
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX six_dept_kpi_obs_user_dept_time
  ON public.six_dept_kpi_observations (user_id, kpi_id, observed_at DESC);

-- 月次集計 materialized view (= dashboard read 用 / EF refresh)
CREATE MATERIALIZED VIEW public.six_dept_kpi_monthly AS
SELECT
  o.user_id,
  d.dept,
  d.kpi_key,
  d.display_name,
  d.unit,
  d.target_value,
  d.is_higher_better,
  date_trunc('month', o.observed_at) AS month,
  COUNT(*) AS obs_count,
  AVG(o.value) AS avg_value,
  SUM(o.value) AS sum_value,
  MIN(o.value) AS min_value,
  MAX(o.value) AS max_value,
  MAX(o.observed_at) AS last_observed_at
FROM public.six_dept_kpi_observations o
JOIN public.six_dept_kpi_definitions d ON d.id = o.kpi_id
GROUP BY o.user_id, d.dept, d.kpi_key, d.display_name, d.unit,
         d.target_value, d.is_higher_better, date_trunc('month', o.observed_at);

CREATE UNIQUE INDEX six_dept_kpi_monthly_pk
  ON public.six_dept_kpi_monthly (user_id, dept, kpi_key, month);
```

### 2.2 RLS policy ([AI-DEV-23] #2 deny-by-default)

```sql
ALTER TABLE public.six_dept_kpi_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.six_dept_kpi_observations ENABLE ROW LEVEL SECURITY;

-- read: 自分の行のみ
CREATE POLICY six_dept_def_self_read ON public.six_dept_kpi_definitions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY six_dept_obs_self_read ON public.six_dept_kpi_observations
  FOR SELECT USING (auth.uid() = user_id);

-- write: EF (service_role) 経由のみ (= AI 抽出 path 監査)
-- manual entry path 用に SELF write も別 policy で許可 (source='manual' のみ)
CREATE POLICY six_dept_obs_self_manual_insert ON public.six_dept_kpi_observations
  FOR INSERT WITH CHECK (auth.uid() = user_id AND source = 'manual');
CREATE POLICY six_dept_def_self_write ON public.six_dept_kpi_definitions
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

## 3. Edge Function 設計 (= 既存 hub 統合 / [EF-FIRST] [EF-CAP-50] 遵守)

**新規 EF を作らず**、既存 `kpi-hub` (推定 / もし無ければ `growth-hub` に action 追加) に 3 action 拡張:

| action | input | output | 用途 |
|---|---|---|---|
| `kpi.extract_from_ai` | `{ ai_session_id, raw_text, model_hint? }` | `{ proposed: [{dept, kpi_key, value, confidence}] }` | AI 出力 → KPI 候補抽出 (= LLM 経由 / Anthropic Sonnet 4.6) |
| `kpi.commit_observation` | `{ kpi_id, value, source, ai_session_id?, raw_text? }` | `{ observation_id }` | 確認後 INSERT (= 監査 trail) |
| `kpi.refresh_monthly` | `{}` | `{ refreshed_at }` | materialized view refresh (= cron 1h) |

**EF 数**: 既存 hub action 追加のみ → **新規 EF 0 件** ([EF-CAP-50] 完全遵守)。

## 4. UI 設計 (= Flutter widget / Win Codex 担当)

### 4.1 page 構成

| route | widget | 既存 page との関係 |
|---|---|---|
| `/six-dept-kpi` | `SixDeptKpiPage` (= 新規) | hub page / 6 部門 grid + 月次推移 chart |
| `/six-dept-kpi/<dept>` | `DeptKpiDetailPage` (= 新規) | 部門単位 drill-down (= KPI 一覧 + add manual obs button) |
| `/life-goals-kpi` | 既存 [life_goals_kpi_page.dart](lib/pages/life_goals_kpi_page.dart) | **HQ 部門 view として再利用** (= 重複作らない) |

### 4.2 SixDeptKpiPage 構成

```
[Header: "自分株式会社 6 部門 KPI"]
[最終 AI 抽出時刻: 2026-05-05 14:32 / source=Claude]

┌─ R&D (rnd) ──────┐ ┌─ 財務 ────────┐ ┌─ マーケ ──────┐
│ 学習 12h / 目標 20h│ │ MRR ¥18,400  │ │ 投稿 24/30 │
│ ▲ progress bar    │ │ ▼ trend chart │ │ ● badges  │
└──────────────────┘ └───────────────┘ └────────────┘

┌─ 人事 (心) ──────┐ ┌─ 健康 (体) ★ ─┐ ┌─ HQ ─────────┐
│ mood avg 7.2/10  │ │ 睡眠 7.1h / 歩数│ │ OKR 進捗 62% │
│ stress 中        │ │ 8,432 / 体重    │ │ → /life-goals │
└──────────────────┘ └──────────────────┘ └──────────────┘

★ = PHILOSOPHY #4 「最優先」マーカー
```

### 4.3 重要 UX

- **manual entry button**: 各 KPI carded で `+` tap → `value` 入力 → `kpi.commit_observation` (source=`manual`) call
- **AI 抽出 review modal**: `kpi.extract_from_ai` 結果を 1 件ずつ approve/skip (= [AI-DEV-23] #7 quality-gate)
- **過去比較**: 月次 vs 前月 / 前年同月 (= materialized view から read)
- **vendor 非依存表示**: source badge (`Claude` / `GPT` / `Gemini` / `manual`) で抽出元可視化

## 5. 実装受入順序 (= Win Codex hand off)

| step | 担当 | 工数推定 | 受入条件 |
|---|---|---:|---|
| 1. migration `_create_six_dept_kpi_tables.sql` | Codex | 1.5h | apply success / RLS deny anon 確認 |
| 2. `kpi-hub` 3 action 追加 (= EF Deno) | Codex | 3h | curl smoke test (= each action 200) |
| 3. `kpi_service.dart` (= Supabase wrapper) | Codex | 1h | unit test (= mock client) |
| 4. `SixDeptKpiPage` + `DeptKpiDetailPage` | Codex | 4h | dart format / flutter analyze 0 |
| 5. AI 抽出 path 結線 (= chat hub → kpi.extract_from_ai) | Codex | 2h | E2E smoke (= AI 発話 → KPI proposal 表示) |
| 6. seed migration (= 各部門 5 KPI default) | Codex | 0.5h | login 後 grid 6 マス埋まる |

合計工数: ~12h (= Codex 1 instance / 1.5 営業日相当)

## 6. 受け入れ条件 mapping (= Issue #1316)

| Issue 条件 | 本 spec 対応 |
|---|---|
| ① 6 部門 KPI 専用 DB table | §2 (`six_dept_kpi_definitions` + `six_dept_kpi_observations` + materialized view) |
| ② AI セッション終了後も Supabase 永続 | §2 (`raw_text` + `ai_session_id` 監査列) + §3 (`kpi.commit_observation` action) |
| ③ vendor 非依存 dashboard | §4.2 (`source` badge 可視化) + §3 (`source` enum 4 種 = manual/ai_extract/sync_external/wearable) |

## 7. 関連 doc + risk

- 関連 spec: [MONETIZATION_DESIGN.md](docs/MONETIZATION_DESIGN.md) (= part 142 / Pro tier 機能差別化候補)
- 関連 page: [life_goals_kpi_page.dart](lib/pages/life_goals_kpi_page.dart) (= HQ 部門 view 再利用)
- risk-1: AI 抽出精度低 → manual entry path 必須 (§4.3 で担保)
- risk-2: 部門 enum 拡張時の migration → `dept_code` ENUM ADD VALUE で対応 (= ALTER TYPE)
- risk-3: materialized view refresh 遅延 → cron 1h 運用 (= 即時性が必要なら trigger 化検討)

## 8. dogfood

- `[INSTANCE-ROLES]` 設計 spec のみ (= 実装は Codex hand off) 第 3 例 (= part 142 #1305 / #1309 に続く)
- `[EF-CAP-50]` 既存 hub action 追加で完全遵守
- `[PHILOSOPHY-22]` #4 (6 部署) + #7 (vendor 独立 = 資産化) 7+/9
- `[BRAIN-32]` PKM = AI 揮発履歴を永続資産化 (= 第二の脳 #1 + #2)
