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
addopts = "-q --cov --cov-report=term-missing:skip-covered --cov-report=xml:coverage.xml --cov-report=html:htmlcov --cov-fail-under=20"
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

  - repo: local
    hooks:
      - id: ensure-tests-exist
        name: Ensure tests exist
        entry: python scripts/ensure_tests_exist.py
        language: system
        pass_filenames: false
        always_run: true
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

# Require at least one pytest file to exist
if ! find tests -type f \( -name 'test_*.py' -o -name '*_test.py' \) 2>/dev/null | grep -q .; then
  echo "[verify:py] No pytest files found (e.g., tests/test_example.py). Add tests before committing." >&2
  exit 1
fi

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

# local test-existence checker used by pre-commit
if [ ! -f scripts/ensure_tests_exist.py ]; then
cat > scripts/ensure_tests_exist.py << 'PY'
import os, sys

def has_tests():
    for root, _, files in os.walk('tests'):
        for f in files:
            if (f.startswith('test_') and f.endswith('.py')) or f.endswith('_test.py'):
                return True
    return False

if not has_tests():
    print("[pre-commit] No tests found in 'tests/'. Add at least one (e.g., tests/test_example.py).", file=sys.stderr)
    sys.exit(1)
PY
fi

# local reports script (complexity + coverage artifacts)
if [ ! -f scripts/python_reports.sh ]; then
cat > scripts/python_reports.sh << 'SH'
#!/usr/bin/env bash
set -euo pipefail

RUN=""
if command -v uv >/dev/null 2>&1; then RUN="uv run "; fi

mkdir -p docs/analysis

echo "[reports:py] Pytest with coverage (XML + HTML)"
${RUN}pytest -q --cov --cov-report=term-missing:skip-covered --cov-report=xml:coverage.xml --cov-report=html:htmlcov || true

echo "[reports:py] Radon (cc) → docs/analysis/radon-cc.txt"
${RUN}radon cc -s -a . | tee docs/analysis/radon-cc.txt || true

echo "[reports:py] Radon (raw) → docs/analysis/radon-raw.txt"
${RUN}radon raw -s . | tee docs/analysis/radon-raw.txt || true

echo "[reports:py] Xenon gate (non-blocking for reports) → docs/analysis/xenon.txt"
${RUN}xenon --max-absolute B --max-modules B --max-average B . | tee docs/analysis/xenon.txt || true

