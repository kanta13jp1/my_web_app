# Win Claude 設計 spec — 起票 template (= operator-facing / 1 spec ritual + 早見表)

> **status**: meta-spec / Win版#132 part 155 / 2026-05-05 / **第 5 改訂** (= 13 spec / sensitive 6 領域 / multi-trigger + 統合 spec 第 1 例反映)
> **issue**: 内部 docs (= Win Claude territory / NotebookLM 蓄積)
> **scope**: 設計 spec を **1 件起票する際の operator ritual + axis 早見表**
> **抽象 layer**: pattern + 共通項 + 異領域比較は [`docs/DESIGN_SPEC_PATTERNS.md`](DESIGN_SPEC_PATTERNS.md) (= designer-facing / 第 6 改訂) を参照
> **derived from**: 通常 7 spec + sensitive 6 spec (= part 143-155)

## 1. 2 doc 体制 (= part 153 で分離)

- 本 doc (= TEMPLATE) — **operator** (= 起票者) 用 / 8 step ritual + 11 spec axis 早見表
- [`DESIGN_SPEC_PATTERNS.md`](DESIGN_SPEC_PATTERNS.md) — **designer** (= 抽象 reviewer) 用 / 6 pattern + 異領域共通項 + 階層化 PR workflow

役割重複解消のため、本 doc では pattern 詳細を割愛 / PATTERNS.md へ link.

## 2. 適用判断 (= Win Claude territory か / 5-question matrix)

5 質問で **YES 1 つ以上 = Win Claude territory** (= 設計 spec ship 候補):

| Q# | 質問 |
|---|---|
| Q1 | 設計 / architect / schema 設計が中核か |
| Q2 | docs / SOP / runbook が主成果物か |
| Q3 | UI design / mockup / widget catalog 化を含むか |
| Q4 | triage / 競合 / AI 大学 / mobile UAT / 動画 task か |
| Q5 | 部署横断 / 9 原則 cross-check / 抽象化 review が必要か |

