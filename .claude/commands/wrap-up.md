---
description: セッション終了前に学習を抽出し、永続メモリ (memory/) に保存する。次回セッションの Master Brain として機能する。
---

このセッションを振り返り、以下の手順で永続メモリに保存してください。

## Step 1: セッション分析

会話履歴全体を振り返り、4カテゴリに分類する:

### A. 成功パターン
- うまくいったアプローチ・コマンド・設計判断
- ユーザーが「yes」「完璧」「これ」と反応したもの
- 予想より少ないステップで解決できたもの

### B. 失敗・訂正
- ユーザーに「違う」「やめて」「元に戻して」と言われたこと
- ツール呼び出しが拒否されたこと
- 間違えたファイルパス・関数名・数値

### C. 新規発見
- このセッションで初めて知ったプロジェクト固有の仕様
- 想定と異なっていた実装の詳細
- 今後注意すべき制約・依存関係

### D. ルール候補
- COMPRESSED_PROMPT_V3.md に追記すべき新ルール・数値更新
- .markdownlintignore への追加候補
- インスタンス分担の変更点

## Step 2: memory/ に保存

**重要**: `C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\` に書き込む。

今日の日付 (YYYYMMDD) を使ってファイルを作成:

内容があるカテゴリのみファイル化する（空なら作らない）:

- 成功パターンがある場合: `feedback_success_YYYYMMDD.md`
- 失敗・訂正がある場合: `feedback_correction_YYYYMMDD.md`
- 新規発見がある場合: `project_YYYYMMDD.md`

各ファイルのフォーマット:

```markdown
---
name: [簡潔なタイトル]
description: [1行の説明 — 未来の自分が参照判断できる粒度で]
type: [feedback または project]
---

[内容]

**Why:** [なぜこれが重要か]
**How to apply:** [次回どう適用するか]
```

MEMORY.md インデックスにも1行追加する。

## Step 3: 未完了タスクの記録

このセッションで着手したが完了しなかったタスクを MEMORY.md の末尾にコメントとして追記:

```markdown
<!-- wrap-up YYYYMMDD
未完了:
- [タスク名]: [状態と次のステップ]

次回優先:
- [最優先タスク]
-->
```

## Step 4: GROWTH_STRATEGY_ROADMAP.md 更新

`docs/GROWTH_STRATEGY_ROADMAP.md` の末尾にセッション記録を追記し、git commit する。

## Step 5: 完了報告

以下の形式で報告する:

```
✅ wrap-up 完了
- 成功パターン: X件 → feedback_success_YYYYMMDD.md
- 訂正: X件 → feedback_correction_YYYYMMDD.md
- 新規発見: X件 → project_YYYYMMDD.md
- 未完了タスク: X件
- 次回優先: [タスク名]
```
