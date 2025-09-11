#!/usr/bin/env bash
set -euo pipefail

PM="${1:-npm}"

if [ ! -f package.json ]; then
  echo "[setup-npm] No package.json found. Initializing..."
  case "$PM" in
    pnpm) pnpm init -y >/dev/null ;;
    yarn) yarn init -y >/dev/null ;;
    npm|*) npm init -y >/dev/null ;;
  esac
else
  echo "[setup-npm] package.json exists. Merging scripts..."
fi

node - <<'NODE'
const fs = require('fs')
const pkg = fs.existsSync('package.json') ? JSON.parse(fs.readFileSync('package.json','utf8')) : {}
pkg.type = pkg.type || 'module'
pkg.scripts = Object.assign({
  dev: 'vite',
  build: 'tsc -b && vite build',
  typecheck: 'tsc -p tsconfig.app.json',
  lint: 'eslint .',
  preview: 'vite preview',
  test: 'vitest run',
  'complexity': 'fta src',
  'complexity:json': "mkdir -p reports && fta src --format json > reports/fta.json && echo 'Wrote reports/fta.json'",
  'complexity:report': 'node scripts/generate-complexity-report.mjs',
  'quality:fta': 'node scripts/compare-fta.mjs',
  prepare: 'husky',
  verify: "npm run -s lint && npm run -s typecheck && npm run -s test && npm run -s complexity:json && node scripts/check-fta-cap.mjs"
}, pkg.scripts || {})
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n')
console.log('[setup-npm] scripts merged.')
NODE

echo "[setup-npm] Add core devDependencies (run install manually to avoid network during script authoring)."
echo "[setup-npm] Suggested devDependencies:"
cat <<DEPS
  eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh \
  husky lint-staged vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom \
  typescript vite @vitejs/plugin-react-swc vite-plugin-checker fta-cli
DEPS
