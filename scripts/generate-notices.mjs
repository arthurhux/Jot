import { readFile, readdir, writeFile } from 'node:fs/promises'

const root = new URL('../', import.meta.url)
const lock = JSON.parse(await readFile(new URL('Editor/package-lock.json', root), 'utf8'))
const sections = ['Jot — Third-party notices\n\nLicenses for the editor and icon runtime dependencies.\nThese notices do not grant a license to Jot\'s original source code.']

for (const [path, metadata] of Object.entries(lock.packages).sort(([a], [b]) => a.localeCompare(b))) {
  if (!path || metadata.dev) continue
  const directory = new URL(`Editor/${path}/`, root)
  const packageInfo = JSON.parse(await readFile(new URL('package.json', directory), 'utf8'))
  const files = (await readdir(directory)).filter(name => /^(licen[cs]e|copying)(\.|$)/i.test(name)).sort()
  if (!files.length) throw new Error(`Missing license text for ${packageInfo.name}`)
  const texts = await Promise.all(files.map(name => readFile(new URL(name, directory), 'utf8')))
  sections.push(`${packageInfo.name} ${metadata.version}\nLicense: ${metadata.license ?? packageInfo.license}\n\n${texts.join('\n\n').trim()}`)
}

await writeFile(new URL('THIRD_PARTY_NOTICES.txt', root), `${sections.join('\n\n' + '='.repeat(72) + '\n\n')}\n`)
console.log(`Generated third-party notices for ${sections.length - 1} dependencies.`)
