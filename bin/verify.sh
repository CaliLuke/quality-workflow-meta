#!/usr/bin/env bash
set -euo pipefail

echo "[verify] Running lint..." && npm run -s lint
echo "[verify] Running typecheck..." && npm run -s typecheck
echo "[verify] Running tests..." && npm run -s test
echo "[verify] Generating FTA JSON..." && npm run -s complexity:json
echo "[verify] Enforcing FTA cap..." && node scripts/check-fta-cap.mjs
echo "[verify] OK"

