# Install and Run (JavaScript/TypeScript)

## Quick Start (one-shot)
Run inside your target project directory:

```
bash <(curl -fsSL https://raw.githubusercontent.com/CaliLuke/quality-workflow-meta/main/docs/one-shot-installer.sh) --type frontend --pm bun
```

## Local Alternative
From a local checkout of this repo:

```
bash bin/bootstrap-frontend.sh
# or explicitly via the selector
bash bin/bootstrap.sh --type frontend
```

Options
- Ephemeral mode (remove installer after setup): `SELF_DESTRUCT=1 ...`
- Pick package manager: `PM=pnpm` or `PM=yarn` (auto-detects bun by default)

## Verify Locally

```
bun install
bun run verify
```

Useful commands
- Lint: `bun run lint`
- Typecheck: `bun run typecheck`
- Tests: `bun run test`
- Complexity report: `bun run complexity:report`

## After Install
- Read the Safety Manual: `docs/safety-manuals/safety-manual-javascript.md`
- CI workflows are scaffolded in `.github/workflows/`
