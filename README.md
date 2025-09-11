# Quality Workflow Meta

A meta-repo to design and document setup scripts that let an AI bootstrap a production-grade repository (frontend or Python) with opinionated development safeguards.

## Goals
- Codify safeguards, tooling, and project hygiene into reusable setup scripts and docs.
- Make it trivial for an AI (or a human) to initialize a new repo with:
  - Pre-commit enforcement (Husky, lint-staged) and consistent lint/format rules.
  - TypeScript + Vite baseline, testing (Vitest), and Storybook for UI flows.
  - GitHub Actions-ready CI gates and reporting patterns.
  - Local dev ergonomics (env scaffolding, Docker support where useful).
  - Clear docs so the AI knows what to wire up and why.


## Deliverables (initial pass)
- Inventory of safeguards and conventions across supported stacks (frontend, Python).
- Minimal, idempotent setup scripts to reproduce those safeguards in a fresh repo.
- A short operator’s guide so an AI can reliably apply and verify the setup.

## Next Steps
- Maintain and refine the concrete checklists (hooks, CI, configs, tests, scripts).
- Decide which parts must be parameterized (app name, package manager, CI flavors, etc.).
- Implement a first end-to-end bootstrap flow and validate on a sample repo.

## Getting Started
- Prerequisites:
  - Frontend: Node.js 20+ and a package manager (npm/pnpm/yarn).
  - Python: Install uv (https://docs.astral.sh/uv/). Python 3.11+ recommended.

### Install uv
- macOS (Homebrew): `brew install uv`
- Linux/macOS (official script): `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Verify: `uv --version`
- Frontend (TypeScript/React):
  - Run: `bash bin/bootstrap-frontend.sh` (optionally select PM: `PM=pnpm bash bin/bootstrap-frontend.sh`)
  - Ephemeral mode (removes installer after setup): `SELF_DESTRUCT=1 bash bin/bootstrap-frontend.sh`
  - Install dev dependencies (pick one):
    - npm: `npm i -D eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh husky lint-staged vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom typescript vite @vitejs/plugin-react-swc vite-plugin-checker fta-cli`
    - pnpm: `pnpm add -D eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh husky lint-staged vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom typescript vite @vitejs/plugin-react-swc vite-plugin-checker fta-cli`
    - yarn: `yarn add -D eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh husky lint-staged vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom typescript vite @vitejs/plugin-react-swc vite-plugin-checker fta-cli`
  - Verify: `npm run verify`

- Python:
  - Run: `bash bin/bootstrap.sh --type python` (ephemeral via one‑shot below)
  - Sync dev tools (uv): `uv sync --all-groups`
  - Enable hooks: `uv run pre-commit install`
  - Verify: `uv run scripts/python_verify.sh`
  - Generate reports: `uv run scripts/python_reports.sh` (coverage.xml, htmlcov/, docs/analysis/*)

Notes
- Scripts are idempotent and won’t overwrite existing configs without cause.
- Default setup excludes Storybook/Docker/backend docs sync; you can add them later if needed.
 - Ephemeral mode removes the `bin/` installer scripts after setup; the Safety Manual remains at `docs/safety-manual.md`.

## One-Shot (curl | bash)
- You can run the installer without checking it into your repo:
  - Frontend: `bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type frontend --pm pnpm`
  - Python:   `bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type python`
  - With options: add `--ref <branch|tag>` or `--keep` to retain bin/ for inspection.
- Or copy `docs/one-shot-installer.sh` into your project and run:
  - `bash docs/one-shot-installer.sh --type frontend --pm npm` (defaults to self-destruct)
  - `bash docs/one-shot-installer.sh --type python`

Security note: Always review install scripts before piping to `bash`.

## Policies & CI Summary
- Test presence required (commit guards):
  - Frontend: pre-commit blocks commits if no test files exist (e.g., `src/**/*.test.ts`).
  - Python: pre-commit blocks commits if no pytest files exist (e.g., `tests/test_example.py`).
- Frontend CI:
  - Quality: lint + typecheck + full FTA baseline (fails when any file exceeds the hard cap; artifacts uploaded).
  - Tests (Vitest) with coverage artifacts (lcov + HTML) uploaded, and Build (Vite) jobs.
  - PR Quality Gate: delta-only FTA on changed TS/TSX files for review signal.
- Python CI:
  - uv setup + sync all groups.
  - Lint/format/imports (ruff/black/isort), typecheck (mypy), tests with coverage (XML + HTML).
  - Complexity: xenon gate; radon CC/RAW reports; artifacts uploaded (coverage.xml, htmlcov/, docs/analysis/*).

See `docs/safety-manual.md` for tuning options, thresholds, and common commands.

## License
This project is licensed under the MIT License (see `LICENSE`). MIT permits use and modification as long as attribution is retained.
