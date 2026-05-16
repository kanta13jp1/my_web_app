#!/usr/bin/env bash
set -euo pipefail

# Mark published blog draft frontmatter in a branch-protection-safe way.
# The workflow always writes the change to a temporary branch first. If BLOG_PAT
# or a compatible fallback token can merge the PR, it is auto-merged; otherwise
# the branch/PR remains as the manual fallback.

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "::error::${name} is required"
    exit 1
  fi
}

mark_published() {
  local file="$1"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    return 0
  fi

  if grep -q "^published: false" "$file"; then
    sed -i 's/^published: false/published: true/' "$file"
  elif grep -q "^published:" "$file"; then
    return 0
  elif head -1 "$file" | grep -q "^---"; then
    local tmp
    tmp=$(mktemp)
    awk '
      NR == 1 && $0 == "---" { print; in_fm=1; next }
      in_fm && $0 == "---" && !inserted { print "published: true"; inserted=1; print; in_fm=0; next }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    local tmp
    tmp=$(mktemp)
    printf -- "---\npublished: true\n---\n" > "$tmp"
    cat "$file" >> "$tmp"
    mv "$tmp" "$file"
  fi
}

require_env DRAFT_PATH
require_env GITHUB_REPOSITORY

RUN_ID="${GITHUB_RUN_ID:-local}"
TRACE="${TRACE_ID:-blog-publish-${RUN_ID}}"
TOKEN="${BLOG_PAT:-${GH_PAT_BLOG_MERGE:-${BYPASS_RULES:-${GITHUB_TOKEN:-}}}}"
BRANCH="blog-publish/${RUN_ID}-$(TZ=Asia/Tokyo date +'%Y%m%d-%H%M%S')"
COMMIT_MSG="docs: mark blog draft published $(basename "$DRAFT_PATH")"
if [ -n "${DRAFT_PATH_EN:-}" ]; then
  COMMIT_MSG="$COMMIT_MSG + $(basename "$DRAFT_PATH_EN")"
fi

echo "[trace=$TRACE] status automation branch: $BRANCH"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git fetch origin main
git checkout -B "$BRANCH" origin/main

mark_published "$DRAFT_PATH"
mark_published "${DRAFT_PATH_EN:-}"

git add "$DRAFT_PATH"
if [ -n "${DRAFT_PATH_EN:-}" ] && [ -f "$DRAFT_PATH_EN" ]; then
  git add "$DRAFT_PATH_EN"
fi

if git diff --cached --quiet; then
  echo "[trace=$TRACE] no published flag changes; skipping status branch"
  exit 0
fi

git commit -m "$COMMIT_MSG"

if [ -n "$TOKEN" ]; then
  git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true
  git remote set-url origin "https://x-access-token:${TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi

git push origin "$BRANCH"
echo "[trace=$TRACE] pushed fallback branch $BRANCH"

PR_URL=""
if command -v gh >/dev/null 2>&1; then
  export GH_TOKEN="${TOKEN:-${GH_TOKEN:-}}"
  if [ -n "${GH_TOKEN:-}" ]; then
    PR_URL=$(gh pr create \
      --base main \
      --head "$BRANCH" \
      --title "$COMMIT_MSG" \
      --body "Automated blog-publish status update. If auto-merge is unavailable, merge this PR manually." \
      2>/tmp/blog-publish-pr-create.err || true)
    if [ -n "$PR_URL" ]; then
      echo "[trace=$TRACE] status PR: $PR_URL"
      if gh pr merge "$PR_URL" --auto --squash --delete-branch 2>/tmp/blog-publish-pr-merge.err; then
        echo "[trace=$TRACE] status PR auto-merged"
      else
        echo "::warning::[trace=$TRACE] status PR auto-merge failed; leaving fallback PR/branch."
        cat /tmp/blog-publish-pr-merge.err || true
      fi
    else
      echo "::warning::[trace=$TRACE] PR creation failed; branch remains for manual merge."
      cat /tmp/blog-publish-pr-create.err || true
    fi
  else
    echo "::warning::[trace=$TRACE] no GitHub token available for PR creation; branch remains for manual merge."
  fi
else
  echo "::warning::[trace=$TRACE] gh CLI unavailable; branch remains for manual merge."
fi

{
  echo "## Blog publish status automation"
  echo ""
  echo "| item | value |"
  echo "| --- | --- |"
  echo "| trace_id | \`$TRACE\` |"
  echo "| branch | \`$BRANCH\` |"
  echo "| pr | ${PR_URL:-not-created} |"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
