#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap-rust] Preparing Rust safeguards (cargo fmt/clippy/test, optional audit, CI workflow)."

# Ensure basic cargo manifest exists for new projects.
if [ ! -f Cargo.toml ]; then
  cat > Cargo.toml <<'TOML'
[package]
name = "your-crate"
version = "0.1.0"
edition = "2021"
rust-version = "1.74"

[lib]
path = "src/lib.rs"

[dependencies]

[dev-dependencies]
TOML
  echo "[bootstrap-rust] Wrote Cargo.toml"
else
  echo "[bootstrap-rust] Cargo.toml exists; leaving as-is."
fi

# Provide a starter library + test to guarantee at least one #[test].
mkdir -p src
if [ ! -f src/lib.rs ]; then
  cat > src/lib.rs <<'RS'
pub fn add(left: i32, right: i32) -> i32 {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn adds_numbers() {
        assert_eq!(add(2, 2), 4);
    }
}
RS
  echo "[bootstrap-rust] Wrote src/lib.rs with sample test"
else
  echo "[bootstrap-rust] src/lib.rs exists; leaving as-is."
fi

# Create a placeholder integration test directory if missing.
mkdir -p tests
if [ ! -f tests/smoke.rs ]; then
  cat > tests/smoke.rs <<'RS'
#[test]
fn smoke() {
    assert_eq!(2 + 2, 4);
}
RS
  echo "[bootstrap-rust] Added tests/smoke.rs"
fi

# Setup pre-commit hooks (local hooks hitting cargo tools) if not already defined.
if [ ! -f .pre-commit-config.yaml ]; then
  cat > .pre-commit-config.yaml <<'YML'
repos:
  - repo: local
    hooks:
      - id: cargo-fmt
        name: Cargo fmt --check
        entry: cargo fmt --all -- --check
        language: system
        pass_filenames: false
      - id: cargo-clippy
        name: Cargo clippy (deny warnings)
        entry: cargo clippy --workspace --all-targets --all-features -- -D warnings
        language: system
        pass_filenames: false
      - id: cargo-test
        name: Cargo test (workspace)
        entry: cargo test --workspace --all-features
        language: system
        pass_filenames: false
      - id: cargo-audit
        name: Cargo audit (if available)
        entry: bash -c 'command -v cargo-audit >/dev/null 2>&1 && [ -f Cargo.lock ] && cargo audit || echo "[pre-commit] Skipping cargo audit (install cargo-audit and ensure Cargo.lock exists)."'
        language: system
        pass_filenames: false
  - repo: https://github.com/bnjbvr/cargo-machete
    rev: main
    hooks:
      - id: cargo-machete
YML
  echo "[bootstrap-rust] Wrote .pre-commit-config.yaml"
else
  echo "[bootstrap-rust] .pre-commit-config.yaml exists; ensuring cargo-machete hook is present."
  if ! grep -q 'id: cargo-machete' .pre-commit-config.yaml 2>/dev/null; then
    cat >> .pre-commit-config.yaml <<'YML'

# Added by bootstrap-rust: unused dependency check
- repo: https://github.com/bnjbvr/cargo-machete
  rev: main
  hooks:
    - id: cargo-machete
YML
    echo "[bootstrap-rust] Appended cargo-machete pre-commit hook."
  else
    echo "[bootstrap-rust] cargo-machete hook already configured."
  fi
fi

mkdir -p scripts
if [ ! -f scripts/rust_verify.sh ]; then
  cat > scripts/rust_verify.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v cargo >/dev/null 2>&1; then
  echo "[verify:rs] 'cargo' not found on PATH. Install Rust via rustup." >&2
  exit 1
fi

if [ ! -f Cargo.toml ]; then
  echo "[verify:rs] Cargo.toml missing. Run from the project root." >&2
  exit 1
fi

if ! cargo test --workspace --all-features -- --list 2>/dev/null | grep -E '^(test|doctest) ' >/dev/null; then
  echo "[verify:rs] No tests detected. Add #[test] modules or files under tests/." >&2
  exit 1
fi

echo "[verify:rs] cargo fmt --all -- --check"
cargo fmt --all -- --check

echo "[verify:rs] cargo clippy --workspace --all-targets --all-features -- -D warnings"
cargo clippy --workspace --all-targets --all-features -- -D warnings

echo "[verify:rs] cargo test --workspace --all-features"
cargo test --workspace --all-features

