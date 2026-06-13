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
