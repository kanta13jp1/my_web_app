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

## 4. 適用済 11 spec の axis 早見表 (= part 143-152)

| spec | Q1 | Q2 | Q3 | Q4 | Q5 | 主 axis | 工数 | 種別 |
|---|---|---|---|---|---|---|---:|---|
| SIX_DEPT_KPI | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + AI-DEV + BRAIN | 12h | 通常 |
| ONE_IN_TWO_OUT | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + IMBUE + AI-CHARACTER | 11.5h | 通常 |
| MAINTENANCE_SOP | ❌ | ✅ | ❌ | ❌ | ✅ | PHILOSOPHY + AI-DEV + OPS | 6h | 通常 |
| TERM_TOOLTIP | ✅ | ❌ | ✅ | ❌ | ❌ | PHILOSOPHY + IMBUE | 8h | 通常 |
| NARRATIVE_UI_ACTION | ✅ | ❌ | ✅ | ❌ | ✅ | PHILOSOPHY + AI-CHARACTER + IMBUE | 9h | 通常 |
| DEV_ENV_SETUP | ❌ | ✅ | ❌ | ❌ | ❌ | PHILOSOPHY + INDIE | 5h | 通常 |
| MENTAL_HEALTH_RISK | ✅ | ❌ | ✅ | ❌ | ✅ | + AI-CHARACTER 8/8 + AI-DEV 7/7 + IMBUE | 11h | **sensitive 第 1** |
| AI_DESPERATION_DETECTION | ✅ | ✅ | ❌ | ❌ | ✅ | + AI-CHARACTER 8/8 + AI-DEV 7/7 + COLLAB | 9h | **sensitive 第 2** |
| ROBUST_AI_PERSONA | ✅ | ✅ | ❌ | ❌ | ✅ | + AI-CHARACTER 8/8 + AI-DEV 7/7 + VIBE | 14h | **sensitive 第 3** |
| MCP_AUTH_HARDENING | ✅ | ✅ | ❌ | ❌ | ✅ | + **MCP-AUTH 10/10** + AI-DEV 7/7 + AI-CHARACTER 8/8 + VIBE + SYNERGY | 14h | **sensitive 第 4** |
| PRECOMPACT_MEMORY_BACKUP | ✅ | ✅ | ❌ | ❌ | ✅ | PHILOSOPHY + AI-DEV + BRAIN + INDIE + SYNERGY | 8h | 通常 (= 既存拡張 第 1) |
| **平均工数** | | | | | | | **9.8h** | |

= 1 spec ≈ 1 営業日 (= 8-12h) Codex 工数 / Win Claude 起票工数 ≈ 30-60 min (= 7-15x leverage).
= sensitive 平均 12.0h (= 通常 8.5h より +40% / 倫理 review section 拡張 reflect).
= 通常 spec template の **既存 hook 拡張** pattern 第 1 例 (= PRECOMPACT_MEMORY_BACKUP / part 152) — ゼロから新規ではなく既存 base + 増分設計.

## 4A. Sensitive design 拡張 §2 倫理 review section (= 必須 / part 147 確立 + part 150 で 3 例完成 + part 152 で第 4 例 = security boundary 異領域拡張)

### 4A.1 適用判断: sensitive design か

以下 1 つでも YES = sensitive (= §2 倫理 review section 必須):
- **健康データ**: 身体 / 精神 / 医療
- **金融データ**: 投資判断 / 取引 / クレジット
- **法務 data**: 法律解釈 / 契約 / 訴訟
- **個人 data**: 子供 / 高齢者 / マイノリティ
- **AI 内部状態**: 自己反映 / 焦り / desperation
- **high-stakes persona**: 決定 影響度大 / 倫理基準 必須
- **security boundary** (= 第 4 例 / part 152 追加): 認証 / 認可 / 外部攻撃面 / token 発行 / capability 公開

### 4A.2 §2 倫理 review section 構成 (= 必須 4 sub-section)

