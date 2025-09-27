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
mkdir -p docs/safety-manuals
if [ ! -f docs/safety-manuals/safety-manual-javascript.md ]; then
  cat > docs/safety-manuals/safety-manual-javascript.md <<'MD'
# Safety Manual (JavaScript/TypeScript)

This project is bootstrapped with Husky hooks, ESLint, TypeScript, Vitest, and FTA complexity gates. These safeguards block commits or CI when quality bars are missed.

## Installed Safeguards
- Pre-commit (Husky) runs lint-staged, typecheck, tests, and the FTA complexity cap.
- Pre-push hook re-runs `bun run lint` and `bun run typecheck`.
- ESLint (flat config) with SonarJS cognitive complexity and classic `complexity` rules.
- Vitest with coverage thresholds and an FTA complexity JSON report.
- GitHub Actions workflows for CI and the PR quality gate.

## Common Commands
- Install deps: `bun install`
- Full gate: `bun run verify`
- Lint only: `bun run lint`
- Typecheck: `bun run typecheck`
- Tests: `bun run test`
- Complexity report: `bun run complexity:report`

## Adjusting Safeguards
- Hard complexity cap: set `FTA_HARD_CAP` (default 50) before running checks or in CI.
- Complexity delta budget: set `FTA_DELTA_PCT` (default 10) for the PR quality gate.
- ESLint budgets: tweak `complexity` or `sonarjs/cognitive-complexity` in `eslint.config.js` (default 15).
- Coverage: raise thresholds in `vitest.config.ts` under `test.coverage.thresholds` as the suite grows.

## Disabling or Removing
- Temporary hook skip: `git commit --no-verify` (use sparingly and document why).
- Remove Husky: delete `.husky/` and the `prepare` script from `package.json`.
- Remove complexity checks: delete scripts under `scripts/` beginning with `fta-` and update hooks/CI accordingly.

## Keeping It Fast
- Prefer small commits so FTA analysis completes quickly.
- Cache dependencies in CI via `oven-sh/setup-bun` for reproducible installs.

## Upgrades
- Update dev dependencies with `bun add -d <pkg>@latest`.
- Re-run the bootstrap anytime; it is idempotent and will not overwrite manual edits.
MD
fi

# Ensure Agents.md exists or append JS/TS agreement if present already
DEST="Agents.md"; if [ -f AGENTS.md ] && [ ! -f "$DEST" ]; then DEST="AGENTS.md"; fi
JS_HEADER="# Agents.md (JavaScript/TypeScript)"
if [ ! -f "$DEST" ]; then
  cat > "$DEST" <<'AG'
# Agents.md (JavaScript/TypeScript)

Use this working agreement to guide agent behavior in JS/TS repos.

## Agent Working Agreement
1. Never skip checks
   - Do not run `git commit --no-verify`, set `HUSKY=0`, remove/alter hooks, or bypass CI without explicit human approval.
2. Always run the full local gate before commit
   - `bun run complexity:json && bun scripts/check-fta-cap.mjs && bun run test`
   - Or run the consolidated gate: `bun run verify` (if configured)
3. When blocked by hooks or tests, stop and report
   - Paste the failing command and the top relevant error output.
   - Propose a fix and request confirmation if risky.
4. Do not weaken thresholds or disable lint rules to pass
   - Do not raise `FTA_HARD_CAP` or lower coverage thresholds without approval.
   - Do not comment out tests to increase pass rate.
5. Keep changes small and incremental
   - Re-run checks after each change; prefer short, reviewable diffs.

Related docs: `docs/safety-manuals/safety-manual-javascript.md`
AG
  echo "[bootstrap] Wrote $DEST (JS/TS policy)"
else
  if ! grep -q "^# Agents.md (JavaScript/TypeScript)" "$DEST" 2>/dev/null; then
    printf '\n\n%s\n' "$JS_HEADER" >> "$DEST"
    cat >> "$DEST" <<'AG'

Use this working agreement to guide agent behavior in JS/TS repos.

## Agent Working Agreement
1. Never skip checks
   - Do not run `git commit --no-verify`, set `HUSKY=0`, remove/alter hooks, or bypass CI without explicit human approval.
2. Always run the full local gate before commit
   - `bun run complexity:json && bun scripts/check-fta-cap.mjs && bun run test`
   - Or run the consolidated gate: `bun run verify` (if configured)
3. When blocked by hooks or tests, stop and report
   - Paste the failing command and the top relevant error output.
   - Propose a fix and request confirmation if risky.
4. Do not weaken thresholds or disable lint rules to pass
   - Do not raise `FTA_HARD_CAP` or lower coverage thresholds without approval.
   - Do not comment out tests to increase pass rate.
5. Keep changes small and incremental
   - Re-run checks after each change; prefer short, reviewable diffs.

Related docs: `docs/safety-manuals/safety-manual-javascript.md`
AG
    echo "[bootstrap] Appended JS/TS policy to $DEST"
  else
    echo "[bootstrap] $DEST already contains JS/TS policy; leaving as-is."
  fi
fi

# Summary of created/updated paths (best-effort)
echo "[bootstrap] Created/updated files:"
printf '%s\n' \
  '  - docs/safety-manuals/safety-manual-javascript.md' \
  '  - Agents.md (created/updated)'

echo "\n[bootstrap] Complete. Next: run '$PM install' and '$PM run verify'"

if [ "$SELF_DESTRUCT" = "1" ]; then
  echo "[bootstrap] Scheduling self-cleanup of bin/ installer scripts..."
  (
    sleep 1
    rm -rf "$SCRIPT_DIR" 2>/dev/null || true
  ) &
fi
