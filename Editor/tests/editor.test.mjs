import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { Window } from 'happy-dom'

const browser = new Window({ url: 'http://localhost/' })
for (const key of ['window', 'document', 'navigator', 'Node', 'HTMLElement', 'HTMLAnchorElement', 'HTMLInputElement', 'Element', 'MutationObserver', 'ResizeObserver', 'DOMParser', 'getComputedStyle', 'requestAnimationFrame', 'cancelAnimationFrame']) {
  const value = browser[key]
  Object.defineProperty(globalThis, key, { value: typeof value === 'function' && /^(getComputedStyle|requestAnimationFrame|cancelAnimationFrame)$/.test(key) ? value.bind(browser) : value, configurable: true })
}
const { Editor } = await import('@tiptap/core')
const { documentExtensions } = await import('../src/extensions.js')
const { findRanges } = await import('../src/find.js')

function editorFor(markdown) {
  const element = document.createElement('div')
  document.body.appendChild(element)
  return new Editor({ element, extensions: documentExtensions(), content: markdown, contentType: 'markdown', injectCSS: false })
}

test('Markdown round trip retains headings, checked tasks, inline marks, links, and language', () => {
  const original = '# Trip notes\n\nA **bold** plan with *ideas*, ~~old text~~ and [a link](https://example.com).\n\n- [x] Book train\n- [ ] Pack bag\n\n```swift\nlet city = "Porto"\n```'
  const editor = editorFor(original)
  const json = editor.getJSON()
  assert.equal(json.content[0].type, 'heading')
  assert.equal(json.content[0].attrs.level, 1)
  const tasks = json.content.find(node => node.type === 'taskList')
  assert.deepEqual(tasks.content.map(node => node.attrs.checked), [true, false])
  assert.equal(json.content.find(node => node.type === 'codeBlock').attrs.language, 'swift')
  const roundTrip = editorFor(editor.getMarkdown())
  assert.deepEqual(roundTrip.getJSON(), json)
  editor.destroy()
  roundTrip.destroy()
})

test('plain text and JSON keep document characters intact', () => {
  const editor = editorFor('## Café\n\nPortuguês & 日本語. `let x = 1`')
  const json = editor.getJSON()
  const restored = new Editor({ extensions: documentExtensions(), content: json, injectCSS: false })
  assert.deepEqual(restored.getJSON(), json)
  assert.equal(restored.getText({ blockSeparator: '\n' }), 'Café\nPortuguês & 日本語. let x = 1')
  editor.destroy()
  restored.destroy()
})

test('find matches span formatting and treat punctuation literally', () => {
  const editor = editorFor('A **bold** plan. Find (this) and café.\n\nA bold plan again.')
  const matches = findRanges(editor.state.doc, 'bold plan')
  assert.equal(matches.length, 2)
  assert.equal(editor.state.doc.textBetween(matches[0].from, matches[0].to), 'bold plan')
  assert.equal(findRanges(editor.state.doc, '(this)').length, 1)
  assert.equal(findRanges(editor.state.doc, 'CAFÉ').length, 1)
  assert.equal(findRanges(editor.state.doc, '').length, 0)
  editor.destroy()
})

test('native bridge loads without edits, reports the right note, preserves undo, and supports trash preview', async () => {
  document.body.innerHTML = (await readFile(new URL('../src/index.html', import.meta.url), 'utf8')).match(/<body>([\s\S]*)<\/body>/)[1]
  const messages = []
  window.webkit = { messageHandlers: { jot: { postMessage: message => messages.push(message) } } }
  await import('../src/main.js')
  assert.ok(messages.some(message => message.type === 'ready'))
  window.jot.loadNote({ id: 'first', markdown: 'Original first note', caretFrom: 1, caretTo: 1, scrollTop: 0 })
  assert.equal(messages.filter(message => message.type === 'content').length, 0)
  assert.equal(window.jot.getSnapshot().id, 'first')
  assert.equal(window.jot.getSnapshot().caretFrom, 1)
  window.jot.runCommand('insertMarkdown', 'Added ')
  const first = window.jot.getSnapshot()
  assert.match(first.plainText, /Added/)
  assert.equal(messages.filter(message => message.type === 'content').at(-1).id, 'first')
  const beforeSwitch = messages.filter(message => message.type === 'content').length
  window.jot.loadNote({ id: 'second', markdown: 'Second note', editable: false })
  assert.equal(window.jot.runCommand('toggleBold'), false)
  assert.equal(window.jot.runCommand('insertMarkdown', 'Blocked'), false)
  assert.equal(window.jot.getSnapshot().plainText, 'Second note')
  const sortedKeys = (_, value) => value && typeof value === 'object' && !Array.isArray(value)
    ? Object.fromEntries(Object.keys(value).sort().map(key => [key, value[key]])) : value
  // Swift persists JSON with sorted keys. Loading that equivalent object must retain history.
  window.jot.loadNote(JSON.parse(JSON.stringify(first, sortedKeys)))
  assert.equal(messages.filter(message => message.type === 'content').length, beforeSwitch)
  assert.equal(window.jot.getSnapshot().plainText, first.plainText)
  // Simulate an A → B → A switch before the native side receives A's latest update.
  window.jot.loadNote({ id: 'second', markdown: 'Second note', editable: false })
  window.jot.loadNote({ id: 'first', markdown: 'Original first note', caretFrom: 1 })
  assert.equal(window.jot.getSnapshot().plainText, first.plainText)
  assert.equal(messages.filter(message => message.type === 'content').length, beforeSwitch)
  window.jot.runCommand('undo')
  assert.equal(window.jot.getSnapshot().plainText, 'Original first note')
  window.jot.setEditable(false)
  assert.equal(window.jot.runCommand('insertMarkdown', 'Blocked again'), false)
  window.jot.setEditable(true)
  assert.equal(window.jot.find('note').count, 1)
  assert.equal(window.jot.nextMatch().index, 1)
  window.jot.loadNote({ id: 'first', markdown: 'An explicit replacement', replaceContent: true })
  assert.equal(window.jot.getSnapshot().plainText, 'An explicit replacement')
  const beforeFlush = messages.length
  const flushed = window.jot.flush()
  assert.equal(flushed.plainText, 'An explicit replacement')
  assert.deepEqual(messages.slice(beforeFlush).map(message => message.type), ['content', 'selection', 'scroll'])
  assert.ok(messages.slice(beforeFlush).every(message => message.id === 'first'))
  // The idle-editor cache is a memory budget, not a cap on saved/openable notes.
  const saved = window.jot.getSnapshot()
  for (let index = 0; index < 40; index++) {
    window.jot.loadNote({ id: `library-${index}`, markdown: `Thought ${index}` })
    assert.equal(window.jot.getSnapshot().plainText, `Thought ${index}`)
  }
  window.jot.loadNote(saved)
  assert.equal(window.jot.getSnapshot().plainText, saved.plainText, 'an evicted editor reloads its persisted document')
  const nativeFind = new window.KeyboardEvent('keydown', { key: 'f', metaKey: true, cancelable: true })
  document.dispatchEvent(nativeFind)
  assert.equal(nativeFind.defaultPrevented, false, 'native CmdF must reach the search-notes menu')
  delete window.webkit
  const browserFind = new window.KeyboardEvent('keydown', { key: 'f', metaKey: true, cancelable: true })
  document.dispatchEvent(browserFind)
  assert.equal(browserFind.defaultPrevented, true, 'browser preview keeps its own in-note find')
  await browser.happyDOM.abort()
})
