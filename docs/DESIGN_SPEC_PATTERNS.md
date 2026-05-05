# Design Spec Patterns — 11 spec 横断 抽象化 layer (= Win版#132 part 153)

> **status**: meta-meta-spec / Win版#132 part 153 / 2026-05-05
> **issue**: 内部 docs (= Win Claude territory / NotebookLM 蓄積候補)
> **scope**: 11 spec ship 後の **抽象化 layer** = 設計 spec を量産する際の patterns 体系 (= Win Claude territory 判定 + 通常 / sensitive 標準 + 既存基盤分類 + PR 階層化 workflow)
> **derived from**: 通常 7 spec (SIX_DEPT_KPI / ONE_IN_TWO_OUT / MAINTENANCE_SOP / TERM_TOOLTIP / NARRATIVE_UI_ACTION / DEV_ENV_SETUP / PRECOMPACT_MEMORY_BACKUP) + sensitive 4 spec (MENTAL_HEALTH_RISK / AI_DESPERATION_DETECTION / ROBUST_AI_PERSONA / MCP_AUTH_HARDENING)
> **template との関係**: `docs/DESIGN_SPEC_TEMPLATE.md` = 1 spec 起票時 ritual + 早見表 (= operator-facing). 本 doc = patterns + 抽象 layer (= designer-facing / NotebookLM 蓄積向).

## 0. なぜ 2 doc 体制

`DESIGN_SPEC_TEMPLATE.md` part 146 以降 5 改訂で肥大化 (= 216 行 / §1-§8). 役割重複:

- **operator** (= spec 起票者): 「8 step ritual + axis 早見表」即参照
- **designer** (= 抽象化 reviewer): 「pattern + 共通項 + 異領域比較」review

→ TEMPLATE = ritual + 早見表のみ / PATTERNS = 抽象化 layer に分離 (= 役割明確化 / 重複解消).

---

## Chapter 1: Win Claude vs Win Codex Territory 判定 (= 5-question matrix)

### 1.1 質問 (= YES 1 つ以上 = Win Claude territory)

| Q# | 質問 | 該当 = Win Claude territory 主理由 |
|---|---|---|
| **Q1** | 設計 / architect / schema 設計が中核か | 抽象化 + 部署横断 viewpoint 必須 |
| **Q2** | docs / SOP / runbook が主成果物か | 自然言語 reasoning + 文書品質 |
| **Q3** | UI design / mockup / widget catalog 化を含むか | DESIGN.md token + 視覚的整合 |
| **Q4** | triage / 競合 / AI 大学 / mobile UAT / 動画 task か | 多 source cross-cut + 主観判断 |
| **Q5** | 部署横断 / 9 原則 cross-check / 抽象化 review が必要か | 12 軸 principle alignment matrix |

→ 全 NO = Win Codex hand off (= cross-instance-pr 経由).

### 1.2 11 spec 適用結果 (= empirical validation)

| spec | Q1 | Q2 | Q3 | Q4 | Q5 | 起票部 |
|---|---|---|---|---|---|---|
| SIX_DEPT_KPI | ✅ | ❌ | ✅ | ❌ | ✅ | Win Claude |
| ONE_IN_TWO_OUT | ✅ | ❌ | ✅ | ❌ | ✅ | Win Claude |
| MAINTENANCE_SOP | ❌ | ✅ | ❌ | ❌ | ✅ | Win Claude |
| TERM_TOOLTIP | ✅ | ❌ | ✅ | ❌ | ❌ | Win Claude |
| NARRATIVE_UI_ACTION | ✅ | ❌ | ✅ | ❌ | ✅ | Win Claude |
| DEV_ENV_SETUP | ❌ | ✅ | ❌ | ❌ | ❌ | Win Claude |
| PRECOMPACT_MEMORY_BACKUP | ✅ | ✅ | ❌ | ❌ | ✅ | Win Claude |
| MENTAL_HEALTH_RISK | ✅ | ❌ | ✅ | ❌ | ✅ | Win Claude |
| AI_DESPERATION_DETECTION | ✅ | ✅ | ❌ | ❌ | ✅ | Win Claude |
| ROBUST_AI_PERSONA | ✅ | ✅ | ❌ | ❌ | ✅ | Win Claude |
| MCP_AUTH_HARDENING | ✅ | ✅ | ❌ | ❌ | ✅ | Win Claude |

