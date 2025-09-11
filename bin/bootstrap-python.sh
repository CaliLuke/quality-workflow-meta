#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap-python] Preparing Python safeguards (pre-commit, ruff/black/isort, mypy, pytest, xenon/radon, CI) with uv (pyproject.toml)."

# pyproject.toml (tool configs)
if [ ! -f pyproject.toml ]; then
cat > pyproject.toml << 'TOML'
[project]
name = "your-project"
version = "0.0.0"
requires-python = ">=3.11"
readme = "README.md"
dependencies = []

[dependency-groups]
dev = [
  "black==24.8.0",
  "ruff==0.6.9",
  "isort==5.13.2",
  "mypy==1.11.2",
  "pytest==8.3.3",
  "pytest-cov==5.0.0",
  "pre-commit==4.0.1",
  "radon==6.0.1",
  "xenon==0.9.2",
]

[tool.black]
line-length = 100
target-version = ["py311"]

[tool.isort]
profile = "black"
line_length = 100

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP"]
ignore = ["E203"]

[tool.mypy]
python_version = "3.11"
strict = true
ignore_missing_imports = true
warn_unused_ignores = true
warn_redundant_casts = true
warn_unused_configs = true

[tool.pytest.ini_options]
addopts = "-q --cov --cov-report=term-missing"
TOML
  echo "[bootstrap-python] Wrote pyproject.toml (uv-based)"
else
  echo "[bootstrap-python] pyproject.toml exists; leaving as-is. Consider adding [dependency-groups].dev with tooling if missing."
fi

# .pre-commit-config.yaml
if [ ! -f .pre-commit-config.yaml ]; then
cat > .pre-commit-config.yaml << 'YML'
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: ["--fix"]
      - id: ruff-format

  - repo: https://github.com/psf/black
    rev: 24.8.0
    hooks:
      - id: black

  - repo: https://github.com/pycqa/isort
    rev: 5.13.2
    hooks:
      - id: isort

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: end-of-file-fixer
      - id: trailing-whitespace

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.11.2
    hooks:
      - id: mypy
        additional_dependencies: []
YML
echo "[bootstrap-python] Wrote .pre-commit-config.yaml"
else
  echo "[bootstrap-python] .pre-commit-config.yaml exists; leaving as-is."
fi

# local verify script
mkdir -p scripts
if [ ! -f scripts/python_verify.sh ]; then
cat > scripts/python_verify.sh << 'SH'
#!/usr/bin/env bash
set -euo pipefail

RUN=""
if command -v uv >/dev/null 2>&1; then RUN="uv run "; fi

echo "[verify:py] Ruff (lint)" && ${RUN}ruff check . --fix
echo "[verify:py] Black (format check)" && ${RUN}black --check .
echo "[verify:py] Isort (imports check)" && ${RUN}isort --check-only .
echo "[verify:py] Mypy (type check)" && ${RUN}mypy .
echo "[verify:py] Pytest" && ${RUN}pytest
echo "[verify:py] Radon (cc report)" && ${RUN}radon cc -s -a . || true
echo "[verify:py] Xenon (complexity gate)" && ${RUN}xenon --max-absolute B --max-modules B --max-average B .
echo "[verify:py] OK"
SH
chmod +x scripts/python_verify.sh
fi

# CI workflow (uv-based)
mkdir -p .github/workflows
if [ ! -f .github/workflows/ci-python.yml ]; then
cat > .github/workflows/ci-python.yml << 'YML'
name: CI (Python)

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
        with:
          python-version: '3.11'
      - name: Sync (all groups)
        run: uv sync --all-groups
      - name: Lint & Typecheck
        run: |
          uv run ruff check .
          uv run black --check .
          uv run isort --check-only .
          uv run mypy .
      - name: Tests
        run: uv run pytest
      - name: Complexity Gate (xenon)
        run: uv run xenon --max-absolute B --max-modules B --max-average B .
YML
echo "[bootstrap-python] Wrote .github/workflows/ci-python.yml"
fi

# Manual (ensure docs exist and always create a base manual if missing)
mkdir -p docs
if [ ! -f docs/safety-manual.md ]; then
  cat > docs/safety-manual.md << 'BASE'
# Safety Manual

This manual explains how to use and adjust the development safeguards installed
by the bootstrap. It remains after the installer self-destructs.

## Common Commands
- Lint: `ruff check .` (Python) / `npm run lint` (Frontend)
- Typecheck: `mypy .` (Python) / `npm run typecheck` (Frontend)
- Tests: `pytest` (Python) / `npm run test` (Frontend)
BASE
fi

if ! grep -q "^## Python Variant" docs/safety-manual.md 2>/dev/null; then
  cat >> docs/safety-manual.md << 'MD'

## Python Variant
- Install dev tools: `uv sync --all-groups`
- Enable hooks: `uv run pre-commit install`
- Verify locally: `uv run scripts/python_verify.sh`
- Adjust complexity thresholds: tweak xenon flags (e.g., `--max-absolute B`).
- CI: `.github/workflows/ci-python.yml` runs lint, typecheck, tests, and xenon gate.
MD
fi

echo "[bootstrap-python] Complete. Next: 'uv sync --all-groups' && 'uv run pre-commit install' && 'uv run scripts/python_verify.sh'"

# Attempt to install pre-commit hooks automatically if available
if command -v uv >/dev/null 2>&1; then
  echo "[bootstrap-python] Detected uv; installing hooks via uv..."
  uv run pre-commit install || true
  uv run pre-commit install --hook-type commit-msg || true
  echo "[bootstrap-python] Pre-commit hooks installed (via uv)."
elif command -v pre-commit >/dev/null 2>&1; then
  echo "[bootstrap-python] Detected pre-commit, installing hooks..."
  pre-commit install || true
  pre-commit install --hook-type commit-msg || true
  echo "[bootstrap-python] Pre-commit hooks installed."
else
  echo "[bootstrap-python] 'uv' or 'pre-commit' not found on PATH. After syncing dev deps with uv, run: uv run pre-commit install"
fi

# Summary of created/updated paths (best-effort)
echo "[bootstrap-python] Created/updated files:"
printf '%s\n' \
  '  - pyproject.toml' \
  '  - .pre-commit-config.yaml' \
  '  - scripts/python_verify.sh' \
  '  - .github/workflows/ci-python.yml' \
  '  - docs/safety-manual.md'
