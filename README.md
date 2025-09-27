# Quality Workflow Meta

Enforce complexity, linting, tests, and CI so AI-written code stays decoupled, tractable, and commit-blocked until quality gates pass.

## Table of Contents
- [Quality Workflow Meta](#quality-workflow-meta)
  - [Table of Contents](#table-of-contents)
  - [Why?](#why)
  - [Features](#features)
  - [Installation](#installation)
      - [Notes](#notes)
  - [How It Works](#how-it-works)
  - [Manual for AI](#manual-for-ai)
    - [Agents.md](#agentsmd)
    - [JavaScript/TypeScript, Python, Rust](#javascripttypescript-python-rust)
  - [Configuration \& Thresholds](#configuration--thresholds)
  - [Best Fit](#best-fit)
  - [Troubleshooting](#troubleshooting)
  - [Contributing](#contributing)
  - [License](#license)

## Why?
- AI-generated code tends to be tightly coupled and overly complex, creating technical debt quickly.
- As complexity grows, agents struggle to reason about the code and bugs become hard to troubleshoot.
- Manually enforcing tests and linting fails in practice—agents routinely forget to run them.
- This repo automates complexity, lint, and test gates via hooks and CI so the agent must fix issues before commit/push, keeping code manageable at any size.

## Features
- Automated setup / self-destruct installer
- Code metrics and quality gates (FTA, ESLint + SonarJS cognitive complexity; xenon/radon for Python)
- Tests must pass before commit/push (Husky or pre-commit enforced)
- Leaves lightweight scripts and a Safety Manual under `docs/`
- Supports JavaScript/TypeScript (Vite/Vitest), Python (uv + pytest), and Rust (cargo fmt/clippy/test)

## Installation

See the docs for stack-specific installation and run instructions:
- JavaScript/TypeScript: `docs/install-javascript.md`
- Python: `docs/install-python.md`
- Rust: `docs/install-rust.md`

#### Notes

- Scripts are idempotent and won’t overwrite existing configs without cause.
- Default setup excludes Storybook/Docker/backend docs sync; add them later if needed. (Note from original README)
- Ephemeral mode removes the `bin/` installer after setup; the stack-specific Safety Manual remains under `docs/safety-manuals/` (for example `docs/safety-manuals/safety-manual-python.md`).
- Security: Always review install scripts before piping to `bash`.

## How It Works
- Runs once to scaffold configs, scripts, and hooks; leaves `docs/` and `scripts/` for ongoing use.
- Frontend: installs Husky hooks (`.husky/pre-commit`, `.husky/pre-push`), ESLint (+ SonarJS), TypeScript, Vite, Vitest, and FTA complexity tools.
- Python: writes `pyproject.toml`, `.pre-commit-config.yaml`, and CI; uses uv for tooling, pytest for tests, xenon/radon for complexity.
- Enforces tests and metrics locally: commits re-run lint, typecheck, tests, and FTA checks; pre-push runs lint + typecheck.
- CI mirrors local checks and uploads artifacts (coverage, analysis reports).

## Manual for AI

After installing, follow the stack guides for daily commands and gates:
- JavaScript/TypeScript: `docs/safety-manuals/safety-manual-javascript.md`
- Python: `docs/safety-manuals/safety-manual-python.md`
- Rust: `docs/safety-manuals/safety-manual-rust.md`

### Agents.md
- The installer will create or update `Agents.md` in your repo root with the relevant working agreement.
- The per-language agent working agreements also live in `docs/`:
  - JavaScript/TypeScript: `docs/agents-md/Agents-javascript.md`
  - Python: `docs/agents-md/Agents-python.md`
  - Rust: `docs/agents-md/Agents-rust.md`
  Use these as your project’s Agents.md baseline (copy to your repo root if desired).

### JavaScript/TypeScript, Python, Rust
For detailed runbooks (commands, gates, CI), use the stack-specific Safety Manuals listed above.

## Configuration & Thresholds

Frontend
- FTA hard cap: `FTA_HARD_CAP` env var (default 50). Used by `scripts/check-fta-cap.mjs` and CI.
- FTA delta percent: `FTA_DELTA_PCT` env var (default 10). Used by PR quality gate.
- ESLint complexity rules: in `eslint.config.js` set `complexity: ['error', 15]` and `sonarjs/cognitive-complexity: ['error', 15]`.
- Coverage thresholds: edit `vitest.config.ts` under `test.coverage.thresholds` (lines, functions, branches, statements; defaults start low at 20% lines).

Python
- Xenon thresholds: adjust flags in `scripts/python_verify.sh` and `.github/workflows/ci-python.yml` (e.g., `--max-absolute B`).
- Coverage threshold: in `pyproject.toml` under `[tool.pytest.ini_options].addopts` (`--cov-fail-under=20`). Ratchet up over time.
- Lint/format/type: tune `[tool.ruff.*]`, `[tool.black]`, `[tool.isort]`, `[tool.mypy]` in `pyproject.toml`.

Rust
- Clippy strictness: edit the command in `scripts/rust_verify.sh` and `.github/workflows/ci-rust.yml` (e.g., drop `--all-features` if unused or add denial lints).
- Audit requirements: install `cargo-audit` locally/CI to enforce vulnerability checks, or remove the hook/CI step if handled elsewhere.
- Test discovery guard: `scripts/rust_verify.sh` fails when `cargo test -- --list` finds no tests—keep at least one unit or integration test.
- Documentation build: adjust or remove the `cargo doc --no-deps` step if your workspace cannot build docs.

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
