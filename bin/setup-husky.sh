#!/usr/bin/env bash
set -euo pipefail

PM="${PM:-}"
if [ -z "$PM" ]; then
  if command -v bun >/dev/null 2>&1; then PM=bun
  elif command -v pnpm >/dev/null 2>&1; then PM=pnpm
  elif command -v yarn >/dev/null 2>&1; then PM=yarn
  else PM=bun; fi
fi

echo "[setup-husky] Ensuring Husky is set up (prepare script + init)"
node - <<'NODE'
const fs=require('fs')
const p='package.json'
const pkg=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,'utf8')):{}
pkg.scripts=pkg.scripts||{}
pkg.scripts.prepare='husky'
fs.writeFileSync(p,JSON.stringify(pkg,null,2)+'\n')
console.log('[setup-husky] ensure scripts.prepare=husky')
NODE

bunx husky >/dev/null 2>&1 || true

mkdir -p .husky

cat > .husky/pre-commit <<'SH'
#!/usr/bin/env sh
set -e

printf "\n\033[1;36m[husky] pre-commit: lint + typecheck + tests + complexity\033[0m\n"
printf "[husky] staged files:\n" && git diff --cached --name-only || true

printf "\n[husky] running lint-staged...\n"
bunx lint-staged

# Require at least one test file to exist in the repository
if ! find src tests -type f \
  \( -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.spec.ts' -o -name '*.spec.tsx' \
     -name '*.test.js' -o -name '*.test.jsx' -o -name '*.spec.js' -o -name '*.spec.jsx' \) \
  2>/dev/null | head -n 1 | grep -q .; then
  printf "\n[husky] No test files found (e.g., src/**/*.test.ts). Add at least one test before committing.\n" >&2
  exit 1
fi

printf "\n[husky] running typecheck...\n"
bun run typecheck

printf "\n[husky] running tests...\n"
bun run test

printf "\n[husky] generating complexity JSON...\n"
bun run complexity:json
printf "[husky] enforcing FTA cap...\n"
bun scripts/check-fta-cap.mjs

printf "\n\033[1;32m[husky] pre-commit passed.\033[0m\n\n"
SH
chmod +x .husky/pre-commit

cat > .husky/pre-push <<'SH'
#!/usr/bin/env sh
set -e

printf "\n\033[1;36m[husky] pre-push: lint + typecheck\033[0m\n"
bun run lint
bun run typecheck
printf "\n\033[1;32m[husky] pre-push passed.\033[0m\n\n"
SH
chmod +x .husky/pre-push

echo "[setup-husky] Hooks installed."
