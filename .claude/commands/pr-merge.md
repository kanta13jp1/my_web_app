---
description: PR をマージし、証明できた場合のみ対応する worktree を撤去する (merge + remove = 1 set)
---

# /pr-merge

引数: `$ARGUMENTS` = `<PR番号> [--admin] [--dry-run]`

## 手順

1. 引数から PR 番号を取る。省略された場合は `gh pr view --json number` で現在ブランチの PR を解決する。
2. 次を **1 回だけ** 実行する(メインリポジトリ `C:\Users\kanta\GitHub\my_web_app` から実行すること)。

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\kanta\GitHub\my_web_app\scripts\pr_merge_and_release.ps1" -Pr <PR番号> -Repo kanta13jp1/my_web_app
```

`--admin` が指定されていれば `-Admin` を、`--dry-run` なら `-DryRun` を付ける。

3. 出力の最後の 1 行 (`WORKTREE RELEASE ...`) をそのままユーザーに見せる。加工しない。

## 重要な約束

- **マージ後に手で `git worktree remove` を実行しない。** このコマンドが 1 セットで面倒を見る。
- `CLEANUP QUARANTINED` が出たら、それは未コミットの手作業か、git に存在しない ignored ファイル
  (`.env` / `evidence/` など) がある worktree。**自動で消してはいけない。** ユーザーに判断を仰ぐ。
- `CLEANUP QUEUED` は自己マージ (worktree の中からそこの PR をマージした) か、
  dart/flutter プロセスが生きている場合。次回の `/pr-merge` か `/worktree-sweep` で自動的に片づく。
- `MERGE FAILED` が出たら撤去は一切行われていない。PR 番号を確認する。

## 撤去されたものの復旧

削除前に必ず attic に退避している。`C:\Users\kanta\.claude\state\worktree-attic\<hash>-<timestamp>\` に
`meta.json` (head_sha / branch / origin)、`worktree.diff`、`index.diff`、`untracked.tar` がある。
`meta.json` の `head_sha` から `git worktree add` で復元できる。**保持は 30 日**。

## 無効化 (kill switch)

- そのセッションだけ: `$env:MWA_WORKTREE_RELEASE_DISABLED = '1'`
- 恒久的: `New-Item -ItemType File "C:\Users\kanta\GitHub\my_web_app\.cache\worktree-release.DISABLED"`
- 最も確実: このコマンドを使わず `gh pr merge` を直に叩く(撤去は一切走らない)
