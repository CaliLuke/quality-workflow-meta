# Safety Manual

This manual explains how to use and adjust the development safeguards installed by the bootstrap. The installer is ephemeral and can self‑remove; all changes below remain as standard project files.

## What’s Installed
- Frontend projects:
  - Pre-commit hooks (Husky): lint-staged → typecheck → tests → complexity cap.
  - Pre-push hook: full repo lint + typecheck.
  - ESLint (flat) + TypeScript + Vite + Vitest baseline configs.
  - GitHub Actions: CI (quality/tests/build) and a PR quality gate (FTA).
  - Complexity tooling (FTA): scripts in `scripts/` and reports in `reports/`.
- Python projects:
  - Pre-commit (ruff, black, isort, mypy).
  - Tests (pytest).
  - Complexity gate (xenon; radon for reports).
  - Dependency management via `uv` (pyproject.toml with `[dependency-groups].dev`).
  - GitHub Actions: uv setup, sync, and checks.

## Common Commands
- Frontend:
  - Lint: `npm run lint`
  - Typecheck: `npm run typecheck`
  - Tests: `npm run test`
  - Full verification: `npm run verify`
  - Generate complexity report (markdown): `npm run complexity:report`
  - CI runs a full FTA baseline on every build and uploads `reports/fta.json`.
- Python:
  - Sync dev tools: `uv sync --all-groups`
  - Install hooks: `uv run pre-commit install`
  - Verify: `uv run scripts/python_verify.sh`

## Adjusting Safeties
- Frontend:
  - Complexity thresholds (FTA):
    - Hard cap: set `FTA_HARD_CAP` (default `50`) in your CI vars or shell.
    - Delta threshold: set `FTA_DELTA_PCT` (default `10`).
    - Local pre-commit uses the hard cap via `scripts/check-fta-cap.mjs`.
  - ESLint rule budget: `complexity` rule (in `eslint.config.js`) defaults to 15.
  - Pre-commit behavior: `.husky/pre-commit`. Temporary skip: `--no-verify`.
  - Quality gate: `.github/workflows/quality-gate.yml` compares only changed TS/TSX.
  - Vite dev proxy: set `DEV_BACKEND_URL` during `npm run dev`.
- Python:
  - Complexity: adjust xenon flags in `scripts/python_verify.sh` and CI (e.g., `--max-absolute B`).
  - mypy strictness: tune `[tool.mypy]` in `pyproject.toml`.
  - ruff/black/isort: configure under `[tool.ruff.*]`, `[tool.black]`, `[tool.isort]`.

## Disabling or Removing Pieces
- Temporarily disable hooks: `git commit --no-verify` or comment lines in `.husky/*`.
- Remove Husky entirely: delete `.husky/` and `prepare` script in `package.json`.
- Remove CI: delete workflows in `.github/workflows/`.
- Remove complexity checks: delete `scripts/check-fta-cap.mjs` and references from hooks and scripts.

## Keeping Things Fast
- Prefer small PRs; analysis runs faster on fewer changes.
- Frontend: cache via `actions/setup-node@v4` (npm cache).
- Python: uv handles lockless, fast installs in CI via `astral-sh/setup-uv`.

## Upgrades
- Update dev dependencies as usual (e.g., `npm i -D <pkg>@latest`).
- If you re-run the bootstrap in the future, it is idempotent and will merge rather than clobber.

---
Questions or adjustments you want standardized? Add them here so the team (or your AI helper) knows the intended guardrails.
