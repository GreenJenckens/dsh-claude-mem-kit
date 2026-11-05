// Write ~/.claude-mem/transcript-watch.json with the DSH schema taken from the
// installed @claude-mem/dsh package. No upstream code is stored in this repo.
// MIT License, Copyright (c) 2026 GreenJenckens.
//
// Usage:
//   node write-watch.mjs --example <file> --package <dir> [--watch <file>] [--dry-run]
import { readFileSync, writeFileSync, copyFileSync, existsSync, mkdirSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'

const args = {}
for (let i = 2; i < process.argv.length; i++) {
  const key = process.argv[i]
  if (!key.startsWith('--')) continue
  const next = process.argv[i + 1]
  if (next === undefined || next.startsWith('--')) args[key.slice(2)] = true
  else { args[key.slice(2)] = next; i++ }
}

const expand = (value) =>
  typeof value === 'string' && /^~(?=$|[\\/])/.test(value) ? join(homedir(), value.slice(1)) : value

const expandDeep = (value) => {
  if (Array.isArray(value)) return value.map(expandDeep)
  if (value && typeof value === 'object') {
    const out = {}
    for (const [k, v] of Object.entries(value)) out[k] = expandDeep(v)
    return out
  }
  return expand(value)
}

const examplePath = args.example
const packageDir = args.package
const dryRun = args['dry-run'] === true
const watchPath = args.watch ?? join(homedir(), '.claude-mem', 'transcript-watch.json')

if (!examplePath) { console.error('write-watch: --example is required'); process.exit(2) }
if (!packageDir) { console.error('write-watch: --package is required (path to the @claude-mem/dsh package)'); process.exit(2) }

const schemaPath = join(packageDir, 'transcript-schema.json')
if (!existsSync(schemaPath)) {
  console.error(`write-watch: ${schemaPath} not found — is @claude-mem/dsh installed?`)
  process.exit(3)
}

const example = expandDeep(JSON.parse(readFileSync(examplePath, 'utf8')))
const schema = JSON.parse(readFileSync(schemaPath, 'utf8'))
const current = existsSync(watchPath)
  ? JSON.parse(readFileSync(watchPath, 'utf8').replace(/^\uFEFF/, ''))
  : { version: 1, schemas: {}, watches: [] }

current.version ??= 1
current.schemas ??= {}
current.schemas.dsh = schema
current.watches = (current.watches ?? []).filter((watch) => watch?.name !== 'dsh')
current.watches.push(...(example.watches ?? []))
if (example.stateFile) current.stateFile = example.stateFile
else current.stateFile ??= join(homedir(), '.claude-mem', 'transcript-watch-state.json')

console.log(`write-watch: ${watchPath}`)
for (const watch of current.watches) console.log(`  watch ${watch.name}: ${watch.path}`)

if (dryRun) { console.log('write-watch: dry run, nothing written'); process.exit(0) }

mkdirSync(dirname(watchPath), { recursive: true })
if (existsSync(watchPath)) copyFileSync(watchPath, `${watchPath}.bak`)
writeFileSync(watchPath, JSON.stringify(current, null, 2) + '\n', 'utf8')
console.log('write-watch: written (backup: transcript-watch.json.bak)')
