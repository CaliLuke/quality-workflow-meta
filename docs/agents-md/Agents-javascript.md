# Agents.md (JavaScript/TypeScript)

Use this working agreement to guide agent behavior in JS/TS repos.

## Agent Working Agreement
1. Never skip checks
   - Do not run `git commit --no-verify`, set `HUSKY=0`, remove/alter hooks, or bypass CI without explicit human approval.
2. Always run the full local gate before commit
   - `bun run complexity:json && bun scripts/check-fta-cap.mjs && bun run test`
   - Or run the consolidated gate: `bun run verify` (if configured)
3. When blocked by hooks or tests, stop and report
   - Paste the failing command and the top relevant error output.
   - Propose a fix and request confirmation if risky.
4. Do not weaken thresholds or disable lint rules to pass
   - Do not raise `FTA_HARD_CAP` or lower coverage thresholds without approval.
   - Do not comment out tests to increase pass rate.
5. Keep changes small and incremental
   - Re-run checks after each change; prefer short, reviewable diffs.

Related docs: `docs/safety-manuals/safety-manual-javascript.md`
