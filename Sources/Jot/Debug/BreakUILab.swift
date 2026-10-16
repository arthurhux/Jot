#if DEBUG
import AppKit
import SwiftUI
import WebKit

/// Developer-only entry point. Uses the production views and storage format,
/// a separate bundle/preferences domain, and disposable fixture directories.
@MainActor
final class BreakUILabDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    static var widestWidth: Int { Int(NSScreen.main?.visibleFrame.width ?? 1200) }
    @Published var dataset: BreakUIDataset = .demo
    @Published var surface = "Notes"
    @Published var width = 480
    @Published var zoom = false
    @Published var rtl = false
    @Published var status = "Isolated fixtures · production views · no global shortcut"
    @Published private(set) var isAuditing = false
    private(set) var store: NoteStore!
    private(set) var state: AppState!
    private(set) var editor: EditorController!
    private var panel: NotesPanel!
    private var controls: NSWindow!
    private var fixtureDirectory: URL!
    private var readinessTask: Task<Void, Never>?
    private var auditTask: Task<Void, Never>?
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("JotBreakUI-\(UUID().uuidString)", isDirectory: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let app = NSMenuItem()
        let submenu = NSMenu()
        let showControls = submenu.addItem(withTitle: "Show Developer Controls", action: #selector(showDeveloperControls), keyEquivalent: "k")
        showControls.target = self
        showControls.keyEquivalentModifierMask = [.command, .option]
        let showNotes = submenu.addItem(withTitle: "Show Notes Window", action: #selector(showNotesWindow), keyEquivalent: "j")
        showNotes.target = self
        showNotes.keyEquivalentModifierMask = [.command, .option]
        submenu.addItem(.separator())
        submenu.addItem(withTitle: "Quit UI Lab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        app.submenu = submenu
        menu.addItem(app)
        NSApp.mainMenu = menu
        panel = NotesPanel(contentRect: NSRect(x: 100, y: 200, width: 480, height: 560),
                           styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Jot UI Lab — isolated test data"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.minSize = NSSize(width: 320, height: 280)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.backgroundColor = JotTheme.nsBackground
        panel.shortcut = { [weak self] event in self?.handleShortcut(event) ?? false }
        load(.demo)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        controls = NSWindow(contentRect: NSRect(x: 100, y: 40, width: 650, height: 125),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        controls.title = "UI stress test · developer controls"
        controls.delegate = self
        controls.isReleasedWhenClosed = false
        controls.contentView = NSHostingView(rootView: BreakUIControls(lab: self))
        if let screen = panel.screen {
            controls.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 325, y: screen.visibleFrame.minY + 18))
        }
        controls.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.arguments.contains("--audit") {
            auditTask = Task { [weak self] in await self?.audit() }
        }
    }

    func load(_ dataset: BreakUIDataset) {
        readinessTask?.cancel()
        self.dataset = dataset
        let notes = dataset.notes()
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            struct Snapshot: Encodable { let version = 1; let notes: [Note]; let selectedID: UUID? }
            let data = dataset == .corrupt ? Data("{\"version\":1,\"notes\":[".utf8) : try JSONEncoder().encode(Snapshot(notes: notes, selectedID: notes.first?.id))
            try data.write(to: directory.appendingPathComponent("notes.json"))
        } catch { status = "Fixture error: \(error.localizedDescription)"; return }
        store?.flush()
        fixtureDirectory = directory
        store = NoteStore(directory: directory, trashRetentionInterval: nil)
        state = AppState()
        state.shortcutLabel = dataset == .worst ? "⌃⌥⇧⌘Space" : "⌥N"
        editor = EditorController(store: store)
        state.overlayDidChange = { [weak self] overlay in
            self?.editor.setModalPresented(overlay != nil)
            if overlay == nil { self?.store.query = ""; self?.editor.focus() }
        }
        state.trashNote = { [weak self] id in self?.store.moveToTrash(id) }
        state.toggleFloating = { [weak self] in
            guard let self else { return }; self.state.alwaysOnTop.toggle()
        }
        state.configureShortcut = { [weak self] in
            guard let self else { return }
            ShortcutRecorderPresenter.present(for: self.panel, currentLabel: self.state.shortcutLabel) { recorded in
                if let recorded { self.state.shortcutLabel = recorded.label }
            }
        }
        showSurface()
        let view = NSHostingView(rootView: WorkspaceView(store: store, state: state, editor: editor)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight))
        view.sizingOptions = []
        panel.contentView = view
        panel.escape = { [weak self] in self?.state.overlay = nil }
        let loadedEditor = editor!
        let hasNote = store.selectedNote != nil
        readinessTask = Task { @MainActor [weak self] in
            guard let self, await self.waitForEditor(loadedEditor, hasNote: hasNote) else { return }
            self.applyEnvironment()
        }
        status = "\(dataset.rawValue) · \(notes.count.formatted()) records · isolated data"
    }

    func showSurface() {
        state.overlay = surface == "Notes" ? .browse : surface == "Settings" ? .settings : nil
        if surface == "Notes" { state.focusSearchToken += 1 }
    }
    func resize() {
        var frame = panel.frame
        frame.size.width = CGFloat(width)
        if let screen = panel.screen {
            frame.origin.x = max(screen.visibleFrame.minX, min(frame.origin.x, screen.visibleFrame.maxX - frame.width))
        }
        panel.setFrame(frame, display: true)
    }
    func applyEnvironment() {
        editor.webView?.pageZoom = zoom ? 2 : 1
        editor.webView?.evaluateJavaScript("document.documentElement.dir = '\(rtl ? "rtl" : "ltr")'", completionHandler: nil)
    }
    func changeDirection() { load(dataset) }
    @objc private func showDeveloperControls() { controls.makeKeyAndOrderFront(nil) }
    @objc private func showNotesWindow() { panel.makeKeyAndOrderFront(nil) }
    private func handleShortcut(_ event: NSEvent) -> Bool {
        guard !isAuditing else { return false }
        guard event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
              let key = event.charactersIgnoringModifiers else { return false }
        if let number = Int(key), (1...BreakUIDataset.allCases.count).contains(number) {
            load(BreakUIDataset.allCases[number - 1]); return true
        }
        switch key {
        case "e": surface = "Editor"; showSurface()
        case "b": surface = "Notes"; showSurface()
        case ",": surface = "Settings"; showSurface()
        case "[": width = 360; resize()
        case "]": width = 480; resize()
        case "0": width = 320; resize()
        case "9": width = Self.widestWidth; resize()
        default: return false
        }
        return true
    }
    private func waitForEditor(_ expected: EditorController, hasNote: Bool) async -> Bool {
        for _ in 0..<100 {
            guard !Task.isCancelled, editor === expected else { return false }
            if expected.isReady || !hasNote { break }
            do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return false }
        }
        do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return false }
        return !Task.isCancelled && editor === expected
    }
    private func js(_ source: String) async throws -> Any? { try await editor.webView?.evaluateJavaScript(source) }

    func audit() async {
        guard !isAuditing else { return }
        isAuditing = true
        defer { isAuditing = false }
        var results: [[String: Any]] = []
        for scenario in BreakUIDataset.allCases {
            surface = "Editor"; zoom = false; rtl = false
            load(scenario)
            guard await waitForEditor(editor, hasNote: store.selectedNote != nil) else { return }
            let expected = scenario == .huge ? 1284 : (scenario == .empty || scenario == .corrupt) ? 0 : scenario == .one ? 1 : scenario == .worst ? 18 : 3
            let start = Date()
            for _ in 0..<100 { _ = store.browserSections }
            results.append(["dataset": scenario.rawValue, "activeCount": store.activeCount, "expectedCount": expected,
                            "sections100Milliseconds": Date().timeIntervalSince(start) * 1000,
                            "editorReady": editor.isReady, "editorFailure": editor.failure ?? "none"])
            let saved = store.flush()
            let reloaded = NoteStore(directory: fixtureDirectory, trashRetentionInterval: nil)
            results.append(["check": "Persistence round-trip", "dataset": scenario.rawValue,
                            "records": reloaded.notes.count, "preserved": saved && reloaded.notes == store.notes])
            if scenario == .worst {
                store.query = "Untitled"
                results.append(["check": "Search displayed fallback title", "expected": 2, "actual": store.visibleNotes.count])
                store.query = "Ngoc"
                results.append(["check": "Diacritic-insensitive search", "query": "Ngoc", "actual": store.visibleNotes.count])
                store.query = ""
            }
            if store.selectedNote == nil { continue }
            for size in [320, 360, 480, Self.widestWidth] {
                width = size; resize()
                for magnified in [false, true] {
                    zoom = magnified; applyEnvironment()
                    _ = try? await js("window.jot.setToolbarVisible(true)")
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    do {
                        let metrics = try await js("""
                        (() => {
                            const box = selector => { const e = document.querySelector(selector); const r = e.getBoundingClientRect(); return {width:r.width, client:e.clientWidth, scroll:e.scrollWidth, height:r.height}; };
                            const overflow = selector => { const p = document.querySelector(selector).getBoundingClientRect(); return [...document.querySelector(selector).children].filter(e => !e.hidden && e.getBoundingClientRect().right > p.right + 1).map(e => e.id || e.getAttribute('aria-label') || e.tagName); };
                            return { viewport:innerWidth, toolbar:box('#toolbar'), toolbarOverflow:overflow('#toolbar'), scroller:box('#scroller'), document:box('.document:not([hidden]) .tiptap'), literalScriptElements:document.querySelectorAll('.tiptap script').length, snapshotLength:window.jot.getSnapshot()?.plainText.length };
                        })()
                        """)
                        results.append(["dataset": scenario.rawValue, "width": size, "zoom": magnified ? 200 : 100, "metrics": metrics ?? [:]])
                    } catch { results.append(["dataset": scenario.rawValue, "error": error.localizedDescription]) }
                }
            }
            if scenario == .worst {
                for size in [320, 360, 480, Self.widestWidth] {
                    width = size; resize()
                    for magnified in [false, true] {
                        zoom = magnified; applyEnvironment()
                        for bar in ["link", "find"] {
                            _ = try? await js(bar == "link" ? "window.jot.runCommand('link')" : "document.getElementById('link-close').click(); document.getElementById('show-find').click(); window.jot.find('Decision')")
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            let metrics = try? await js("""
                            (() => ({viewport:innerWidth, count:document.getElementById('find-count').textContent,
                                inputFocused:document.activeElement===document.getElementById('\(bar)-input'),
                                focusVisible:document.getElementById('\(bar)-input').matches(':focus-visible'),
                                focusOutline:getComputedStyle(document.getElementById('\(bar)-input')).outlineStyle,
                                focusOutlineWidth:getComputedStyle(document.getElementById('\(bar)-input')).outlineWidth,
                                hidden:document.getElementById('\(bar)-bar').hidden,
                                buttons:[...document.querySelectorAll('#\(bar)-bar button')].map(e => {
                                    const r=e.getBoundingClientRect(), style=getComputedStyle(e);
                                    const range=document.createRange(); range.selectNodeContents(e);
                                    return {text:e.textContent || e.getAttribute('aria-label'), left:r.left, right:r.right,
                                        boxWidth:r.width, contentWidth:range.getBoundingClientRect().width,
                                        visible:r.left>=0 && r.right<=innerWidth,
                                        labelFits:range.getBoundingClientRect().width+parseFloat(style.paddingLeft)+parseFloat(style.paddingRight)<=e.clientWidth+1};
                                })}))()
                            """)
                            results.append(["check": "\(bar.capitalized) controls", "width": size, "zoom": magnified ? 200 : 100, "metrics": metrics ?? [:]])
                        }
                        _ = try? await js("document.getElementById('find-close').click()")
                    }
                }
                for address in ["example.com", "mailto:hello@example.com", "tel:+15555550100", "javascript:alert(1)"] {
                    guard let encoded = try? JSONEncoder().encode(address),
                          let value = String(data: encoded, encoding: .utf8) else {
                        results.append(["check": "Link address validation", "error": "Could not encode address fixture"])
                        continue
                    }
                    let metrics = try? await js("""
                    (() => {
                        window.jot.runCommand('link');
                        const input=document.getElementById('link-input'), form=document.getElementById('link-bar');
                        input.value=\(value); input.dispatchEvent(new Event('input')); form.requestSubmit();
                        const result={address:input.value, inputType:input.type, noValidate:form.noValidate,
                            accepted:form.hidden, validationMessage:input.validationMessage};
                        document.getElementById('link-close').click();
                        return result;
                    })()
                    """)
                    results.append(["check": "Link address validation", "expectedAccepted": !address.hasPrefix("javascript:"), "metrics": metrics ?? [:]])
                }
                zoom = false; applyEnvironment()
                for note in store.notes {
                    let start = Date()
                    store.select(note.id)
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    let snapshot = try? await js("window.jot.getSnapshot()") as? [String: Any]
                    let scriptCount = try? await js("document.querySelectorAll('.tiptap script').length")
                    let editable = try? await js("document.querySelector('.document:not([hidden]) .tiptap')?.getAttribute('contenteditable')")
                    results.append(["check": "Round-trip edge-case note", "title": note.displayTitle,
                                    "characters": note.plainText.count,
                                    "correctNoteID": snapshot?["id"] as? String == note.id.uuidString,
                                    "textPreserved": snapshot?["plainText"] as? String == note.plainText,
                                    "scriptElements": scriptCount ?? -1, "editable": editable ?? "unknown",
                                    "deleted": note.isDeleted, "loadMillisecondsIncluding250msPause": Date().timeIntervalSince(start) * 1000])
                }
            }
            if scenario == .huge { results += await auditNativeBrowser() }
        }
        do {
            let output = root.appendingPathComponent("audit.json")
            try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]).write(to: output)
            print("JOT_BREAK_UI_AUDIT=\(output.path)"); fflush(stdout)
            status = "Audit saved: \(output.path)"
        } catch { status = error.localizedDescription }
        surface = "Notes"; width = 480; zoom = false; rtl = false
        resize(); load(.worst)
    }

    private func auditNativeBrowser() async -> [[String: Any]] {
        surface = "Notes"; showSurface()
        width = 360; resize()
        var results: [[String: Any]] = []
        for cycle in 1...8 {
            for query in ["1284", "Customer", ""] {
                guard !Task.isCancelled else { return results }
                store.query = query
                do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return results }
                guard let rootView = panel.contentView, let table = findNotesTable(in: rootView) else {
                    results.append(["check": "Native accessibility endpoints", "error": "Missing notes table"])
                    return results
                }
                let actions = table.accessibilityCustomActions() ?? []
                let last = actions.first(where: { $0.name == "Scroll to last note" })?.handler?() ?? false
                table.layoutSubtreeIfNeeded()
                let lastVisible = NSLocationInRange(table.numberOfRows - 1, table.rows(in: table.visibleRect))
                let first = actions.first(where: { $0.name == "Scroll to first note" })?.handler?() ?? false
                table.layoutSubtreeIfNeeded()
                var realized = 0
                table.enumerateAvailableRowViews { _, _ in realized += 1 }
                results.append(["check": "Native accessibility endpoints", "cycle": cycle, "query": query,
                                "rows": table.numberOfRows, "expectedRows": BrowserListItem.rows(in: store.browserSections).count,
                                "accessibilityRows": table.accessibilityRows()?.count ?? 0, "realizedRows": realized,
                                "actionsSucceeded": first && last, "lastVisible": lastVisible,
                                "firstVisible": NSLocationInRange(0, table.rows(in: table.visibleRect))])
            }
        }
        return results
    }

    private func findNotesTable(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView, table.accessibilityIdentifier() == "notesList" { return table }
        for child in view.subviews { if let table = findNotesTable(in: child) { return table } }
        return nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === panel { NSApp.terminate(nil) }
        else { DispatchQueue.main.async { [weak self] in self?.showNotesWindow() } }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        readinessTask?.cancel(); auditTask?.cancel(); store.flush()
    }
}