→ 全 NO = Win Codex hand off (= cross-instance-pr 経由).
→ 詳細 (= 失敗 pattern + 11 spec validation): [`PATTERNS.md` Ch1](DESIGN_SPEC_PATTERNS.md#chapter-1-win-claude-vs-win-codex-territory-判定--5-question-matrix).

## 3. Spec 標準 5 section (= 通常 / 全 11 spec で共通)

```
§1 思想              (= 1-3 段落 / root cause + PHILOSOPHY-22 等引用)
§2 既存基盤確認      (= infra 3 段階 status table / Ch4 = PATTERNS.md Ch4 参照)
§3 設計              (= schema / UI / payload / SOP の full code block)
§4 受入条件 mapping  (= Issue 受入 #1-#N → §X.Y)
§5 Win Codex hand off (= checkbox + EF 数 + 工数)
```

(= sensitive design は §1 と §2 の間に **§2. 倫理 review** 挿入 / [PATTERNS.md Ch3](DESIGN_SPEC_PATTERNS.md#chapter-3-sensitive-design-§2-倫理-review-section--4-領域--共通-44) 参照)

各 section MUST do / NG: [`PATTERNS.md` Ch2](DESIGN_SPEC_PATTERNS.md#chapter-2-通常-spec-5-section-標準--11-spec-共通骨格).

## 4. 適用済 13 spec の axis 早見表 (= empirical baseline / part 143-155)

| spec | Q1 | Q2 | Q3 | Q4 | Q5 | 主 axis | 工数 | 種別 |
|---|---|---|---|---|---|---|---:|---|
| SIX_DEPT_KPI | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + AI-DEV + BRAIN | 12h | 通常 |
| ONE_IN_TWO_OUT | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + IMBUE + AI-CHARACTER | 11.5h | 通常 |
| MAINTENANCE_SOP | ❌ | ✅ | ❌ | ❌ | ✅ | PHILOSOPHY + AI-DEV + OPS | 6h | 通常 |
| TERM_TOOLTIP | ✅ | ❌ | ✅ | ❌ | ❌ | PHILOSOPHY + IMBUE | 8h | 通常 |
| NARRATIVE_UI_ACTION | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + AI-CHARACTER + IMBUE | 9h | 通常 |
| DEV_ENV_SETUP | ❌ | ✅ | ❌ | ❌ | ❌ | PHILOSOPHY + INDIE | 5h | 通常 |
| PRECOMPACT_MEMORY_BACKUP | ✅ | ✅ | ❌ | ❌ | ✅ | PHILOSOPHY + AI-DEV + BRAIN + INDIE + SYNERGY | 8h | 通常 (= 既存拡張 第 1) |
| MENTAL_HEALTH_RISK | ✅ | ❌ | ✅ | ❌ | ✅ | + AI-CHARACTER 8/8 + AI-DEV 7/7 + IMBUE | 11h | **sensitive 第 1** (単独) |
| AI_DESPERATION_DETECTION | ✅ | ✅ | ❌ | ❌ | ✅ | + AI-CHARACTER 8/8 + AI-DEV 7/7 + COLLAB | 9h | **sensitive 第 2** (単独) |
| ROBUST_AI_PERSONA | ✅ | ✅ | ❌ | ❌ | ✅ | + AI-CHARACTER 8/8 + AI-DEV 7/7 + VIBE | 14h | **sensitive 第 3** (単独) |
| MCP_AUTH_HARDENING | ✅ | ✅ | ❌ | ❌ | ✅ | + **MCP-AUTH 10/10** + AI-DEV 7/7 + AI-CHARACTER 8/8 + VIBE + SYNERGY | 14h | **sensitive 第 4** (単独) |
| PII_GUARDRAIL | ✅ | ✅ | ❌ | ❌ | ✅ | + AI-CHARACTER 8/8 + AI-DEV 7/7 + MCP-AUTH cross-link | 14h | **sensitive 第 5** (二重: 個人+security) |
| **VIBE_SANDBOX** | ✅ | ✅ | ✅ | ❌ | ✅ | + AI-CHARACTER 8/8 + AI-DEV 7/7 + **VIBE 7/7** + MCP-AUTH + PII cross-link | 14h | **sensitive 第 6** (三重: 個人+AI生成+security / 統合 spec 第 1) |
| AI_LIFE_RESET_PLANNER | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + AI-DEV 7/7 + IMBUE 7/7 + COLLAB | 8h | 通常 (= 既存 hub action 拡張) |
| RAG_KNOWLEDGE_GRAPH | ✅ | ✅ | ✅ | ❌ | ✅ | **PHILOSOPHY 9/9** + AI-DEV 7/7 + IMBUE 7/7 + PII cross-link | 10h | 通常 (= sensitive 境界 / PII cross-link 第 1 例) |
| **平均工数** | | | | | | | **10.1h** | (= 通常 8.7h / sensitive 単独 12.0h / 二重 14h / 三重 14h) |

= 1 spec ≈ 1 営業日 (= 5-14h Codex 工数) / Win Claude 起票工数 ≈ 30-60 min (= 7-28x leverage / 統合 spec で reviewer 効率 2x 上乗せ).
= 詳細 KPI: [`PATTERNS.md` Ch6](DESIGN_SPEC_PATTERNS.md#chapter-6-13-spec-工数-kpi--empirical-baseline--第-6-改訂).

## 5. 適用原則 matrix (= spec 種別ごと適用 axis 決定)

| spec 種別 | 必須 axis | 推奨 axis |
|---|---|---|
| 永続化 / KPI | PHILOSOPHY-22 + AI-DEV-23 | BRAIN-32 |
| UI 整理 / 表現 | PHILOSOPHY-22 + IMBUE-25 | AI-CHARACTER-24 |
| ops / SOP / runbook | PHILOSOPHY-22 + AI-DEV-23 | OPS-28 |
| AI tool schema | PHILOSOPHY-22 + AI-CHARACTER-24 + IMBUE-25 | AI-DEV-23 |
| dev env / docs | PHILOSOPHY-22 + INDIE-29 | SYNERGY-30 |
| **sensitive 単独 trigger** (= 健康 / 金融 / 個人 / AI 内部状態 / persona / security) | + **AI-CHARACTER-24 8/8 必須** + **AI-DEV-23 7/7 必須** | + **§2 倫理 review section 必須** |
| **sensitive 二重 trigger** (= 第 5 例 PII / 個人+security 等) | 上記 + **cross-link spec 1 件必須** | + redact 透明性 + double-gate |
| **sensitive 三重 trigger** (= 第 6 例 SANDBOX / 個人+AI生成+security 等 / 過去最多) | 上記 + **VIBE-30 7/7 必須** + **cross-link spec 2 件必須** + **4-eyes principle** + **構造的隔離 4 層** | + §7 統合 mapping section (= 統合 spec 時) |
| **AI 生成コンテンツ全般** (= 第 6 例で必須化) | + **VIBE-30 7/7 必須** | + leaf 判定 3 条件 programmatic check |

sensitive 拡張詳細 (= 6 領域共通 NOT to do/MUST do + multi-trigger 直交合成): [`PATTERNS.md` Ch3](DESIGN_SPEC_PATTERNS.md#chapter-3-sensitive-design-§2-倫理-review-section--6-領域--共通-44--multi-trigger).

## 6. 起票 ritual (= Win Claude 起票時 8 step)

```
1. Issue body read         — 受入条件 #1-#N 抽出
2. 5-question matrix       — Win Claude territory 判定 (= §2)
3. 既存 infra grep         — Glob docs/**/*.md + Grep schema/EF で reuse 確認
                            (= 3 段階分類 / PATTERNS.md Ch4)
4. 思想 1-3 段落           — root cause + 原則引用 (= §3 §1)
5. Section 3 設計          — schema / UI / payload を full code block
6. Section 4-5 mapping+hand off — checkbox + EF cap + 工数 (= §3 §4 §5)
7. 9 原則 alignment        — §5 適用原則 matrix で必須 axis 決定
8. commit + PR + ROADMAP-LOG entry
```

= 全 step 1 session 内完結 (= 1 spec 30-60 min).

並行 ship (= 1 session 2+ spec) は **PR 階層化** で: [`PATTERNS.md` Ch5](DESIGN_SPEC_PATTERNS.md#chapter-5-pr-階層化-spec-ship-workflow--並行-ship-pattern-第-2-例).

## 7. 失敗パターン早見

| pattern | 症状 | 対策 |
|---|---|---|
| section 順入れ替え | 思想 → hand off → schema | §3 必ず schema/UI / §5 必ず hand off |
| 9 原則欠落 | alignment section なし | §5 axis matrix で **必須** axis 強制 |
| 受入 mapping 抜け | #N が spec 内で未対応 | §4 self-check / commit 前 grep |
| 工数欠落 | 「TBD」「未定」 | §5 必ず推定 (= 1.5-14h レンジ) |
| EF 数明記なし | [EF-CAP-50] 違反 risk | §5 必ず「EF 数 +N」明記 |
| sensitive で §2 倫理 review 欠落 | AI-CHARACTER-24 #6 倫理 gate 違反 | sensitive 7 trigger 1 つでも該当 → §2 必須 |
| `--base main` で階層化 PR | 直前 PR diff も含む leak | `--base claude/<prev-head>` 必須 |
| Q5 自動 ✅ 化 | あらゆる spec が Win Claude 流入 | Q5 = **9 原則 cross-check が中核成果物** に限定 |

詳細 anti-pattern: [`PATTERNS.md` Ch7.2](DESIGN_SPEC_PATTERNS.md#chapter-7-pattern-横展開--第-6-改訂候補).

## 8. 横展開計画

- 本 template + PATTERNS.md を NotebookLM `jibun-master-brain` 蓄積
- part 154+ 新 spec ship 時 §4 早見表更新 + 平均工数追跡
- 12+ spec 突破で第 6 改訂 trigger (= [PATTERNS.md Ch7.2](DESIGN_SPEC_PATTERNS.md#chapter-7-pattern-横展開--第-6-改訂候補) 参照)

## 9. PHILOSOPHY-22 / BRAIN-32 alignment

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
