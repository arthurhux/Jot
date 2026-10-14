import { mkdir, readFile, readdir, unlink, writeFile } from 'node:fs/promises'
import svgpath from 'svgpath'
import { jotIcons, jotIconStyle } from './src/icons.js'

const output = new URL('../Sources/Jot/Resources/Icons/', import.meta.url)
await mkdir(output, { recursive: true })
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;')
const number = value => {
  const n = Number(value)
  if (!Number.isFinite(n)) throw new Error(`Invalid icon coordinate: ${value}`)
  return String(Number(n.toFixed(6)))
}
const point = (x, y) => `CGPoint(x: ${number(x)}, y: ${number(y)})`
const rect = (x, y, w, h) => `CGRect(x: ${number(x)}, y: ${number(y)}, width: ${number(w)}, height: ${number(h)})`
const swift = [
  '// Generated from the pinned Lucide package by Editor/generate-icons.mjs. Do not edit.',
  'import CoreGraphics',
  '',
  'enum LucideGeometry {',
  `    static let controlSize: CGFloat = ${jotIconStyle.size}`,
  `    static let strokeWidth: CGFloat = ${jotIconStyle.strokeWidth}`,
  `    static let viewBox: CGFloat = ${jotIconStyle.viewBox}`,
  '    static let paths: [String: CGPath] = makePaths()',
  '',
  '    private static func makePaths() -> [String: CGPath] {',
  '        var result: [String: CGPath] = [:]',
]

function pathCommands(d) {
  const parsed = svgpath(d).unshort().unarc().abs()
  if (parsed.err) throw new Error(parsed.err)
  const lines = []
  parsed.iterate((s, _index, x, y) => {
    switch (s[0]) {
      case 'M': lines.push(`path.move(to: ${point(s[1], s[2])})`); break
      case 'L': lines.push(`path.addLine(to: ${point(s[1], s[2])})`); break
      case 'H': lines.push(`path.addLine(to: ${point(s[1], y)})`); break
      case 'V': lines.push(`path.addLine(to: ${point(x, s[1])})`); break
      case 'C': lines.push(`path.addCurve(to: ${point(s[5], s[6])}, control1: ${point(s[1], s[2])}, control2: ${point(s[3], s[4])})`); break
      case 'Q': lines.push(`path.addQuadCurve(to: ${point(s[3], s[4])}, control: ${point(s[1], s[2])})`); break
      case 'Z': lines.push('path.closeSubpath()'); break
      default: throw new Error(`Unsupported normalized SVG command: ${s[0]}`)
    }
  })
  return lines
}

function nodeCommands(tag, a) {
  switch (tag) {
    case 'path': return pathCommands(a.d)
    case 'line': return [`path.move(to: ${point(a.x1, a.y1)})`, `path.addLine(to: ${point(a.x2, a.y2)})`]
    case 'circle': return [`path.addEllipse(in: ${rect(Number(a.cx) - Number(a.r), Number(a.cy) - Number(a.r), Number(a.r) * 2, Number(a.r) * 2)})`]
    case 'ellipse': return [`path.addEllipse(in: ${rect(Number(a.cx) - Number(a.rx), Number(a.cy) - Number(a.ry), Number(a.rx) * 2, Number(a.ry) * 2)})`]
    case 'rect': {
      const r = rect(a.x ?? 0, a.y ?? 0, a.width, a.height)
      return a.rx || a.ry
        ? [`path.addRoundedRect(in: ${r}, cornerWidth: ${number(a.rx ?? a.ry)}, cornerHeight: ${number(a.ry ?? a.rx)})`]
        : [`path.addRect(${r})`]
    }
    case 'polyline':
    case 'polygon': {
      const p = a.points.trim().split(/[\s,]+/).map(Number)
      if (p.length % 2) throw new Error(`Invalid ${tag} points`)
      const lines = []
      for (let i = 0; i < p.length; i += 2) lines.push(`path.${i ? 'addLine' : 'move'}(to: ${point(p[i], p[i + 1])})`)
      if (tag === 'polygon') lines.push('path.closeSubpath()')
      return lines
    }
    default: throw new Error(`Unsupported Lucide shape: ${tag}`)
  }
}

for (const [name, nodes] of Object.entries(jotIcons)) {
  const body = nodes.map(([tag, attributes]) => `<${tag} vector-effect="non-scaling-stroke" ${Object.entries(attributes).map(([key, value]) => `${key}="${escape(value)}"`).join(' ')}/>`).join('')
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${jotIconStyle.size}" height="${jotIconStyle.size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${jotIconStyle.strokeWidth}" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`
  await writeFile(new URL(`${name}.svg`, output), svg)
  swift.push('        do {', '            let path = CGMutablePath()')
  for (const [tag, attributes] of nodes) {
    if (attributes.transform) throw new Error(`Unexpected shape transform in ${name}`)
    for (const command of nodeCommands(tag, attributes)) swift.push(`            ${command}`)
  }
  swift.push(`            result["${name}"] = path.copy()!`, '        }')
}
swift.push('        return result', '    }', '}', '')
await writeFile(new URL('../Sources/Jot/LucideGeometry.swift', import.meta.url), swift.join('\n'))
// Remove obsolete generated raster templates after the vector source succeeds.
for (const file of await readdir(output)) if (file.endsWith('.png')) await unlink(new URL(file, output))
const license = await readFile(new URL('./node_modules/lucide/LICENSE', import.meta.url), 'utf8')
await writeFile(new URL('LUCIDE-LICENSE.txt', output), license)

