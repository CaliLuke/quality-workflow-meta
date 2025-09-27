# Safety Manual (Rust)

This project is bootstrapped with cargo fmt/clippy/test hooks, an optional cargo-audit step, and matching GitHub Actions workflows.

## Installed Safeguards
- Pre-commit hooks (via `prek`) run `cargo fmt --check`, `cargo clippy -- -D warnings` (with cognitive complexity budget), `cargo test`, optional `cargo audit`, and `cargo machete` for unused dependency checks.
- Workspace scaffolds include starter unit and integration tests to keep the verify script green.
- GitHub Actions workflow (`.github/workflows/ci-rust.yml`) executes fmt, clippy, coverage gate, doc, and optional audit steps.

## Common Commands
- Verify locally: `./scripts/rust_verify.sh`
- Reports and docs: `./scripts/rust_reports.sh`
- Unit tests: `cargo test --workspace --all-features`
- Linting only: `cargo clippy --workspace --all-targets --all-features -- -D warnings`
- Formatting: `cargo fmt`

## Adjusting Safeguards
- Clippy scope: edit commands in `scripts/rust_verify.sh` or `.github/workflows/ci-rust.yml` to change features/targets or lint levels.
- Audit gate: install `cargo-audit` locally and in CI to enforce vulnerability checks, or remove the hook step if managed elsewhere.
- Test discovery: the verify script fails when `cargo test -- --list` finds no tests; keep at least one unit or integration test on disk.
- Documentation build: remove or tweak the `cargo doc --no-deps` step if your project cannot generate docs.

## Disabling or Removing
- Temporary hook skip: `SKIP=cargo-fmt cargo-clippy cargo-test cargo-audit cargo-machete prek run --all-files` (document skips).
- Remove hooks: delete `.pre-commit-config.yaml` and remove installed Git hook(s) if needed.
- Remove CI: delete `.github/workflows/ci-rust.yml` and related steps.

## Keeping It Fast
- Install toolchain components once with `rustup component add clippy rustfmt`.
- Use `swatinem/rust-cache` in CI to cache builds and doc artifacts.

## Upgrades
- Update dependencies through `cargo update` and commit `Cargo.lock` diffs.
- Re-run the bootstrap to pick up new safeguards; scripts are idempotent and preserve manual edits.

## Budgets & Thresholds
- Cognitive complexity: configured in `clippy.toml` (default `cognitive-complexity-threshold = 25`).
- Coverage gate: `./scripts/rust_verify.sh` enforces a low starting threshold (`COVERAGE_MIN` env, default 20). CI enforces `--fail-under-lines=20`.
- Doc/comments: crate template enables `#![deny(missing_docs, rustdoc::missing_crate_level_docs)]` and warns on missing panic/error/safety docs for APIs.
