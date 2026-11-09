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
    /// Preview each production surface on this Mac: Liquid Glass (macOS 26+),
    /// the macOS 14–15 look, or the Reduce Transparency fallback.
    @Published var surfaceStyle: SurfaceStyle = SurfaceStyle.supportsLiquidGlass ? .glass : .classic {
        didSet { state?.labSurface = surfaceStyle }
    }
    /// A bright, busy window behind the panel: the worst case for glass legibility.
    @Published var brightBackdrop = false {
        didSet { updateBackdrop() }
    }
    @Published var referenceType = false {
        didSet {
            state?.labReferenceTypography = referenceType
            applyEnvironment()
        }
    }
    private var backdrop: NSWindow?
    /// Preview Increase Contrast (secondary text to white, window near-opaque).
    @Published var increasedContrast = false {
        didSet { state?.labIncreasedContrast = increasedContrast }
    }
    private var pointerTracker: PointerTracker?
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
        let snapshot = submenu.addItem(withTitle: "Save Window Snapshot", action: #selector(saveSnapshot), keyEquivalent: "s")
        snapshot.target = self
        snapshot.keyEquivalentModifierMask = [.command, .option]
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
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.shortcut = { [weak self] event in self?.handleShortcut(event) ?? false }
        let arguments = ProcessInfo.processInfo.arguments
        // --tone=#RRGGBB --transparency=0.36 --inactive-transparency=0.6: preset
        // the lab's window appearance before the fixture loads (contrast checks).
        func value(_ name: String) -> String? { arguments.first(where: { $0.hasPrefix("--\(name)=") }).map { String($0.dropFirst(name.count + 3)) } }
        var appearance = WindowAppearance.loadLab()
        if let tone = value("tone").flatMap(NSColor.init(hex:)) { appearance.tone = WindowAppearance.legible(tone) }
        if let active = value("transparency").flatMap(Double.init) { appearance.activeTransparency = active }
        if let inactive = value("inactive-transparency").flatMap(Double.init) { appearance.inactiveTransparency = inactive }
        appearance.saveLab()
        if let value = arguments.first(where: { $0.hasPrefix("--surface=") })?.dropFirst("--surface=".count) {
            surfaceStyle = ["classic": .classic, "solid": .solid][String(value)] ?? surfaceStyle
        }
        if let value = arguments.first(where: { $0.hasPrefix("--lab-surface=") })?.dropFirst("--lab-surface=".count) {
            surface = String(value)
        }
        load(.demo)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        if ProcessInfo.processInfo.arguments.contains("--bright-backdrop") { brightBackdrop = true }
        controls = NSWindow(contentRect: NSRect(x: 100, y: 40, width: 650, height: 214),
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
        if let directory = arguments.first(where: { $0.hasPrefix("--snapshot-dir=") })?.dropFirst("--snapshot-dir=".count) {
            auditTask = Task { [weak self] in await self?.snapshotMatrix(into: URL(fileURLWithPath: String(directory), isDirectory: true)) }
        } else if ProcessInfo.processInfo.arguments.contains("--audit") {
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
        state.labSurface = surfaceStyle
        state.labReferenceTypography = referenceType
        state.shortcutLabel = dataset == .worst ? "⌃⌥⇧⌘Space" : "⌥N"
        editor = EditorController(store: store)
        state.overlayDidChange = { [weak self] overlay in
            self?.editor.setModalPresented(overlay != nil)
            if overlay == nil { self?.store.query = ""; self?.editor.focus() }
        }
        state.trashNote = { [weak self] id in self?.store.moveToTrash(id) }
        state.windowAppearance = WindowAppearance.loadLab()
        state.labIncreasedContrast = increasedContrast
        state.windowIsKey = panel.isKeyWindow
        state.setWindowControlsVisible = { [weak self] visible in self?.panel.setWindowControlsVisible(visible) }
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
        panel.adoptToolbarTitlebar(into: state)
        let view = NSHostingView(rootView: WorkspaceView(store: store, state: state, editor: editor)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight))
        view.sizingOptions = []
        panel.setRoundedContent(view)
        pointerTracker = PointerTracker(view: view) { [weak self] inside in self?.state.pointerInside = inside }
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
        state.overlay = ["Notes": .browse, "Settings": .settings, "Actions": .actions][surface]
        if surface == "Notes" { state.focusSearchToken += 1 }
    }
    func resize() {
        var frame = panel.frame
        frame.size.width = CGFloat(width)
        if let screen = panel.screen {
            frame.origin.x = max(screen.visibleFrame.minX, min(frame.origin.x, screen.visibleFrame.maxX - frame.width))
        }
        panel.setFrame(frame, display: true)
        updateBackdrop()
    }
    func updateBackdrop() {
        guard brightBackdrop, let panel else { backdrop?.orderOut(nil); return }
        let window = backdrop ?? {
            let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.ignoresMouseEvents = true
            window.contentView = NSHostingView(rootView: BrightBackdrop())
            backdrop = window
            return window
        }()
        window.setFrame(panel.frame.insetBy(dx: -140, dy: -90), display: true)
        window.order(.below, relativeTo: panel.windowNumber)
    }
    func applyEnvironment() {
        editor.webView?.pageZoom = zoom ? 2 : 1
        editor.webView?.evaluateJavaScript(
            "document.documentElement.classList.toggle('lab-reference-type', \(referenceType));",
            completionHandler: nil
        )
        editor.webView?.evaluateJavaScript("document.documentElement.dir = '\(rtl ? "rtl" : "ltr")'", completionHandler: nil)
    }
    func changeDirection() { load(dataset) }

    // MARK: Material snapshots
    // Captures the panel through the window server, so Liquid Glass and the
    // window material appear as composited on screen. Needs no Screen Recording
    // permission for this app's own windows.
    @objc private func saveSnapshot() {
        let url = root.appendingPathComponent("snapshot-\(surfaceStyle.id)-\(surface).png".replacingOccurrences(of: " ", with: "-"))
        status = writeSnapshot(to: url) ? "Snapshot saved: \(url.path)" : "Snapshot failed"
    }

    @discardableResult
    func writeSnapshot(to url: URL) -> Bool {
        typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return false }
        let create = unsafeBitCast(symbol, to: CreateImage.self)
        // Capture the panel's rectangle including the windows beneath it, so the
        // behind-window material shows what it actually blurs (for example the
        // bright backdrop). Other apps' windows appear only with Screen Recording
        // permission; this app's own windows always do.
        let screenHeight = NSScreen.screens.first?.frame.maxY ?? panel.frame.maxY
        let rect = CGRect(x: panel.frame.minX, y: screenHeight - panel.frame.maxY, width: panel.frame.width, height: panel.frame.height)
        let options = CGWindowListOption([.optionOnScreenBelowWindow, .optionIncludingWindow]).rawValue
        guard let image = create(rect, options, CGWindowID(panel.windowNumber), CGWindowImageOption.bestResolution.rawValue)?.takeRetainedValue(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot failed: \(url.lastPathComponent) visible=\(panel.isVisible) window=\(panel.windowNumber) app-hidden=\(NSApp.isHidden)\n".utf8))
            return false
        }
        return (try? data.write(to: url)) != nil
    }

    /// Retries while the window server catches up (for example right after
    /// launch or an app switch), so a matrix run doesn't silently lose frames.
    private func captureRetrying(_ url: URL) async -> Bool {
        for attempt in 0..<5 {
            if NSApp.isHidden { NSApp.unhide(nil) }
            if !panel.isVisible { panel.orderFrontRegardless() }
            if writeSnapshot(to: url) { return true }
            try? await Task.sleep(nanoseconds: UInt64(200_000_000 * (attempt + 1)))
        }
        return false
    }

    /// --snapshot-dir=<path>: every surface style × Editor/Notes/Settings, plus
    /// the bright-backdrop worst case, then quit.
    func snapshotMatrix(into directory: URL) async {
        isAuditing = true
        state.labForcesKeyAppearance = true
        state.windowIsKey = true
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = await waitForEditor(editor, hasNote: store.selectedNote != nil)
        var written: [String] = []
        let styles = SurfaceStyle.allCases.filter { $0 != .glass || SurfaceStyle.supportsLiquidGlass }
        for backdropOn in [false, true] {
            brightBackdrop = backdropOn
            for style in styles where !backdropOn || style != .solid {
                surfaceStyle = style
                for name in ["Editor", "Notes", "Settings", "Actions"] {
                    surface = name; showSurface()
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    let file = "\(style == .glass ? "glass" : style == .classic ? "classic" : "solid")\(backdropOn ? "-bright" : "")-\(name.lowercased()).png"
                    if await captureRetrying(directory.appendingPathComponent(file)) { written.append(file) }
                }
            }
        }
        // Inactive: another app is key and the pointer is elsewhere, so the
        // window is more see-through and its controls are hidden.
        surfaceStyle = SurfaceStyle.supportsLiquidGlass ? .glass : .classic; brightBackdrop = true; surface = "Editor"; showSurface()
        state.labForcesKeyAppearance = false; state.windowIsKey = false; state.pointerInside = false
        try? await Task.sleep(nanoseconds: 900_000_000)
        if await captureRetrying(directory.appendingPathComponent("inactive-bright-editor.png")) { written.append("inactive-bright-editor.png") }
        state.labForcesKeyAppearance = true; state.windowIsKey = true
        increasedContrast = true
        try? await Task.sleep(nanoseconds: 700_000_000)
        if await captureRetrying(directory.appendingPathComponent("contrast-bright-editor.png")) { written.append("contrast-bright-editor.png") }
        increasedContrast = false
        // The glass formatting strip, open at a roomy and at the minimum width.
        if SurfaceStyle.supportsLiquidGlass {
            surfaceStyle = .glass; brightBackdrop = true; surface = "Editor"; showSurface()
            for snapshotWidth in [480, 360] {
                width = snapshotWidth; resize()
                state.formattingVisible = true
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                let file = "glass-strip-\(snapshotWidth).png"
                if await captureRetrying(directory.appendingPathComponent(file)) { written.append(file) }
                state.formattingVisible = false
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
        // The native link field, requested by the editor itself (JS → native).
        width = 480; resize(); brightBackdrop = true; surface = "Editor"; showSurface()
        editor.focus()
        try? await Task.sleep(nanoseconds: 400_000_000)
        editor.command("link")
        try? await Task.sleep(nanoseconds: 900_000_000)
        let linkFile = editor.linkRequest == nil ? "link-not-requested.png" : "link-editor.png"
        if await captureRetrying(directory.appendingPathComponent(linkFile)) { written.append(linkFile) }
        editor.cancelLink()
        try? written.joined(separator: "\n").write(to: directory.appendingPathComponent("done.txt"), atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }
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
        controls.orderOut(nil)
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
                            if bar == "find" {
                                _ = try? await js("document.getElementById('link-close').click()")
                                // Tiptap restores editor focus on its next frame.
                                // Let that finish before opening the next field.
                                try? await Task.sleep(nanoseconds: 50_000_000)
                            }
                            // WebKit suppresses :focus-visible in an inactive
                            // window even when document.activeElement is set.
                            NSApp.activate(ignoringOtherApps: true)
                            panel.makeKeyAndOrderFront(nil)
                            if let webView = editor.webView { panel.makeFirstResponder(webView) }
                            _ = try? await js(bar == "link" ? "window.jot.runCommand('link')" : "document.getElementById('show-find').click(); window.jot.find('Decision')")
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

    func windowDidBecomeKey(_ notification: Notification) {
        if notification.object as? NSWindow === panel, !(state?.labForcesKeyAppearance ?? false) { state?.windowIsKey = true }
    }
    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSWindow === panel, !(state?.labForcesKeyAppearance ?? false) { state?.windowIsKey = false }
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
                Picker("Surface", selection: $lab.surface) { ForEach(["Editor", "Notes", "Settings", "Actions"], id: \.self) { Text($0) } }
                    .onChange(of: lab.surface) { _, _ in lab.showSurface() }
                Picker("Width", selection: $lab.width) { ForEach(Array(Set([320, 360, 480, 780, BreakUILabDelegate.widestWidth])).sorted(), id: \.self) { Text("\($0) pt").tag($0) } }
                    .onChange(of: lab.width) { _, _ in lab.resize() }
                Toggle("200% editor", isOn: $lab.zoom).onChange(of: lab.zoom) { _, _ in lab.applyEnvironment() }
                Toggle("RTL probe", isOn: $lab.rtl).onChange(of: lab.rtl) { _, _ in lab.changeDirection() }
            }.font(.system(size: 11))
            if let state = lab.state { LabAppearanceControls(state: state) }
            HStack(spacing: 12) {
                Picker("Material", selection: $lab.surfaceStyle) {
                    ForEach(SurfaceStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                            .disabled(style == .glass && !SurfaceStyle.supportsLiquidGlass)
                    }
                }.pickerStyle(.segmented)
                Toggle("Bright backdrop", isOn: $lab.brightBackdrop)
                Toggle("Increase Contrast", isOn: $lab.increasedContrast)
                Toggle("Reference type", isOn: $lab.referenceType)
            }.font(.system(size: 11))
            Text(lab.status).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }.padding(14).frame(width: 650, height: 214).preferredColorScheme(.dark).disabled(lab.isAuditing)
    }
}

