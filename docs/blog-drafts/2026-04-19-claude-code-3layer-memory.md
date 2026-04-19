---
title: "Claude Codeのセッション間記憶を3層で設計する — memory/ + NotebookLM + COMPRESSED_PROMPT"
tags: ClaudeCode,AI,個人開発,buildinpublic,architecture
published: false
---

# Claude Codeのセッション間記憶を3層で設計する

## 問題: Claude はセッションをまたいで記憶しない

Claude Code は1セッションが終わると記憶をリセットする。
毎回「前回どこまでやったか」「禁止事項は何か」「アーキテクチャの経緯は」を
1から説明する必要がある。

これを解決するための3層メモリシステムを構築した。

## Layer 1: セッション内 — claude-mem (SQLite + Gemini圧縮)

```bash
# セッション開始時に Worker を起動
npx claude-mem start

# 全ツール使用を自動記録
# ベクター検索で過去の操作を検索可能
```

SQLite にセッション中の全操作を保存。Gemini で圧縮してベクトル化。
「あのファイルはどこに保存したか」「どのコマンドを実行したか」を検索できる。

## Layer 2: セッション間 — memory/ mdファイル (auto-capture hook)

```
C:\Users\kanta\.claude\projects\...\memory\
  MEMORY.md                # インデックス (毎セッション読み込み)
  feedback_success_*.md    # 成功パターン
  feedback_correction_*.md # 禁止事項・失敗パターン
  project_*.md             # セッション完了記録
  user_*.md                # ユーザー設定・好み
```

MEMORY.md は CLAUDE.md に組み込まれ、**毎セッション自動で読み込まれる**。

```markdown
<!-- MEMORY.md の構造 -->
| File | Description |
|------|-------------|
| feedback_correction_20260418_qiita_self_reply_loop.md | 🚨 blog_engagement.py 自動返信無限ループバグ |
| project_20260419_ps149_155.md | PS版#149-155: T-1 13本(過去最高) + dart:ui_web fix |
```

### auto-capture hook の設定

```json
// ~/.claude/settings.json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [{ "type": "command", "command": "python3 hooks/auto-capture.py" }]
      }
    ]
  }
}
```

ツール使用ごとに hook が走り、重要な操作を自動でキャプチャする。

## Layer 3: プロジェクト横断 — NotebookLM Master Brain

```bash
# 深い調査・長期アーキテクチャ知識を蓄積
notebooklm use jibun-master-brain
notebooklm source add memory/feedback_success_20260419.md
notebooklm ask "過去の成功パターンは？"
```

NotebookLM に全セッションのサマリーを蓄積。
「なぜ Supabase を選んだか」「過去に試して失敗したアプローチ」を横断検索できる。

## セッション開始プロトコル

```bash
# 1. memory/ を読む (CLAUDE.md 経由で自動)
# 2. cross-instance-prs を確認
ls docs/cross-instance-prs/ | grep -v "done/"

# 3. 並行インスタンス確認
git log origin/main --oneline -10

# 4. Master Brain に問い合わせ (重要な判断時)
notebooklm ask "今日の優先タスクは？"
```

## セッション終了プロトコル (/wrap-up)

```bash
# 成功パターンを記録
Write memory/feedback_success_YYYYMMDD.md

# 禁止事項を記録
Write memory/feedback_correction_YYYYMMDD.md

# セッション完了記録
Write memory/project_YYYYMMDD_xxx.md

# MEMORY.md インデックス更新
Edit memory/MEMORY.md (先頭行に追加)

# Master Brain に蓄積
notebooklm source add memory/project_YYYYMMDD_xxx.md
```

## 効果: 同じ失敗を繰り返さない

```markdown
<!-- memory/feedback_correction_20260418_qiita_self_reply_loop.md -->
Qiita auto-reply ループバグ:
- blog_engagement.py が自分のコメントに自動返信 → 無限ループ
- 原因: author == 自分 の skip チェックなし
- 対策: author チェック必須 + MAX_REPLIES_PER_RUN cap
```

このメモが毎セッション読み込まれることで、同じバグを再実装しない。

## まとめ

| 層 | ツール | 用途 |
|----|--------|------|
| L1 セッション内 | claude-mem (SQLite) | 操作ログ・ベクター検索 |
| L2 セッション間 | memory/ mdファイル | 成功/失敗パターン・設定 |
| L3 プロジェクト横断 | NotebookLM Master Brain | 深い知識・意思決定経緯 |

「記憶が消える」という Claude の弱点を3層で補完することで、
セッションをまたいだ継続的な開発が可能になる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#ClaudeCode #AI #buildinpublic #個人開発