if command -v cargo-audit >/dev/null 2>&1 && [ -f Cargo.lock ]; then
  echo "[verify:rs] cargo audit"
  cargo audit
else
  echo "[verify:rs] Skipping cargo audit (install cargo-audit and ensure Cargo.lock exists to enable)."
fi

echo "[verify:rs] OK"
SH
  chmod +x scripts/rust_verify.sh
fi

if [ ! -f scripts/rust_reports.sh ]; then
  cat > scripts/rust_reports.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v cargo >/dev/null 2>&1; then
  echo "[reports:rs] 'cargo' not found on PATH. Install Rust via rustup." >&2
  exit 1
fi

mkdir -p docs/analysis

echo "[reports:rs] cargo test (workspace) → docs/analysis/cargo-test.txt"
cargo test --workspace --all-features -- --nocapture | tee docs/analysis/cargo-test.txt || true

echo "[reports:rs] cargo clippy JSON diagnostics → docs/analysis/cargo-clippy.json"
cargo clippy --workspace --all-targets --all-features --message-format=json > docs/analysis/cargo-clippy.json || true

if command -v cargo-audit >/dev/null 2>&1 && [ -f Cargo.lock ]; then
  echo "[reports:rs] cargo audit → docs/analysis/cargo-audit.txt"
  cargo audit | tee docs/analysis/cargo-audit.txt || true
else
  echo "[reports:rs] Skipping cargo audit report (install cargo-audit and ensure Cargo.lock exists)."
fi

echo "[reports:rs] cargo doc --workspace --all-features --no-deps"
cargo doc --workspace --all-features --no-deps || true

echo "[reports:rs] Done. See docs/analysis and target/doc."
SH
  chmod +x scripts/rust_reports.sh
fi

mkdir -p .github/workflows
if [ ! -f .github/workflows/ci-rust.yml ]; then
  cat > .github/workflows/ci-rust.yml <<'YML'
name: CI (Rust)

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
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy
      - uses: swatinem/rust-cache@v2
      - name: cargo fmt
        run: cargo fmt --all -- --check
      - name: cargo clippy
        run: cargo clippy --workspace --all-targets --all-features -- -D warnings
      - name: cargo test
        run: cargo test --workspace --all-features
      - name: cargo doc
        run: cargo doc --workspace --all-features --no-deps
      - name: cargo audit (optional)
        if: ${{ always() }}
        run: |
          if [ -f Cargo.lock ]; then
            cargo install --locked cargo-audit
            cargo audit
          else
            echo 'Cargo.lock missing - skipping cargo audit.'
          fi
      - name: Output summary
        if: ${{ always() }}
        run: |
          echo '### Rust checks' >> "$GITHUB_STEP_SUMMARY"
          echo '* fmt/clippy/test/doc ran via CI (see logs for details).' >> "$GITHUB_STEP_SUMMARY"
YML
  echo "[bootstrap-rust] Wrote .github/workflows/ci-rust.yml"
fi

# Ensure docs exist and include Rust guidance.
mkdir -p docs/safety-manuals
if [ ! -f docs/safety-manuals/safety-manual-rust.md ]; then
  cat > docs/safety-manuals/safety-manual-rust.md <<'MD'
# Safety Manual (Rust)

This project is bootstrapped with cargo fmt/clippy/test hooks, an optional cargo-audit step, and matching GitHub Actions workflows.

## Installed Safeguards
- Pre-commit hooks run `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`, an optional `cargo audit`, and `cargo machete` for unused dependency checks.
- Workspace scaffolds include starter unit and integration tests to keep the verify script green.
- GitHub Actions workflow (`.github/workflows/ci-rust.yml`) executes fmt, clippy, test, doc, and audit steps.

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

### Unused Dependencies (cargo-machete)
- Install once: `cargo install --locked cargo-machete`
- Pre-commit runs `cargo machete` and fails if unused dependencies are detected (exit code 1).
- False positives: configure ignores/renames via `package.metadata.cargo-machete` or `workspace.metadata.cargo-machete` in `Cargo.toml`.
- More accuracy: pass `--with-metadata` locally if needed (may update `Cargo.lock`).

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
MD
fi

# Ensure Agents.md exists or append Rust agreement if present already
DEST="Agents.md"; if [ -f AGENTS.md ] && [ ! -f "$DEST" ]; then DEST="AGENTS.md"; fi
RS_HEADER="# Agents.md (Rust)"
if [ ! -f "$DEST" ]; then
  cat > "$DEST" <<'AG'
