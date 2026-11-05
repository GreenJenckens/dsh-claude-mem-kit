// Merge the cost profile into ~/.claude-mem/settings.json.
// MIT License, Copyright (c) 2026 GreenJenckens.
//
// Usage:
//   node apply-tuning.mjs --example <file> [--settings <file>] [--dry-run]
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

const examplePath = args.example
const dryRun = args['dry-run'] === true
const settingsPath = args.settings ?? join(homedir(), '.claude-mem', 'settings.json')
const observerKey = typeof args.key === 'string' ? args.key.trim() : ''

if (!examplePath) { console.error('apply-tuning: --example is required'); process.exit(2) }

const example = JSON.parse(readFileSync(examplePath, 'utf8').replace(/^\uFEFF/, ''))
const current = existsSync(settingsPath)
  ? JSON.parse(readFileSync(settingsPath, 'utf8').replace(/^\uFEFF/, ''))
  : {}

const expand = (value) =>
  typeof value === 'string' && /^~(?=$|[\\/])/.test(value) ? join(homedir(), value.slice(1)) : value

const changed = []
for (const [key, value] of Object.entries(example)) {
  if (typeof value === 'string' && value.startsWith('<')) continue // placeholder, never written
  const next = expand(value)
  if (String(current[key]) !== String(next)) { current[key] = next; changed.push(key) }
}

if (observerKey) {
  if (String(current.CLAUDE_MEM_OPENAI_COMPAT_API_KEY) !== observerKey) {
    current.CLAUDE_MEM_OPENAI_COMPAT_API_KEY = observerKey
    changed.push('CLAUDE_MEM_OPENAI_COMPAT_API_KEY')
  }
}

console.log(`apply-tuning: ${settingsPath}`)
console.log(`  applied: ${changed.length} key(s)${changed.length ? ' — ' + changed.join(', ') : ''}`)
if (!current.CLAUDE_MEM_OPENAI_COMPAT_API_KEY) {
  console.log('  NOTE: CLAUDE_MEM_OPENAI_COMPAT_API_KEY is empty — put your observer API key into settings.json')
}

if (dryRun) { console.log('apply-tuning: dry run, nothing written'); process.exit(0) }
if (changed.length === 0) { console.log('apply-tuning: already up to date'); process.exit(0) }

mkdirSync(dirname(settingsPath), { recursive: true })
copyFileSync(settingsPath, `${settingsPath}.bak`)
writeFileSync(settingsPath, JSON.stringify(current, null, 2) + '\n', 'utf8')
console.log('apply-tuning: written (backup: settings.json.bak)')
