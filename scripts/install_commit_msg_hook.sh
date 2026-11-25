#!/usr/bin/env bash
set -euo pipefail

# Install the local Git commit-msg hook into the resolved Git hooks directory
# (supporting both standard repositories and linked Git worktrees).

FORCE="false"
DRY_RUN="false"

usage() {
  cat <<'EOF'
Usage: scripts/install_commit_msg_hook.sh [--force] [--dry-run] [-h|--help]

Installs .git/hooks/commit-msg (via git rev-parse --git-path hooks) to invoke
scripts/check_commit_message.py on commit messages.
EOF
}

while [ "$#" -gt 0 ]; do
  case "${1:-}" in
    --force)
      FORCE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: ${1:-}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
RAW_HOOKS_DIR="$(git -C "${REPO_ROOT}" rev-parse --git-path hooks)"

case "${RAW_HOOKS_DIR}" in
  /*|[A-Za-z]:/*|[A-Za-z]:\\*)
    HOOKS_DIR="${RAW_HOOKS_DIR}"
    ;;
  *)
    HOOKS_DIR="${REPO_ROOT}/${RAW_HOOKS_DIR}"
    ;;
esac

HOOK_PATH="${HOOKS_DIR}/commit-msg"
MANAGED_MARKER="# Managed by scripts/install_commit_msg_hook.sh"

if [ -e "${HOOK_PATH}" ] && [ "${FORCE}" != "true" ]; then
  if ! grep -qF "${MANAGED_MARKER}" "${HOOK_PATH}"; then
    if [ "${DRY_RUN}" = "true" ]; then
      echo "[dry-run] Existing custom hook found at ${HOOK_PATH}; pass --force to overwrite."
      exit 0
    fi
    echo "Existing custom hook found at ${HOOK_PATH}; pass --force to overwrite." >&2
    exit 1
  fi
fi

if [ "${DRY_RUN}" = "true" ]; then
  echo "[dry-run] Would install commit-msg hook at: ${HOOK_PATH}"
  exit 0
fi

mkdir -p "${HOOKS_DIR}"
cat > "${HOOK_PATH}" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
# Managed by scripts/install_commit_msg_hook.sh

COMMIT_MSG_FILE="${1:-}"
if [ -z "${COMMIT_MSG_FILE}" ]; then
  echo "commit-msg hook requires commit message file path as argument 1." >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
else
  PYTHON_BIN="python"
fi

if [ -f "${REPO_ROOT}/scripts/check_no_verify_bypass.py" ]; then
  "${PYTHON_BIN}" "${REPO_ROOT}/scripts/check_no_verify_bypass.py" --message-file "${COMMIT_MSG_FILE}"
fi

exec "${PYTHON_BIN}" "${REPO_ROOT}/scripts/check_commit_message.py" --message-file "${COMMIT_MSG_FILE}"
HOOK

chmod +x "${HOOK_PATH}"
echo "Installed commit-msg hook: ${HOOK_PATH}"