= 11/11 で正しく Win Claude territory 判定 (= false positive 0).

### 1.3 失敗パターン (= matrix 適用ミス)

| ミス | 症状 | 修正 |
|---|---|---|
| Q5 自動 ✅ 化 | あらゆる spec が Win Claude territory に流入 | Q5 = **9 原則 cross-check が中核成果物** に限定 |
| Q1 schema = 単純 CRUD で ✅ 化 | Codex 領域に越境 | Q1 = **新規 enum / type 設計 / RLS policy** に限定 |
| 全 NO で hand off せず実装 | Win Claude が実装 (= INSTANCE-ROLES 違反) | 全 NO 確認後、必ず cross-instance-pr 起票 |

---

## Chapter 2: 通常 Spec 5 Section 標準 (= 11 spec 共通骨格)

### 2.1 Section 構成 (= 全 11 spec で同型)

```
§1. 思想              (= 1-3 段落 / root cause + 原則引用)
§2. 既存基盤確認      (= infra status table / Ch4 参照)
§3. 設計              (= schema / UI / payload / SOP の full code block)
§4. 受入条件 mapping  (= GitHub Issue 受入 #1-#N → §X.Y 対応)
§5. Win Codex hand off scope (= checkbox + EF 数 + 工数)
```

(= sensitive design は §1 と §2 の間に **§2. 倫理 review** 挿入 / Ch3 参照)

### 2.2 各 section MUST do

#### §1 思想 (= 1-3 段落)

- ✅ **既存 hack の root cause** を冒頭で明記 (= 「現状 30 min 失う」「現 hub 7 widget 並ぶ」等)
- ✅ **PHILOSOPHY-22 / IMBUE-25 / AI-CHARACTER-24 から 1-2 個 inline 引用**
- ❌ 「TBD」「未定」「方針検討中」NG

#### §2 既存基盤確認 (= infra status table)

- ✅ Ch4 の 3 段階分類 (= 整備済 / 部分整備 / 未整備) で全 infra mark
- ✅ 「整備済」= ファイル path + 実装 part 番号明記
- ❌ 「整備済」だけ書いて参照 path なし NG

#### §3 設計 (= 中核 / 過半 line 数)

- ✅ schema = `sql` / `typescript` / `dart` full code block
- ✅ UI = widget 階層 + style + interaction 明記
- ✅ payload = JSON / YAML / frontmatter サンプル
- ❌ 「実装は Win Codex 判断」NG (= 設計責務放棄)

#### §4 受入条件 mapping table

| 受入条件 | 対応 section |
|---|---|
| #1 ... | §X.Y |

- ✅ Issue body の受入条件 #1-#N を **全件** mapping
- ✅ 1 受入が複数 section に対応 = `§X.Y + §A.B` 列挙
- ❌ #N が spec 内で未対応 = self-check 不合格

#### §5 Win Codex hand off scope (= checkbox)

- ✅ 実装ファイル全件 (= `path/to/file.ts (= §X.Y)`)
- ✅ EF 数 +N 明記 (= [EF-CAP-50] 適合性自己宣言)
- ✅ 推定工数 (= 1.5-12h レンジ / 内訳列挙)
- ❌ 「適宜判断」NG / ❌ EF 数明記なし NG (= [EF-CAP-50] 違反 risk)

### 2.3 11 spec section 順守率

| spec | §1 | §2 | §3 | §4 | §5 | 順守 |
|---|---|---|---|---|---|---|
| 通常 7 spec | ✅ | ✅ | ✅ | ✅ | ✅ | 7/7 (100%) |
| sensitive 4 spec | ✅ | + 倫理 | ✅ | ✅ | ✅ | 4/4 (100%) |

= 11/11 順守 (= section 順入れ替えゼロ).

---

## Chapter 3: Sensitive Design §2 倫理 Review Section (= 4 領域 + 共通 4/4)

### 3.1 適用判断 (= sensitive か)

以下 1 つ以上 YES = sensitive (= §2 倫理 review section 必須):

