#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PM="${PM:-}"
if [ -z "$PM" ]; then
  if command -v bun >/dev/null 2>&1; then PM=bun
  elif command -v pnpm >/dev/null 2>&1; then PM=pnpm
  elif command -v yarn >/dev/null 2>&1; then PM=yarn
  else PM=bun; fi
fi

SELF_DESTRUCT="${SELF_DESTRUCT:-0}"

echo "[bootstrap] Using package manager: $PM"
echo "[bootstrap] Self-destruct after setup: ${SELF_DESTRUCT}"

"$SCRIPT_DIR/setup-npm.sh" "$PM"
"$SCRIPT_DIR/setup-eslint.sh"
"$SCRIPT_DIR/setup-ts-vite.sh"
"$SCRIPT_DIR/setup-complexity.sh"
"$SCRIPT_DIR/setup-husky.sh"
"$SCRIPT_DIR/setup-ci.sh"

# Ensure the manual is present
if [ ! -f docs/safety-manual.md ]; then
  mkdir -p docs
  cat > docs/safety-manual.md <<'MD'
# Safety Manual

See README “Getting Started” for commands. Adjust thresholds via env vars `FTA_HARD_CAP` and `FTA_DELTA_PCT`; change ESLint `complexity` and `sonarjs/cognitive-complexity` rules in `eslint.config.js`. Skip hooks with `--no-verify` (use sparingly).
MD
fi

echo "\n[bootstrap] Complete. Next: run '$PM install' and '$PM run verify'"

if [ "$SELF_DESTRUCT" = "1" ]; then
  echo "[bootstrap] Scheduling self-cleanup of bin/ installer scripts..."
  (
    sleep 1
    rm -rf "$SCRIPT_DIR" 2>/dev/null || true
  ) &
fi
