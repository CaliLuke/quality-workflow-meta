# Safety Manual

This manual explains how to use and adjust the development safeguards installed by the bootstrap. The installer is ephemeral and can self‑remove; all changes below remain as standard project files.

## What’s Installed
- Pre-commit hooks (Husky): lint-staged → typecheck → tests → complexity cap.
- Pre-push hook: full repo lint + typecheck.
- ESLint (flat) + TypeScript + Vite + Vitest baseline configs.
- GitHub Actions: CI (quality/tests/build) and a PR quality gate (FTA).
- Complexity tooling (FTA): scripts in `scripts/` and reports in `reports/`.

## Common Commands
- Lint: `npm run lint`
- Typecheck: `npm run typecheck`
- Tests: `npm run test`
- Full verification: `npm run verify`
- Generate complexity report (markdown): `npm run complexity:report`

## Adjusting Safeties
- Complexity thresholds (FTA):
  - Hard cap: set `FTA_HARD_CAP` (default `50`) in your CI vars or shell.
  - Delta threshold: set `FTA_DELTA_PCT` (default `10`).
  - Local pre-commit uses the hard cap via `scripts/check-fta-cap.mjs`.
- ESLint rule budget:
  - `complexity` rule is set to 15 (in `eslint.config.js`). Adjust as needed.
- Pre-commit behavior:
  - Hook at `.husky/pre-commit`. To temporarily skip: commit with `--no-verify` (not recommended for regular use).
- Quality gate PR behavior:
  - Workflow: `.github/workflows/quality-gate.yml`.
  - Compares FTA for changed TS/TSX files against base. Tune caps via repo/Org variables.
- Vite dev proxy:
  - Set `DEV_BACKEND_URL` to forward `/api` to your backend while running `npm run dev`.

## Disabling or Removing Pieces
- Temporarily disable hooks: `git commit --no-verify` or comment lines in `.husky/*`.
- Remove Husky entirely: delete `.husky/` and `prepare` script in `package.json`.
- Remove CI: delete workflows in `.github/workflows/`.
- Remove complexity checks: delete `scripts/check-fta-cap.mjs` and references from hooks and scripts.

## Keeping Things Fast
- Prefer small PRs; FTA and ESLint run faster on fewer changes.
- Cache dependencies in CI via `actions/setup-node@v4` with npm cache.

## Upgrades
- Update dev dependencies as usual (e.g., `npm i -D <pkg>@latest`).
- If you re-run the bootstrap in the future, it is idempotent and will merge rather than clobber.

---
Questions or adjustments you want standardized? Add them here so the team (or your AI helper) knows the intended guardrails.
