import { readFile, writeFile } from 'node:fs/promises'

const source = await readFile(new URL('../Theme/tweakcn.css', import.meta.url), 'utf8')
const root = source.match(/:root\s*\{([\s\S]*?)\}/)?.[1]
const dark = source.match(/\.dark\s*\{([\s\S]*?)\}/)?.[1]
if (!root || !dark) throw new Error('Theme/tweakcn.css must contain :root and .dark token blocks.')
await writeFile(new URL('../Editor/src/theme.css', import.meta.url), `/* Generated from Theme/tweakcn.css. Edit that source, then rebuild. */\n:root {${root}}\n:root.dark {${dark}}\n`)

const tokens = Object.fromEntries([...dark.matchAll(/--([\w-]+):\s*([^;]+);/g)].map(([, key, value]) => [key, value.trim()]))
const camel = key => key.replace(/-([a-z0-9])/g, (_, letter) => letter.toUpperCase())
// OKLCH → Oklab → linear sRGB, then the standard sRGB transfer function.
// Matrix source: https://bottosson.github.io/posts/oklab/ (public domain / MIT).
function rgb(value) {
  const parsed = value.match(/^oklch\(([\d.]+) ([\d.]+) ([\d.]+)\)$/)
  if (!parsed) throw new Error(`Expected an OKLCH color, received ${value}`)
  const [L, C, h] = parsed.slice(1).map(Number)
  const a = C * Math.cos(h * Math.PI / 180), b = C * Math.sin(h * Math.PI / 180)
  const l = (L + .3963377774 * a + .2158037573 * b) ** 3
  const m = (L - .1055613458 * a - .0638541728 * b) ** 3
  const s = (L - .0894841775 * a - 1.2914855480 * b) ** 3
  return [4.0767416621 * l - 3.3077115913 * m + .2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - .3413193965 * s,
    -.0041960863 * l - .7034186147 * m + 1.7076147010 * s].map(linear => {
      const encoded = linear <= .0031308 ? 12.92 * linear : 1.055 * linear ** (1 / 2.4) - .055
      return Math.max(0, Math.min(1, encoded)).toFixed(7)
    })
}
const colors = Object.entries(tokens).filter(([, value]) => value.startsWith('oklch(')).map(([key, value]) => {
  const [r, g, b] = rgb(value)
  return `    static let ${camel(key)} = Color(.sRGB, red: ${r}, green: ${g}, blue: ${b}, opacity: 1)`
}).join('\n')
const radius = Number.parseFloat(tokens.radius) * 16
const swift = `// Generated from the .dark tokens in Theme/tweakcn.css. Do not edit by hand.\nimport AppKit\nimport SwiftUI\n\nenum JotTheme {\n${colors}\n    static let radius: CGFloat = ${radius}\n    static let smallRadius: CGFloat = ${radius - 4}\n    static var nsBackground: NSColor { NSColor(background) }\n}\n`
await writeFile(new URL('../Sources/Jot/JotTheme.swift', import.meta.url), swift)

