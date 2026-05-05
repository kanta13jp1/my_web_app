#!/bin/bash
# T-1 Blog Dispatch Script — Claude Code 不要で blog-publish.yml を dispatch する
# 使い方: bash scripts/t1-dispatch.sh <slug> [platforms]
# 例:     bash scripts/t1-dispatch.sh "2026-04-26-ai-vendor-dependency-portfolio-bs-framework"
# 例:     bash scripts/t1-dispatch.sh "2026-04-26-ai-vendor-dependency-portfolio-bs-framework" "qiita,devto"

set -euo pipefail

SLUG=${1:?usage: t1-dispatch.sh <slug> [platforms]}
PLATFORMS=${2:-devto}

JA_PATH="docs/blog-drafts/${SLUG}.md"
EN_PATH="docs/blog-drafts/${SLUG}-en.md"

# ── Pre-check ─────────────────────────────────────────────────────────────
if [ ! -f "$JA_PATH" ] && [ ! -f "$EN_PATH" ]; then
  echo "❌ Neither ${JA_PATH} nor ${EN_PATH} found"
  exit 1
fi

python scripts/check_remote_synced.py \
  --remote origin \
  --branch main \
  --require-clean \
  --ignore-path ".claude/settings.local.json"

echo "📋 Dispatch plan:"
echo "  JA: $JA_PATH ($([ -f "$JA_PATH" ] && echo exists || echo missing))"
echo "  EN: $EN_PATH ($([ -f "$EN_PATH" ] && echo exists || echo missing))"
echo "  Platforms: $PLATFORMS"

# Tag count check (dev.to 4-tag cap)
for f in "$JA_PATH" "$EN_PATH"; do
  [ -f "$f" ] || continue
  TAGS=$(grep '^tags:' "$f" | head -1 | sed 's/^tags:[[:space:]]*//')
  COUNT=$(echo "$TAGS" | tr ',' '\n' | grep -c .)
  if [ "$COUNT" -gt 4 ]; then
    echo "  ⚠️ $f: $COUNT tags (5th will be silently dropped on dev.to)"
  fi
done

# Parallel dispatch check (last 5 min)
RECENT=$(gh run list --workflow=blog-publish.yml --limit 5 \
  --json databaseId,status,createdAt \
  --jq "[.[] | select(.createdAt > \"$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v -5M +%Y-%m-%dT%H:%M:%SZ)\") | .databaseId] | length" 2>/dev/null || echo 0)
if [ "$RECENT" -gt 0 ]; then
  echo "  ⚠️ $RECENT run(s) in last 5min — checking for collision..."
fi

# ── Dispatch ──────────────────────────────────────────────────────────────
echo ""
echo "🚀 Dispatching blog-publish.yml..."

ARGS="-f draft_path=${JA_PATH} -f platforms=${PLATFORMS} -f dry_run=false"
if [ -f "$EN_PATH" ]; then
  ARGS="$ARGS -f draft_path_en=${EN_PATH}"
fi

gh workflow run blog-publish.yml $ARGS
echo "✅ Dispatch OK"

# ── Wait + result ─────────────────────────────────────────────────────────
echo "⏳ Waiting for completion..."
until gh run list --workflow=blog-publish.yml --limit 1 \
  --json status --jq '.[0].status == "completed"' | grep -q true; do
  sleep 5
done

RUN_ID=$(gh run list --workflow=blog-publish.yml --limit 1 --json databaseId --jq '.[0].databaseId')
CONCLUSION=$(gh run list --workflow=blog-publish.yml --limit 1 --json conclusion --jq '.[0].conclusion')
echo "Run $RUN_ID: $CONCLUSION"

if [ "$CONCLUSION" = "success" ]; then
  # Extract URLs
  DEVTO_URL=$(gh run view --log --job=$(gh run view "$RUN_ID" --json jobs --jq '.jobs[0].databaseId') 2>&1 \
    | grep -oE "https://dev\.to/[a-zA-Z0-9_/-]+" | sort -u | head -1)
  QIITA_URL=$(gh run view --log --job=$(gh run view "$RUN_ID" --json jobs --jq '.jobs[0].databaseId') 2>&1 \
    | grep -oE "https://qiita\.com/[a-zA-Z0-9_/-]+" | sort -u | head -1)

  [ -n "$DEVTO_URL" ] && echo "  dev.to: $DEVTO_URL"
  [ -n "$QIITA_URL" ] && echo "  Qiita:  $QIITA_URL"

  # Merge orphan branch
  BRANCH="blog-publish/${RUN_ID}-*"
  git fetch origin && git branch -r | grep "blog-publish/${RUN_ID}" | while read -r B; do
    B="${B#origin/}"
    echo "  Merging $B..."
    git merge "origin/$B" --no-edit
    git pull --rebase origin main && git push origin HEAD:main
    git push origin --delete "$B" 2>/dev/null || true
  done
else
  echo "❌ Run failed. Check: gh run view $RUN_ID"
  exit 1
fi
