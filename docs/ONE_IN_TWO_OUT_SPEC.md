# 1 In 2 Out — UI 整理アシスト spec (#1345 / part 143)

> **status**: 設計 spec / Win版#132 part 143 / 2026-05-05
> **issue**: [#1345](https://github.com/kanta13jp1/my_web_app/issues/1345) [追加要望] 「イン・ツー・アウト（1 In 2 Out）」型UI整理アシスト機能の追加
> **scope**: 設計のみ (Win Claude territory) / 実装は Win Codex (= migration + EF Deno + Flutter widget) ハンドオフ
> **NotebookLM source**: `d91788ce` 国民民主党の政策と日本の未来
> **PHILOSOPHY-22 alignment**: #5 (商品=価値) + #6 (時間最適化) / **IMBUE-25** #2 (認知負荷削減) + #6 (CEO 感)

## 1. 思想

「新規ウィジェット 1 個追加 → 過去 N 日未使用ウィジェット 2 個削除/非表示提案」=
**機能肥大化を能動的に防ぐ UX**。
PHILOSOPHY 原則 #6 「ユーザーの時間を浪費しないか」の自走化。

## 2. 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| widget access log table | **未整備** | §3 で新設 |
| usage 集計 EF | **未整備** | §4 で `widget-usage-hub` 新規 action 追加 |
| dashboard widget catalog | 部分整備 (= [home page](lib/pages/home_page.dart) hard-coded) | §5 で `widget_id` enum 化提案 |
| route 単位 access log | 部分整備 ([ai_service.dart](lib/services/ai_service.dart) で session log) | §3 で route+widget 粒度に拡張 |

## 3. Schema 設計 (= Win Codex 担当 / 1 migration)

### 3.1 中核 table

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_widget_usage_log.sql

CREATE TABLE public.widget_usage_log (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  widget_id text NOT NULL,                     -- 'home.budget_card' / 'home.cfo_card'
  route text NOT NULL,                         -- '/home' / '/cfo-office'
  action text NOT NULL DEFAULT 'view'
    CHECK (action IN ('view','tap','dwell','drag')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  session_id text,
  dwell_ms int                                 -- action=dwell 時のみ
);

CREATE INDEX widget_usage_user_widget_time
  ON public.widget_usage_log (user_id, widget_id, occurred_at DESC);

-- ユーザー dashboard 構成の永続化 (= 表示 / 非表示 / 順序)
CREATE TABLE public.user_widget_layout (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  widget_id text NOT NULL,
  display_order int NOT NULL DEFAULT 100,
  is_visible boolean NOT NULL DEFAULT true,
  hidden_at timestamptz,                       -- is_visible=false 化時刻
  hidden_reason text                           -- '1in2out' / 'manual' / 'auto_archive'
    CHECK (hidden_reason IN ('1in2out','manual','auto_archive') OR hidden_reason IS NULL),
  added_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, widget_id)
);

-- 1 In 2 Out 提案履歴 (= 監査 + opt-out 学習)
CREATE TABLE public.one_in_two_out_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  triggered_by_widget_id text NOT NULL,
  proposed_remove_widget_ids text[] NOT NULL,  -- length 2
  user_decision text NOT NULL DEFAULT 'pending'
    CHECK (user_decision IN ('pending','accept_all','accept_partial','skip','opted_out')),
  accepted_widget_ids text[] NOT NULL DEFAULT '{}',
  proposed_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz
);

-- ユーザー level の opt-out 設定
ALTER TABLE public.user_settings  -- 既存推定 / 無ければ create
  ADD COLUMN IF NOT EXISTS one_in_two_out_enabled boolean NOT NULL DEFAULT true;
```

### 3.2 RLS ([AI-DEV-23] #2 deny-by-default)

```sql
ALTER TABLE public.widget_usage_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_widget_layout ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.one_in_two_out_proposals ENABLE ROW LEVEL SECURITY;

CREATE POLICY widget_usage_self_all ON public.widget_usage_log
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_layout_self_all ON public.user_widget_layout
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY one_in_two_out_self_all ON public.one_in_two_out_proposals
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

## 4. Edge Function 設計 ([EF-FIRST] [EF-CAP-50] 遵守)

**新規 EF を作らず**、既存 `growth-hub` (推定) に 3 action 追加:

| action | input | output | 用途 |
|---|---|---|---|
| `widget_usage.log` | `{ widget_id, route, action, dwell_ms? }` | `{ ok }` | bulk INSERT (= debounce 5s / 100 件 batch) |
| `widget_usage.suggest_remove` | `{ trigger_widget_id, lookback_days?: 30 }` | `{ proposals: [{widget_id, last_used_at, score}] }` length 2 | スコアリング (= recency + frequency + dwell) |
| `widget_usage.commit_layout_change` | `{ added: text[], hidden: [{widget_id, reason}] }` | `{ proposal_id }` | layout + proposals 同 transaction で更新 |

### 4.1 suggest_remove スコアリング algorithm