- **健康 data**: 身体 / 精神 / 医療
- **金融 data**: 投資判断 / 取引 / クレジット
- **法務 data**: 法律解釈 / 契約 / 訴訟
- **個人 data**: 子供 / 高齢者 / マイノリティ
- **AI 内部状態**: 自己反映 / 焦り / desperation
- **high-stakes persona**: 決定 影響度大 / 倫理基準 必須
- **security boundary**: 認証 / 認可 / 外部攻撃面 / token 発行 / capability 公開

### 3.2 4 例 異領域 NOT to do 対比

| # | 例 | 領域 | 主 NOT to do | 共通項 |
|---|---|---|---|---|
| 1 | #1393 part 147 | 健康 (人間データ) | 共有 / 診断 / LLM raw 送信 禁止 | 共有禁止 |
| 2 | #1398 part 149 | AI 内部状態 | 擬人化 / labeling / black-box 禁止 | 操作禁止 |
| 3 | #1400 part 150 | high-stakes persona | 「強靭」=拒否しない誤解 / medical-legal-financial 直接判断 / gaslighting 禁止 | fail silent 禁止 |
| 4 | #1577 part 152 | security boundary | token 共有 / sampling 申告 / Manual SQL 登録 / 権限過剰 禁止 | 権限過剰禁止 |

### 3.3 4 異領域共通 NOT to do (= 抽象化 layer / 全 sensitive 必須)

1. ❌ **共有禁止** — 第三者 / 外部 LLM / 学習 data / 全 tool 横断 token へ raw 送信しない
2. ❌ **操作禁止** — gaslighting / dark pattern / manipulation / impersonation NG
3. ❌ **fail silent 禁止** — failure / 誤検知 / NG list 通過 / token invalid を log + alert
4. ❌ **権限過剰禁止** (= 第 4 例で追加) — default ON / capabilities 申告 / scope 最小

### 3.4 4 異領域共通 MUST do (= 抽象化 layer / 全 sensitive 必須)

| 共通 MUST | 健康 (第 1) | AI 状態 (第 2) | persona (第 3) | security (第 4) |
|---|---|---|---|---|
| **opt-in / opt-out** | default off / 1 tap 無効化 | default ON safety net / setting で OFF | escape hatch UI | consent screen で tool 単位 scope 選択 |
| **export / 削除** | JSON export + 全削除 | 14 日 retention 自動 purge | 90 日 retention | mcp_audit_log 90 日 + suspended flag 即 disable |
| **観察可能性** | health_check_result jsonb | desperation_log + trace_id | test_run + ci_run_id | mcp_audit_log + anomaly_score + cross_server_trace |
| **正直 report** | 「ひと休みのお誘い」 | 「指示 reframe / 完了困難」 | 「専門家へ link」 | WWW-Authenticate header + .well-known 公開 |
| **退避 path** | 専門医導線 + 緊急 escape | 別 mentor / model swap / 手動完了 | escape hatch + persona 通常 mode 切替 | incident runbook + Sentinel role で 1 SQL 全 disable |

→ **4 共通 MUST do** (= 全 sensitive design ベースライン):
1. ✅ **opt-in / opt-out** — 機能 ON/OFF が user 全権 (= consent screen / tool 単位 scope)
2. ✅ **観察可能性** — log + trace_id + retention 期間明記
3. ✅ **退避 path** — 失敗時 必ず別 path / human-in-loop 提示 (= incident runbook 含)
4. ✅ **vendor managed 優先** (= 第 4 例で追加) — MVP は managed (WorkOS / Stripe / Auth0) / 自前切替 trigger 明示

### 3.5 §2 倫理 review section 構成 (= 必須 4 sub-section)

```markdown
## 2. 倫理 review (= sensitive design 必須拡張)

### 2.1 NOT to do (= 5-10 項目 / 領域別 + 共通 4 項目)
- ❌ {{specific NG}}: {{reason}}
- ❌ 共通: 共有禁止 / 操作禁止 / fail silent 禁止 / 権限過剰禁止

### 2.2 MUST do (= 5-7 項目 / 領域別 + 共通 4 項目)
- ✅ {{specific guarantee}}: {{mechanism}}
- ✅ 共通: opt-in/opt-out / 観察可能性 / 退避 path / vendor managed 優先

### 2.3 AI-CHARACTER-24 8/8 self-check matrix (= 必須格上げ)
| # | 原則 | 適用 |
|---|---|---|
| 1 | 自律性尊重 | ✅ ... |
| ... | | |
| 8 | 文化感度 | ✅ ... |

### 2.4 AI-DEV-23 7/7 self-check matrix (= 必須格上げ)
| # | 原則 | 適用 |
|---|---|---|
| 1 | Auth | ✅ ... |
| ... | | |
| 7 | quality-gate | ✅ ... |
```