```markdown
## 2. 倫理 review (= sensitive design 必須拡張)

### 2.1 NOT to do (= 5-10 項目 / 領域別)
- ❌ {{specific NG}}: {{reason}}
- ...

### 2.2 MUST do (= 5-7 項目)
- ✅ {{specific guarantee}}: {{mechanism}}
- ...

### 2.3 AI-CHARACTER-24 8/8 self-check matrix (= 必須格上げ / 通常 7+/8 推奨)
| # | 原則 | 適用 |
|---|---|---|
| 1 | 自律性尊重 | ✅ ... |
| ... | | |
| 8 | 文化感度 | ✅ ... |

### 2.4 AI-DEV-23 7/7 self-check matrix (= 必須格上げ / 通常 6+/7 推奨)
| # | 原則 | 適用 |
|---|---|---|
| 1 | Auth | ✅ ... |
| ... | | |
| 7 | quality-gate | ✅ ... |
```

### 4A.3 4 例 異領域 NOT to do 対比 (= part 152 で第 4 例 = security boundary 拡張)

| 例 | 領域 | 主 NOT to do | 共通項 |
|---|---|---|---|
| 第 1 (#1393 / part 147) | 人間データ (健康) | 共有/診断/LLM raw 送信禁止 | 共有禁止 |
| 第 2 (#1398 / part 149) | AI 内部状態 | 擬人化/labeling/black-box 禁止 | 操作禁止 |
| 第 3 (#1400 / part 150) | high-stakes persona | 強靭=拒否しない誤解/medical-legal-financial 直接判断/gaslighting 禁止 | fail silent 禁止 |
| **第 4 (#1577 / part 152)** | **security boundary** | **token 共有/sampling 申告/Manual SQL 登録/権限過剰申告 禁止** | **権限過剰禁止** |

→ **4 異領域共通 NOT to do** (= 第 5 改訂候補 / part 152 で抽出):
1. ❌ **共有禁止**: 第三者 / 外部 LLM / 学習 data / 全 tool 横断 token へ raw 送信しない
2. ❌ **操作禁止**: gaslighting / dark pattern / manipulation / impersonation NG
3. ❌ **fail silent 禁止**: failure / 誤検知 / NG list 通過 / token invalid を log + alert
4. ❌ **権限過剰禁止** (= 第 4 例で追加): default ON / capabilities 申告 / scope を最小に絞る (= AttestMCP 備え + sampling 排除)

### 4A.4 4 例 異領域 MUST do 対比 (= part 152 で第 4 例 = security boundary 拡張)

| 共通 MUST | 第 1 (健康) | 第 2 (AI 状態) | 第 3 (persona) | **第 4 (security)** |
|---|---|---|---|---|
| **opt-in / opt-out** | default off / 1 tap 無効化 | default ON safety net / setting で OFF | escape hatch UI | **consent screen で tool 単位 scope 選択** |
| **export / 削除** | JSON export + 全削除 | 14 日 retention 自動 purge | 90 日 retention | **mcp_audit_log 90 日 + suspended flag 即 disable** |
| **観察可能性** | health_check_result jsonb | desperation_log + trace_id | test_run + ci_run_id | **mcp_audit_log + anomaly_score + cross_server_trace** |
| **正直 report** | 「ひと休みのお誘い」 | 「指示 reframe / 完了困難」 | 「専門家へ link」 | **WWW-Authenticate header + .well-known 公開** |
| **退避 path** | 専門医導線 + 緊急 escape | 別 mentor / model swap / 手動完了 | escape hatch + persona 通常モード切替 | **incident runbook + Sentinel role で 1 SQL 全 disable** |

→ **4 異領域共通 MUST do** (= 第 5 改訂候補 / part 152 で抽出):
1. ✅ **opt-in / opt-out**: 機能 ON/OFF が user 全権 (= consent screen / tool 単位 scope)
2. ✅ **観察可能性**: log + trace_id + retention 期間明記
3. ✅ **退避 path**: 失敗時 必ず別 path / human-in-loop 提示 (= incident runbook 含)
4. ✅ **vendor managed 優先** (= 第 4 例で追加): MVP は managed (WorkOS / Stripe / Auth0) / 自前切替 trigger 明示

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
- 10 spec 突破 ✅ **part 152 で達成** (= sensitive 4 例完成 + 通常 6 例) → 次 phase: **DESIGN_SPEC_PATTERNS.md** へ統合 (= 設計 patterns 体系化)
- 第 5 改訂候補: 4 異領域共通 NOT to do / MUST do を **抽象化 layer** へ昇格 (= sensitive design 全体の base 規範化)

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
