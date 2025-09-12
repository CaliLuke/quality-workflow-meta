#!/usr/bin/env bash
set -euo pipefail

# One-shot ephemeral installer. Run inside your existing repo.
# It clones the bootstrap scripts to a temp dir, runs them with SELF_DESTRUCT=1,
# and cleans up. After completion, only the safeguards and docs remain.

# Defaults (override via flags or env)
REPO_URL="${REPO_URL:-https://github.com/CaliLuke/quality-workflow-meta.git}"
REPO_REF="${REPO_REF:-main}"
PM_FLAG="${PM:-}"
TYPE_FLAG="${TYPE:-frontend}"
SELF_DESTRUCT="${SELF_DESTRUCT:-1}"

usage() {
  cat <<USAGE
Usage: one-shot-installer.sh [options]

Options:
  --repo <url>        Source repo for bootstrap scripts (default: ${REPO_URL})
  --ref <git-ref>     Git ref/branch/tag to use         (default: ${REPO_REF})
  --pm <bun|pnpm|yarn> Package manager to assume         (default: auto-detect)
  --type <frontend|python> Select installer path         (default: frontend)
  --keep              Do NOT self-destruct install scripts after setup
  -h, --help          Show this help

Env vars:
  REPO_URL, REPO_REF, PM, SELF_DESTRUCT=0|1

Run inside your target project directory.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO_URL="$2"; shift 2;;
    --ref) REPO_REF="$2"; shift 2;;
    --pm) PM_FLAG="$2"; shift 2;;
    --type) TYPE_FLAG="$2"; shift 2;;
    --keep) SELF_DESTRUCT=0; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 2;;
  esac
done

# Validate type early for clearer feedback
case "$TYPE_FLAG" in
  frontend|python) ;;
  *)
    echo "[one-shot] Unsupported --type: '$TYPE_FLAG'. Use 'frontend' or 'python'." >&2
    exit 2
    ;;
esac

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t qwm-installer)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "[one-shot] Cloning ${REPO_URL}@${REPO_REF} to temp..."
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_DIR/repo" 1>&2

if [ ! -d "$TMP_DIR/repo/bin" ]; then
  echo "[one-shot] Missing bin/ in source repo; aborting." >&2
  exit 1
fi

echo "[one-shot] Copying installer into project..."
cp -R "$TMP_DIR/repo/bin" ./

PM_ENV=""; if [ -n "$PM_FLAG" ]; then PM_ENV="PM=$PM_FLAG"; fi
SD_ENV="SELF_DESTRUCT=$SELF_DESTRUCT"
echo "[one-shot] Running bootstrap (ephemeral=${SELF_DESTRUCT})..."
if [ "$TYPE_FLAG" = "python" ]; then
  echo "[one-shot] Selected type=python"
  env $PM_ENV $SD_ENV TYPE=python bash ./bin/bootstrap.sh --type python
else
  echo "[one-shot] Selected type=frontend"
  env $PM_ENV $SD_ENV TYPE=frontend bash ./bin/bootstrap.sh --type frontend
fi

# Defensive cleanup if SELF_DESTRUCT didn't remove bin/
# Defensive cleanup if SELF_DESTRUCT didn't remove bin/
if [ "$SELF_DESTRUCT" = "1" ] && [ -d ./bin ]; then
  echo "[one-shot] Removing leftover installer (bin/)..."
  rm -rf ./bin || true
fi

# Post-run verification for expected artifacts
if [ "$TYPE_FLAG" = "python" ]; then
  echo "[one-shot] Verifying Python bootstrap artifacts..."
  missing=0
  for f in pyproject.toml .pre-commit-config.yaml .github/workflows/ci-python.yml; do
    if [ ! -f "$f" ]; then echo "[one-shot] Missing: $f"; missing=1; fi
  done
  if [ $missing -eq 1 ]; then
    echo "[one-shot] Warning: Some Python artifacts were not found. Check the logs above or re-run with --keep to inspect bin/." >&2
  fi
else
  echo "[one-shot] Verifying Frontend bootstrap artifacts..."
  missing=0
  for f in package.json eslint.config.js .github/workflows/ci.yml; do
    if [ ! -f "$f" ]; then echo "[one-shot] Missing: $f"; missing=1; fi
  done
  if [ $missing -eq 1 ]; then
    echo "[one-shot] Warning: Some Frontend artifacts were not found. Check the logs above or re-run with --keep to inspect bin/." >&2
  fi
fi

# Print stack-specific next steps based on files present (robust to arg parsing)
if [ -f pyproject.toml ] && [ -f .pre-commit-config.yaml ]; then
  cat <<'EON'

[one-shot] Done.

Next steps (Python):
- Install dev tools (uv):
  uv sync --all-groups
- Enable hooks:
  uv run pre-commit install
- Verify locally:
  uv run scripts/python_verify.sh
- Adjust safeties: see docs/safety-manual.md (should now exist)
  - Also review: pyproject.toml, .pre-commit-config.yaml, .github/workflows/ci-python.yml
EON
elif [ -f package.json ] || [ -f eslint.config.js ]; then
  cat <<'EON'

[one-shot] Done.

Next steps (Frontend):
- Install dev dependencies (bun):
  bun add -d eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh \
    husky lint-staged vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event \
    jsdom typescript vite @vitejs/plugin-react-swc vite-plugin-checker fta-cli
- Verify:
  bun run verify
- Adjust safeties: see docs/safety-manual.md (should now exist)
EON
else
  cat <<'EON'

[one-shot] Done.

Next steps:
- Review docs/safety-manual.md
- Confirm expected files were created (Python or Frontend stack). Re-run with the desired --type if needed.
EON
fi
