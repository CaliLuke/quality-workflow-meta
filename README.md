# Quality Workflow Meta

Enforce complexity, linting, tests, and CI so AI-written code stays decoupled, tractable, and commit-blocked until quality gates pass.

**Why?**
- AI-generated code tends to be tightly coupled and overly complex, creating technical debt quickly.
- As complexity grows, agents struggle to reason about the code and bugs become hard to troubleshoot.
- Manually enforcing tests and linting fails in practice—agents routinely forget to run them.
- This repo automates complexity, lint, and test gates via hooks and CI so the agent must fix issues before commit/push, keeping code manageable at any size.

**Features**
- Automated setup / self-destruct installer
- Code metrics and quality gates (FTA, ESLint complexity; xenon/radon for Python)
- Tests must pass before commit/push (Husky or pre-commit enforced)
- Leaves lightweight scripts and a Safety Manual under `docs/`
- Supports JavaScript/TypeScript (Vite/Vitest) and Python (uv + pytest)

## Installation

Quick start (one-shot, no checkout):

```
# Frontend
bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type frontend --pm bun

# Python
bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type python
```

What happens
- Copies `bin/` installer into your repo, runs the selected bootstrap, and (by default) self-destructs the installer.
- Adds Git hooks and baseline configs; scaffolds CI workflows under `.github/workflows/`.
- Writes docs and analysis helpers under `docs/` and `scripts/`.
- Safe to revert: changes are standard files; remove or edit as needed.

Suggested workflow
- Create a feature branch.
- Run the installer (one-shot or local `bin/`).
- Review diffs, run local checks, and commit.
- Merge or delete the branch if undesired.

Alternatives
- Run from a local checkout of this repo:
  - Frontend (TypeScript/React):
    - `bash bin/bootstrap-frontend.sh`
    - Ephemeral mode: `SELF_DESTRUCT=1 bash bin/bootstrap-frontend.sh`
    - Use a specific package manager: `PM=pnpm bash bin/bootstrap-frontend.sh`
    - Install dev dependencies (pick one):
      - bun: `bun add -d eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh husky lint-staged vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom typescript vite @vitejs/plugin-react-swc vite-plugin-checker fta-cli`
      - pnpm: `pnpm add -D eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh husky lint-staged vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom typescript vite @vitejs/plugin-react-swc vite-plugin-checker fta-cli`
      - yarn: `yarn add -D eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh husky lint-staged vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom typescript vite @vitejs/plugin-react-swc vite-plugin-checker fta-cli`
    - Verify: `bun run verify`
  - Python:
    - `bash bin/bootstrap.sh --type python` (ephemeral via one‑shot above)
    - Sync dev tools (uv): `uv sync --all-groups`
    - Enable hooks: `uv run pre-commit install`
    - Verify: `uv run scripts/python_verify.sh`
    - Reports: `uv run scripts/python_reports.sh` (coverage.xml, `htmlcov/`, `docs/analysis/*`)
- Or copy `docs/one-shot-installer.sh` into your project and run:
  - `bash docs/one-shot-installer.sh --type frontend --pm bun` (defaults to self-destruct)
  - `bash docs/one-shot-installer.sh --type python`

Notes (from original README, clarified)
- Scripts are idempotent and won’t overwrite existing configs without cause.
- Default setup excludes Storybook/Docker/backend docs sync; add them later if needed. (Note from original README)
- Ephemeral mode removes the `bin/` installer after setup; the Safety Manual remains at `docs/safety-manual.md`.
- Security: Always review install scripts before piping to `bash`.

## How It Works
- Runs once to scaffold configs, scripts, and hooks; leaves `docs/` and `scripts/` for ongoing use.
- Frontend: installs Husky hooks (`.husky/pre-commit`, `.husky/pre-push`), ESLint, TypeScript, Vite, Vitest, and FTA complexity tools.
- Python: writes `pyproject.toml`, `.pre-commit-config.yaml`, and CI; uses uv for tooling, pytest for tests, xenon/radon for complexity.
- Enforces tests and metrics locally: commits re-run lint, typecheck, tests, and FTA checks; pre-push runs lint + typecheck.
- CI mirrors local checks and uploads artifacts (coverage, analysis reports).

## Manual for AI

This section defines exactly what an AI (or a human) should do before committing or pushing changes. It starts with a common install step, then provides stack-specific flows.

Quick Navigation
- [Common Setup (Install Bootstrap)](#common-setup-install-bootstrap)
- [JavaScript/TypeScript](#javascripttypescript)
- [Python](#python)

### Common Setup (Install Bootstrap)
- Create a feature branch, then install the safeguards in your repo using one of:
```
# Frontend (JavaScript/TypeScript)
bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type frontend --pm bun

# Python
bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type python
```
- The installer is ephemeral by default (self-destructs) and leaves standard files (hooks/configs/scripts) plus `docs/safety-manual.md`.
- After install, follow the appropriate stack section below.

### JavaScript/TypeScript

Prerequisites
- Node.js 20+ and a package manager (bun/pnpm/yarn). Install Bun v1+.

Steps
1) Run metrics
```
bun run complexity:json
bun scripts/check-fta-cap.mjs
```
Pass/Fail
- Pass: proceed to tests. Output includes `[FTA] All files under cap (X).`
- Fail: commit blocked by complexity. Report: `FTA hard cap exceeded` and list offending files from `scripts/check-fta-cap.mjs`. Suggest refactoring or lowering complexity before continuing.

2) Run tests
```
bun run test
```
Pass/Fail
- Pass: proceed to commit.
- Fail: report which tests failed (Vitest output). Do not commit until passing.

3) Commit (hook rechecks)
```
git add -A
git commit -m "<message>"
```
Hook behavior
- Pre-commit runs: lint-staged → typecheck → tests → FTA cap. If no tests exist, commit fails with: `No test files found (e.g., src/**/*.test.ts). Add at least one test before committing.`
- On FTA failure, commit fails with offending files and scores.

