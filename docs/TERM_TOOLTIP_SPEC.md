# Inline Term Tooltip — 専門用語ハイライト+解説 spec (#1348 / part 144)

> **status**: 設計 spec / Win版#132 part 144 / 2026-05-05
> **issue**: [#1348](https://github.com/kanta13jp1/my_web_app/issues/1348) [追加要望] 専門用語・関連法令のインライン解説ツールチップの追加
> **scope**: 設計のみ (Win Claude territory / UI design + spec) / 実装は Win Codex (= migration + Flutter widget) ハンドオフ
> **NotebookLM source**: `7e72ced1` 衆議院憲法審査会：憲法改正の論点と起草への進路
> **PHILOSOPHY-22 alignment**: #5 (商品=価値 — 教育価値) + #6 (時間最適化 — 認知負荷削減) / **IMBUE-25** #2 (認知負荷削減) + #4 (mentor 感)

## 1. 思想

「広範性要件」「参議院の緊急集会」「国家緊急権」 — 一般読者には文字が滑る専門用語. これを
**読み流さず即理解** に変える tooltip = mentor 感 (= IMBUE #4) の自走化.
辞書負荷ゼロで読解力の段差を埋める = PHILOSOPHY #6 「時間最適化」の体現.

## 2. 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| 専門用語辞書 table | **未整備** | §3 で新設 |
| 文字起こし表示 widget | 整備済 (= [transcript_view.dart](lib/widgets/transcript_view.dart) 想定) | §4 で TermTooltipText wrapper 追加 |
| RichText / TextSpan | Flutter 標準 | §4 で活用 |
| tooltip 表示 widget | 部分 (= MaterialTooltip) | §4 でモバイル tap 対応 custom widget |

## 3. Schema 設計 (= Win Codex 担当 / 1 migration)

### 3.1 中核 table

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_glossary_terms.sql

CREATE TABLE public.glossary_terms (
  id bigserial PRIMARY KEY,
  term text NOT NULL,                          -- '広範性要件' (検索 key)
  term_normalized text NOT NULL,               -- 'こうはんせいようけん' (search 拡張用)
  category text NOT NULL                       -- 'constitutional' / 'legal' / 'medical' / 'tech'
    CHECK (category IN ('constitutional','legal','medical','tech','political','other')),
  definition_short text NOT NULL,              -- tooltip 1 行 (= 80 字目安)
  definition_long text,                        -- 詳細 modal 用 (= 任意 / 数百字)
  related_terms text[] DEFAULT '{}',           -- 関連語 (= 「国家緊急権」→ 「緊急政令」)
  reference_url text,                          -- 出典 (= e-Gov / 国会会議録)
  source_notebook_id text,                     -- NotebookLM ID (= seed 元)
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (term, category)
);

CREATE INDEX glossary_term_active ON public.glossary_terms (term) WHERE is_active = true;
CREATE INDEX glossary_term_normalized ON public.glossary_terms (term_normalized) WHERE is_active = true;
CREATE INDEX glossary_category ON public.glossary_terms (category, is_active);

ALTER TABLE public.glossary_terms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "glossary_read_anon" ON public.glossary_terms
  FOR SELECT USING (is_active = true);

CREATE POLICY "glossary_write_admin" ON public.glossary_terms
  FOR ALL USING (auth.role() = 'service_role');
```

### 3.2 用語クリック log (= 任意 / 学習 source)

```sql
CREATE TABLE public.glossary_term_views (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  term_id bigint NOT NULL REFERENCES public.glossary_terms(id) ON DELETE CASCADE,
  context_route text,                          -- '/transcript/123'
  viewed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX glossary_view_term_time ON public.glossary_term_views (term_id, viewed_at DESC);
```

= 何度も見られる用語 = top N で「重要用語学習リスト」auto-curate (= 将来拡張 / part 144 scope 外).

## 4. UI 設計 (= Win Codex 実装 / Win Claude design ガイド)

### 4.1 widget 階層

```
TranscriptView (existing)
  └─ TermHighlightedText (NEW / Win Codex impl)
       └─ RichText
            └─ List<TextSpan>
                 ├─ plain TextSpan (非専門用語)
                 └─ HighlightedTermSpan (NEW / TapGestureRecognizer + hover)
                      └─ on tap → showTermTooltip(BuildContext, GlossaryTerm)
```

### 4.2 ハイライト style (受入 #1)

| 要素 | spec |
|---|---|
| underline | dashed / 1.5px / colorScheme.primary.withOpacity(0.6) |
| 文字色 | colorScheme.onSurface (= 通常色維持 / 過剰強調回避) |
| hover (Web) | background colorScheme.primary.withOpacity(0.08) |
| tap feedback | InkWell ripple |

### 4.3 tooltip 表示 (受入 #2 / #3)

```
desktop (= mouse hover):
  → MaterialTooltip 風 / 上方 / 200ms 遅延 / 自動消失 4s

mobile (= tap):
  → showModalBottomSheet 軽量版 (= heightFactor 0.3)
  → ヘッダー: 用語 + category badge
  → body: definition_short (= 太字) + definition_long (= 任意)
  → "閉じる" + "詳細を見る" (= reference_url launchUrl)
  → 関連語 chip 列 (= tap で再 sheet)
```

= mobile / desktop 共通 widget (= `TermTooltip(term: GlossaryTerm)` Stateless / responsive 分岐内蔵).

### 4.4 マッチング algorithm (受入 #1 / 実装メモ反映)

```
[1] 起動時:
    → glossary_terms (is_active=true) を全件 GET (= 想定 < 1000 行)
    → in-memory cache (= GlossaryService Singleton / 1h TTL)

[2] 表示時 (= TermHighlightedText.build):
    → 入力 text を 1-pass linear scan
    → Aho-Corasick 風 multi-pattern match (= dart `aho_corasick` pkg or 自前 trie)
       OR (簡易版) 用語数 N < 500 なら正規表現 alternation 1 回
    → match 区間を HighlightedTermSpan / 残り plain TextSpan

[3] 重複処理:
    → longest match 優先 (= 「国家緊急権」「緊急権」両登録時 → 「国家緊急権」採用)
    → 同 offset で複数 category match 時 → 先頭 1 つ採用 (= 後続 cache 抑制)
```

### 4.5 performance budget

| metric | budget | 計測 |
|---|---|---|
| 起動時 dictionary fetch | < 300ms (= cold) / < 50ms (= 1h cache) | DevTools network |
| 1 page 1000 字 highlight | < 16ms (= 60fps frame budget 内) | DevTools timeline |
| dict size | < 500 用語 / 100KB | initial release cap |

## 5. 初期辞書 seed (= Win Codex 担当 / 1 seed migration)

NotebookLM `7e72ced1` 由来の頻出 20 用語を seed:

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_seed_glossary_constitutional.sql

INSERT INTO public.glossary_terms (term, term_normalized, category, definition_short, reference_url, source_notebook_id)
VALUES
  ('広範性要件', 'こうはんせいようけん', 'constitutional',
   '緊急事態条項発動の前提となる、影響範囲が広域に及ぶことを示す要件',
   'https://www.shugiin.go.jp/internet/itdb_kenpou.nsf/html/kenpou/index.htm',
   '7e72ced1-67b5-4f47-a3a0-2327236ffbd5'),
  ('参議院の緊急集会', 'さんぎいんのきんきゅうしゅうかい', 'constitutional',
   '衆議院解散中に内閣が国会の議決を要する事態に直面した時、参議院のみで開く臨時会議 (憲法54条2項)',
   'https://elaws.e-gov.go.jp/document?lawid=321CONSTITUTION',
   '7e72ced1-67b5-4f47-a3a0-2327236ffbd5'),
  -- ... (= 残 18 用語 / Win Codex hand off)
  ('国家緊急権', 'こっかきんきゅうけん', 'constitutional',
   '戦争・大規模災害・内乱等の非常時に、通常憲法秩序を一時停止して政府権限を強化する権能',
   'https://www.shugiin.go.jp/internet/itdb_kenpou.nsf/html/kenpou/index.htm',
   '7e72ced1-67b5-4f47-a3a0-2327236ffbd5');
```

= 残 18 用語 list は notebook 本文から Win Codex 抽出 (= claim_task で別 issue 起票も可).

## 6. Win Codex hand off scope

- [ ] `supabase/migrations/<ts>_create_glossary_terms.sql` (= §3.1)
- [ ] `supabase/migrations/<ts>_create_glossary_term_views.sql` (= §3.2 / 任意 / 2 次)
- [ ] `supabase/migrations/<ts>_seed_glossary_constitutional.sql` (= §5 / 20 用語)
- [ ] `lib/services/glossary_service.dart` (= cache + match)
- [ ] `lib/widgets/term_highlighted_text.dart` (= §4.1)
- [ ] `lib/widgets/term_tooltip.dart` (= §4.3 / responsive)
- [ ] `lib/pages/transcript_view.dart` 既存 widget の text 部分を `TermHighlightedText` に差替

EF 数 +0 (= REST 直接 query で十分 / [EF-CAP-50] 完全遵守).
推定工数: 8h (= migration+seed 2h + service 1.5h + widget 3h + integration 1.5h).

## 7. PHILOSOPHY-22 / IMBUE-25 alignment

### PHILOSOPHY-22

- ✅ #2 ミッション — 教育価値で社会貢献
- ✅ #5 商品=価値 — 一次資料アクセス改善
- ✅ #6 時間最適化 — 辞書検索の手間ゼロ化
- ✅ #7 資産負債 — glossary_terms = 知識資産
- ✅ #8 KPI — view log で重要用語 surface

### IMBUE-25

- ✅ #2 認知負荷削減 — 文を読み流さず即理解
- ✅ #4 mentor 感 — wikipedia/e-Gov 風 inline 解説
- ✅ #6 CEO 感 — 自分専用辞書を成長させる感

## 8. 受け入れ条件 mapping

| 受入条件 | 対応 section |
|---|---|
| #1 辞書 base ハイライト | §3.1 (table) + §4.4 (algorithm) + §4.2 (style) |
| #2 hover/tap で tooltip 表示 | §4.3 (desktop hover / mobile sheet) |
| #3 mobile タッチ操作で開閉 | §4.3 (showModalBottomSheet 「閉じる」button) |
