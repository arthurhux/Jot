import { Editor } from '@tiptap/core'
import { documentExtensions } from './extensions.js'
import { Find, findKey } from './find.js'
import { createElement } from 'lucide'
import { jotIcons, jotIconStyle } from './icons.js'

const scroller = document.getElementById('scroller')
const documents = document.getElementById('documents')
const toolbar = document.getElementById('toolbar')
const blockType = document.getElementById('block-type')
const findBar = document.getElementById('find-bar')
const findInput = document.getElementById('find-input')
const findCount = document.getElementById('find-count')
const linkBar = document.getElementById('link-bar')
const linkInput = document.getElementById('link-input')
const entries = new Map()
let current = null
let loading = false
let scrollFrame = 0
let heightFrame = 0
toolbar.hidden = true

function post(message) {
  try { window.webkit?.messageHandlers?.jot?.postMessage(message) } catch (_) { /* A browser preview has no native bridge. */ }
}

function reportError(error) {
  post({ type: 'error', message: error?.message || String(error) })
}

window.addEventListener('error', event => reportError(event.error || event.message))
window.addEventListener('unhandledrejection', event => reportError(event.reason))

function snapshot(entry = current) {
  if (!entry) return null
  const { editor, id } = entry
  const { from, to } = editor.state.selection
  return {
    id,
    json: editor.getJSON(),
    markdown: editor.getMarkdown(),
    plainText: editor.getText({ blockSeparator: '\n' }),
    caretFrom: from,
    caretTo: to,
    scrollTop: entry === current ? scroller.scrollTop : entry.scrollTop,
  }
}

function content(entry) {
  const data = snapshot(entry)
  post({ type: 'content', id: data.id, json: data.json, markdown: data.markdown, plainText: data.plainText })
}

function emitHeight() {
  cancelAnimationFrame(heightFrame)
  heightFrame = requestAnimationFrame(() => {
    if (!current) return
    const content = current.editor.view.dom
    const last = content.lastElementChild
    const naturalHeight = last ? last.getBoundingClientRect().bottom - content.getBoundingClientRect().top : 0
    const bottomPadding = Number.parseFloat(getComputedStyle(content).paddingBottom) || 0
    post({ type: 'height', value: Math.ceil(naturalHeight + bottomPadding + toolbar.offsetHeight) })
  })
}

function formatting() {
  const editor = current?.editor
  toolbar.querySelectorAll('button[data-command]').forEach(button => {
    button.disabled = !editor || !editor.isEditable
  })
  blockType.disabled = !editor || !editor.isEditable
  if (!editor) return
  const states = {
    toggleBold: editor.isActive('bold'),
    toggleItalic: editor.isActive('italic'),
    toggleStrike: editor.isActive('strike'),
    toggleCode: editor.isActive('code'),
    toggleBulletList: editor.isActive('bulletList'),
    toggleOrderedList: editor.isActive('orderedList'),
    toggleTaskList: editor.isActive('taskList'),
    toggleCodeBlock: editor.isActive('codeBlock'),
    link: editor.isActive('link'),
  }
  Object.entries(states).forEach(([command, active]) => {
    toolbar.querySelector(`[data-command="${command}"]`)?.setAttribute('aria-pressed', String(active))
  })
  const canUndo = editor.can().undo()
  const canRedo = editor.can().redo()
  toolbar.querySelector('[data-command="undo"]').disabled = !editor.isEditable || !canUndo
  toolbar.querySelector('[data-command="redo"]').disabled = !editor.isEditable || !canRedo
  const level = editor.getAttributes('heading').level
  blockType.value = level ? `heading${level}` : 'paragraph'
  post({ type: 'formatting', id: current.id, ...states, canUndo, canRedo, heading: level || 0, editable: editor.isEditable })
}

