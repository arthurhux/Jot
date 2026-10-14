import { build } from 'esbuild'
import { copyFile, mkdir } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import '../scripts/generate-theme.mjs'
import './generate-icons.mjs'
import '../scripts/generate-notices.mjs'

const output = fileURLToPath(new URL('../Sources/Jot/Resources/Editor/', import.meta.url))
await mkdir(output, { recursive: true })
await build({
  entryPoints: [fileURLToPath(new URL('./src/main.js', import.meta.url))],
  outfile: `${output}/editor.js`,
  bundle: true,
  format: 'iife',
  target: ['safari16'],
  minify: true,
  legalComments: 'eof',
  logLevel: 'info',
})
for (const name of ['index.html', 'editor.css', 'theme.css']) {
  await copyFile(new URL(`./src/${name}`, import.meta.url), `${output}/${name}`)
}
