# [cross-instance-pr] kg-indexer-nightly failure 修正 — Issue #2152 hand-off

**To**: Win版 (Codex CLI) — 実装/修正PR/SQL/EF Deno/GHA role
**From**: Win版 (Claude Code) — Win版#132 part 179 / triage
**Priority**: medium
**Date**: 2026-05-08
**Deadline**: 2026-05-19 (= 11 day grace / WBS top 5 期限)
**Related**: [Issue #2152](https://github.com/kanta13jp1/my_web_app/issues/2152) / [`.github/workflows/kg-indexer-nightly.yml`](../../.github/workflows/kg-indexer-nightly.yml)

## 背景

Knowledge Graph nightly indexer (= [run 25518994705](https://github.com/kanta13jp1/my_web_app/actions/runs/25518994705)) が 2026-05-07 20:01 UTC scheduled run で **exit code 1** で失敗.

Annotation: `No files were found with the provided path: tmp/kg-indexer/. No artifacts will be uploaded.`

= "Run indexers" step (= 5 indexer 連続実行) が中途失敗 → tmp/kg-indexer/ 出力 0 件 → upload artifact 警告.

## 該当ファイル

- `.github/workflows/kg-indexer-nightly.yml` (= workflow)
- `scripts/kg_index_common.py`
- `scripts/kg_index_docs.py`
- `scripts/kg_index_github_issues.py`
- `scripts/kg_index_memory_vault.py`
- `scripts/kg_index_notebooklm_intake.py`
- `scripts/kg_index_wbs_tasks.py`

## 依頼事項 (= Codex 実装範囲)

### 1. Failure 原因特定

```bash
gh run view 25518994705 --log-failed
```

= どの indexer で fail か特定. `commit 7e76026e7e0b915f051b2e82d7b276e8ed878cc9` 時点の state で再現.

### 2. 修正方針 (= 推奨優先順)

1. **個別 indexer fail を fail-soft 化** — 1 indexer fail でも他 4 indexer 継続. 最終 step で artifact 0 件なら exit 1, 1+ 件なら exit 0.
2. **root cause fix** — 失敗 indexer (= memory_vault / notebooklm_intake のいずれか可能性高) の例外処理改善.

### 3. Acceptance criteria

- [ ] kg-indexer-nightly が連続 3 日 success (= 5/9, 5/10, 5/11)
- [ ] tmp/kg-indexer/ に 5 indexer 全 artifact 出力
- [ ] PR description で「Issue #2152 修正 / fail-soft 化 + root cause fix」明示
- [ ] 失敗 issue auto-open は維持 (= "Open or update failure issue" step 健全)

## 委譲外 (= Win Claude 担当)

- なし. Self-contained.

## Reference

- Issue: [#2152](https://github.com/kanta13jp1/my_web_app/issues/2152)
- Failed run: <https://github.com/kanta13jp1/my_web_app/actions/runs/25518994705>
- Workflow: [`.github/workflows/kg-indexer-nightly.yml`](../../.github/workflows/kg-indexer-nightly.yml)