function inputContent(note) {
  if (note.json && typeof note.json === 'object') return { content: note.json }
  if (typeof note.markdown === 'string' && note.markdown.length) return { content: note.markdown, contentType: 'markdown' }
  const paragraphs = (note.plainText || '').split('\n').map(text => ({
    type: 'paragraph', ...(text ? { content: [{ type: 'text', text }] } : {}),
  }))
  return { content: { type: 'doc', content: paragraphs } }
}

function equalJSON(left, right) {
  if (left === right) return true
  if (left === null || right === null || typeof left !== 'object' || typeof right !== 'object') return false
  const keys = Object.keys(left)
  if (keys.length !== Object.keys(right).length) return false
  return keys.every(key => Object.hasOwn(right, key) && equalJSON(left[key], right[key]))
}

function createEntry(note) {
  const element = document.createElement('section')
  element.className = 'document'
  element.hidden = true
  documents.appendChild(element)
  const entry = { id: note.id, element, editor: null, scrollTop: note.scrollTop || 0 }
  entry.editor = new Editor({
    element,
    extensions: [...documentExtensions(), Find],
    injectCSS: false,
    ...inputContent(note),
    editable: note.editable !== false,
    autofocus: false,
    editorProps: {
      attributes: { 'aria-label': 'Note body', spellcheck: 'true', role: 'textbox', 'aria-multiline': 'true' },
      handleKeyDown(_, event) {
        if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
          event.preventDefault()
          showLink()
          return true
        }
        return false
      },
      handlePaste(_, event) {
        const plain = event.clipboardData?.getData('text/plain')
        const html = event.clipboardData?.getData('text/html')
        if (!html && plain && /(^|\n)(#{1,3} |```|- \[[ xX]\] |[-*] |\d+\. )/.test(plain)) {
          entry.editor.commands.insertContent(entry.editor.markdown.parse(plain).content)
          return true
        }
        return false
      },
      handleDOMEvents: {
        click(_, event) {
          const anchor = event.target.closest?.('a')
          if (!anchor) return false
          // A deliberate click opens links through WKNavigationDelegate; normal typing stays in the editor.
          if (event.metaKey || event.ctrlKey || !entry.editor.isEditable) {
            event.preventDefault()
            const url = anchor.getAttribute('href')
            if (/^(https?:|mailto:)/i.test(url || '')) window.location.href = url
            return true
          }
          return false
        },
      },
    },
    onUpdate() {
      if (!loading && current === entry) {
        content(entry)
        updateFindCount()
        emitHeight()
      }
    },
    onSelectionUpdate() {
      if (!loading && current === entry) {
        const { from, to } = entry.editor.state.selection
        post({ type: 'selection', id: entry.id, from, to })
        formatting()
      }
    },
    onTransaction() { if (!loading && current === entry) formatting() },
  })
  return entry
}

function loadNote(note) {
  if (!note || !note.id) return
  loading = true
  try {
    if (current) {
      current.scrollTop = scroller.scrollTop
      current.element.hidden = true
    }
    let entry = entries.get(note.id)
    if (!entry) {
      entry = createEntry(note)
      entries.set(note.id, entry)
    } else {
      // Cached editor content is authoritative: native persistence can trail WK messages.
      // Imports receive new IDs; an intentional replacement must opt in explicitly.
      if (note.replaceContent === true) {
        const incoming = inputContent(note)
        const changed = incoming.contentType === 'markdown'
          ? incoming.content.trim() !== entry.editor.getMarkdown().trim()
          : !equalJSON(incoming.content, entry.editor.getJSON())
        if (changed) entry.editor.commands.setContent(incoming.content, { contentType: incoming.contentType, emitUpdate: false })
      }
      entry.editor.setEditable(note.editable !== false, false)
      // Move the used editor to the end of the cache, preserving per-note undo history.
      entries.delete(note.id)
      entries.set(note.id, entry)
    }
    current = entry
    entry.element.hidden = false
    const maximum = entry.editor.state.doc.content.size
    const from = Math.max(0, Math.min(note.caretFrom ?? entry.editor.state.selection.from, maximum))
    const to = Math.max(from, Math.min(note.caretTo ?? from, maximum))
    entry.editor.commands.setTextSelection({ from, to })
    scroller.scrollTop = Math.max(0, note.scrollTop ?? entry.scrollTop ?? 0)
    entry.scrollTop = scroller.scrollTop
    findBar.hidden = true
    linkBar.hidden = true
    entry.editor.view.dispatch(entry.editor.state.tr.setMeta(findKey, { query: '', active: 0 }).setMeta('addToHistory', false))
    // Bound idle editor memory while retaining undo for the most recently used notes.
    while (entries.size > 24) {
      const [oldestID, oldest] = entries.entries().next().value
      oldest.editor.destroy()
      oldest.element.remove()
      entries.delete(oldestID)
    }
  } catch (error) { reportError(error) } finally { loading = false }
  formatting()
  emitHeight()
}

