---
name: cross-instance-pr
description: |
  自分株式会社で VSCode版 / PowerShell版 / Windowsアプリ版 / WEB版のインスタンス間で
  作業依頼を渡すための docs/cross-instance-prs/ md ファイルを作成・コミットする。

  Triggers on: "/cross-instance-pr", "cross-instance-pr 作成", "他インスタンスに依頼",
  "VSCode版に UI 追加依頼", "PS版にワークフロー修正依頼".

  引数:
  - to={vscode|ps|win|web}: 宛先インスタンス (必須)
  - title="<短い件名>": ファイル名・見出し (必須)
  - priority={high|medium|low}: 優先度 (省略時 medium)

  例:
  - /cross-instance-pr to=vscode title="SambaNova UI同期" priority=medium
  - /cross-instance-pr to=ps title="新WF追加依頼" priority=high
---

# cross-instance-pr 作成スキル

## 概要

`docs/cross-instance-prs/` に frontmatter 付きの Markdown ファイルを作成して
他インスタンスへ作業依頼を渡す。`done/` サブフォルダに完了済みを移動する運用。

## 前提

- **送信元インスタンス (from)**: 実行時の会話で明示されているインスタンス名を使う
  (例: VSCode版#90, Windows版#74, PS版#111)
- **宛先 (to)**: 引数 `to=` で指定
  - `vscode` → "VSCode版"
  - `ps` → "PowerShell版"
  - `win` → "Windowsアプリ版"
  - `web` → "WEB版"

## 手順

### Step 1: 引数パース + ファイル名決定

ファイル名: `docs/cross-instance-prs/YYYYMMDD_<slug>.md`

- `YYYYMMDD`: 今日の日付 (JST)
- `<slug>`: title をローマ字・アンダースコア区切りに正規化 (例: 「SambaNova UI同期」→ `sambanova_ui`)

### Step 2: frontmatter + 本文を生成

テンプレート:

```markdown
---
date: YYYY-MM-DD
from: <from-instance>#<session-number>
to: <to-display-name>
status: pending
priority: <priority>
---

# <タイトル>

## 概要

<ユーザーの意図を 2〜3 行で要約>

## 依頼内容

<具体的な作業項目を番号付きで>

1. ...
2. ...
3. ...

## 関連ファイル

- `path/to/relevant/file.dart`
- ...

## 完了条件

- [ ] ...
- [ ] ...

宛先インスタンスが完了したら `done/` に移動してください。
```

### Step 3: Write ツールで作成

絶対パス必須 (プロジェクトルート起点の Windows パス)。

### Step 4: git add + commit

コミットメッセージ:
```
docs: cross-instance-pr <タイトル> (<from> → <to>)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

### Step 5: rebase + push

```bash
git fetch origin main
git rebase origin/main  # conflict 出たら Python で解決
git push origin HEAD:main
```

## 運用上の注意

- **stale PR 検出**: root と `done/` に同名ファイル・内容一致なら root 削除 (アーカイブ漏れ)
- **完了マーク**: 宛先インスタンスは作業完了後 `git mv` で `done/` に移動
- **重複防止**: 同日同 slug ファイルが存在したら `_2` サフィックス追加
- **優先度目安**:
  - `high`: 次のセッション開始時点で必ず着手してほしい (CI が失敗している・production 障害)
  - `medium`: 数セッション以内に着手 (UI 同期・新機能追加)
  - `low`: 時間のあるとき (リファクタリング候補)

## 送信元が不明なとき

1. 直近 git log で最新コミットに記載された `(XXX版#N)` を参考にする
2. ユーザーに「現在のインスタンス」を質問する
3. memory の `user_instance_*.md` を参照する
