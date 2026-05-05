# Win Claude 設計 spec — 標準 template (= 6 spec 抽出 / part 143-145)

> **status**: meta-spec / Win版#132 part 146 / 2026-05-05
> **issue**: 内部 docs (= Win Claude territory / NotebookLM 蓄積候補)
> **scope**: 設計 spec を量産する際の共通 template + 適用条件 + 9 原則 alignment 早見表
> **derived from**: SIX_DEPT_KPI_PERSISTENCE_SPEC + ONE_IN_TWO_OUT_SPEC + MAINTENANCE_SOP_SPEC + TERM_TOOLTIP_SPEC + NARRATIVE_UI_ACTION_SPEC + DEV_ENV_SETUP_GUIDE

## 1. なぜ template 化

part 143-145 で 6 spec ship したが、各 section 構成は同型. 7 件目以降 (= part 147+ 推定 +5 件)
を効率化 + 9 原則チェック漏れ防止のため **5 section + alignment matrix** を標準化する.

## 2. 適用判断 (= Win Claude territory か)

5-question matrix で **YES 1 つ以上 = Win Claude territory** (= 設計 spec ship 候補):

1. Q1 設計 / architect / schema 設計が中核か
2. Q2 docs / SOP / runbook が主成果物か
3. Q3 UI design / mockup / widget catalog 化 を含むか
4. Q4 triage / 競合 / AI 大学 / mobile UAT / 動画 task か
5. Q5 部署横断 / 9 原則 cross-check / 抽象化レビューが必要か

→ 全 NO = Win Codex hand off (= cross-instance-pr 経由).

## 3. Spec 標準 5 section (= 全 6 spec で共通)

### Section 1: 思想

- 1-3 段落で **「なぜ作るか」**
- 関連 PHILOSOPHY-22 / IMBUE-25 / AI-CHARACTER-24 原則を 1-2 個 inline 引用
- 既存 hack の root cause を明記

### Section 2: 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| {{infra-1}} | 整備済 / 部分整備 / 未整備 | §3 で {{action}} |

= 「ゼロから作るのか/既存拡張なのか」を冒頭で明示.

### Section 3: Schema / UI 設計

サブセクション:
- §3.1 中核 table / enum / type definition (= TypeScript or SQL)
- §3.2 関連 table / payload schema
- §3.3 RLS policy / 安全弁
- §3.4 (= UI spec の場合) widget 階層 + style + interaction

### Section 4: Win Codex hand off scope

- [ ] checkbox list で **実装ファイル全件** 列挙
- 各ファイルに `(= §X.Y)` 参照
- EF 数 +N (= [EF-CAP-50] 適合性明記)
- 推定工数 (= 1.5-12h レンジ)

### Section 5: 9 原則 alignment + 受入条件 mapping

#### 5.1 適用原則 matrix (= spec ごと適用 axis 決定)

| spec 種別 | 必須 axis | 推奨 axis |
|---|---|---|
| 永続化 / KPI | PHILOSOPHY-22 + AI-DEV-23 | BRAIN-32 |
| UI 整理 / 表現 | PHILOSOPHY-22 + IMBUE-25 | AI-CHARACTER-24 |
| ops / SOP / runbook | PHILOSOPHY-22 + AI-DEV-23 | OPS-28 |
| AI tool schema | PHILOSOPHY-22 + AI-CHARACTER-24 + IMBUE-25 | AI-DEV-23 |
| dev env / docs | PHILOSOPHY-22 + INDIE-29 | SYNERGY-30 |
| sensitive (= 健康/金融/個人) | + AI-CHARACTER-24 #6 倫理 gate **必須** + AI-DEV-23 全項 | (倫理 review section 追加) |

#### 5.2 受入条件 mapping table

| 受入条件 | 対応 section |
|---|---|
| #1 ... | §X.Y |
| #2 ... | §X.Y |
| #3 ... | §X.Y |

= GitHub Issue 受入 #1-#N が必ず spec section に対応する self-check.

## 4. 適用済 6 spec の axis 早見表

| spec | Q1 | Q2 | Q3 | Q4 | Q5 | 主 axis | 工数 |
|---|---|---|---|---|---|---|---:|
| SIX_DEPT_KPI | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + AI-DEV + BRAIN | 12h |
| ONE_IN_TWO_OUT | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + IMBUE + AI-CHARACTER | 11.5h |
| MAINTENANCE_SOP | ❌ | ✅ | ❌ | ❌ | ✅ | PHILOSOPHY + AI-DEV + OPS | 6h |
| TERM_TOOLTIP | ✅ | ❌ | ✅ | ❌ | ❌ | PHILOSOPHY + IMBUE | 8h |
| NARRATIVE_UI_ACTION | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + AI-CHARACTER + IMBUE | 9h |
| DEV_ENV_SETUP | ❌ | ✅ | ❌ | ❌ | ❌ | PHILOSOPHY + INDIE | 5h |
| **平均工数** | | | | | | | **8.6h** |

= 1 spec ≈ 1 営業日 (= 8h) Codex 工数 / Win Claude 起票工数 ≈ 30-60 min (= 7-15x leverage).

## 5. 起票 ritual (= Win Claude 起票時 8 step)

1. **Issue body read** — 受入条件 #1-#N 抽出
2. **5-question matrix** — Win Claude territory 判定
3. **既存 infra grep** — `Glob docs/**/*.md` + `Grep schema/EF` で reuse 確認
4. **思想 1-3 段落** — root cause + 原則引用
5. **Section 3 設計** — schema / UI / payload を full code block で
6. **Section 4 hand off scope** — checkbox + EF cap + 工数
7. **Section 5 alignment** — §4 適用原則 matrix で必須 axis 決定 + 受入 mapping
8. **commit + PR + ROADMAP-LOG entry**

= 全 step 1 session 内完結 (= part 143-145 で実証 / 1 spec 30-60 min).

## 6. 失敗パターン (= 避けるべき)

| pattern | 症状 | 対策 |
|---|---|---|
| section 順入れ替え | 思想 → hand off → schema | §3 必ず schema/UI / §4 必ず hand off |
| 9 原則欠落 | alignment section なし | §5.1 axis matrix で **必須** axis 強制 |
| 受入 mapping 抜け | #2 が spec 内で未対応 | §5.2 self-check / commit 前 grep |
| 工数欠落 | 「TBD」「未定」 | §4 必ず推定 (= 1.5-12h レンジ) |
| EF 数明記なし | [EF-CAP-50] 違反 risk | §4 必ず「EF 数 +N」明記 |

## 7. 横展開計画

- 本 template を NotebookLM `jibun-master-brain` 蓄積 (= part 146)
- part 147+ 新 spec ship 時 §4 早見表更新 + 平均工数追跡
- 10 spec 突破時 (= 推定 part 150 頃) **DESIGN_SPEC_PATTERNS.md** へ統合 (= 設計 patterns 体系化)

## 8. PHILOSOPHY-22 / BRAIN-32 alignment

### PHILOSOPHY-22

- ✅ #2 ミッション — 設計の質を量産で守る
- ✅ #4 6 部署 — Win Claude territory = architect 部署の効率化
- ✅ #5 商品=価値 — spec が多ければ多いほど資産
- ✅ #7 資産負債 — template = 永続資産

### BRAIN-32

- ✅ #1 Atomic Note — 各 spec が独立 Atomic Note
- ✅ #3 横断検索 — wiki_compile.py で `docs/concepts/` 自動取込
- ✅ #5 メンテナンス — §4 早見表で老化検知
- ✅ #7 PKM 永続化 — NotebookLM 蓄積
