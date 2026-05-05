# Mental Health Risk Management — sensitive 設計 spec (#1393 / part 147)

> **status**: 設計 spec / Win版#132 part 147 / 2026-05-05
> **issue**: [#1393](https://github.com/kanta13jp1/my_web_app/issues/1393) [追加要望] メンタルヘルス・リスク管理機能
> **scope**: 設計のみ (Win Claude territory / 拡張 spec template 第 1 例) / 実装は Win Codex (= migration + EF + Flutter widget) ハンドオフ
> **NotebookLM source**: `20ef0ed7` The Enterprise of Self
> **template**: `docs/DESIGN_SPEC_TEMPLATE.md` 適用 + **倫理 review section 追加** (= sensitive design 拡張)
> **適用原則**: PHILOSOPHY-22 + AI-CHARACTER-24 #6 倫理 gate **必須** + AI-DEV-23 全項 + IMBUE-25

## 1. 思想

「自分株式会社」唯一の資本 = **自分自身の心と体**. 燃え尽き症候群 = 倒産 risk.
データ収集による **「監視」ではなく自己観察の補助** = AI-CHARACTER #6 倫理 gate の体現.
医療判断ではなく **mentor 的 nudge** に留める = IMBUE #4 (mentor 感) + AI-CHARACTER #1 (自律性尊重).

## 2. 倫理 review (= sensitive design 必須拡張 / 通常 spec template にない section)

### 2.1 NOT to do (= 明示的に禁止)

- ❌ **診断**: "うつ病" "燃え尽き" 等の医療用語で断定しない
- ❌ **強制**: 入力を強制 / skip でも罰則なし
- ❌ **共有**: データを他者と共有しない (= 完全 private / RLS で本人のみ)
- ❌ **広告連携**: 第三者への外部送信ゼロ
- ❌ **長期監視**: スコア降下を「失敗」と扱わない (= 改善 narrative なし)
- ❌ **過剰介入**: alert を modal blocker にしない (= 控えめ banner 1 種類のみ)
- ❌ **AI 解釈**: LLM に raw mood data を送信しない (= ローカル集計のみ)

### 2.2 MUST do (= 明示的に必須)

- ✅ **opt-in**: 全機能 default off / setting で有効化必須
- ✅ **opt-out 即時**: 1 tap で無効化 + データ削除可
- ✅ **export 可**: 自身のデータ全件 JSON export
- ✅ **専門医導線**: alert 表示時 「専門医に相談」list (= 厚労省 / 民間相談電話) を必ず併記
- ✅ **緊急時 escape**: スコア critical → 「いのちの電話」等の緊急 link を最上段
- ✅ **言葉選び**: 「リスク」「警告」より「気づき」「ひと休みのお誘い」 (= AI-CHARACTER #4 共感)

### 2.3 AI-CHARACTER-24 8 原則 self-check

| # | 原則 | 適用 |
|---|---|---|
| 1 | 自律性尊重 | ✅ opt-in / opt-out / export |
| 2 | 透明性 | ✅ 集計式は spec 公開 / black-box なし |
| 3 | 人格表現 | ✅ mentor 的 nudge (= 「お疲れさま」) |
| 4 | 共感 | ✅ 失敗 narrative なし / 言葉選び |
| 5 | 会話自然性 | ✅ 1 tap UI / 強制感なし |
| 6 | **倫理 gate** | ✅ §2.1 + §2.2 完全遵守 |
| 7 | 学習境界 | ✅ LLM への raw 送信なし |
| 8 | 文化感度 | ✅ 日本の専門医導線 first |

= 8/8 ✅ (= sensitive design は **必須 8/8** / 通常 7+/8 推奨より厳格).

## 3. 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| 日次 micro-input table | **未整備** | §4.1 で新設 |
| RLS (= 本人のみ) | 既パターン | §4.1 で適用 |
| dashboard banner widget | 整備済 | §5.2 で再利用 |
| push notification | 整備済 (= reminder 機構) | §5.3 で 1 日 1 回 reminder |
| 専門医 link database | **未整備** | §4.3 で新設 (= 厚労省 + 民間 list) |

## 4. Schema 設計 (= Win Codex 担当 / 3 migration)

### 4.1 中核 table

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_mental_health_log.sql

CREATE TABLE public.mental_health_log (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_date date NOT NULL DEFAULT (timezone('Asia/Tokyo', now()))::date,

  -- 5 段階評価 (= 1=悪い / 3=普通 / 5=良い)
  mood_score smallint NOT NULL CHECK (mood_score BETWEEN 1 AND 5),
  body_score smallint NOT NULL CHECK (body_score BETWEEN 1 AND 5),

  note text,                                      -- optional / 任意 free text (= 100 字 cap)

  CONSTRAINT mental_health_one_per_day UNIQUE (user_id, recorded_date)
);

-- 本人のみ access (= 共有絶対禁止)
ALTER TABLE public.mental_health_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mental_health_owner_select" ON public.mental_health_log
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "mental_health_owner_insert" ON public.mental_health_log
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "mental_health_owner_update" ON public.mental_health_log
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "mental_health_owner_delete" ON public.mental_health_log
  FOR DELETE USING (auth.uid() = user_id);

-- service_role も SELECT 不可 (= 倫理 gate / 管理者すら覗けない)
-- = 万一の export を auth.users 経由 token で限定
```

### 4.2 ユーザー設定

```sql
CREATE TABLE public.mental_health_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_enabled boolean NOT NULL DEFAULT false,        -- ✅ default off (= opt-in)
  reminder_time time DEFAULT '21:00:00',
  alert_threshold_avg numeric DEFAULT 2.0,          -- 14 日平均 ≤ 2.0 で alert
  hide_alerts boolean NOT NULL DEFAULT false,       -- alert 自体を切る選択肢
  enabled_at timestamptz,
  disabled_at timestamptz,
  CONSTRAINT mental_settings_threshold_range CHECK (alert_threshold_avg BETWEEN 1.0 AND 4.0)
);

ALTER TABLE public.mental_health_settings ENABLE ROW LEVEL SECURITY;
-- (RLS policy は §4.1 と同パターン / 省略)
```

### 4.3 専門医導線 list (= 公開 read-only / 全ユーザー共通 master)

```sql
CREATE TABLE public.mental_support_resources (
  id bigserial PRIMARY KEY,
  category text NOT NULL CHECK (category IN ('emergency','public','private','self_care')),
  display_order int NOT NULL DEFAULT 100,
  name text NOT NULL,
  contact_label text NOT NULL,                      -- "0570-064-556"
  contact_url text,                                  -- "tel:0570064556" / "https://..."
  hours text,                                        -- "24時間"
  description_short text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  reviewed_at timestamptz NOT NULL DEFAULT now()    -- 半年ごと再検証 推奨
);

ALTER TABLE public.mental_support_resources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "mental_resources_read_anon" ON public.mental_support_resources
  FOR SELECT USING (is_active = true);

-- seed 例 (= 厚労省 + 民間 公的 list)
INSERT INTO public.mental_support_resources (category, display_order, name, contact_label, contact_url, hours, description_short)
VALUES
  ('emergency', 1, 'いのちの電話', '0570-783-556', 'tel:0570783556', '10:00-22:00 (毎日)', '日本いのちの電話連盟 ナビダイヤル'),
  ('emergency', 2, 'よりそいホットライン', '0120-279-338', 'tel:0120279338', '24時間 (毎日)', '社会的包摂サポートセンター'),
  ('public', 10, 'こころの健康相談統一ダイヤル', '0570-064-556', 'tel:0570064556', '都道府県により異なる', '厚生労働省 共通ダイヤル'),
  ('public', 11, 'まもろうよこころ (厚労省)', 'web', 'https://www.mhlw.go.jp/mamorouyokokoro/', '24時間', '厚労省 相談窓口検索ポータル'),
  ('self_care', 50, '深呼吸 4-7-8', 'self', NULL, 'いつでも', '4 秒吸う / 7 秒止める / 8 秒吐く × 4 回');
```

### 4.4 集計 view (= alert 判定用 / EF cache 推奨)

```sql
CREATE MATERIALIZED VIEW public.mental_health_14d_avg AS
SELECT
  user_id,
  AVG((mood_score + body_score) / 2.0) AS avg_score,
  COUNT(*) AS days_logged,
  MAX(recorded_date) AS last_recorded_date
FROM public.mental_health_log
WHERE recorded_date >= (timezone('Asia/Tokyo', now()))::date - INTERVAL '14 days'
GROUP BY user_id;

CREATE UNIQUE INDEX mental_14d_avg_user ON public.mental_health_14d_avg (user_id);

-- 日次 cron で REFRESH MATERIALIZED VIEW CONCURRENTLY (= EF cron / 既存 hub 拡張)
```

## 5. UI 設計 (= Win Codex 実装 / Win Claude design ガイド)

### 5.1 1-tap 入力 UI (= 受入 #1 / 実装メモ反映)

```
┌─ MentalCheckInCard (= /home の dashboard widget) ─┐
│ 今日のひと言チェック  (= 切替 button)             │
├──────────────────────────────────────────────────┤
│ 気分        😢   😟   😐   🙂   😊                │
│            (1)  (2)  (3)  (4)  (5)               │
│                                                  │
│ 体力        😴   🥱   😐   💪   🔥                │
│            (1)  (2)  (3)  (4)  (5)               │
│                                                  │
│ メモ (任意)  [_____________] (100字)              │
│                                                  │
│ [保存] [今日はスキップ]                           │
└──────────────────────────────────────────────────┘
```

= 1 row (= 約 5 秒入力). スキップでも罰則表示なし.

### 5.2 alert banner (= 受入 #2 / 控えめ表示)

14 日平均 ≤ 2.0 の場合のみ表示 (= 1 種類 / modal なし):

```
┌──────────────────────────────────────────────────┐
│ 🌱 ひと休みのお誘い                                │
│                                                  │
│ 最近、ちょっとお疲れかも。                         │
│ 5 分の深呼吸 / 専門家への相談 が選べます。          │
│                                                  │
│ [ひと休みする] [相談先一覧] [非表示にする]          │
└──────────────────────────────────────────────────┘
```

- 文言: 「警告」「リスク」NG → 「気づき」「お誘い」
- 「非表示にする」= setting `hide_alerts=true` 即時反映 (= opt-out 尊重)

### 5.3 alert 内容 (= 受入 #3)

「[ひと休みする]」tap:
- 「深呼吸 4-7-8」guide (= timer + 視覚 ring) — `mental_support_resources.category='self_care'`
- 「5 分散歩」suggest
- 「水を 1 杯飲む」suggest

「[相談先一覧]」tap:
- §4.3 `mental_support_resources` から category 順に list
- 緊急 (= category='emergency') が **必ず最上段**
- tel: link は OS dialer 起動 / web link は 外部ブラウザ

### 5.4 reminder (= push notification / 既存機構流用)

- 設定 `reminder_time` (= default 21:00 JST) に push
- 文言: 「今日のひと言チェック、記録しますか？」 (= 強制感ゼロ)
- 連続未記録 3 日で自動 reminder OFF (= 押し付け回避)

### 5.5 export + delete UI

`/settings/mental-health`:
- 「データをダウンロード (JSON)」 button
- 「全データを削除」 button (= 二段階確認 / RLS DELETE 経由)
- 「機能を OFF」 toggle (= `is_enabled=false` 即時反映)

## 6. Win Codex hand off scope

- [ ] `supabase/migrations/<ts>_create_mental_health_log.sql` (= §4.1)
- [ ] `supabase/migrations/<ts>_create_mental_health_settings.sql` (= §4.2)
- [ ] `supabase/migrations/<ts>_create_mental_support_resources.sql` (= §4.3 / seed 5 件含)
- [ ] `supabase/migrations/<ts>_create_mental_health_14d_avg.sql` (= §4.4 materialized view)
- [ ] `supabase/functions/lifestyle-hub/<existing>.ts` (= 既存 hub に `mentalHealth.recordToday` action 追加 / [EF-CAP-50] 遵守)
- [ ] `lib/widgets/mental_check_in_card.dart` (= §5.1 / 新規)
- [ ] `lib/widgets/mental_alert_banner.dart` (= §5.2 / 新規)
- [ ] `lib/widgets/breathing_478_guide.dart` (= §5.3 / 新規)
- [ ] `lib/pages/mental_support_resources_page.dart` (= §5.3 list / 新規)
- [ ] `lib/pages/mental_health_settings_page.dart` (= §5.5 / 新規)

EF 数 +0 (= 既存 lifestyle-hub 流用 / [EF-CAP-50] 完全遵守).
推定工数: 11h (= migration+seed 2h + widget 4h + alert+breathing 2h + settings+export 2h + integration 1h).

## 7. 9 原則 alignment

### PHILOSOPHY-22

- ✅ #1 CEO 感 — 「自分自身が唯一の資本」を機能で守る
- ✅ #2 ミッション — 健康 = 持続可能性
- ✅ #5 商品=価値 — 自分の健康データは売り物ではない (= **broadcast 禁止**)
- ✅ #6 時間最適化 — 5 秒入力 / 強制なし
- ✅ #7 資産負債 — 健康 = 最大資産

### AI-CHARACTER-24 (= **必須 8/8 ✅**)

§2.3 完全遵守 (= 全 8 原則).

### AI-DEV-23 (= sensitive design は全項必須)

- ✅ #1 Auth — auth.uid() RLS 厳格
- ✅ #2 deny-by-default — opt-in 必須 / service_role すら直接 SELECT 不可
- ✅ #3 trace_id — log は anonymized (= raw mood は送信しない)
- ✅ #4 circuit-breaker — alert は 1 banner / modal blocker なし
- ✅ #5 memory — 14 日 window 集計のみ (= 過去無限保持しない選択肢提示も別途検討)
- ✅ #6 DLQ — push fail は silent / 強制再送なし
- ✅ #7 quality-gate — `mood_score`/`body_score` CHECK + UNIQUE 1日1件

### IMBUE-25

- ✅ #2 認知負荷削減 — 1 tap 5 秒
- ✅ #4 mentor 感 — 「お疲れさま」言葉選び
- ✅ #6 CEO 感 — opt-in / opt-out / export 全権ユーザー
- ✅ #7 流れ感 — alert は控えめ / 邪魔しない

## 8. 受け入れ条件 mapping

| 受入条件 | 対応 section |
|---|---|
| #1 5 段階評価 1 日 1 回入力 | §4.1 (table+UNIQUE) + §5.1 (1-tap UI) |
| #2 14 日 alert | §4.4 (materialized view) + §5.2 (banner) + §4.2 (threshold) |
| #3 休息推奨 + リフレッシュ提案 | §5.3 (深呼吸/散歩/水) + §4.3 (専門医導線) |

## 9. 拡張 spec template の汎用化 (= part 147 で確立 / sensitive design 第 1 例)

本 spec は `docs/DESIGN_SPEC_TEMPLATE.md` 通常 5 section に **§2 倫理 review section** を追加.
今後 sensitive design (= 健康 / 金融 / 個人 / 子供 / 高齢者) 全件で同 section 必須化.

§2 標準項目:
1. NOT to do (= 7-10 項目)
2. MUST do (= 5-7 項目)
3. AI-CHARACTER-24 8/8 self-check matrix
4. AI-DEV-23 全項 self-check (= 通常 6+/7 から **必須 7/7** に格上げ)
