#!/usr/bin/env bash
set -euo pipefail

write_if_missing() {
  local path="$1"; shift
  if [ -f "$path" ]; then
    echo "[setup-ts-vite] $path exists; leaving as-is."
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
$@
EOF
  echo "[setup-ts-vite] Wrote $path"
}

# tsconfig.json
if [ ! -f tsconfig.json ]; then
cat > tsconfig.json <<'JSON'
{
  "files": [],
  "compilerOptions": {
    "types": ["vitest/globals", "@testing-library/jest-dom"]
  },
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
JSON
  echo "[setup-ts-vite] Wrote tsconfig.json"
else
  echo "[setup-ts-vite] tsconfig.json exists; leaving as-is."
fi

# tsconfig.app.json
if [ ! -f tsconfig.app.json ]; then
cat > tsconfig.app.json <<'JSON'
{
  "compilerOptions": {
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo",
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "verbatimModuleSyntax": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "erasableSyntaxOnly": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedSideEffectImports": true,
    "baseUrl": ".",
    "paths": {
      "src/*": ["src/*"]
    }
  },
  "include": ["src"],
  "exclude": [
    "src/**/tests/**",
    "src/**/*.stories.ts",
    "src/**/*.stories.tsx",
    "src/**/*.stories.js",
    "src/**/*.stories.jsx"
  ]
}
JSON
  echo "[setup-ts-vite] Wrote tsconfig.app.json"
else
  echo "[setup-ts-vite] tsconfig.app.json exists; leaving as-is."
fi

# tsconfig.node.json
if [ ! -f tsconfig.node.json ]; then
cat > tsconfig.node.json <<'JSON'
{
  "compilerOptions": {
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.node.tsbuildinfo",
    "target": "ES2023",
    "lib": ["ES2023"],
    "types": ["node"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "verbatimModuleSyntax": true,
    "moduleDetection": "force",
    "noEmit": true,
    "isolatedModules": true,
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "erasableSyntaxOnly": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedSideEffectImports": true
  },
  "include": [
    "vite.config.ts",
    "types/**/*.d.ts"
  ]
}
JSON
  echo "[setup-ts-vite] Wrote tsconfig.node.json"
else
  echo "[setup-ts-vite] tsconfig.node.json exists; leaving as-is."
fi

# vite.config.ts
if [ ! -f vite.config.ts ]; then
cat > vite.config.ts <<'TS'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'
import checker from 'vite-plugin-checker'
import path from 'node:path'
import pkg from './package.json' with { type: 'json' }

export default defineConfig(() => ({
  plugins: [react(), checker({ typescript: true })],
  resolve: { alias: [{ find: 'src', replacement: path.resolve(__dirname, 'src') }] },
  define: { 'import.meta.env.VITE_APP_VERSION': JSON.stringify(pkg.version) },
  server: {
    port: Number(process.env.PORT) || 3000,
    host: true,
    proxy: {
      '/api': {
        target: process.env.DEV_BACKEND_URL || 'http://localhost:8000',
        changeOrigin: true,
        rewrite: (p: string) => p.replace(/^\/api/, '')
      }
    }
  },
  build: { sourcemap: false, reportCompressedSize: false },
}))
TS
  echo "[setup-ts-vite] Wrote vite.config.ts"
else
  echo "[setup-ts-vite] vite.config.ts exists; leaving as-is."
fi

# vitest.config.ts
if [ ! -f vitest.config.ts ]; then
cat > vitest.config.ts <<'TS'
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react-swc'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: 'src/test/setup.ts',
    css: true,
    testTimeout: 4000,
    hookTimeout: 4000,
    teardownTimeout: 4000,
    pool: 'forks',
    threads: false,
    isolate: true,
    clearMocks: true,
    restoreMocks: true,
  },
})
TS
  echo "[setup-ts-vite] Wrote vitest.config.ts"
else
  echo "[setup-ts-vite] vitest.config.ts exists; leaving as-is."
fi

# Ensure test setup scaffold exists if using default path
if [ ! -d src/test ]; then mkdir -p src/test; fi
if [ ! -f src/test/setup.ts ]; then echo "// test setup placeholder" > src/test/setup.ts; fi

echo "[setup-ts-vite] TypeScript + Vite + Vitest baseline ensured."

