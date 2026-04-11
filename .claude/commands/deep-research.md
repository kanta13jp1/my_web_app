---
description: 重いドキュメント分析・競合調査・Web リサーチを NotebookLM に委譲してトークンを節約する（ゼロトークンリサーチ）。引数にトピック・ファイルパス・URLを渡す。
---

# /deep-research — ゼロトークンリサーチ

**原則**: 30ファイル以上の分析・競合調査・外部ドキュメント収集はすべて NotebookLM に委譲する。
Claude は **結果の整理・統合・アクション抽出のみ** を担当する。

引数: `$ARGUMENTS`

---

## Step 1: 引数を解析

`$ARGUMENTS` を以下のいずれかとして処理する:

| パターン | 処理方法 |
|---------|---------|
| テキスト/トピック | `notebooklm source add-research` で Web 自律調査 |
| ファイルパス (スペース区切り) | `notebooklm source add <file>` でアップロード |
| `--url https://...` | `notebooklm source add <url>` で URL 追加 |
| `--files f1 f2 --query 質問` | 複数ファイルを source add → ask |
| `--generate <type>` | 分析後に成果物 (slide-deck/flashcards 等) を生成 |

---

## Step 2: 認証確認

```bash
notebooklm status
```

**未認証の場合**:

```text
セットアップが必要です:
  pip install "notebooklm-py[browser]"
  playwright install chromium
  notebooklm login
  notebooklm skill install
その後 /deep-research を再実行してください。
```

---

## Step 3: NotebookLM でリサーチ実行

### A. トピック調査（Web Deep Research）

```bash
notebooklm create "deep-research-YYYYMMDD"
notebooklm source add-research "[トピック — 具体的なクエリほど精度が上がる]"
notebooklm research wait      # 調査完了まで待機
notebooklm ask "主要な知見を3点まとめて"
notebooklm ask "このプロジェクト (Flutter Web + Supabase ライフマネジメントアプリ) への示唆は？"
```

### B. ファイル分析

```bash
notebooklm create "file-analysis-YYYYMMDD"
notebooklm source add "<file1>"
notebooklm source add "<file2>"
# ... 最大50ソース (free) / 300ソース (pro)
notebooklm ask "[質問]"
```

### C. URL 分析

```bash
notebooklm create "url-analysis-YYYYMMDD"
notebooklm source add "https://..."
notebooklm ask "要約して。このプロジェクトへの影響は？"
```

### D. YouTube 分析

```bash
notebooklm source add --type youtube "https://youtube.com/watch?v=..."
notebooklm ask "動画の主要ポイントは？"
```

### E. 成果物の自動生成（オプション）

```bash
notebooklm generate slide-deck "要点をスライドにまとめて"
notebooklm generate flashcards "重要用語を中心に"
notebooklm generate mind-map
notebooklm generate data-table "主要概念を比較"
notebooklm generate audio "engaging deep dive" --wait
notebooklm generate quiz "難易度中"
notebooklm generate infographic
notebooklm download <type>    # ローカルに保存
```

---

## Step 4: 結果を整理・統合

NotebookLM の出力を受け取り、以下を行う:

1. **重複・冗長な部分を除去**
2. **このプロジェクトのコンテキストに合わせて解釈**:
   - 競合調査 → 自分株式会社への影響と対応策を抽出
   - コード分析 → 修正すべき箇所と優先度を整理
   - 技術調査 → 実装に使えるパターンを抽出
3. **アクションアイテムを抽出**（番号付きリストで提示）
4. **必要なら `docs/` や GROWTH_STRATEGY_ROADMAP.md への反映を提案**

---

## Step 5: 重要な発見の保存（オプション）

発見が今後も参照価値を持つ場合は memory/ に保存し、Master Brain に蓄積:

```bash
# ローカル保存
# → C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\project_YYYYMMDD.md

# Master Brain に追加（認証済みの場合）
notebooklm use <jibun-master-brain-notebook-id>
notebooklm source add "./memory/project_YYYYMMDD.md"
```

---

## DBS フレームワーク: エキスパートスキル構築

Deep Research の結果を Claude Code スキルに変換する手順:

```text
D (Direction)   = 意思決定ロジック・手順・エラー回復 → SKILL.md のコア
B (Blueprints)  = テンプレート・ガイドライン・分類表 → サポートファイル
S (Solutions)   = API 呼び出し・計算など確定的コード → スクリプト
```

DBS 分類後に `/skill-creator` を実行すると SKILL.md が自動生成・テストされる。

---

## トークン節約の目安

| 作業 | 通常の Claude 消費 | このワークフロー |
|------|------------------|----------------|
| 30ファイル分析 | ~150K tokens | ~5K tokens (要約整理のみ) |
| 競合調査 (10社) | ~80K tokens | ~3K tokens |
| 技術ドキュメント調査 | ~60K tokens | ~2K tokens |
| YouTube + PDF 混合 (20本) | ~200K tokens | ~4K tokens |

**月 $20 プランで $200 相当の作業ができる。**

---

## 使用例

```text
/deep-research 競合21社の最新動向をまとめて
/deep-research lib/pages/landing_page.dart のパフォーマンス改善点
/deep-research --url https://flutter.dev/docs/release/whats-new --query Flutter最新機能は？
/deep-research --files docs/DESIGN.md supabase/functions/ai-assistant/index.ts --query APIとUIの整合性チェック
/deep-research Notion 3.4の新機能と自分株式会社への影響
/deep-research advanced Flutter Web animation techniques 2026 --generate flashcards
```
