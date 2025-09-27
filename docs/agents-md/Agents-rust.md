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
