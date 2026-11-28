# 自分株式会社 共有コンテキスト同期メモリ (`COMPRESSED_PROMPT.md`)

> 正規詳細版: [`.github/COMPRESSED_PROMPT_V3.md`](.github/COMPRESSED_PROMPT_V3.md) / Codex運用: [`AGENTS.md`](AGENTS.md) / Claude運用: [`CLAUDE.md`](CLAUDE.md)
> このファイルは `python scripts/sync_compressed_prompt.py --write` で決定論的に生成・同期されます。

## Current 2-Instance Override

並列作業時は以下の2インスタンス体制と共有ルールを必ず遵守し、重複実装・静的解析エラーを防ぎます。

| レーン | 主な担当領域 | 同期・検証ゲート |
| --- | --- | --- |
| **Claude Code #1 (Windows app)** | アーキテクチャ設計・調査・ドキュメント・WBS/UXトリアージ | `docs/`, `AGENTS.md`, `CLAUDE.md` |
| **Codex #1 (Windows app)** | 実装・CI/CD・GitHub PR・Edge Functions・マイグレーション | Cloud CI + `sync_compressed_prompt.py --check` |
| **User / Automation** | 手動承認・スケジュール監視・GitHub Actions | `permissions: {}` 最小権限実行 |

## 必須プッシュ前同期プロトコル (`git pull --rebase`)

全エージェントおよび開発者は、コミット・プッシュ直前に必ず以下を実行し、他インスタンスの変更と競合なく同期します。

```bash
git stash
git pull --rebase origin main
git push
git stash pop
```

- オプトイン Git フック有効化: `git config core.hooksPath .githooks`
- `.githooks/pre-commit`: Dart ファイルの重複 `dispose` / `setState` を事前検証 (`scripts/check_duplicate_dispose.py`)。
- `.githooks/pre-push`: `COMPRESSED_PROMPT.md` 同期確認 (`scripts/sync_compressed_prompt.py --check`) と `origin/main` 遅延検知（`git pull --rebase origin main` 要求）。

## CI/CD `flutter analyze` 0エラー・0警告 厳格通過条件

- `.github/workflows/ci.yml` (`Analyze code`) は `python scripts/quality_gate.py --analyze-only --analyzer-artifact-dir .ci-logs/analyzer` を `continue-on-error` なしで実行します。
- `analysis_options.yaml` により `unused_import` / `unused_local_variable` / `dead_code` / `unused_element` / `prefer_const_constructors` 等の違反はすべてビルド失敗として拒否されます。
- ローカルでの `COMPRESSED_PROMPT.md` 整合検証は `python scripts/sync_compressed_prompt.py --check` で実行できます。

## 同期スナップショット

<!-- COMPRESSED_PROMPT_SYNC:START -->
```json
{
  "source": ".github/COMPRESSED_PROMPT_V3.md",
  "v3_checksum": "7a8b6c3690976910",
  "v3_lines": 1058,
  "metrics": {
    "migrations": 2125,
    "edge_functions": 35,
    "workflows": 224,
    "features": 18
  },
  "ci_analyze_gate": "strict-zero-errors-zero-warnings",
  "pre_push_rebase_guard": ".githooks/pre-push"
}
```
<!-- COMPRESSED_PROMPT_SYNC:END -->