private struct BreakUIControls: View {
    @ObservedObject var lab: BreakUILabDelegate
    var body: some View {
        VStack(spacing: 10) {
            Picker("Dataset", selection: Binding(get: { lab.dataset }, set: { lab.load($0) })) {
                ForEach(BreakUIDataset.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityLabel("Demo data / Worst case")
            HStack(spacing: 12) {
                Picker("Surface", selection: $lab.surface) { ForEach(["Editor", "Notes", "Settings"], id: \.self) { Text($0) } }
                    .onChange(of: lab.surface) { _, _ in lab.showSurface() }
                Picker("Width", selection: $lab.width) { ForEach(Array(Set([320, 360, 480, 780, BreakUILabDelegate.widestWidth])).sorted(), id: \.self) { Text("\($0) pt").tag($0) } }
                    .onChange(of: lab.width) { _, _ in lab.resize() }
                Toggle("200% editor", isOn: $lab.zoom).onChange(of: lab.zoom) { _, _ in lab.applyEnvironment() }
                Toggle("RTL probe", isOn: $lab.rtl).onChange(of: lab.rtl) { _, _ in lab.changeDirection() }
            }.font(.system(size: 11))
            Text(lab.status).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }.padding(14).frame(width: 650, height: 125).preferredColorScheme(.dark).disabled(lab.isAuditing)
    }
}
#endif