```
score(widget) =
  - 0.5 * recency_days(widget)                  # 最終利用から経過日数
  - 0.3 * normalized_freq(widget, lookback)     # 利用回数 / lookback days
  - 0.2 * normalized_dwell(widget, lookback)    # 平均 dwell_ms
+ pinned_bonus(widget)                          # ユーザーが pin 済なら +1000 (= 候補から除外)

// score 高 = 削除候補度高
```

- `lookback_days=30` default / setting で 7-90 可変
- `pinned_bonus` 巨大値で **明示的 pin 済 widget は提案候補から除外** (= UX 安全弁)

## 5. UI 設計 (= Flutter widget / Win Codex 担当)

### 5.1 trigger flow

```
[user が新ウィジェット追加 button tap]
  ↓
[/widget-catalog modal で widget 選択]
  ↓
[user_settings.one_in_two_out_enabled? ]
  ├─ false → 即追加 (= legacy path)
  └─ true → suggest_remove call
              ↓
       [proposal modal 表示]
       「新しく "X" を追加します。
         普段あまり使われていない以下を整理しませんか?」
       ┌────────────────────────────────────┐
       │ □ Widget A (最終利用 23 日前 / 月 1 回)│
       │ □ Widget B (最終利用 18 日前 / 月 2 回)│
       │ [スキップしてそのまま追加] [選んで整理]│
       │ ────────────────────────────────── │
       │ [☐ 今後この提案を表示しない (opt-out)] │
       └────────────────────────────────────┘
              ↓
       commit_layout_change call (= 1 transaction)
              ↓
       [home へ戻る + snackbar 「整理完了 / +1 / -2」]
```

### 5.2 widget cataloguing 提案

現状 home page の widget は hard-coded → **`widget_id` enum 化** で識別性確保:

| widget_id | display_name | 配置 |
|---|---|---|
| `home.budget_card` | 財務サマリー | home grid |
| `home.cfo_card` | CFO Office | home grid |
| `home.life_goals_card` | OKR 進捗 | home grid |
| `home.meal_log_card` | 食事ログ | home grid |
| `home.self_touch_card` | 心の健康 | home grid |
| ... | ... | ... |

(= [home_page.dart](lib/pages/home_page.dart) リファクタ要 / Codex hand off scope に含む)

## 6. 受け入れ条件 mapping (= Issue #1345)

| Issue 条件 | 本 spec 対応 |
|---|---|
| ① 新規 widget 追加が trigger | §5.1 (catalog modal の add button hook) |
| ② 利用頻度 data から 2 件 auto-list | §3.1 (`widget_usage_log`) + §4.1 (scoring) |
| ③ skip 可 / opt-out 可 | §5.1 (modal 「スキップ」button + 「opt-out」checkbox) + §3.1 (`user_settings.one_in_two_out_enabled`) |

## 7. 実装受入順序 (= Win Codex hand off)

| step | 担当 | 工数 | 受入条件 |
|---|---|---:|---|
| 1. migration `_create_widget_usage_log.sql` | Codex | 1.5h | apply success / RLS deny anon |
| 2. `growth-hub` 3 action 追加 | Codex | 3h | curl smoke (= 各 action 200) |
| 3. `widget_usage_service.dart` (= debounce 5s batch) | Codex | 1.5h | unit test (= mock client + timer) |
| 4. home page widget_id 化 refactor | Codex | 2h | dart format + flutter analyze 0 |
| 5. `OneInTwoOutModal` widget + add hook | Codex | 3h | E2E (= 追加 → modal → 削除確認) |
| 6. settings page opt-out toggle | Codex | 0.5h | toggle persist 確認 |

合計工数: ~11.5h (= Codex 1 instance / 1.5 営業日相当)

## 8. risk + 関連 doc

- 関連 spec: [SIX_DEPT_KPI_PERSISTENCE_SPEC.md](docs/SIX_DEPT_KPI_PERSISTENCE_SPEC.md) (= 同 part 143)
- 関連 page: [home_page.dart](lib/pages/home_page.dart) (= widget_id 化 refactor 対象)
- risk-1: log 量肥大 → debounce + monthly partition 検討 (`widget_usage_log` を pg_partman で月次)
- risk-2: 提案精度低 → opt-out 連発 → §3 `one_in_two_out_proposals.user_decision='opted_out'` 集計で改善 loop
- risk-3: pin 機能未実装段階で誤提案 → §4.1 で `pinned_bonus` を将来 hook (= Phase 2 で pin 実装)

## 9. dogfood

- `[INSTANCE-ROLES]` 設計 spec のみ (= 実装は Codex hand off) 第 4 例
- `[EF-CAP-50]` 既存 hub action 追加で完全遵守
- `[PHILOSOPHY-22]` #5 (価値) + #6 (時間) 7+/9
- `[IMBUE-25]` #2 認知負荷削減 + #6 CEO 感 (= 「自分の company を整理する」体験) 6+/7
- `[COLLAB-26]` #3 Red-Team (= AI が自社の機能を能動的に抑制提案) 6+/7
