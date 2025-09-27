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
