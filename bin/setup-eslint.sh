#!/usr/bin/env bash
set -euo pipefail

if [ ! -f .lintstagedrc.json ]; then
  cat > .lintstagedrc.json <<'JSON'
{
  "*.{ts,tsx,js,jsx}": [
    "eslint --fix --max-warnings=0"
  ]
}
JSON
  echo "[setup-eslint] Wrote .lintstagedrc.json"
else
  echo "[setup-eslint] .lintstagedrc.json exists; leaving as-is."
fi

if [ ! -f eslint.config.js ]; then
  cat > eslint.config.js <<'JS'
import js from '@eslint/js'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import tseslint from 'typescript-eslint'
import { globalIgnores } from 'eslint/config'

export default tseslint.config([
  globalIgnores(['dist', 'storybook-static']),
  {
    linterOptions: { reportUnusedDisableDirectives: 'off' },
  },
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommended,
      reactHooks.configs['recommended-latest'],
      reactRefresh.configs.vite,
    ],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
    },
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      'react-refresh/only-export-components': 'off',
      'complexity': ['error', 15],
    },
  },
  {
    files: ['src/**/tests/**/*.{ts,tsx}', 'src/test/**/*.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unused-vars': 'off',
      'react-refresh/only-export-components': 'off',
      'react-hooks/exhaustive-deps': 'off',
    },
  },
])
JS
  echo "[setup-eslint] Wrote eslint.config.js"
else
  echo "[setup-eslint] eslint.config.js exists; leaving as-is."
fi

node - <<'NODE'
const fs = require('fs')
if (!fs.existsSync('package.json')) process.exit(0)
const pkg = JSON.parse(fs.readFileSync('package.json','utf8'))
pkg.scripts = pkg.scripts || {}
pkg.scripts.lint = pkg.scripts.lint || 'eslint .'
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n')
console.log('[setup-eslint] ensured script: lint')
NODE
