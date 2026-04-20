---
name: hook-rule-audit
description: |
  月 1 回実行する `~/.claude/hooks/inject-rules.txt` の rule audit skill。
  Distyl AI 研究 (指示 500 個 → 最高精度 68% 遵守) に基づき rule の rot/重複/陳腐化を
  検知して整理する。Win版#131 で導入。`consolidate-memory` skill と同じスケジュール推奨。
  Triggers on: "/hook-rule-audit", "hook rule 監査", "inject-rules.txt 整理",
  "ルール棚卸し", "rule audit", "毎ターン rule 見直し".
---

# Hook Rule Audit Skill

## ゴール

`~/.claude/hooks/inject-rules.txt` の rule (現在 20 個 / 134 行) を月 1 回監査し、
以下を実施:

1. **不使用検知** — 過去 30 日のセッション memory grep で参照ゼロの rule 抽出
2. **重複検知** — 内容が overlap する rule pair を merge 候補に
3. **陳腐化検知** — 「Win#XX 必須」と紐付いてるが該当 Win セッション instance 廃止 = stale
4. **行数監査** — 全 rule で 200 行超なら splitting 必要 (Distyl 研究 500 個閾値の余裕確保)
5. **新規候補** — 直近 memory の `feedback_correction_*` から 3+ 回繰り返した失敗 → 新 rule 化提案

## 実行ステップ

### Step 1: 現状計測

```bash
wc -l ~/.claude/hooks/inject-rules.txt
grep -c "^\[" ~/.claude/hooks/inject-rules.txt
grep -oE "^\[[A-Z-]+[0-9]*\]" ~/.claude/hooks/inject-rules.txt | sort -u
```

期待: rule 数 ≤ 25 / 行数 ≤ 200。超過 → 圧縮または分割提案。

### Step 2: 不使用検知 — memory との cross-reference

```bash
# 各 rule 名 (例: [DART-FORMAT]) を memory フォルダで grep
for rule in $(grep -oE "^\[[A-Z-]+[0-9]*\]" ~/.claude/hooks/inject-rules.txt); do
  count=$(grep -rl "$rule" "/c/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory/" 2>/dev/null | wc -l)
  echo "$rule: $count files"
done | sort -t: -k2 -n | head -10
```

参照 0 + 30 日経過の rule = removal 候補 (ユーザー確認後)。

### Step 3: 重複検知 — 内容類似 rule pair 抽出

手動 review:
- `[DART-FORMAT]` (dart format → analyze → push) と `[REBASE]` (push 前に rebase) は連続適用 → merge 不可 (両方必須)
- `[STASH-SAFETY]` と `[REBASE]` は文脈共有 → 説明統合可能性
- `[EF-FIRST]` と `[EF-CAP-50]` は EF まわりで対 → cross-reference するなら統合 OK

merge 候補があれば 1 行サマリで提案 (実 merge は ユーザー承認後)。

### Step 4: 陳腐化検知

`Win#XX 必須` パターンを抽出して Win 番号と現在 instance 制 (10 instance 制 = Win#116 以降) を比較:

```bash
grep -oE "Win[#版]+[0-9]+" ~/.claude/hooks/inject-rules.txt | sort -u
```

Win 番号が 50+ 古い = stale 可能性 → 対応する CLAUDE.md / docs を読み rule が今も有効か確認。

### Step 5: 新規候補抽出

直近 30 日の `memory/feedback_correction_*.md` を読み、3+ 回繰り返した failure pattern を rule 化候補に:

```bash
ls -t /c/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory/feedback_correction_*.md | head -10
```

例: `feedback_correction_20260420_qiita_rolling_limit.md` のような同種失敗が他にもあれば → `[QIITA-RATE-LIMIT]` rule 提案。

### Step 6: 報告フォーマット

以下を ユーザーに表示 (rule 自動編集はせず、承認後に Edit):

```
## Hook Rule Audit (YYYY-MM-DD)

### 計測
- rule 数: X / 134 行
- 閾値: 25 rule / 200 行 (Distyl AI 研究の 500 個閾値の 5% 余裕)

### 不使用候補 (参照ゼロ + 30 日経過)
- [RULE-NAME] — 最終参照: なし → removal?

### 重複/merge 候補
- [RULE-A] + [RULE-B] — 内容 overlap (XX%) → merge?

### 陳腐化候補
- [RULE-NAME] (Win#XX) — Win#XX は 50+ 前 → 仕様確認?

### 新規候補
- [PROPOSED-RULE] — 直近 N 回の同種 failure pattern → 追加?

### 推奨アクション
- 即 apply: [list]
- ユーザー承認待ち: [list]
- 据置: [list]
```

### Step 7: 承認後の更新フロー

ユーザーが `apply` と回答した項目を `~/.claude/hooks/inject-rules.txt` に Edit:

1. backup: `cp ~/.claude/hooks/inject-rules.txt ~/.claude/hooks/inject-rules.txt.bak.YYYYMMDD`
2. Edit (削除/merge/追加)
3. 検証: `grep -c "^\[" ~/.claude/hooks/inject-rules.txt` で rule 数確認
4. 次セッションから自動的に新 rule が system-reminder で注入される

## 担当

- **PS版#1** (Rule17 WF health 専任) と組み合わせて月初の同じ日に実行推奨
- 月 1 回 ペース ≒ `consolidate-memory` skill と同期

## 出力先

- `memory/feedback_success_YYYYMMDD_hook_audit.md` (audit 結果サマリ)
- `docs/GROWTH_STRATEGY_ROADMAP.md` 末尾追記 (rule 変更履歴)

## 注意事項

- 「失敗パターン rule」(`[AUTO-REPLY]` など bug 例から生まれた rule) は absolute keep
- `[INSTANCE]` `[INSTANCE-ROLES]` は 10 instance 制の core 設定 = 削除不可
- audit 中に新規 rule を追加するときは Distyl 閾値 (500) の 5% (= 25 rule) を超えないこと

## 参考

- NotebookLM 該当ノート (Win版#131 で言及): "Distyl AI 500 個 → 68% 遵守"
- `docs/memory-architecture.md` (3 層メモリ全体像)
- Win版#98 (UserPromptSubmit hook 導入) / Win版#131 (CLAUDE.md → hook migration)
