# Jot editor

Original vanilla JavaScript implementation using Tiptap 3.32.0 and lowlight 3.3.0. `npm ci`, `npm test`, and `npm run build` regenerate the checked-in offline assets in `../Sources/Jot/Resources/Editor`. The app never needs Node.js or a network connection to edit notes.

The native host loads `index.html` with read access to its containing directory and waits for `{type: 'ready'}`. It then calls:

```js
window.jot.loadNote({
  id: 'stable note ID',
  json: null,                  // Tiptap document object, preferred when present
  markdown: '# A thought',    // Fallback to Markdown, then plain text
  plainText: '',
  caretFrom: 1,
  caretTo: 1,
  scrollTop: 0,
  editable: true,
  replaceContent: false,
})
```

Loading a note does not send content changes. Editors are cached for the 24 most recently used IDs to preserve independent undo histories. Cached content is authoritative during switching because native messages may be asynchronous. Use `replaceContent: true` only for an intentional external replacement; imports should use a new ID.

Other bridge methods:

- `getSnapshot()` returns `{id,json,markdown,plainText,caretFrom,caretTo,scrollTop}`, or `null`.
- `flush()` returns the snapshot and posts matching `content`, `selection`, and `scroll` messages.
- `runCommand(name, value)` runs standard commands, including `toggleBold`, `toggleItalic`, `toggleStrike`, `toggleCode`, `toggleBulletList`, `toggleOrderedList`, `toggleTaskList`, `toggleCodeBlock`, `setParagraph`, `toggleHeading`, `setHeading`, `undo`, `redo`, `setLink`, `unsetLink`, and `insertMarkdown`. Heading values can be `1`–`3` or `{level: 1}`. Link values can be a URL string or `{href: 'https://example.com'}`.
- `setAppearance(dark)`, `setEditable(editable)`, and `focus()` update the current editor.
- `find(query)` and `nextMatch(direction = 1)` return `{count,index}`. Search indexes are one-based, or zero when no matches exist.

Messages go through `window.webkit.messageHandlers.jot.postMessage`. Types are `ready`, `content`, `selection`, `scroll`, `height`, `formatting`, `search`, and `error`. Every note-specific message includes its ID. Height measures natural content height, including editor padding and formatting toolbar.

The host owns native menu shortcuts; in particular, native ⌘F reaches search across notes. The editor's find button and browser-preview ⌘F search within the current note. Links open with ⌘-click (or a regular click in read-only mode); the host should intercept external navigation and open permitted URLs in the default browser.

The generated JavaScript is an IIFE with no module loading or remote assets. CSP blocks runtime connections and inline scripts. Formatting and search remain immediate; pointer controls have a named 120 ms settling transition, with reduced motion, reduced transparency, and increased contrast support.
