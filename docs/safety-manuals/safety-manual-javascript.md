# Safety Manual (JavaScript/TypeScript)

This project is bootstrapped with Husky hooks, ESLint, TypeScript, Vitest, and FTA complexity gates. These safeguards block commits or CI when quality bars are missed.

## Installed Safeguards
- Pre-commit (Husky) runs lint-staged, typecheck, tests, and the FTA complexity cap.
- Pre-push hook re-runs `bun run lint` and `bun run typecheck`.
- ESLint (flat config) with SonarJS cognitive complexity and classic `complexity` rules.
- Vitest with coverage thresholds and an FTA complexity JSON report.
- GitHub Actions workflows for CI and the PR quality gate.

## Common Commands
- Install deps: `bun install`
- Full gate: `bun run verify`
- Lint only: `bun run lint`
- Typecheck: `bun run typecheck`
- Tests: `bun run test`
- Complexity report: `bun run complexity:report`

## Adjusting Safeguards
- Hard complexity cap: set `FTA_HARD_CAP` (default 50) before running checks or in CI.
- Complexity delta budget: set `FTA_DELTA_PCT` (default 10) for the PR quality gate.
- ESLint budgets: tweak `complexity` or `sonarjs/cognitive-complexity` in `eslint.config.js` (default 15).
- Coverage: raise thresholds in `vitest.config.ts` under `test.coverage.thresholds` as the suite grows.

## Disabling or Removing
- Temporary hook skip: `git commit --no-verify` (use sparingly and document why).
- Remove Husky: delete `.husky/` and the `prepare` script from `package.json`.
- Remove complexity checks: delete scripts under `scripts/` beginning with `fta-` and update hooks/CI accordingly.

## Keeping It Fast
- Prefer small commits so FTA analysis completes quickly.
- Cache dependencies in CI via `oven-sh/setup-bun` for reproducible installs.

## Upgrades
- Update dev dependencies with `bun add -d <pkg>@latest`.
- Re-run the bootstrap anytime; it is idempotent and will not overwrite manual edits.