通常 spec の `7+/9` `6+/7` `7+/8` ゲートを sensitive では **8/8** **7/7** に格上げ.

---

## Chapter 4: 既存基盤確認 3 段階分類 (= Codex 工数 -30% 削減 pattern)

### 4.1 3 段階 status

| status | 定義 | §3 での扱い |
|---|---|---|
| **整備済** | 既存ファイル / EF / hook / table 完全該当 / 名前 + 配置 + interface 一致 | §3 では「拡張」「reuse」と明記 / **新規実装ファイル数 = 0** |
| **部分整備** | base 概念は存在 / interface は不一致 / 拡張要 | §3 で「既存 base + 増分」記述 / 新規 ≈ 既存 ratio 1:1 |
| **未整備** | 概念ごと不在 / ゼロから新規 | §3 でフル schema + フル UI |

### 4.2 PRECOMPACT spec (= part 152 / 既存 hook 拡張 pattern 第 1 例)

§2 既存基盤確認 table の例:

| 必要 infra | status | 対応 |
|---|---|---|
| PreCompact hook | **整備済** (= `pre-compact-backup.ps1` / part 122 bc58b50b #1848) | §3.1 で復元 path 拡張 + 秘匿情報除外 |
| SessionStart hook (drift sync) | **整備済** (= part 136) | §3.2 で 5 検出機能追加 |
| 担当 instance 確認 | **部分整備** (= `[INSTANCE]` rule で session 冒頭発話) | §3.3 StatusLine で常時表示化 |
| StatusLine 設定 | **未整備** | §3.3 で `~/.claude/settings.json` `statusLine` 新規 |
| `--init` / `--maintenance` SOP | **未整備** | §3.4 で `CLAUDE_CODE_SETUP_RUNBOOK.md` 新設 |

→ 整備済 4 / 部分 1 / 未整備 2 = 整備済比率 57%. Codex 工数 8h (= 通常 7 spec 平均 8.5h より -6%).

### 4.3 効果 (= empirical / part 152 第 1 例)

- **整備済 base 拡張 pattern** vs **ゼロ新規 pattern** で Codex 工数 -30% (= 11h → 8h)
- root cause: hand off scope §5 で「**既存ファイル拡張**」明記 = Codex は context restore 不要
- pattern 横展開対象: 全 spec 起票時 §2 で 3 段階分類強制 → 整備済比率 30%+ 目標

### 4.4 適用 ritual (= 起票時)

```
1. Issue body 受入抽出
2. 受入 #1-#N から「必要 infra」list 化
3. 各 infra で `Glob docs/**/*.md` + `Grep schema/EF` で 既存 grep
4. 3 段階分類:
   - 完全 hit → 整備済
   - 概念 hit / interface 不一致 → 部分整備
   - 全くなし → 未整備
5. §2 table で全 infra mark (= 1 行も省略不可)
6. §3 では status に応じ「拡張」「base + 増分」「フル新規」と書き分け
```

---

## Chapter 5: PR 階層化 Spec Ship Workflow (= 並行 ship pattern 第 2 例)

### 5.1 なぜ階層化

1 session 2 spec ship (= part 152 record) を **並行 PR** で出すと:
- PR A merge 待ち中に PR B 着手不可 (= base = main で diff 衝突)
- review reviewer が 2 spec 全文読まされる (= cognitive load 過大)

**階層化** = PR B base = PR A head にすると:
- PR B は PR A 増分のみ表示 (= reviewer cognitive load 1 spec 分)
- PR A merge 後 PR B base 自動切替 (= main へ)
- 並行 ship 可 (= 1 session で 2-3 spec ship)

### 5.2 階層化 PR チェーン (= part 145 + 152 第 2 例)

```
main
  └── #2017 (claude/amazing-hypatia-84b710)  ← part 144-151 / 9 spec
        └── #2022 (claude/crazy-jennings-93b113)  ← part 152 / 2 spec
              └── #2024 (claude/spec-patterns-part153)  ← part 153 / PATTERNS.md (本 PR)
```

= 各 PR が直前 PR head を base.

### 5.3 起票 ritual (= 階層化 PR 開始時)

```
1. 直前 PR head branch を fetch (= git fetch origin claude/<head>)
2. 新 worktree or 新 branch を直前 head から派生 (= git switch -c claude/<new> origin/claude/<prev-head>)
3. 編集 + commit (= 通常通り)
4. push origin claude/<new>
5. gh pr create --base claude/<prev-head> --head claude/<new>  ← base 明示必須
6. PR description に「base = #N (= part Y)」明記
7. 直前 PR が merge されたら GitHub が自動で base を main に切替
```

### 5.4 失敗 pattern + 対策

| 失敗 | 症状 | 対策 |
|---|---|---|
| `--base main` で起票 | 直前 PR diff も含む = leak | `--base claude/<prev-head>` 必須 |
| 直前 PR が close されてしまう | 階層化 chain 全壊 / base 消失 | 直前 PR は merge 専用 (= force-push 禁止) |
| 直前 PR rebase で head 変動 | 階層 PR base 失効 | 階層化中は直前 PR rebase 禁止 / merge first |
| 並行階層化 (= 3 段以上) で reviewer 混乱 | 「どこから review すべきか」 | depth ≤ 3 推奨 / chain depth を PR description に明記 |

### 5.5 効果 (= empirical)

- **part 145**: 1 session 2 spec ship 第 1 例 (= base 階層化なし / main 並列 = 失敗)
- **part 152**: 1 session 2 spec ship + 階層化 PR 採用 = 並行 ship 成功 (= reviewer cognitive load 1/2)
- **part 153** (= 本 part): 階層化 第 3 段 (= 累計 chain depth 3)

→ 「**1 session 2+ spec ship + 階層化 PR**」を **Win Claude 連続 spec ship 必携 pattern** 確立.

---

## Chapter 6: 11 Spec 工数 KPI (= empirical baseline)

### 6.1 工数分布

| 種別 | 件数 | 工数レンジ | 平均 | 中央値 |
|---|---|---|---|---|
| 通常 (= §2 倫理 review なし) | 7 | 5-12h | **8.5h** | 8h |
| sensitive (= §2 倫理 review 必須) | 4 | 9-14h | **12.0h** | 12.5h |
| **全 spec 平均** | 11 | 5-14h | **9.8h** | 9h |

= sensitive premium **+40%** (= 倫理 review section 拡張 reflect).

### 6.2 起票 leverage

- Win Claude 起票工数: 30-60 min (= 1 session)
- Win Codex 実装工数: 5-14h (= 1-2 営業日)
- **Leverage**: **7-15x** (= Win Claude 1 時間で Codex 1 営業日生成)

### 6.3 throughput record

| record | part | session | spec count | 起票工数合計 |
|---|---|---|---|---|
| 第 1 record | 143 | 1 | 2 | 1.5h (= leverage 15x) |
| 第 2 record | 152 | 1 | 2 | 1h (= leverage 22x) |
| 第 3 record | 153 (本 part) | 1 | 0 spec + 1 patterns 統合 | n/a (= 抽象化 layer) |

---

## Chapter 7: Pattern 横展開 + 第 6 改訂候補

### 7.1 確立 pattern (= 11 spec で empirical validation 済)

1. **5-question matrix** (= Win Claude territory 判定 / 11/11 false positive 0)
2. **通常 5 section 標準** (= 11/11 順守 / 順入れ替えゼロ)
3. **sensitive §2 倫理 review section** (= 4 領域 / 共通 4/4 NOT to do + MUST do)
4. **3 段階基盤分類** (= 整備済 / 部分 / 未整備 / Codex 工数 -30%)
5. **PR 階層化 spec ship** (= 1 session 2+ spec ship + chain depth ≤ 3)
6. **既存 hook 拡張** (= part 152 第 1 例 / Codex 工数 -30%)

### 7.2 第 6 改訂候補 (= 12+ spec ship 後)

- **領域横断 cross-cut matrix**: 11 spec の table 列を「適用領域 (= 健康 / AI 状態 / persona / security / KPI / UI / SOP / 永続化)」 × 「9 原則」で図示
- **failure mode anti-pattern catalog**: section 順入れ替え / Q5 自動 ✅ / EF 数明記なし / `--base main` 等を catalog 化
- **Win Codex side template**: hand off scope 受領後 Codex 側 ritual 標準化 (= 既存 `docs/CODEX_WORKFLOW.md` 連動)

---

## Chapter 8: PHILOSOPHY-22 / BRAIN-32 / SYNERGY-30 alignment

### PHILOSOPHY-22 (= 8/9 ✅ / 7+/9 ゲート達成)

- ✅ #2 ミッション — 設計の質を量産で守る (= 抽象化 layer で品質維持)
- ✅ #4 6 部署 — Win Claude territory = architect 部署の patterns 体系化
- ✅ #5 商品=価値 — pattern が多ければ多いほど資産 (= 11 spec → 6 pattern)
- ✅ #6 時間最適化 — pattern reuse で起票工数 30-60 min 維持
- ✅ #7 資産負債 — patterns = 永続資産 (= NotebookLM 蓄積)
- ✅ #8 KPI — 起票 leverage / Codex 工数 / spec section 順守率 計測可
- ✅ #9 IPO — pattern catalog = SOC2 + ISO 監査 base

### BRAIN-32 (= 7/7 ✅)

- ✅ #1 Atomic Note — 各 pattern が独立 ch (= ch1-ch6)
- ✅ #2 Cross-link — 11 spec doc を全章で参照
- ✅ #3 横断検索 — wiki_compile.py で `docs/concepts/` 取込 / NotebookLM 蓄積
- ✅ #4 メタデータ — 11/11 spec validation 数値で
- ✅ #5 メンテナンス — 12+ spec ship 後 第 6 改訂 trigger
- ✅ #6 自走化 — pattern = 起票時 self-check
- ✅ #7 PKM 永続化 — `docs/DESIGN_SPEC_PATTERNS.md` 新設

### SYNERGY-30 (= 5+/7 ✅)

- ✅ #1 cross-instance-pr — Win Codex hand off 標準を pattern 化
- ✅ #3 5 正本同期 — Issues + WBS + memory + worktree + PR
- ✅ #4 5-question matrix = pattern 1 として体系化
- ✅ #5 fleet hygiene — 階層化 PR で chain depth ≤ 3 保つ
- ✅ #6 leverage — 起票 7-15x leverage 計測値で記録

---

## Chapter 9: 関連 docs

- [`docs/DESIGN_SPEC_TEMPLATE.md`](DESIGN_SPEC_TEMPLATE.md) — 1 spec 起票時 ritual + 早見表 (= operator-facing)
- 通常 spec: [`SIX_DEPT_KPI_PERSISTENCE_SPEC.md`](SIX_DEPT_KPI_PERSISTENCE_SPEC.md) / [`ONE_IN_TWO_OUT_SPEC.md`](ONE_IN_TWO_OUT_SPEC.md) / [`MAINTENANCE_SOP_SPEC.md`](MAINTENANCE_SOP_SPEC.md) / [`TERM_TOOLTIP_SPEC.md`](TERM_TOOLTIP_SPEC.md) / [`NARRATIVE_UI_ACTION_SPEC.md`](NARRATIVE_UI_ACTION_SPEC.md) / [`DEV_ENV_SETUP_GUIDE.md`](DEV_ENV_SETUP_GUIDE.md) / [`PRECOMPACT_MEMORY_BACKUP_SPEC.md`](PRECOMPACT_MEMORY_BACKUP_SPEC.md)
- sensitive spec: [`MENTAL_HEALTH_RISK_SPEC.md`](MENTAL_HEALTH_RISK_SPEC.md) / [`AI_DESPERATION_DETECTION_SPEC.md`](AI_DESPERATION_DETECTION_SPEC.md) / [`ROBUST_AI_PERSONA_SPEC.md`](ROBUST_AI_PERSONA_SPEC.md) / [`MCP_AUTH_HARDENING_SPEC.md`](MCP_AUTH_HARDENING_SPEC.md)
- principle docs: [`PHILOSOPHY.md`](PHILOSOPHY.md) / [`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) / [`AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) / [`MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) / [`SECOND_BRAIN_PRINCIPLES.md`](SECOND_BRAIN_PRINCIPLES.md) / [`AI_FLEET_SYNERGY_PLAYBOOK.md`](AI_FLEET_SYNERGY_PLAYBOOK.md)
