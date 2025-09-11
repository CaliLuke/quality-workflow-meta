#!/usr/bin/env bash
set -euo pipefail

# Frontend-only CI setup. Guard against running in non-frontend projects.
if [ ! -f package.json ]; then
  echo "[setup-ci] Skipping: package.json not found (frontend CI applies to JS/TS projects)." >&2
  echo "[setup-ci] Hint: For Python projects, run 'bash bin/bootstrap.sh --type python' to scaffold ci-python.yml." >&2
  exit 0
fi

mkdir -p .github/workflows

# Minimal CI: quality, tests, build
if [ ! -f .github/workflows/ci.yml ]; then
cat > .github/workflows/ci.yml <<'YML'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  quality:
    name: Lint and Typecheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci --no-audit --no-fund --omit=optional --legacy-peer-deps
      - run: npm run lint
      - run: npm run typecheck
      - name: Complexity baseline (FTA)
        run: |
          npm run -s complexity:json
          node scripts/check-fta-cap.mjs
      - name: Upload FTA artifacts
        if: ${{ always() }}
        uses: actions/upload-artifact@v4
        with:
          name: fta-baseline
          path: |
            reports/fta.json
            docs/analysis/**

  tests:
    name: Unit Tests (Vitest)
    runs-on: ubuntu-latest
    needs: quality
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci --no-audit --no-fund --legacy-peer-deps
      - name: Tests (Vitest + Coverage)
        run: npm run test -- --coverage
      - name: Upload coverage artifacts
        if: ${{ always() }}
        uses: actions/upload-artifact@v4
        with:
          name: frontend-coverage
          path: |
            coverage/**
            !coverage/tmp/**

  build:
    name: Build (Vite)
    runs-on: ubuntu-latest
    needs: [quality, tests]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci --no-audit --no-fund --legacy-peer-deps
      - run: npm run build
YML
  echo "[setup-ci] Wrote .github/workflows/ci.yml"
else
  echo "[setup-ci] .github/workflows/ci.yml exists; leaving as-is."
fi

# FTA quality gate for PRs
if [ ! -f .github/workflows/quality-gate.yml ]; then
cat > .github/workflows/quality-gate.yml <<'YML'
name: Quality Gate

on:
  pull_request:
    branches: [ main ]

jobs:
  fta-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci --no-audit --no-fund --legacy-peer-deps
      - name: Generate current FTA JSON
        run: npm run -s complexity:json
      - name: Generate base FTA JSON
        env:
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
        run: |
          git worktree add ../base "$BASE_SHA"
          pushd ../base
          npm ci --no-audit --no-fund --legacy-peer-deps
          npx -y fta src --format json > reports/fta.json
          popd
          mkdir -p reports
          cp ../base/reports/fta.json reports/fta.base.json
          git worktree remove ../base --force
      - name: Compute changed TS files
        id: diff
        env:
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          CHANGED=$(git diff --name-only "$BASE_SHA".."$HEAD_SHA" -- 'src/**/*.ts' 'src/**/*.tsx' | tr '\n' ',' | sed 's/,$//')
          echo "changed=$CHANGED" >> $GITHUB_OUTPUT
      - name: Enforce thresholds
        env:
          FTA_HARD_CAP: ${{ vars.FTA_HARD_CAP || 50 }}
          FTA_DELTA_PCT: ${{ vars.FTA_DELTA_PCT || 10 }}
        run: node scripts/compare-fta.mjs --current=reports/fta.json --base=reports/fta.base.json --changed='${{ steps.diff.outputs.changed }}'
YML
  echo "[setup-ci] Wrote .github/workflows/quality-gate.yml"
else
  echo "[setup-ci] .github/workflows/quality-gate.yml exists; leaving as-is."
fi

echo "[setup-ci] CI workflows scaffolded."
