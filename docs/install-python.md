# Install and Run (Python)

## Quick Start (one-shot)
Run inside your target project directory:

```
bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type python
```

## Local Alternative
From a local checkout of this repo:

```
bash bin/bootstrap.sh --type python
```

## Verify Locally

```
uv sync --all-groups
uv run pre-commit install
uv run scripts/python_verify.sh
```

Useful commands
- Reports: `uv run scripts/python_reports.sh`

## After Install
- Read the Safety Manual: `docs/safety-manuals/safety-manual-python.md`
- CI workflow: `.github/workflows/ci-python.yml`
