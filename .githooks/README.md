# .githooks

ローカルの git hooks。リポジトリ追跡下に置き、各自が opt-in で有効化する。

## 有効化

```bash
git config core.hooksPath .githooks
```

(無効化: `git config --unset core.hooksPath`)

## pre-commit

`scripts/check_duplicate_dispose.py` を実行し、**二重 dispose / 二重 await /
二重 setState**(part 280 で本番障害になった系統)をコミット前に検知する。

- `lib/**/*.dart` がステージされている時だけ走る(非 dart コミットは即通過)。
- 監査本体は CI と同一スクリプト。通常 ~2.6s(`--max-seconds 60` で線形時間も担保)。
- 同じゲートは [`ci.yml`](../.github/workflows/ci.yml) でも走るため、hook 未設定でも
  CI で必ず検出される。hook は「手元での早期検知」用。
- 緊急迂回は `git commit --no-verify`(非推奨)。

## pre-push

`scripts/sync_compressed_prompt.py --check` および `origin/main` との差分を検証し、
共有メモリ (`COMPRESSED_PROMPT.md`) の同期漏れや `git pull --rebase origin main` 未実施のままの
古いプッシュを事前にブロックする（緊急スキップ: `SKIP_PRE_PUSH_SYNC=1`）。

## commit-msg (オプトイン導入)

`scripts/check_commit_message.py` により、コミットメッセージにチケット番号参照
（例: `refs #2727`, `Closes #2727`, `Related to #2727`, `feat: summary (#2727)`）が含まれるかを検証する。
`Merge ...`, `Revert "..."`, `fixup!`, `squash!`, `amend!` で始まる自動生成コミットは免除される。

```bash
bash scripts/install_commit_msg_hook.sh
```

`git rev-parse --git-path hooks` を解決して該当リポジトリ／ワークツリーの `.git/hooks/commit-msg` に配置するため、
既存の `lefthook.yml` や `.githooks/pre-push` の動作を妨げずに適用できる（確認のみ: `--dry-run`、上書き: `--force`）。
コミットメッセージに `[skip ci]` または `[ci skip]` を含めた場合、GitHub Actions では必須ステータスチェック
（`ci-complete` 等）を維持したまま重い非必須の Web ビルド／OGP 生成ステップだけを安全にスキップする。
