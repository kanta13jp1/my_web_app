#!/usr/bin/env bash
# DIY crash-safe Markdown agent memory hook for CI / headless environments (#2709).
# Captures PostToolUse / Stop / task completion decisions into Git-tracked Markdown
# without SQLite or Bun background daemons, preserving git-blame provenance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PY_SCRIPT="${REPO_ROOT}/scripts/ci_markdown_memory.py"

MEMORY_FILE="${CI_MEMORY_FILE:-memory/ci_agent_ledger/ci_events.md}"
AGENT_NAME="${CI_MEMORY_AGENT:-ci-agent}"
DECISION="${CI_MEMORY_DECISION:-}"
TOOL_NAME="${CI_MEMORY_TOOL:-none}"
OUTCOME="${CI_MEMORY_OUTCOME:-ok}"
SUMMARY="${CI_MEMORY_SUMMARY:-}"
RUN_ID="${GITHUB_RUN_ID:-local}"
CHANGED_FILES="${CI_MEMORY_CHANGED_FILES:-}"
DO_COMMIT=false
DO_PUSH=false
DO_RECOVER=false
DO_AUDIT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --memory-file) MEMORY_FILE="$2"; shift 2 ;;
    --agent) AGENT_NAME="$2"; shift 2 ;;
    --decision) DECISION="$2"; shift 2 ;;
    --tool) TOOL_NAME="$2"; shift 2 ;;
    --outcome) OUTCOME="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --changed-files) CHANGED_FILES="$2"; shift 2 ;;
    --commit) DO_COMMIT=true; shift ;;
    --push) DO_PUSH=true; shift ;;
    --recover) DO_RECOVER=true; shift ;;
    --audit-blame) DO_AUDIT=true; shift ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

PYTHON_BIN="python3"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

if [[ "$DO_RECOVER" == "true" && -z "$DECISION" && -z "$SUMMARY" ]]; then
  exec "$PYTHON_BIN" -B "$PY_SCRIPT" \
    --repo-root "$REPO_ROOT" \
    --memory-file "$MEMORY_FILE" \
    --recover
fi

if [[ "$DO_AUDIT" == "true" ]]; then
  exec "$PYTHON_BIN" -B "$PY_SCRIPT" \
    --repo-root "$REPO_ROOT" \
    --memory-file "$MEMORY_FILE" \
    --audit-blame
fi

CMD=(
  "$PYTHON_BIN" -B "$PY_SCRIPT"
  --repo-root "$REPO_ROOT"
  --memory-file "$MEMORY_FILE"
  --agent "$AGENT_NAME"
  --decision "${DECISION:-auto_capture}"
  --tool "$TOOL_NAME"
  --outcome "$OUTCOME"
  --summary "$SUMMARY"
  --run-id "$RUN_ID"
  --changed-files "$CHANGED_FILES"
  --hook-stdin
)

if [[ "$DO_COMMIT" == "true" ]]; then
  CMD+=(--commit)
fi
if [[ "$DO_PUSH" == "true" ]]; then
  CMD+=(--push)
fi

exec "${CMD[@]}"
