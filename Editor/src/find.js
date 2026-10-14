import { Extension } from '@tiptap/core'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'

export const findKey = new PluginKey('jotFind')

export function findRanges(doc, query) {
  if (!query) return []
  const expression = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'giu')
  const matches = []
  doc.descendants((node, position) => {
    if (!node.isTextblock) return true
    let text = ''
    const positions = []
    node.descendants((child, childPosition) => {
      if (child.isText) {
        for (let i = 0; i < child.text.length; i += 1) {
          text += child.text[i]
          positions.push(position + 1 + childPosition + i)
        }
      } else if (child.isLeaf) {
        text += '\n'
        positions.push(position + 1 + childPosition)
      }
    })
    expression.lastIndex = 0
    for (const match of text.matchAll(expression)) {
      const index = match.index
      matches.push({ from: positions[index], to: positions[index + match[0].length - 1] + 1 })
    }
    return false
  })
  return matches
}

function result(doc, query, active = 0) {
  const matches = findRanges(doc, query)
  const index = matches.length ? ((active % matches.length) + matches.length) % matches.length : 0
  return {
    query, matches, active: index,
    decorations: DecorationSet.create(doc, matches.map((match, i) => Decoration.inline(
      match.from, match.to, { class: i === index ? 'find-match find-current' : 'find-match' },
    ))),
  }
}

export const Find = Extension.create({
  name: 'jotFind',
  addProseMirrorPlugins() {
    return [new Plugin({
      key: findKey,
      state: {
        init: (_, state) => result(state.doc, ''),
        apply(transaction, previous) {
          const update = transaction.getMeta(findKey)
          if (update) return result(transaction.doc, update.query ?? previous.query, update.active ?? 0)
          if (transaction.docChanged) return result(transaction.doc, previous.query, previous.active)
          return previous
        },
      },
      props: { decorations: state => findKey.getState(state).decorations },
    })]
  },
})
