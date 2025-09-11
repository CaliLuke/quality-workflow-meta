#!/usr/bin/env bash
set -euo pipefail

PM="${PM:-}"
if [ -z "$PM" ]; then
  if command -v pnpm >/dev/null 2>&1; then PM=pnpm
  elif command -v yarn >/dev/null 2>&1; then PM=yarn
  else PM=npm; fi
fi

echo "[setup-husky] Ensuring Husky is set up (prepare script + init)"
case "$PM" in
  pnpm) pnpm pkg set scripts.prepare=husky >/dev/null || true ;;
  yarn) jq '.scripts.prepare="husky"' package.json > package.json.tmp && mv package.json.tmp package.json || true ;;
  npm|*) npm pkg set scripts.prepare=husky >/dev/null || true ;;
esac

npx --yes husky >/dev/null 2>&1 || true

mkdir -p .husky

cat > .husky/pre-commit <<'SH'
#!/usr/bin/env sh
set -e

printf "\n\033[1;36m[husky] pre-commit: lint + typecheck + tests + complexity\033[0m\n"
printf "[husky] staged files:\n" && git diff --cached --name-only || true

printf "\n[husky] running lint-staged...\n"
npm exec lint-staged

printf "\n[husky] running typecheck...\n"
npm run -s typecheck

printf "\n[husky] running tests...\n"
npm run -s test

printf "\n[husky] generating complexity JSON...\n"
npm run -s complexity:json
printf "[husky] enforcing FTA cap...\n"
node scripts/check-fta-cap.mjs

printf "\n\033[1;32m[husky] pre-commit passed.\033[0m\n\n"
SH
chmod +x .husky/pre-commit

cat > .husky/pre-push <<'SH'
#!/usr/bin/env sh
set -e

printf "\n\033[1;36m[husky] pre-push: lint + typecheck\033[0m\n"
npm run -s lint
npm run -s typecheck
printf "\n\033[1;32m[husky] pre-push passed.\033[0m\n\n"
SH
chmod +x .husky/pre-push

echo "[setup-husky] Hooks installed."

