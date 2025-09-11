#!/usr/bin/env bash
set -euo pipefail

mkdir -p scripts docs/analysis reports

# check-fta-cap.mjs
if [ ! -f scripts/check-fta-cap.mjs ]; then
cat > scripts/check-fta-cap.mjs <<'JS'
#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const CAP = Number(process.env.FTA_HARD_CAP || 50)
const JSON_PATH = path.resolve('reports/fta.json')

if (!fs.existsSync(JSON_PATH)) {
  console.error(`[FTA] Missing ${JSON_PATH}. Generate it first with \`npm run complexity:json\`.`)
  process.exit(2)
}

const data = JSON.parse(fs.readFileSync(JSON_PATH, 'utf8'))
const offenders = data.filter((d) => d.fta_score > CAP)

if (offenders.length) {
  console.error(`\n[FTA] Hard cap exceeded (cap=${CAP}). Offending files:`)
  offenders
    .sort((a, b) => b.fta_score - a.fta_score)
    .forEach((o) => console.error(` - ${o.file_name}  score=${o.fta_score.toFixed(2)}`))
  console.error('\nRefactor or split code until scores are under the cap, then commit again.')
  process.exit(1)
}

console.log(`[FTA] All files under cap (${CAP}).`)
JS
chmod +x scripts/check-fta-cap.mjs
echo "[setup-complexity] Wrote scripts/check-fta-cap.mjs"
fi

# compare-fta.mjs
if [ ! -f scripts/compare-fta.mjs ]; then
cat > scripts/compare-fta.mjs <<'JS'
#!/usr/bin/env node
import fs from 'node:fs'

function readJson(p) { return JSON.parse(fs.readFileSync(p, 'utf8')) }
function parseArgs(argv) {
  const args = {}
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i]
    if (a.startsWith('--')) { const [k, v] = a.split('='); args[k.slice(2)] = v ?? argv[++i] }
  }
  return args
}

const args = parseArgs(process.argv)
const currentPath = args.current || 'reports/fta.json'
const basePath = args.base || 'reports/fta.base.json'
const changedArg = args.changed || ''

