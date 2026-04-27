# Codex 並行開発ワークフロー

> 目的: Claude Code 10 インスタンスに、Codex 2 インスタンスを固定 worktree で追加し、SQL / EF / algorithm 系の実装を衝突少なく並行処理する。

## 1. インスタンス割当

| インスタンス | worktree | branch | 主担当 | 補助先 |
| --- | --- | --- | --- | --- |
| Codex#1 | `.claude/worktrees/instance-codex1` | `codex/codex1-wip` | SQL / migration / seed 生成 | PS#3 |
| Codex#2 | `.claude/worktrees/instance-codex2` | `codex/codex2-wip` | EF(Deno) / algorithm / GHA補助 | PS#5 / PS#6 |

Codex は Claude Code の代替司令塔ではなく、実装補助枠として扱う。設計判断、cross-instance-pr、memory consolidation、最終統合判断は Claude Code 側に残す。

## 2. 起動手順

```bash
cd C:/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-codex1
git fetch origin main
git rebase origin/main
codex
```

```bash
cd C:/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-codex2
git fetch origin main
git rebase origin/main
codex
```

未作成の環境では main repo から次を実行する。

```bash
cd C:/Users/kanta/GitHub/my_web_app
powershell -ExecutionPolicy Bypass -File .claude/scripts/setup-instance-worktree.ps1 codex1
powershell -ExecutionPolicy Bypass -File .claude/scripts/setup-instance-worktree.ps1 codex2
```

Git Bash / WSL が使える環境では、既存の Bash 版も利用できる。

```bash
bash .claude/scripts/setup-instance-worktree.sh codex1
bash .claude/scripts/setup-instance-worktree.sh codex2
```

## 3. 作業ルール

- main repo (`C:/Users/kanta/GitHub/my_web_app`) は直接編集しない。
- uncommitted 変更を長時間残さない。stash ではなく小さい commit か WIP commit で退避する。
- 原則は担当 branch に push する。

```bash
git push -u origin codex/codex1-wip
git push -u origin codex/codex2-wip
```

`git push origin HEAD:main` は、競合確認、test/lint、Claude Code 統合確認が終わった場合のみ使う。

## 4. 責任境界

Codex#1 が触る範囲:

- `supabase/migrations/**/*.sql`
- SQL seed / data backfill
- SQL生成に必要な最小限の docs / handoff

Codex#2 が触る範囲:

- `supabase/functions/**`
- algorithm / batch / scraper 改善
- `.github/workflows/**` の小規模補助

共通して避ける範囲:

- UI / design 判断
- アーキテクチャ方針の変更
- WBS / memory の直接大規模編集
- 他インスタンスの担当ファイル

## 5. WBS 連携

Codex CLI から WBS MCP を直接使えない場合は、作業完了時に次のどちらかで連携する。

1. `docs/cross-instance-prs/YYYYMMDD_codex<N>_<title>.md` に handoff を作る。
2. Claude Code 側へ WBS 更新を依頼する。

handoff には最低限、目的、変更ファイル、実行した検証、残リスク、次に見るべきインスタンスを記録する。

## 6. 推奨検証

SQL / migration:

```bash
supabase db lint
```

EF(Deno):

```bash
deno lint supabase/functions/<function-name>/index.ts
deno check supabase/functions/<function-name>/index.ts
```

Flutter 影響がある場合:

```bash
flutter analyze
```

検証不可の場合は、handoff に「未実行理由」と「依頼先」を明記する。
