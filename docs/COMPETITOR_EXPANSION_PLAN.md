# 競合 21→190 社化 拡張計画

**策定**: 2026-04-25 (Win版#132 part 10)
**契機**: ユーザー要請「AI大学のコンテンツ数と同数程度には増やしたい」
**現状**: 21 社 (hard-coded `comparison_page.dart` const map)
**目標**: 190 社 (DB ベース / scheduled task で自動拡張)

---

## 1. 現状アーキテクチャ vs 目標 (AI大学方式)

### 現状: 競合 21 社 (拡張困難)

| 要素 | 場所 | 拡張コスト |
|------|------|-----------|
| 競合定義 | `lib/pages/comparison_page.dart` の `_CompetitorInfo` const map | **〜50 行/社** Dart 編集 |
| 比較表データ | 同 file の hard-coded list | 全件再ビルド必要 |
| `growth_plans` labels | `seed_growth_plans_21competitors.sql` | UNIQUE (label) で upsert OK |
| URL 可用性 | `competitor_monitoring` テーブル | Edge Function 経由で自動 |
| 機能パリティ | `competitor_feature_status` テーブル | 自動更新可 |

**問題**: Dart hard-coded がボトルネック。190 社 = ~9500 行追加。

### 目標: AI大学方式 (随時拡張可能)

| 要素 | 場所 | 拡張コスト |
|------|------|-----------|
| 競合定義 | `competitors` テーブル (新設) | 1 row/社 = SQL upsert |
| 比較表データ | `competitor_features` テーブル (新設) | row 追加だけ |
| Flutter UI | Supabase fetch | 増減自動反映 |
| 自動更新 | scheduled task (`competitor-discovery.yml`) | 週次 trending 検出 |

→ **Phase 1 (DB 化) が完了すれば、Phase 2 以降は AI 大学パターンと完全一致**。

---

## 2. 3-Phase 実装計画

### Phase 1: DB 化リファクタ (最優先 / Win 担当 / 1-2 session)

#### 1-1. `competitors` テーブル schema

```sql
CREATE TABLE public.competitors (
  id            text PRIMARY KEY,            -- 'notion', 'evernote', etc
  display_name  text NOT NULL,               -- 'Notion', 'Evernote'
  category      text NOT NULL,               -- 'productivity' / 'fintech' / 'chat' / 'ai-coding' / etc
  website       text,                        -- 'https://www.notion.so/'
  description   text,                        -- 短いタグライン
  logo_url      text,                        -- アイコン URL
  market_cap    bigint,                      -- 推定 market cap (USD)
  user_count    bigint,                      -- 推定 user count
  founded_year  int,                         -- 設立年
  hq_location   text,                        -- 'San Francisco, CA'
  features      jsonb DEFAULT '{}'::jsonb,   -- 機能リスト (key: 機能名 / value: notes)
  jp_strength   text,                        -- 日本市場での強み (free text)
  jp_weakness   text,                        -- 日本市場での弱み
  is_active     boolean DEFAULT true,        -- ranking 表示する/しない
  sort_order    int DEFAULT 100,             -- 表示順
  added_at      timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

CREATE INDEX idx_competitors_category ON public.competitors (category);
CREATE INDEX idx_competitors_active_sort ON public.competitors (is_active, sort_order);
```

#### 1-2. `competitor_features` テーブル (機能パリティ管理)

```sql
CREATE TABLE public.competitor_features (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_id   text REFERENCES public.competitors(id) ON DELETE CASCADE,
  feature_key     text NOT NULL,             -- 'note-taking' / 'voice-input' / etc
  feature_name_ja text NOT NULL,             -- 'ノート作成'
  has_feature     boolean DEFAULT false,     -- 競合が持っているか
  jibun_status    text DEFAULT 'notYet',     -- 'done' / 'inProgress' / 'planned' / 'notYet'
  notes           text,                      -- 補足
  updated_at      timestamptz DEFAULT now(),
  UNIQUE (competitor_id, feature_key)
);
```

#### 1-3. 21 社 seed migration (Phase 1 で同時 commit)

既存 `comparison_page.dart` から抽出して `INSERT ... ON CONFLICT DO UPDATE` で 21 行投入。
本 Win#132 part 10 で **schema + 21 seed** 両方含む single migration を発行。

#### 1-4. Flutter UI 移行 (別 session / VSCode 担当)

`comparison_page.dart` を const map → Supabase fetch + cache に refactor。
500+ 行変更 = `cross-instance-pr` で VSCode 版に handoff。

---

### Phase 2: 段階拡張 (PS#4 担当 / 月次 / 21 → 100)

#### 2-1. カテゴリ別追加リスト

| カテゴリ | 既存 | 追加候補 (例) | 目標 |
|---------|------|-------------|------|
| Productivity | notion, evernote | obsidian, roam, reflect, mem.ai, craft, anytype | 15 社 |
| Fintech | moneyforward | freee, yayoi, quickbooks, mint, ynab, monarch | 10 社 |
| Chat / SNS | slack, chatwork, discord, line, x, facebook | teams, telegram, signal, whatsapp, threads, bluesky | 15 社 |
| AI Coding | claude-code, codex, openclaw, claude-cowork | cursor, windsurf, replit, lovable, bolt-new, v0, copilot | 12 社 |
| Cloud Office | google, microsoft, amazon, github | zoho, dropbox, atlassian, basecamp | 10 社 |
| HR / Attendance | jobcan | smarthr, kingoftime, freee-hr, oboist | 8 社 |
| Specialty | netkeiba, animaworks, liven | (ニッチ競合は適宜) | 5-10 社 |

→ **合計目標: 75-80 社** (Phase 2 完了時)

#### 2-2. 追加プロセス

1. **PS#4** (競合モニタリング担当) が NotebookLM Deep Research で各社調査
2. seed migration `seed_<id>_competitor.sql` 作成 (1 PR per 競合 or batch)
3. AI 大学 と同様のテンプレ:
   ```sql
   INSERT INTO public.competitors (id, display_name, category, website, description, market_cap, ...)
   VALUES ('cursor', 'Cursor', 'ai-coding', 'https://cursor.com/', 'AI-native code editor by Anysphere', ...)
   ON CONFLICT (id) DO UPDATE SET ...;
   ```
4. 同 PR で `competitor_features` も主要機能 5-10 個 seed

---

### Phase 3: 自動 discovery (scheduled task)

#### 3-1. `competitor-discovery.yml` (週次)

```yaml
name: Competitor Discovery (週次自動候補発掘)
on:
  schedule:
    - cron: "0 23 * * 0"  # 毎週月曜 08:00 JST
  workflow_dispatch:

jobs:
  discover:
    steps:
      - name: Discover trending competitors
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
        run: |
          # カテゴリ別に Gemini Flash + Web Search で trending 競合発掘
          for CATEGORY in productivity fintech ai-coding chat; do
            # Gemini に「過去 1 週間で話題の <category> 領域の新興 SaaS / app を 5 社」と質問
            # 既存 competitors テーブルと突合 → 未登録のみ
            # competitor_candidates テーブルに stage (人間 review 待ち)
          done

      - name: Stage candidates
        run: |
          # competitor_candidates テーブルに INSERT
          # PS#4 が次回セッションで review → 正式登録 or reject
```

#### 3-2. `competitor_candidates` テーブル

```sql
CREATE TABLE public.competitor_candidates (
  id              text PRIMARY KEY,
  display_name    text NOT NULL,
  category        text,
  website         text,
  description     text,
  source          text,                      -- 'gemini-discovery' / 'manual-add' / etc
  ai_score        numeric,                   -- 0-1 自動評価 (重要度)
  reviewed        boolean DEFAULT false,
  promoted        boolean DEFAULT false,     -- competitors に promote 済か
  rejected_reason text,
  staged_at       timestamptz DEFAULT now(),
  reviewed_at     timestamptz
);
```

#### 3-3. Promotion フロー

```
週次 discovery → competitor_candidates ステージ
       ↓
PS#4 セッションで review (NotebookLM Deep Research で深掘り)
       ↓
採用なら → seed_<id>_competitor.sql migration → competitors INSERT
拒否なら → rejected_reason 記入 + reviewed=true
```

人間 (CEO 感原則) の最終決裁を必ず通すこと = Philosophy 原則 1 遵守。

---

## 3. 既存自動化との統合

### 3-1. `competitor-monitoring.yml` (既存・PS#4 daily intelligence)

現在 21 社固定 → `competitors` テーブル fetch に変更:
```bash
# 既存
COMPETITORS="notion evernote moneyforward ..."

# 新方式
COMPETITORS=$(curl -sf "$SUPABASE_URL/rest/v1/competitors?select=id&is_active=eq.true" | jq -r '.[].id')
```

これだけで自動的に 190 社対応。

### 3-2. `check-competitor-updates` EF (URL 可用性)

`competitor_monitoring` テーブルは既に dynamic (competitor_name 自由)。
fetch list を `competitors` テーブルから引くだけ。

### 3-3. `competitor_feature_status` (既存) と `competitor_features` (Phase 1-2 新設) の関係

- 既存: 自分株式会社 ↔ 競合 1 対 1 の機能パリティ tracking
- 新設: 競合自身の機能リスト (機能の有無)

両者は **独立**。新設は「競合分析データ」/ 既存は「自分の進捗管理」。

---

## 4. KPI

| Phase | 競合数 | 期日 |
|-------|--------|------|
| 現状 | 21 | 2026-04-25 |
| Phase 1 完了 (DB 化) | 21 | 2026-05-01 |
| Phase 2 (50 社) | 50 | 2026-06-30 |
| Phase 2 (100 社) | 100 | 2026-09-30 |
| Phase 3 (190 社) | 190 | 2027-03-31 |

---

## 5. リスク + 緩和策

| リスク | 緩和 |
|--------|------|
| **UI overload**: 190 社一覧 = 検索/フィルタ無し UI 不可 | Phase 1 と同時に検索 + カテゴリ tab 実装 |
| **DB cost**: 190 行 + features = 〜2K rows | 軽微 (Supabase Free Tier 余裕) |
| **品質低下**: Trending 自動追加で低品質競合混入 | candidates table + 人間 review gate |
| **monitoring cost**: 190 URL × daily check = 5,700 req/月 | 既存 EF (curl) で問題無し / rate limit 配慮 |
| **PS#4 工数**: 月次で 10-20 社 review = 多い | Phase 3 で AI score でソート → 高スコアのみ |

---

## 6. Philosophy Alignment (9/9 ✅)

1. **CEO 感**: ✅ 自動 discovery でも人間 review gate 必須
2. **ミッション駆動**: ✅ 競合分析 = ミッション「ライフ統合」の根拠
3. **優しい mentor**: ✅ ユーザーが見たい競合だけ表示 (favorite filter)
4. **6 部署バランス**: ✅ 競合監視 = 営業/マーケ部署の核
5. **商品=ユーザー価値**: ⚠️ 190 社が user 価値か再考必要 → カテゴリ filter で「主要 5-10 社」default 表示
6. **資本=時間**: ✅ 自動化で時間節約
7. **資産負債 BS**: ✅ row 増加 microbe (Free Tier 範囲)
8. **KPI=昨日の自分**: ✅ 月次で増分 KPI 計測
9. **ゴール=IPO**: ✅ 競合分析厚み = IPO 時の市場規模 PR 強化

---

## 7. AI-DEV 7 原則 (新 GHA 設計時)

### `competitor-discovery.yml` 設計
1. **Auth**: ✅ GHA secret (GEMINI_API_KEY)
2. **Deny-by-default**: ✅ secret 未設定で skip
3. **trace_id**: 検討 (run_id を candidate row に記録)
4. **Cost circuit breaker**: ✅ Gemini Free Tier (RPM 15) 内
5. **Team memory**: ✅ candidates テーブル
6. **Checkpoint+retry**: ✅ failed candidates は次週 retry
7. **Quality gate**: ✅ 人間 review gate (promoted=true まで未公開)

→ **7/7 ✅** (実装時)

---

## 8. 関連 commit (順次更新)

- **Win#132 part 10 (TBD)**: Phase 1 schema migration + 21 社 seed (本 commit)
- 後続: Flutter UI fetch refactor (VSCode 版 cross-instance-pr)
- 後続: PS#4 月次拡張 (50 → 100 → 190)
- 後続: `competitor-discovery.yml` (Phase 3)

---

## 9. 改訂履歴

- **2026-04-25 (Win版#132 part 10)**: 初版作成。ユーザー要請「AI大学並み 190 社化」を受けて 3-Phase 設計策定。
