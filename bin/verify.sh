#!/usr/bin/env bash
set -euo pipefail

echo "[verify] Running lint..." && bun run lint
echo "[verify] Running typecheck..." && bun run typecheck
echo "[verify] Running tests..." && bun run test
echo "[verify] Generating FTA JSON..." && bun run complexity:json
echo "[verify] Enforcing FTA cap..." && bun scripts/check-fta-cap.mjs
echo "[verify] OK"
