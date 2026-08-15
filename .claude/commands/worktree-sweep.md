---
description: worktree の手動一括点検 — キュー drain / dry-run 一覧 / quarantine / orphan 報告
---

# /worktree-sweep

引数: `$ARGUMENTS` = `[--apply]`

Web UI マージや raw `gh pr merge` など `/pr-merge` を通らなかった経路の取りこぼしを回収する。
週次で回すことを想定。

## 手順

1. **キュー drain**(常に安全。全エントリを毎回フル再検証する):

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\kanta\GitHub\my_web_app\scripts\worktree_release.ps1" -DrainQueue -Apply
```

2. **全体 dry-run**。`git worktree list --porcelain` の各ブランチについて、対応する PR が
   MERGED かを `gh pr list --state merged --json number,headRefName` で引き、
   該当するものを `worktree_release.ps1 -Pr <n> -Repo kanta13jp1/my_web_app`(`-Apply` 無し)で判定する。
   出力の `DRY-RUN PRUNE` / `CLEANUP QUARANTINED` / `CLEANUP SKIPPED` を表にまとめる。

3. **quarantine 一覧**を表示: `C:\Users\kanta\GitHub\my_web_app\.cache\worktree-quarantine.jsonl`
   の path / reason / sample を表にして出す。**ここに載ったものを自動削除してはならない。**
   理由が `ignored-local-only-files` の場合、その worktree には git のどこにも存在しない
   `.env` / `evidence/` などがある。中身を確認してからユーザーが判断する。

4. **orphan 報告 (report-only)**: `git worktree list --porcelain` に無いのにディスク上にある
   `C:\tmp\*` / `C:\Users\kanta\GitHub\wt-*` ディレクトリを列挙する。
   これらは `git worktree remove` では到達できない。**削除はユーザーが自分で行う。**

5. `--apply` が指定された場合のみ、手順 2 の dry-run 結果をユーザーに見せ、
   **明示的な同意を得てから** 各 PR について
   `worktree_release.ps1 -Pr <n> -Repo kanta13jp1/my_web_app -Apply` を個別に回す。

## 触ってはいけないもの

- `scripts\worktree_prune.ps1` — `.claude/worktrees/` 専用の別系統。manual-only 契約があり、
  このコマンドからは呼ばない。
- detached HEAD の worktree — ブランチが無く PR と結びつかないため、判定不能として必ず skip する。
