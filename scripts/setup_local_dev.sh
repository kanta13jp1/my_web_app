#!/usr/bin/env bash
set -euo pipefail

# Standardized local onboarding entrypoint for Supabase CLI + Flutter Web (#2724).
# Usage:
#   ./scripts/setup_local_dev.sh [--check] [--write-env] [--start-supabase] [--force] [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

DO_CHECK=false
DO_WRITE_ENV=false
DO_START_SUPABASE=false
DO_FORCE=false
DO_DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./scripts/setup_local_dev.sh [options]
  --check           Validate .fvm/fvm_config.json, supabase/config.toml, and templates
  --write-env       Generate .env.development using local defaults or running Supabase status
  --start-supabase  Run 'supabase start' and hydrate .env.development via stdin (no argv secret leaks)
  --force           Overwrite existing .env.development
  --dry-run         Preview actions without modifying files or starting containers
  --help            Show this message
EOF
}

while [ "$#" -gt 0 ]; do
  ARG="${1:-}"
  case "${ARG}" in
    --check)
      DO_CHECK=true
      ;;
    --write-env)
      DO_WRITE_ENV=true
      ;;
    --start-supabase)
      DO_START_SUPABASE=true
      DO_WRITE_ENV=true
      ;;
    --force)
      DO_FORCE=true
      ;;
    --dry-run)
      DO_DRY_RUN=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: ${ARG}" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "${DO_CHECK}" = false ] && [ "${DO_WRITE_ENV}" = false ]; then
  DO_CHECK=true
fi

PY_CMD="python3"
if ! command -v "${PY_CMD}" >/dev/null 2>&1; then
  PY_CMD="python"
fi

if [ "${DO_CHECK}" = true ]; then
  "${PY_CMD}" "${SCRIPT_DIR}/setup_local_dev.py" --check
fi

if [ "${DO_START_SUPABASE}" = true ]; then
  if [ "${DO_DRY_RUN}" = true ]; then
    echo "[dry-run] would run: supabase start && supabase status -o env | setup_local_dev.py --write-env --status-stdin"
  else
    supabase start
  fi
fi

if [ "${DO_WRITE_ENV}" = true ]; then
  PY_ARGS=(--write-env)
  if [ "${DO_FORCE}" = true ]; then
    PY_ARGS+=(--force)
  fi
  if [ "${DO_DRY_RUN}" = true ]; then
    PY_ARGS+=(--dry-run)
  fi

  if [ "${DO_START_SUPABASE}" = true ] && [ "${DO_DRY_RUN}" = false ]; then
    supabase status -o env | "${PY_CMD}" "${SCRIPT_DIR}/setup_local_dev.py" "${PY_ARGS[@]}" --status-stdin
  else
    "${PY_CMD}" "${SCRIPT_DIR}/setup_local_dev.py" "${PY_ARGS[@]}"
  fi
fi

echo "Local setup ready. Next: flutter pub get && flutter run -d chrome --dart-define-from-file=.env.development"