function setEditable(value) {
  current?.editor.setEditable(Boolean(value), false)
  formatting()
}

function runCommand(name, value) {
  if (!current || !current.editor.isEditable) return false
  const editor = current.editor
  if (name === 'link') { showLink(); return true }
  const commands = {
    toggleBold: chain => chain.toggleBold(),
    toggleItalic: chain => chain.toggleItalic(),
    toggleStrike: chain => chain.toggleStrike(),
    toggleCode: chain => chain.toggleCode(),
    toggleBulletList: chain => chain.toggleBulletList(),
    toggleOrderedList: chain => chain.toggleOrderedList(),
    toggleTaskList: chain => chain.toggleTaskList(),
    toggleCodeBlock: chain => chain.toggleCodeBlock(),
    setParagraph: chain => chain.setParagraph(),
    toggleHeading: chain => chain.toggleHeading({ level: Number(value?.level ?? value) || 1 }),
    setHeading: chain => chain.setHeading({ level: Number(value?.level ?? value) || 1 }),
    undo: chain => chain.undo(),
    redo: chain => chain.redo(),
    unsetLink: chain => chain.extendMarkRange('link').unsetLink(),
    setLink: chain => chain.extendMarkRange('link').setLink({ href: String(value?.href ?? value) }),
    insertMarkdown: chain => chain.insertContent(editor.markdown.parse(String(value)).content),
  }
  if (!commands[name]) return false
  try { return commands[name](editor.chain().focus()).run() } catch (error) { reportError(error); return false }
}

function findStatus() {
  const state = current && findKey.getState(current.editor.state)
  return { count: state?.matches.length || 0, index: state?.matches.length ? state.active + 1 : 0 }
}

function updateFindCount() {
  const { count, index } = findStatus()
  findCount.textContent = findInput.value ? (count ? `${index} of ${count}` : 'No matches') : ''
  if (current) post({ type: 'search', id: current.id, count, index })
  return { count, index }
}

function revealMatch() {
  const state = current && findKey.getState(current.editor.state)
  if (state?.matches.length) {
    const match = state.matches[state.active]
    const coords = current.editor.view.coordsAtPos(match.from)
    const rect = scroller.getBoundingClientRect()
    if (coords.top < rect.top + 20 || coords.bottom > rect.bottom - 20) scroller.scrollTop += coords.top - rect.top - rect.height / 3
  }
}

function find(query) {
  if (!current) return { count: 0, index: 0 }
  findInput.value = query || ''
  current.editor.view.dispatch(current.editor.state.tr.setMeta(findKey, { query: query || '', active: 0 }).setMeta('addToHistory', false))
  revealMatch()
  return updateFindCount()
}

function nextMatch(direction = 1) {
  if (!current) return { count: 0, index: 0 }
  const state = findKey.getState(current.editor.state)
  current.editor.view.dispatch(current.editor.state.tr.setMeta(findKey, { active: state.active + direction }).setMeta('addToHistory', false))
  revealMatch()
  return updateFindCount()
}

function showFind() {
  findBar.hidden = false
  linkBar.hidden = true
  findInput.focus()
  findInput.select()
}