4) Pre-push checks
```
bun run lint
bun run typecheck
```

5) Push
```
git push
```

If your project uses different scripts, run them in the analogous step. For example, replace `bun run test` with your project’s test command. (Clarify: do not invent scripts; use actual ones in your repo.)

Related config files (JS/TS)
- `eslint.config.js`, `vitest.config.ts`, `.husky/*`, `scripts/check-fta-cap.mjs`, `scripts/compare-fta.mjs`, `scripts/generate-complexity-report.mjs`.

### Python

Prerequisites
- Python 3.11+ recommended.
- Install uv (https://docs.astral.sh/uv/):
  - macOS (Homebrew): `brew install uv`
  - Linux/macOS (official): `curl -LsSf https://astral.sh/uv/install.sh | sh`
  - Verify: `uv --version`

Steps
1) Run metrics (and reports)
```
uv sync --all-groups
uv run scripts/python_reports.sh
```
Pass/Fail
- Non-blocking reports write to: `coverage.xml`, `htmlcov/`, `docs/analysis/*.txt`. For a blocking gate locally, run the verify script (next step).

2) Run tests and gates
```
uv run scripts/python_verify.sh
```
What it does
- Ensures at least one pytest file exists; otherwise exits with: `[verify:py] No pytest files found (e.g., tests/test_example.py). Add tests before committing.`
- Runs ruff, black (check), isort (check-only), mypy, pytest, radon cc (non-blocking), and xenon (blocking complexity gate `--max-absolute B --max-modules B --max-average B`).
Pass/Fail
- Pass: proceed to commit.
- Fail: report the first failing tool and its output; do not commit.

3) Commit (hooks)
```
git add -A
git commit -m "<message>"
```
Hook behavior
- After `uv run pre-commit install`, pre-commit enforces ruff/black/isort/mypy and a test-existence check on commit.

4) Pre-push checks (optional but recommended)
```
uv run scripts/python_verify.sh
```

5) Push
```
git push
```

Related config files (Python)
- `pyproject.toml`, `.pre-commit-config.yaml`, `scripts/python_verify.sh`, `scripts/python_reports.sh`.

## Configuration & Thresholds

Frontend
- FTA hard cap: `FTA_HARD_CAP` env var (default 50). Used by `scripts/check-fta-cap.mjs` and CI.
- FTA delta percent: `FTA_DELTA_PCT` env var (default 10). Used by PR quality gate.
- ESLint complexity rule: set in `eslint.config.js` (`complexity: ['error', 15]`).
- Coverage thresholds: edit `vitest.config.ts` under `test.coverage.thresholds` (lines, functions, branches, statements; defaults start low at 20% lines).

Python
- Xenon thresholds: adjust flags in `scripts/python_verify.sh` and `.github/workflows/ci-python.yml` (e.g., `--max-absolute B`).
- Coverage threshold: in `pyproject.toml` under `[tool.pytest.ini_options].addopts` (`--cov-fail-under=20`). Ratchet up over time.
- Lint/format/type: tune `[tool.ruff.*]`, `[tool.black]`, `[tool.isort]`, `[tool.mypy]` in `pyproject.toml`.

Example changes
- Increase FTA hard cap temporarily for a branch:
```
export FTA_HARD_CAP=60
bun run complexity:json && bun scripts/check-fta-cap.mjs
```
- Raise Vitest coverage lines from 20 to 30 in `vitest.config.ts`:
```
# In vitest.config.ts
thresholds: {
  lines: 30,
  functions: 20,
  branches: 10,
  statements: 20,
},
```
- Increase Python coverage to 40 in `pyproject.toml`:
```
# In pyproject.toml
[tool.pytest.ini_options]
addopts = "-q --cov --cov-report=term-missing:skip-covered --cov-report=xml:coverage.xml --cov-report=html:htmlcov --cov-fail-under=40"
```

## Best Fit
- Projects started without safeguards that need a quick, enforceable baseline.
- Repos where AI agents make substantial changes and must be gated.
- Teams wanting local quality gates before CI or alongside it.

## Troubleshooting

Common issues and fixes
- Tests missing (Frontend): pre-commit fails with: `No test files found (e.g., src/**/*.test.ts).` Add at least one test file.
- FTA cap exceeded: `scripts/check-fta-cap.mjs` lists offending files. Refactor or temporarily raise `FTA_HARD_CAP` with caution.
- Hooks not firing (Frontend): ensure Husky is installed and `prepare` exists in `package.json` (run `bunx husky` or re-run bootstrap). Files: `.husky/pre-commit`, `.husky/pre-push`.
- Hooks not installed (Python): run `uv run pre-commit install`. Ensure `.pre-commit-config.yaml` is present.
- CI failures (Frontend): check `.github/workflows/ci.yml` and `quality-gate.yml` logs; ensure devDependencies installed and FTA artifacts generated (`reports/fta.json`).
- CI failures (Python): review `.github/workflows/ci-python.yml`. Coverage under threshold or xenon gate failing; adjust in `pyproject.toml` or xenon flags if appropriate.

(Note from original README) Default setup excludes Storybook/Docker/backend docs sync; add later if needed.

## Contributing
- Issues and PRs are welcome. Useful areas: additional languages/stacks, improved reports, better defaults for thresholds, and documentation upgrades.

## License
This project is licensed under the MIT License (see `LICENSE`). MIT permits use and modification as long as attribution is retained.
