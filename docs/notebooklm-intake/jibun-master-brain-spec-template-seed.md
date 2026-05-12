# NotebookLM seed — Win Claude 設計 spec template + 7 適用例

> **target NotebookLM**: `jibun-master-brain` (= ID prefix `ea6cff25` 推奨 / part 140 教訓)
> **upload method**: NotebookLM CLI で本ファイルを source として add (= `notebooklm add ...`) / 手動でも可
> **purpose**: Win版#132 part 143-147 で確立した設計 spec 標準 template + 7 適用例 + sensitive design 拡張 を Master Brain (= 全 instance ゼロトークン Query 対象) に蓄積する
> **created**: 2026-05-05 (= Win版#132 part 148)

## 1. なぜ蓄積するか

Win Claude が設計 spec を 5 連続セッション (= part 143-147) で 7 件 ship + 1 meta-doc 抽出.
template + 適用例を NotebookLM `jibun-master-brain` に投入することで:

1. **全 instance** (= Win Claude / Win Codex) が `notebooklm use jibun-master-brain` で **ゼロトークン Query** 可能
2. 「過去どんな spec 書いたか / どの axis 適用したか」を即時参照
3. 新 spec 起票時 template 違反を検知 (= 失敗パターン 5 種を NotebookLM が学習済)

## 2. 蓄積 source 一覧 (= 8 docs)

### 2.1 Meta-doc (= template 本体)

- `docs/DESIGN_SPEC_TEMPLATE.md` (= part 146 / 5 section + axis 早見表 + 起票 ritual 8 step + 失敗パターン 5 種)

### 2.2 通常 spec (= 6 件)

- `docs/SIX_DEPT_KPI_PERSISTENCE_SPEC.md` (= [#1316](https://github.com/kanta13jp1/my_web_app/issues/1316) / part 143)
- `docs/ONE_IN_TWO_OUT_SPEC.md` (= [#1345](https://github.com/kanta13jp1/my_web_app/issues/1345) / part 143)
- `docs/MAINTENANCE_SOP_SPEC.md` (= [#1292](https://github.com/kanta13jp1/my_web_app/issues/1292) / part 144)
- `docs/TERM_TOOLTIP_SPEC.md` (= [#1348](https://github.com/kanta13jp1/my_web_app/issues/1348) / part 144)
- `docs/NARRATIVE_UI_ACTION_SPEC.md` (= [#1366](https://github.com/kanta13jp1/my_web_app/issues/1366) / part 145)
- `docs/DEV_ENV_SETUP_GUIDE.md` (= [#1356](https://github.com/kanta13jp1/my_web_app/issues/1356) / part 145)

### 2.3 Sensitive spec (= 1 件 / 倫理 review section 拡張第 1 例)

- `docs/MENTAL_HEALTH_RISK_SPEC.md` (= [#1393](https://github.com/kanta13jp1/my_web_app/issues/1393) / part 147)

## 3. NotebookLM Query 例 (= 蓄積後の活用パターン)

### 3.1 Spec 標準形を Query

```
Q: 「Win Claude 設計 spec の標準 5 section は何？」
A: 思想 / 既存基盤確認 / Schema or UI 設計 / Win Codex hand off scope / 9 原則 alignment + 受入条件 mapping
   (出典: docs/DESIGN_SPEC_TEMPLATE.md §3)
```

### 3.2 Sensitive design 拡張を Query

```
Q: 「sensitive design (= 健康/金融/個人) で必須拡張は何？」
A: §2 倫理 review section 追加. NOT to do 7 項目 + MUST do 5-7 項目 + AI-CHARACTER 8/8 必須 + AI-DEV 7/7 必須
   (出典: docs/MENTAL_HEALTH_RISK_SPEC.md §2 + docs/DESIGN_SPEC_TEMPLATE.md §4 axis 早見表)
```

### 3.3 適用済 axis 早見表を Query

```
Q: 「UI 整理系 spec で必須 axis は？」
A: PHILOSOPHY-22 + IMBUE-25 (必須) + AI-CHARACTER-24 (推奨)
   (出典: docs/DESIGN_SPEC_TEMPLATE.md §4 / 適用例 = ONE_IN_TWO_OUT + TERM_TOOLTIP + NARRATIVE_UI_ACTION)
```

### 3.4 失敗パターン回避を Query

```
Q: 「Win Claude spec 起票時に避けるべき失敗パターンは？」
A: 5 種:
  1. section 順入れ替え
  2. 9 原則欠落
  3. 受入 mapping 抜け
  4. 工数欠落 ("TBD"NG)
  5. EF 数明記なし ([EF-CAP-50] 違反 risk)
  (出典: docs/DESIGN_SPEC_TEMPLATE.md §6)
```

### 3.5 平均工数 + 起票時間を Query

```
Q: 「Win Claude spec 1 件あたりの工数目安は？」
A: 平均工数 8.6h (= Codex 実装) / 起票工数 30-60 min (= Win Claude / 7-15x leverage)
   (出典: docs/DESIGN_SPEC_TEMPLATE.md §4 + §5)
```

## 4. 蓄積実行手順 (= manual or CLI)

### 4.1 NotebookLM CLI 経由 (推奨)

```bash
# notebooklm CLI が install 済の場合
cd /c/Users/kanta/GitHub/my_web_app
notebooklm use ea6cff25                           # ID prefix で Master Brain 開く
notebooklm add docs/DESIGN_SPEC_TEMPLATE.md
notebooklm add docs/SIX_DEPT_KPI_PERSISTENCE_SPEC.md
notebooklm add docs/ONE_IN_TWO_OUT_SPEC.md
notebooklm add docs/MAINTENANCE_SOP_SPEC.md
notebooklm add docs/TERM_TOOLTIP_SPEC.md
notebooklm add docs/NARRATIVE_UI_ACTION_SPEC.md
notebooklm add docs/DEV_ENV_SETUP_GUIDE.md
notebooklm add docs/MENTAL_HEALTH_RISK_SPEC.md
notebooklm add docs/notebooklm-intake/jibun-master-brain-spec-template-seed.md   # 本ファイル
```

### 4.2 手動 (= NotebookLM web UI 経由 / fallback)

1. https://notebooklm.google.com/ で `jibun-master-brain` 開く
2. 「ソース追加」→ 「ウェブサイト」or 「テキスト貼り付け」
3. 上記 8 docs を順次 paste / URL 指定
4. 「source 概要」生成完了後 Query 可能

## 5. 蓄積後の効果計測 (= Win Claude part 149+ で観察)

| metric | baseline (= part 147) | target (= part 152 / 5 part 後) |
|---|---|---|
| 新 spec 起票時間 | 30-60 min | < 30 min (= NotebookLM Query で template 即参照) |
| spec 失敗パターン発生 | 0/7 (= 全件 OK) | 維持 |
| sensitive design § 倫理 review section 適用率 | 1/1 (= part 147 のみ) | 100% 維持 |
| Master Brain Query 回数 | 0 | 5+/session (= 起票時 + 横断 audit 時) |

## 6. PHILOSOPHY-22 / BRAIN-32 alignment

### PHILOSOPHY-22

- ✅ #4 6 部署 — architect 部署の知識資産化
- ✅ #5 商品=価値 — spec 蓄積 = 永続価値
- ✅ #7 資産負債 — Master Brain = 累積 leverage 資産

### BRAIN-32 (= 7/7 ✅ 維持)

- ✅ #1 Atomic Note — 各 spec が Atomic
- ✅ #2 Compile — `wiki_compile.py` で `docs/concepts/` 自動生成既稼働
- ✅ #3 Query — NotebookLM CLI ゼロトークン
- ✅ #4 Lint — `knowledge_vault_lint.py` Health Score 既稼働
- ✅ #5 メンテナンス — 半年ごと spec 平均工数追跡
- ✅ #6 横断 — Win Claude + Win Codex 両方が同じ Master Brain 参照
- ✅ #7 永続化 — 本 seed file = git track + NotebookLM 二重保管