# Agents.md (Rust)

Use this working agreement to guide agent behavior in Rust repos.

## Agent Working Agreement
1. Never skip checks
   - Do not run `git commit --no-verify`, remove/alter hooks, or bypass CI without explicit human approval.
2. Always run the full local gate before commit
   - `./scripts/rust_verify.sh`
3. When blocked by hooks or tests, stop and report
   - Paste the failing command and the top relevant error output.
   - Propose a fix and request confirmation if risky.
4. Do not weaken thresholds or disable lint rules to pass
   - Do not drop `-D warnings` from clippy or skip audit without approval.
   - Do not comment out tests to increase pass rate.
5. Keep changes small and incremental
   - Re-run checks after each change; prefer short, reviewable diffs.

Related docs: `docs/safety-manuals/safety-manual-rust.md`
AG
  echo "[bootstrap-rust] Wrote $DEST (Rust policy)"
else
  if ! grep -q "^# Agents.md (Rust)" "$DEST" 2>/dev/null; then
    printf '\n\n%s\n' "$RS_HEADER" >> "$DEST"
    cat >> "$DEST" <<'AG'

Use this working agreement to guide agent behavior in Rust repos.

## Agent Working Agreement
1. Never skip checks
   - Do not run `git commit --no-verify`, remove/alter hooks, or bypass CI without explicit human approval.
2. Always run the full local gate before commit
   - `./scripts/rust_verify.sh`
3. When blocked by hooks or tests, stop and report
   - Paste the failing command and the top relevant error output.
   - Propose a fix and request confirmation if risky.
4. Do not weaken thresholds or disable lint rules to pass
   - Do not drop `-D warnings` from clippy or skip audit without approval.
   - Do not comment out tests to increase pass rate.
5. Keep changes small and incremental
   - Re-run checks after each change; prefer short, reviewable diffs.

Related docs: `docs/safety-manuals/safety-manual-rust.md`
AG
    echo "[bootstrap-rust] Appended Rust policy to $DEST"
  else
    echo "[bootstrap-rust] $DEST already contains Rust policy; leaving as-is."
  fi
fi

echo "[bootstrap-rust] Complete. Next: 'rustup component add clippy rustfmt' && 'prek install' && './scripts/rust_verify.sh'"

if command -v prek >/dev/null 2>&1; then
  echo "[bootstrap-rust] Installing git hooks via prek..."
  prek install || true
  echo "[bootstrap-rust] Hooks installed with prek."
else
  echo "[bootstrap-rust] 'prek' not found."
  if command -v cargo >/dev/null 2>&1; then
    echo "[bootstrap-rust] Attempting to install prek via cargo (git)..."
    if cargo install --locked --git https://github.com/j178/prek; then
      PREK_BIN="$(command -v prek || echo "$HOME/.cargo/bin/prek")"
      if [ -x "$PREK_BIN" ]; then
        echo "[bootstrap-rust] Running '$PREK_BIN install'..."
        "$PREK_BIN" install || true
        echo "[bootstrap-rust] Hooks installed with prek."
      else
        echo "[bootstrap-rust] prek installed but not on PATH. Add '$HOME/.cargo/bin' to PATH, then run: prek install" >&2
        exit 1
      fi
    else
      echo "[bootstrap-rust] Failed to install prek via cargo. Install manually: brew install prek | uv tool install prek" >&2
      exit 1
    fi
  else
    echo "[bootstrap-rust] Neither 'prek' nor 'cargo' found. Install prek and re-run: brew install prek | uv tool install prek" >&2
    exit 1
  fi
fi

# Friendly reminder to enable machete unused-deps checks
if ! command -v cargo-machete >/dev/null 2>&1; then
  echo "[bootstrap-rust] Tip: install cargo-machete for unused dependency checks: 'cargo install --locked cargo-machete'"
fi

# Summary of created/updated paths
printf '%s\n' \
  '[bootstrap-rust] Created/updated files:' \
  '  - Cargo.toml (if absent)' \
  '  - src/lib.rs (if absent)' \
  '  - tests/smoke.rs' \
  '  - .pre-commit-config.yaml (if absent)' \
  '  - scripts/rust_verify.sh' \
  '  - scripts/rust_reports.sh' \
  '  - .github/workflows/ci-rust.yml' \
  '  - docs/safety-manuals/safety-manual-rust.md' \
  '  - Agents.md (created/updated)'