function closeFind() {
  findBar.hidden = true
  find('')
  current?.editor.commands.focus()
}

function showLink() {
  if (!current?.editor.isEditable) return
  linkBar.hidden = false
  findBar.hidden = true
  linkInput.value = current.editor.getAttributes('link').href || ''
  linkInput.focus()
  linkInput.select()
}

document.querySelectorAll('[data-icon]').forEach(button => {
  const icon = jotIcons[button.dataset.icon]
  if (icon) button.replaceChildren(createElement(icon, { 'aria-hidden': 'true', 'stroke-width': jotIconStyle.strokeWidth }))
})
toolbar.addEventListener('mousedown', event => { if (event.target.closest('button')) event.preventDefault() })
toolbar.addEventListener('click', event => {
  const command = event.target.closest('[data-command]')?.dataset.command
  if (command) runCommand(command)
})
blockType.addEventListener('change', () => {
  if (blockType.value === 'paragraph') runCommand('setParagraph')
  else runCommand('setHeading', Number(blockType.value.replace('heading', '')))
})
document.getElementById('show-find').addEventListener('click', showFind)
findInput.addEventListener('input', () => find(findInput.value))
findBar.addEventListener('submit', event => { event.preventDefault(); nextMatch() })
document.getElementById('find-prev').addEventListener('click', () => nextMatch(-1))
document.getElementById('find-close').addEventListener('click', closeFind)
linkBar.addEventListener('submit', event => {
  event.preventDefault()
  let href = linkInput.value.trim()
  if (href && !/^[a-z][a-z0-9+.-]*:/i.test(href)) href = `https://${href}`
  if (href && !/^(https?:|mailto:|tel:)/i.test(href)) {
    linkInput.setCustomValidity('Use a web, email, or telephone link.')
    linkInput.reportValidity()
    return
  }
  linkInput.setCustomValidity('')
  runCommand(href ? 'setLink' : 'unsetLink', href)
  linkBar.hidden = true
})
linkInput.addEventListener('input', () => linkInput.setCustomValidity(''))
document.getElementById('link-remove').addEventListener('click', () => { runCommand('unsetLink'); linkBar.hidden = true })
document.getElementById('link-close').addEventListener('click', () => { linkBar.hidden = true; current?.editor.commands.focus() })
document.addEventListener('keydown', event => {
  if (!window.webkit?.messageHandlers?.jot && (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'f') {
    event.preventDefault()
    showFind()
  }
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'g') { event.preventDefault(); nextMatch(event.shiftKey ? -1 : 1) }
  if (event.key === 'Escape') {
    if (!findBar.hidden) { event.preventDefault(); closeFind() }
    if (!linkBar.hidden) { event.preventDefault(); linkBar.hidden = true; current?.editor.commands.focus() }
  }
})
scroller.addEventListener('scroll', () => {
  if (loading || !current) return
  cancelAnimationFrame(scrollFrame)
  scrollFrame = requestAnimationFrame(() => {
    if (current) {
      current.scrollTop = scroller.scrollTop
      post({ type: 'scroll', id: current.id, top: scroller.scrollTop })
    }
  })
}, { passive: true })
new ResizeObserver(emitHeight).observe(documents)

window.jot = {
  loadNote,
  runCommand,
  setEditable,
  setAppearance(dark) { document.documentElement.classList.toggle('dark', Boolean(dark)) },
  getSnapshot: () => snapshot(),
  flush() {
    const data = snapshot()
    if (!data) return null
    post({ type: 'content', id: data.id, json: data.json, markdown: data.markdown, plainText: data.plainText })
    post({ type: 'selection', id: data.id, from: data.caretFrom, to: data.caretTo })
    post({ type: 'scroll', id: data.id, top: data.scrollTop })
    return data
  },
  focus: () => current?.editor.commands.focus(),
  setToolbarVisible(visible) { toolbar.hidden = !visible; emitHeight() },
  find,
  nextMatch,
}
formatting()
post({ type: 'ready' })
