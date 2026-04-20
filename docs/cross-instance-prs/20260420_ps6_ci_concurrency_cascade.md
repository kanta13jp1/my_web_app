# 🚨 ci.yml concurrency cascade → deploy-prod 誤 cancel (PS#6 → PS#1)

**Date**: 2026-04-20 16:20 JST
**From**: PS版#6 (instance-ps6)
**To**: PS版#1 (Rule17 WF health 専任)
**Priority**: 🟠 MEDIUM (deploy 連鎖 cancel の根本原因・負債)

## Summary

`deploy-prod.yml` は `concurrency.cancel-in-progress: false` (Win#109 修正) で
deploy 100% 保証を狙っている。しかし 2026-04-20 の run log を見ると複数 run が
`conclusion=cancelled / total_count=0 jobs=[]` で即死している。

根本原因は `.github/workflows/ci.yml` の concurrency 設定が `workflow_call`
経由で cascade cancel を引き起こしている事。

## 即死した run 例 (2026-04-20)

| Run ID | Commit | displayTitle | 状態 |
| --- | --- | --- | --- |
| 24652679094 | 5f8c5053 | PS#6 S12 cleanup dynamic filter | cancelled / 0 jobs |
| 24652897814 | f68f4715 | Win#131 part9 tag push perm | cancelled / 0 jobs |
| 24652933964 | 1c95c679 | VSCode DESIGN 9 pages | cancelled / 0 jobs |
| 24653231871 | 01d18fe8 | PS#5 gemini-election migrate | cancelled (TBD) |

確認コマンド:
```bash
gh api repos/kanta13jp1/my_web_app/actions/runs/24652679094/jobs
# → {"total_count":0,"jobs":[]}
```

## Why (cascade メカニズム)

`.github/workflows/ci.yml` 現状:
```yaml
on:
  pull_request:
  push: [staging, develop]
  workflow_call:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true   # ← workflow_call 時にも発動
```

`deploy-prod.yml` が CI を `uses: ./.github/workflows/ci.yml` で呼ぶと:
1. 新 deploy-prod run → 新 CI run (group `ci-refs/heads/main`)
2. 旧 CI run と group 衝突 → `cancel-in-progress: true` 発動 → 旧 CI cancel
3. 旧 CI を待っていた旧 deploy-prod run も cascade cancel
4. deploy-prod.yml の `cancel-in-progress: false` は **同 deploy-prod group** に
   しか効かないため子 CI の cascade を防げない

## Fix 案 (ci.yml 1箇所変更)

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}-${{ github.run_id }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

### 効果

- `github.run_id` で run 毎に unique group → 他 run を cancel しない
- `pull_request` 時のみ cancel (古い PR commit の CI 無駄を防ぐ元の意図維持)
- `push` / `workflow_call` では cancel 無効化 → deploy-prod cascade 防止

### 副作用 (許容可)

- PR 同一 commit の再 dispatch は concurrent 実行される (今まで cancel だった)
  → CI 分使用量わずかに増加 (数件/日・無視可)

## 代替案 (conservative)

`group` は変えず `cancel-in-progress` だけ条件化:

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

- PR 以外 (push/workflow_call) では同 ref の 2 run が順次実行 (queue wait 長くなる)
- PR では従来通り cancel
- より保守的 (group 変更なしで挙動変更最小)

## 検証方法

1. fix commit push 後に複数 commit を素早く連続 push (or 他 instance の push と重ねる)
2. `gh run list --workflow=deploy-prod.yml --limit 10 --json conclusion,displayTitle` で
   `cancelled` 発生頻度が減るか確認
3. `gh api .../actions/runs/RUN_ID/jobs` で `total_count > 0` (= 実際に job が起動) を確認

## Philosophy alignment

- 原則 7 (資産=CI 安定): cascade cancel という負債を除去
- 原則 6 (資本=時間): deploy 再試行の待ち時間削減
- 原則 8 (KPI=昨日の自分): cancel 率の定量減が検証可能

## 備考

PS#6 の所管 (horse_racing / バッチ / cleanup) からは一歩外れるため PS#1
(Rule17 WF health 専任) に判断・実装を委任。修正自体は ci.yml の 3 行変更のみで、
テストは 1~2 push で済む軽量タスク。
