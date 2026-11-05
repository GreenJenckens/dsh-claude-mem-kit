// Wire or unwire the @claude-mem/dsh bundle in a DSH profile.
// MIT License, Copyright (c) 2026 GreenJenckens.
//
// Usage:
//   node wire-profile.mjs --profile-dir <dir> --bundle <dir> [--dry-run]
//   node wire-profile.mjs --profile-dir <dir> --remove [--dry-run]
import { readFileSync, writeFileSync, copyFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const args = {}
for (let i = 2; i < process.argv.length; i++) {
  const key = process.argv[i]
  if (!key.startsWith('--')) continue
  const next = process.argv[i + 1]
  if (next === undefined || next.startsWith('--')) args[key.slice(2)] = true
  else { args[key.slice(2)] = next; i++ }
}

const profileDir = args['profile-dir']
const dryRun = args['dry-run'] === true
const remove = args.remove === true
const bundleDir = args.bundle

if (!profileDir) {
  console.error('wire-profile: --profile-dir is required')
  process.exit(2)
}
if (!remove && !bundleDir) {
  console.error('wire-profile: --bundle is required unless --remove is passed')
  process.exit(2)
}

const pkgPath = join(profileDir, 'package.json')
if (!existsSync(pkgPath)) {
  console.error(`wire-profile: ${pkgPath} not found — open DeepSeek Harness once so it initializes the profile`)
  process.exit(3)
}

const raw = readFileSync(pkgPath, 'utf8').replace(/^\uFEFF/, '')
const pkg = JSON.parse(raw)
const indent = (raw.match(/\n( +)"/) ?? [, '    '])[1].length
const BUNDLE = '@claude-mem/dsh'

pkg.dependencies ??= {}
pkg.dsh ??= {}
pkg.dsh.profile ??= {}
pkg.dsh.profile.bundles ??= []

if (remove) {
  delete pkg.dependencies[BUNDLE]
  pkg.dsh.profile.bundles = pkg.dsh.profile.bundles.filter((name) => name !== BUNDLE)
  console.log(`wire-profile: removed ${BUNDLE} from ${pkgPath}`)
} else {
  const linkTarget = bundleDir.replace(/\\/g, '/')
  pkg.dependencies[BUNDLE] = `link:${linkTarget}`
  if (!pkg.dsh.profile.bundles.includes(BUNDLE)) pkg.dsh.profile.bundles.push(BUNDLE)
  console.log(`wire-profile: ${BUNDLE} -> ${linkTarget}`)
  console.log(`wire-profile: bundles = ${pkg.dsh.profile.bundles.length} entries`)
}

if (dryRun) {
  console.log('wire-profile: dry run, nothing written')
  process.exit(0)
}

copyFileSync(pkgPath, `${pkgPath}.bak`)
writeFileSync(pkgPath, JSON.stringify(pkg, null, indent) + '\n', 'utf8')
console.log(`wire-profile: wrote ${pkgPath} (backup: package.json.bak)`)
