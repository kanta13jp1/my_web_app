#!/usr/bin/env bash
# Win版#114: インスタンス専用 worktree セットアップ
# 用法:
#   bash .claude/scripts/setup-instance-worktree.sh <instance-name>
# 例:
#   bash .claude/scripts/setup-instance-worktree.sh vscode
#   bash .claude/scripts/setup-instance-worktree.sh win
#   bash .claude/scripts/setup-instance-worktree.sh ps
#
# 各インスタンスは必ず固定名 worktree で作業する (git stash/pull --rebase 干渉回避)。
set -euo pipefail

INSTANCE="${1:-}"
if [[ -z "$INSTANCE" ]]; then
  echo "Usage: $0 <vscode|win|ps1|ps2|ps3|ps4|ps5|ps6>" >&2
  echo "" >&2
  echo "10 インスタンス制 役割:" >&2
  echo "  vscode → UI/design (Rule12,19) / DESIGN.md token" >&2
  echo "  win    → AI大学 / migration / EF cleanup / 動画編集" >&2
  echo "  ps1    → Rule17 WF health + CI 修復" >&2
  echo "  ps2    → T-1 dev.to/Qiita dispatch + blog cleanup" >&2
  echo "  ps3    → AI大学コンテンツ更新 (NotebookLM)" >&2
  echo "  ps4    → 競合モニタリング + 戦略レポート" >&2
  echo "  ps5    → on-call バグ修正 (WEB/📱 Issue → 即修正)" >&2
  echo "  ps6    → horse_racing scraper / バッチ処理" >&2
  echo "" >&2
  echo "(WEB/📱 はファイル編集不要 — GitHub MCP で Issue 発行のみ)" >&2
  exit 1
fi

case "$INSTANCE" in
  vscode|win|ps1|ps2|ps3|ps4|ps5|ps6) ;;
  ps) echo "Error: PS版は 6 つに分割されました。ps1|ps2|ps3|ps4|ps5|ps6 を指定してください" >&2; exit 1 ;;
  *) echo "Error: instance must be one of: vscode, win, ps1..ps6 (got: $INSTANCE)" >&2; exit 1 ;;
esac

# main repo path 検出 (本スクリプトはどこから実行しても OK)
MAIN_REPO=$(git rev-parse --git-common-dir 2>/dev/null | xargs dirname | xargs realpath 2>/dev/null || true)
if [[ -z "$MAIN_REPO" || ! -d "$MAIN_REPO/.git" && ! -f "$MAIN_REPO/.git" ]]; then
  # fallback: assume hardcoded
  MAIN_REPO="C:/Users/kanta/GitHub/my_web_app"
  if [[ ! -d "$MAIN_REPO" ]]; then
    echo "Error: cannot locate main repo" >&2
    exit 1
  fi
fi

WORKTREE_DIR="$MAIN_REPO/.claude/worktrees/instance-$INSTANCE"
BRANCH="claude/$INSTANCE-wip"

echo "==> Main repo: $MAIN_REPO"
echo "==> Worktree:  $WORKTREE_DIR"
echo "==> Branch:    $BRANCH"

cd "$MAIN_REPO"
git fetch origin main --quiet

if [[ -d "$WORKTREE_DIR" ]]; then
  echo "==> Worktree already exists. Updating to latest origin/main..."
  cd "$WORKTREE_DIR"
  git fetch origin main --quiet
  # ローカル変更を保護 (commit 忘れ対策)
  if ! git diff-index --quiet HEAD --; then
    echo "    [!] uncommitted changes detected. Skipping rebase."
    echo "    [!] Commit them first, then rerun this script."
    exit 0
  fi
  git rebase origin/main
  echo "==> Worktree updated."
else
  echo "==> Creating new worktree..."
  # 既存 branch があれば再利用、無ければ新規作成
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add "$WORKTREE_DIR" "$BRANCH"
  else
    git worktree add -b "$BRANCH" "$WORKTREE_DIR" origin/main
  fi
  echo "==> Worktree created."
fi

cd "$WORKTREE_DIR"
# 推奨設定: pull --rebase を auto-stash で安全化
git config rebase.autoStash true
echo "==> rebase.autoStash = true (uncommitted も保護)"

echo ""
echo "✅ Setup complete. Use this directory:"
echo "   cd $WORKTREE_DIR"
echo ""
echo "Push to main: git push origin HEAD:main"
