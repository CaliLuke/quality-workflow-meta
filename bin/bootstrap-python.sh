#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap-python] Preparing Python safeguards (pre-commit, ruff/black/isort, mypy, pytest, xenon/radon, CI)."

# requirements-dev.txt
if [ ! -f requirements-dev.txt ]; then
cat > requirements-dev.txt << 'REQ'
black==24.8.0
ruff==0.6.9
isort==5.13.2
mypy==1.11.2
pytest==8.3.3
pytest-cov==5.0.0
pre-commit==4.0.1
radon==6.0.1
xenon==0.9.2
REQ
echo "[bootstrap-python] Wrote requirements-dev.txt"
else
  echo "[bootstrap-python] requirements-dev.txt exists; leaving as-is."
fi

# pyproject.toml (tool configs)
if [ ! -f pyproject.toml ]; then
cat > pyproject.toml << 'TOML'
[tool.black]
line-length = 100
target-version = ["py311"]

[tool.isort]
profile = "black"
line_length = 100

[tool.ruff]
line-length = 100
target-version = "py311"
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
echo "[bootstrap-python] Wrote pyproject.toml"
else
  echo "[bootstrap-python] pyproject.toml exists; leaving as-is."
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

echo "[verify:py] Ruff (lint)" && ruff check . --fix
echo "[verify:py] Black (format check)" && black --check .
echo "[verify:py] Isort (imports check)" && isort --check-only .
echo "[verify:py] Mypy (type check)" && mypy .
echo "[verify:py] Pytest" && pytest
echo "[verify:py] Radon (cc report)" && radon cc -s -a . || true
echo "[verify:py] Xenon (complexity gate)" && xenon --max-absolute B --max-modules B --max-average B .
echo "[verify:py] OK"
SH
chmod +x scripts/python_verify.sh
fi

# CI workflow
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
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'
      - name: Install dev deps
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements-dev.txt
      - name: Lint & Typecheck
        run: |
          ruff check .
          black --check .
          isort --check-only .
          mypy .
      - name: Tests
        run: pytest
      - name: Complexity Gate (xenon)
        run: xenon --max-absolute B --max-modules B --max-average B .
YML
echo "[bootstrap-python] Wrote .github/workflows/ci-python.yml"
fi

# Manual
mkdir -p docs
if ! grep -q "## Python Variant" docs/safety-manual.md 2>/dev/null; then
cat >> docs/safety-manual.md << 'MD'

## Python Variant
- Install dev tools: `pip install -r requirements-dev.txt`
- Enable hooks: `pre-commit install`
- Verify locally: `scripts/python_verify.sh`
- Adjust complexity thresholds: tweak xenon flags (e.g., `--max-absolute B`).
- CI: `.github/workflows/ci-python.yml` runs lint, typecheck, tests, and xenon gate.
MD
fi

echo "[bootstrap-python] Complete. Next: pip install -r requirements-dev.txt && pre-commit install && scripts/python_verify.sh"

# Attempt to install pre-commit hooks automatically if available
if command -v pre-commit >/dev/null 2>&1; then
  echo "[bootstrap-python] Detected pre-commit, installing hooks..."
  pre-commit install || true
  pre-commit install --hook-type commit-msg || true
  echo "[bootstrap-python] Pre-commit hooks installed."
else
  echo "[bootstrap-python] 'pre-commit' not found on PATH. After installing dev deps, run: pre-commit install"
fi