/// Tunes the shipped window appearance (`WindowAppearance.standard`). Values
/// are kept in the lab's preferences; Copy puts Swift source on the clipboard.
private struct LabAppearanceControls: View {
    @ObservedObject var state: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("Tone").font(.system(size: 11))
                ForEach(WindowAppearance.presets, id: \.hex) { preset in
                    Button(preset.name) { update { $0.tone = WindowAppearance.legible(NSColor(hex: preset.hex) ?? .black) } }
                        .buttonStyle(.link).font(.system(size: 11))
                        .fontWeight(state.windowAppearance.isPreset(preset.hex) ? .bold : .regular)
                }
                ColorPicker("Custom tone", selection: Binding(get: { state.windowAppearance.color },
                                                           set: { color in update { $0.tone = WindowAppearance.legible(NSColor(color)) } }),
                            supportsOpacity: false).labelsHidden()
                Spacer()
                Button("Copy values") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.windowAppearance.swiftLiteral, forType: .string)
                }.font(.system(size: 11)).help("Copies the Swift for WindowAppearance.standard")
            }
            HStack(spacing: 10) {
                slider("Active", value: \.activeTransparency)
                    .help("AA contrast for captions holds up to \(Int(WindowAppearance.measuredActiveLimit * 100))% on Black over a bright desktop")
                slider("Inactive", value: \.inactiveTransparency)
            }
        }
    }

    private func slider(_ title: String, value: WritableKeyPath<WindowAppearance, Double>) -> some View {
        HStack(spacing: 6) {
            Slider(value: Binding(get: { state.windowAppearance[keyPath: value] }, set: { new in update { $0[keyPath: value] = new } }),
                   in: WindowAppearance.labRange) { Text(title).font(.system(size: 11)) }
            Text("\(Int((state.windowAppearance[keyPath: value] * 100).rounded()))%").font(.system(size: 11)).monospacedDigit().frame(width: 34)
        }
    }

    private func update(_ change: (inout WindowAppearance) -> Void) {
        change(&state.windowAppearance)
        state.windowAppearance.saveLab()
    }
}

/// High-luminance, high-detail content for judging glass and material legibility.
private struct BrightBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.white, .yellow, .cyan, .pink, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(0..<24, id: \.self) { line in
                    Text("Bright, busy desktop content behind Jot · line \(line + 1)")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(line.isMultiple(of: 2) ? Color.black : Color.blue)
                }
            }.padding(30)
        }
    }
}
#endif
