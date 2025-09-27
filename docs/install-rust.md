# Install and Run (Rust)

## Quick Start (one-shot)
Run inside your target project directory:

```
bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type rust
```

## Local Alternative
From a local checkout of this repo:

```
bash bin/bootstrap.sh --type rust
```

## Verify Locally

```
rustup component add clippy rustfmt
cargo install --locked cargo-machete  # unused-deps pre-commit hook
pre-commit install
./scripts/rust_verify.sh
```

Useful commands
- Reports/docs: `./scripts/rust_reports.sh`

## After Install
- Read the Safety Manual: `docs/safety-manuals/safety-manual-rust.md`
- CI workflow: `.github/workflows/ci-rust.yml`