echo "[reports:py] Done. Artifacts: coverage.xml, htmlcov/, docs/analysis/*.txt"
SH
chmod +x scripts/python_reports.sh
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
      - name: Tests + Coverage (XML + HTML)
        run: uv run pytest -q --cov --cov-report=term-missing:skip-covered --cov-report=xml:coverage.xml --cov-report=html:htmlcov --cov-fail-under=20
      - name: Complexity Gate (xenon)
        run: uv run xenon --max-absolute B --max-modules B --max-average B .
      - name: Radon reports (cc, raw)
        if: ${{ always() }}
        run: |
          mkdir -p docs/analysis
          uv run radon cc -s -a . | tee docs/analysis/radon-cc.txt || true
          uv run radon raw -s . | tee docs/analysis/radon-raw.txt || true
      - name: CI summary (coverage excerpt)
        if: ${{ always() }}
        run: |
          echo '### Python Coverage' >> "$GITHUB_STEP_SUMMARY"
          # Print a brief summary to the step summary
          uv run pytest -q --cov --cov-report=term-missing:skip-covered | tail -n 30 >> "$GITHUB_STEP_SUMMARY" || true
      - name: Upload coverage + analysis artifacts
        if: ${{ always() }}
        uses: actions/upload-artifact@v4
        with:
          name: python-coverage-and-analysis
          path: |
            coverage.xml
            htmlcov/**
            docs/analysis/**
YML
echo "[bootstrap-python] Wrote .github/workflows/ci-python.yml"
fi

# Manual (ensure docs exist and always create a base manual if missing)
mkdir -p docs/safety-manuals
if [ ! -f docs/safety-manuals/safety-manual-python.md ]; then
  cat > docs/safety-manuals/safety-manual-python.md <<'MD'
# Safety Manual (Python)

This project is bootstrapped with uv-based tooling, strict linters, pytest, and xenon complexity gates. These safeguards block commits when style, type, or test requirements fail.

## Installed Safeguards
- Pre-commit runs ruff (lint + format), black, isort, mypy, and a custom test-existence check.
- Pytest with coverage, radon complexity reports, and xenon blocking thresholds.
- GitHub Actions workflow (`.github/workflows/ci-python.yml`) mirrors the local gate and uploads analysis artifacts.

## Common Commands
- Sync dev tools: `uv sync --all-groups`
- Install hooks: `uv run pre-commit install`
- Full verify: `uv run scripts/python_verify.sh`
- Generate reports: `uv run scripts/python_reports.sh`

## Adjusting Safeguards
- Xenon thresholds: edit flags in `scripts/python_verify.sh` and `.github/workflows/ci-python.yml` (defaults `--max-absolute B --max-modules B --max-average B`).
- Coverage gate: raise `--cov-fail-under` inside `pyproject.toml` under `[tool.pytest.ini_options].addopts`.
- Ruff/black/isort: tune `[tool.ruff.lint]`, `[tool.black]`, and `[tool.isort]` in `pyproject.toml`.
- Mypy strictness: adjust `[tool.mypy]` as needed.

## Disabling or Removing
- Temporary hook skip: `SKIP=ruff black isort mypy` when running `pre-commit run`; document any skips.
- Remove hooks: delete `.pre-commit-config.yaml`, run `pre-commit uninstall`, and clean the `.git/hooks/` entries.
- Remove CI: delete `.github/workflows/ci-python.yml`.

## Keeping It Fast
- Use uv for locked dependency resolution in CI and local runs.
- Cache `.venv` or uv caches in CI for quicker installs.

## Upgrades
- Update tool versions under `[dependency-groups].dev` in `pyproject.toml` then run `uv sync --all-groups`.
- Re-run the bootstrap when new safeguards ship; scripts are idempotent and preserve manual edits.
MD
fi

# Ensure Agents.md exists or append Python agreement if present already
DEST="Agents.md"; if [ -f AGENTS.md ] && [ ! -f "$DEST" ]; then DEST="AGENTS.md"; fi
PY_HEADER="# Agents.md (Python)"
if [ ! -f "$DEST" ]; then
  cat > "$DEST" <<'AG'
# Agents.md (Python)

Use this working agreement to guide agent behavior in Python repos.

## Agent Working Agreement
1. Never skip checks
   - Do not run `git commit --no-verify`, remove/alter hooks, or bypass CI without explicit human approval.
2. Always run the full local gate before commit
   - `uv run scripts/python_verify.sh`
3. When blocked by hooks or tests, stop and report
   - Paste the failing command and the top relevant error output.
   - Propose a fix and request confirmation if risky.
4. Do not weaken thresholds or disable lint rules to pass
   - Do not relax xenon flags or reduce coverage without approval.
   - Do not comment out tests to increase pass rate.
5. Keep changes small and incremental
   - Re-run checks after each change; prefer short, reviewable diffs.

Related docs: `docs/safety-manuals/safety-manual-python.md`
AG
  echo "[bootstrap-python] Wrote $DEST (Python policy)"
else
  if ! grep -q "^# Agents.md (Python)" "$DEST" 2>/dev/null; then
    printf '\n\n%s\n' "$PY_HEADER" >> "$DEST"
    cat >> "$DEST" <<'AG'

Use this working agreement to guide agent behavior in Python repos.

## Agent Working Agreement
1. Never skip checks
   - Do not run `git commit --no-verify`, remove/alter hooks, or bypass CI without explicit human approval.
2. Always run the full local gate before commit
   - `uv run scripts/python_verify.sh`
3. When blocked by hooks or tests, stop and report
   - Paste the failing command and the top relevant error output.
   - Propose a fix and request confirmation if risky.
4. Do not weaken thresholds or disable lint rules to pass
   - Do not relax xenon flags or reduce coverage without approval.
   - Do not comment out tests to increase pass rate.
5. Keep changes small and incremental
   - Re-run checks after each change; prefer short, reviewable diffs.

Related docs: `docs/safety-manuals/safety-manual-python.md`
AG
    echo "[bootstrap-python] Appended Python policy to $DEST"
  else
    echo "[bootstrap-python] $DEST already contains Python policy; leaving as-is."
  fi
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
  '  - scripts/python_reports.sh' \
  '  - .github/workflows/ci-python.yml' \
  '  - docs/safety-manuals/safety-manual-python.md' \
  '  - Agents.md (created/updated)'