const changed = changedArg
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean)
  .filter((f) => f.startsWith('src/') && (f.endsWith('.ts') || f.endsWith('.tsx')))
  .map((f) => f.replace(/^src\//, ''))

if (changed.length === 0) {
  console.log('[quality] No changed TS/TSX files under src/. Skipping FTA gate.')
  process.exit(0)
}

const current = readJson(currentPath)
const base = fs.existsSync(basePath) ? readJson(basePath) : []

const byFile = (arr) => { const m = new Map(); for (const e of arr) m.set(e.file_name, e); return m }
const curMap = byFile(current)
const baseMap = byFile(base)

const HARD_CAP = Number(process.env.FTA_HARD_CAP || 50)
const DELTA_PCT = Number(process.env.FTA_DELTA_PCT || 10)

const failures = []
const report = []
for (const f of changed) {
  const cur = curMap.get(f)
  if (!cur) continue
  const baseEntry = baseMap.get(f)
  const curScore = cur.fta_score
  const baseScore = baseEntry?.fta_score
  report.push({ file: `src/${f}`, curScore, baseScore })
  if (curScore > HARD_CAP) failures.push({ file: `src/${f}`, reason: `FTA ${curScore.toFixed(2)} > ${HARD_CAP}` })
  if (typeof baseScore === 'number' && curScore > baseScore * (1 + DELTA_PCT / 100)) {
    failures.push({ file: `src/${f}`, reason: `FTA Δ>${DELTA_PCT}% (${baseScore.toFixed(2)} → ${curScore.toFixed(2)})` })
  }
}

console.log('[quality] FTA comparison for changed files:')
for (const r of report) {
  console.log(`- ${r.file}: ${typeof r.baseScore === 'number' ? r.baseScore.toFixed(2) : '—'} -> ${r.curScore.toFixed(2)}`)
}

if (failures.length) {
  console.error('\n[quality] FTA gate failed:')
  for (const f of failures) console.error(`- ${f.file}: ${f.reason}`)
  process.exit(1)
}

console.log('[quality] FTA gate passed')
JS
chmod +x scripts/compare-fta.mjs
echo "[setup-complexity] Wrote scripts/compare-fta.mjs"
fi

# fta-comment.mjs (optional PR comment body builder)
if [ ! -f scripts/fta-comment.mjs ]; then
cat > scripts/fta-comment.mjs <<'JS'
#!/usr/bin/env node
import fs from 'node:fs'

function readJson(p) { return JSON.parse(fs.readFileSync(p, 'utf8')) }
function parseArgs(argv) { const a={}; for (let i=2;i<argv.length;i++){ const x=argv[i]; if(x.startsWith('--')){const [k,v]=x.split('='); a[k.slice(2)]=v??argv[++i]} } return a }

const { current='reports/fta.json', base='reports/fta.base.json', changed='' } = parseArgs(process.argv)
const cur = readJson(current)
const baseData = fs.existsSync(base) ? readJson(base) : []

const map = (arr) => { const m = new Map(); for (const e of arr) m.set(e.file_name, e); return m }
const curMap = map(cur); const baseMap = map(baseData)
const changedList = changed.split(',').map(s=>s.trim()).filter(Boolean).map(f=>f.replace(/^src\//,''))

const rows = changedList.map(f => ({
  file: `src/${f}`,
  base: baseMap.get(f)?.fta_score?.toFixed?.(2) ?? '—',
  cur: curMap.get(f)?.fta_score?.toFixed?.(2) ?? '—',
  cyclo: curMap.get(f)?.cyclo ?? '',
  volume: curMap.get(f)?.halstead?.volume?.toFixed?.(2) ?? '',
  effort: curMap.get(f)?.halstead?.effort?.toFixed?.(0) ?? '',
  assessment: curMap.get(f)?.assessment ?? ''
}))

const header = ['File','Base','Current','Cyclo','Volume','Effort','Assessment']
const table = [
  `| ${header.join(' | ')} |`,
  `| ${header.map(()=>'---').join(' | ')} |`,
  ...rows.map(r=>`| ${r.file} | ${r.base} | ${r.cur} | ${r.cyclo} | ${r.volume} | ${r.effort} | ${r.assessment} |`)
].join('\n')

process.stdout.write(`### Quality Gate (FTA)\n\n${table}\n\n- Hard cap: ${process.env.FTA_HARD_CAP||50}, Delta cap: +${process.env.FTA_DELTA_PCT||10}%\n`)
JS
chmod +x scripts/fta-comment.mjs
echo "[setup-complexity] Wrote scripts/fta-comment.mjs"
fi

# generate-complexity-report.mjs
if [ ! -f scripts/generate-complexity-report.mjs ]; then
cat > scripts/generate-complexity-report.mjs <<'JS'
#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const ROOT = process.cwd()
const reportDir = path.join(ROOT, 'reports')
const jsonPath = path.join(reportDir, 'fta.json')
const outDir = path.join(ROOT, 'docs', 'analysis')
const outPath = path.join(outDir, 'complexity-report.md')

function readJson(p) { return JSON.parse(fs.readFileSync(p, 'utf8')) }
function ensureDir(d) { fs.mkdirSync(d, { recursive: true }) }
function table(rows, headers){ return ['| '+headers.join(' | ')+' |','| '+headers.map(()=> '---').join(' | ')+' |',...rows.map(r=>'| '+headers.map(h=>String(r[h]??'')).join(' | ')+' |')].join('\n') }

if (!fs.existsSync(jsonPath)) { console.error('[complexity] reports/fta.json not found. Run `npm run complexity:json` first.'); process.exit(1) }
const data = readJson(jsonPath)
const files = data.map(d=>({
  file: `src/${d.file_name}`,
  lines: d.line_count,
  cyclo: d.cyclo,
  score: d.fta_score,
  assessment: d.assessment,
  volume: typeof d.halstead?.volume === 'number' ? d.halstead.volume.toFixed(2) : '',
}))

const total = files.length
const avg = files.reduce((s,f)=>s+f.score,0)/Math.max(1,total)
const worst = [...files].sort((a,b)=>b.score-a.score).slice(0,20)

const md = [
  '# Complexity Report (FTA)',
  '',
  `- Generated: ${new Date().toISOString()}`,
  `- Files analyzed: ${total}`,
  `- Average FTA score: ${avg.toFixed(2)}`,
  '',
  '## Top 20 by FTA score',
  '',
  table(worst, ['file','lines','cyclo','score','assessment'])
].join('\n')

ensureDir(outDir)
fs.writeFileSync(outPath, md, 'utf8')
console.log('[complexity] Wrote', path.relative(ROOT, outPath))
JS
chmod +x scripts/generate-complexity-report.mjs
echo "[setup-complexity] Wrote scripts/generate-complexity-report.mjs"
fi

echo "[setup-complexity] Complexity tooling scaffolded."

