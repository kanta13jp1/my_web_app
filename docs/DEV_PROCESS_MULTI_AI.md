# Multi-AI 開発プロセス — Claude Code 集中リスク分散設計

**策定**: 2026-04-24 (Win版#132 part 3)
**前提**: Claude Code 依存度を下げ、Codex / Gemini Code Assist / GitHub Copilot / NotebookLM を並列活用することで、単一 AI vendor ダウン時も開発継続できる体制を構築する。

---

## 1. なぜ Claude Code 単独依存が危険か

### 観測事例

| # | 事象 | 影響 |
|---|------|------|
| 1 | Max プラン 5h limit hit → "resets 4am" | 全 10 インスタンス一斉停止 / 夜間 dev 不能 |
| 2 | Context compaction ループ (Win版#131 part 16→17) | 記憶断片化で同じ修正を繰り返す |
| 3 | summary resume 後の大規模タスク注入 | 再 compaction 発生 (PS#3 S26 教訓) |
| 4 | Anthropic API outage (2026-Q1 数回観測) | cross-instance-pr 作成不能 / deploy 監視停止 |
| 5 | $200/月 単一ベンダー課金集中 | 値上げ or プラン改変 = 即 dev 体制崩壊 |

### リスクの本質

- **SPOF (単一障害点)**: 10 インスタンス全てが Anthropic API に依存
- **Context ceiling**: Claude Code は 1M token までだが、実質 200K で劣化開始
- **判断の均質化**: 全判断が Claude の訓練分布 (丁寧・防御的・仮説多め) に寄る
- **課金の天井**: Max プランでも月 $200 の ceiling が実作業 ceiling

---

## 2. 新プロセス: 4-AI 協調 (Claude / Gemini / Codex / Copilot)

### 基本原則

1. **Claude Code = CEO / アーキテクト**: 判断・統合・memory 管理のみ使用 (全 dev 時間の 10-20%)
2. **Gemini Code Assist = 長文 refactor / codebase review**: 500+ 行の一括変更 (30%)
3. **OpenAI Codex = 単機能実装 / algorithm / SQL**: 明確に仕様確定したコード生成 (20%)
4. **GitHub Copilot = inline completion**: エディタ内の即時補完 (30%)
5. **NotebookLM = リサーチ / ドキュメント分析**: 深い調査・競合21社調査 (10%)

### task routing matrix (強制)

| task 種別 | Primary | Secondary | Claude Code の役割 |
|-----------|---------|-----------|--------------------|
| AI大学 provider 追加 (Migration SQL seed) | **Codex** | Gemini | routing 判断のみ |
| AI大学 provider UI 登録 (registry + _providerMeta) | **Copilot** (pattern match) | Gemini | 整合性レビュー |
| Migration 新規 (DDL + seed) | **Codex** (SQL 特化) | Copilot | migration 命名則確認 |
| Flutter widget 新規 | **Gemini Code Assist** (DESIGN.md 参照) | Copilot | design-skills gate |
| Flutter widget 修正 (数行) | **Copilot inline** | — | 不使用 |
| Flutter 大規模 refactor (500+ 行) | **Gemini** (長 context) | — | 事前レビュー |
| EF (Deno) 新 action 追加 | **Codex** + Copilot | — | integration テスト |
| EF (Deno) hub 統合 refactor | **Gemini** | Copilot | dependency 分析 |
| GHA workflow (yml) 修正 | **Codex** | Copilot | 不使用 (静的) |
| Shell script (bash / python) | **Codex** | Copilot | 不使用 |
| ドキュメント執筆 (docs/) | **Gemini** (長文) or 手書き | Copilot | 構成レビューのみ |
| 競合 21 社調査 | **NotebookLM Deep Research** | — | 統合レポート |
| アーキテクチャ判断 | **Claude Code** (独占) | — | 主役 |
| memory/ consolidation | **Claude Code** | — | 主役 |
| cross-instance-pr 作成 | **Claude Code** | — | 主役 |
| commit message / PR description | **Codex** (短) or Claude (長) | — | Co-Authored-By |
| Deploy 監視 / Rule17 WF health | **Claude Code** (PS#1 専任) | — | 主役 |
| design review (Playwright + DESIGN.md) | **Claude Code** (VSCode design-skills) | — | 主役 |

### 見分け方: 「Claude を使うべきか」判定フロー

```text
[タスク発生]
  ↓
Q1: 複数インスタンス間の調整が必要? → YES → Claude Code
  ↓ NO
Q2: 判断 / 戦略 / trade-off 検討? → YES → Claude Code
  ↓ NO
Q3: 既存 pattern の繰り返し? → YES → Codex or Copilot
  ↓ NO
Q4: 500+ 行の一括変更? → YES → Gemini Code Assist
  ↓ NO
Q5: 深いリサーチ (3+ ファイル or 外部 URL)? → YES → NotebookLM
  ↓ NO
→ Copilot inline で完結
```

---

## 3. 役割別 AI 割当の具体ルール

### 3.1 AI大学 provider 追加 (現状最多タスク)

**旧 (Claude 全依存)**:
1. Claude Code が migration SQL を全て書く (3 category × 50-100 行 = 300 行)
2. Claude Code が registry / _providerMeta / _quizzes / _fallback を 4 箇所編集
3. Claude Code が commit + push
= **1 provider = 約 30K tokens 消費**

**新 (multi-AI)**:
1. **Claude Code**: 「次に追加すべき provider は v0 / Windsurf」判断のみ (500 tokens)
2. **NotebookLM Deep Research**: provider の公式サイト + Crunchbase + TechCrunch 3-5 ソース調査 → サマリ生成 (0 Claude tokens)
3. **Codex**: 既存 seed migration を template にして SQL 生成 (Claude 不使用)
4. **Copilot inline**: registry.dart / _providerMeta / _quizzes / _fallback の 4 箇所を pattern 補完 (Claude 不使用)
5. **Claude Code**: 最終レビュー + commit message (2K tokens)
= **1 provider = 約 3K tokens (10 倍節約)**

### 3.2 Flutter widget 新規 (design gate 必須)

**旧**:
- Claude が DESIGN.md 参照しながら widget 生成
- 全コードを context に載せる

**新**:
- **VSCode 版 Claude Code**: design-skills subagent で DESIGN.md 参照 + 構造設計 (skill 内)
- **Gemini Code Assist**: 実コード生成 (DESIGN.md を context に投入)
- **Copilot**: 細部の tweak
- Claude は最終 review + dart format check のみ

### 3.3 EF (Deno) 新 action 追加

**旧**:
- Claude が hub index.ts に action block を追加

**新**:
- **Codex**: 既存 action block を template に新 case branch 生成
- **Claude Code**: authz / deny-by-default / trace_id 原則チェック
- **deploy**: PS#1 が Rule17 で監視 (Claude 使用)

---

## 4. Fallback plan: Claude Code 全停止時

**契機**:
- Anthropic API outage
- Max プラン limit hit
- 契約変更 / 値上げ

**継続可能な作業**:

| 作業 | 代替 tool | 備考 |
|------|-----------|------|
| AI大学 provider 追加 | Codex + Copilot | 既存 150 社の template で 80% 自動化可 |
| Migration 作成 | Codex | SQL 特化モデルで問題なし |
| Flutter 小修正 | Copilot | エディタ内完結 |
| Flutter 大規模 refactor | Gemini Code Assist | 長 context 得意 |
| GHA workflow 修正 | Codex | yml 静的なので AI 判断不要 |
| 競合モニタリング | NotebookLM | Deep Research 自動化 |
| deploy 監視 | GitHub Actions log 手動確認 | PS#1 スクリプト化済 |

**Claude Code 必須タスク (代替不能)**:
- アーキテクチャ大判断 (hub 統合 / EF-CAP-50 遵守判断)
- cross-instance-pr 作成
- memory/ consolidation
- design review (Playwright + design-skills subagent)

→ **Claude 停止時はこれらを 48h pause**。他 AI で継続できる作業を優先進行。

---

## 5. 実装: 各 AI への引き渡しプロトコル

### 5.1 Codex への引き渡し (migration / EF / script)

```bash
# template を示して指示する例
codex "以下の seed migration template を参考に、provider='cognition' (Devin AI) の
seed SQL を 3 category (overview/models/use_cases) で生成。
template: supabase/migrations/20260424220000_seed_v0_ai_university.sql"
```

### 5.2 Gemini Code Assist への引き渡し (大規模 refactor)

```bash
# VSCode 内で Gemini Code Assist 拡張機能経由
# 全 lib/pages/ 配下の DESIGN token 適用を依頼
# @workspace context 指定で 500+ ファイル解析
```

### 5.3 GitHub Copilot の活用 (inline)

- CLAUDE.md 不要 (プロジェクト pattern を file context から学習)
- エディタで 1-5 行単位の補完に徹する
- 大きな判断が必要な箇所では使わない (頻繁に間違う)

### 5.4 NotebookLM Deep Research の活用

```bash
notebooklm source add-research "Cognition AI Devin autonomous coding agent 2026"
notebooklm research wait
notebooklm ask "Devin の差別化軸と料金体系を 3 point で"
# 出力をそのまま Codex に seed SQL 生成依頼で投入
```

---

## 6. 移行計画 (3 段階)

### Phase 1 (即日): 認知転換
- [x] 本ドキュメント作成
- [ ] CLAUDE.md の AI 振り分け早見表を本ドキュメントへの link に置換
- [ ] 各インスタンスの instance-roles で「Claude 必須」タスクを明示

### Phase 2 (1 週間): tool セットアップ検証
- [ ] Codex CLI / ChatGPT Desktop の動作確認
- [ ] Gemini Code Assist VSCode 拡張の context 投入手順確立
- [ ] Copilot の suggestions 品質測定 (Flutter / Dart / Deno それぞれ)

### Phase 3 (1 ヶ月): KPI 計測
- [ ] Claude Code token 消費量 week 比較 (移行前 vs 移行後)
- [ ] Claude 依存率 (全 commit のうち Claude 主導 vs 他 AI 主導)
- [ ] 目標: Claude token 月 50% 削減 / 他 AI で代替可能率 70%+

---

## 7. 自分株式会社の哲学との整合性

### Philosophy 9 原則チェック

| 原則 | 適合性 |
|------|--------|
| 1. CEO 感 (最終決定権) | ✅ Claude = CEO として判断のみ / 他 AI = 実務担当 |
| 2. ミッション駆動 | ✅ 「開発継続性」がミッション / SPOF 除去は直接貢献 |
| 3. 優しい mentor | ✅ 各 AI の特性を理解した routing = mentor 的判断 |
| 4. 6 部署バランス | ✅ Tech 部 (開発) の負荷分散 = 他部署への時間配分改善 |
| 5. 商品=ユーザー価値 | ✅ Anthropic outage 時もサービス改善継続可 = ユーザー連続的価値 |
| 6. 資本=時間 | ✅ Claude 依存削減で夜間 / limit 後も作業可 = 時間資本増加 |
| 7. 資産負債 BS | ✅ 「Claude 依存 = 負債」と認識 → 分散 = 負債削減 |
| 8. KPI=昨日の自分 | ✅ token 消費量と他 AI 代替率の計測で自己改善 |
| 9. ゴール=IPO / ウェルビーイング | ✅ 単一 vendor 依存 = IPO 時のリスク開示項目 / 分散で健全化 |

**9/9 ✅** — 本プロセス変更は自分株式会社哲学に完全適合。

---

## 8. 参考: 競合 21 社の AI 多様化事例

- **Cursor**: OpenAI + Anthropic + Gemini の multi-LLM routing (ユーザー選択可)
- **Replit Agent 4**: Claude Sonnet (主) + GPT-4o (fallback) + DALL-E (画像) の multi-model
- **v0 by Vercel**: OpenAI + Anthropic mix
- **Windsurf (Cascade)**: 自社 fine-tune + Claude + GPT-4o

**示唆**: 成功する AI 製品ほど single-vendor 依存を避けている。自分株式会社の開発プロセスも同じ原則に従うべき。

---

## 9. 更新履歴

- **2026-04-24 (Win版#132 part 3)**: 初版作成。Claude Code 単一依存リスク顕在化 (context compaction ループ + Max limit reset) を受けて策定。
