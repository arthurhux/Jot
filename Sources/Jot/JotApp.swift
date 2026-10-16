import AppKit
import Carbon
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

final class NotesPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var escape: (() -> Void)?
    var shortcut: ((NSEvent) -> Bool)?
    override func cancelOperation(_ sender: Any?) { escape?() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // A nonactivating panel can keep another app's menu bar. Route standard
        // native field-editor commands locally instead of depending on that menu.
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if let fieldEditor = firstResponder as? NSTextView, fieldEditor.isFieldEditor,
           modifiers.contains(.command), modifiers.intersection([.control, .option]).isEmpty,
           let key = event.charactersIgnoringModifiers?.lowercased() {
            let shifted = modifiers.contains(.shift)
            switch key {
            case "a" where !shifted: fieldEditor.selectAll(nil); return true
            case "c" where !shifted: fieldEditor.copy(nil); return true
            case "x" where !shifted && fieldEditor.isEditable: fieldEditor.cut(nil); return true
            case "v" where !shifted && fieldEditor.isEditable: fieldEditor.paste(nil); return true
            case "z" where fieldEditor.isEditable:
                if shifted { fieldEditor.undoManager?.redo() } else { fieldEditor.undoManager?.undo() }
                return true
            default: break
            }
        }
        if shortcut?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

@main
enum JotApp {
    @MainActor static func main() {
        let application = NSApplication.shared
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--break-ui") || Bundle.main.object(forInfoDictionaryKey: "JotBreakUILab") as? Bool == true {
            let lab = BreakUILabDelegate()
            application.delegate = lab
            application.appearance = NSAppearance(named: .darkAqua)
            application.setActivationPolicy(.regular)
            application.run()
            withExtendedLifetime(lab) {}
            return
        }
#endif
        let delegate = AppDelegate()
        application.delegate = delegate
        application.appearance = NSAppearance(named: .darkAqua)
        // Remain available through the status item and hotkey without a Dock
        // or Command-Tab entry. Accessory apps can still present our panel.
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store: NoteStore
    let state = AppState()
    let editor: EditorController
    private var panel: NotesPanel!
    private var statusItem: NSStatusItem!
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var quickShortcut = RecordedShortcut.defaultShortcut
    private var librarySize = NSSize(width: 780, height: 590)
    private var lastEditorHeight = 280.0
    private var terminating = false
    private var terminationReplySent = false
    private var allowUnsavedQuit = false
    private var terminationAttempt = UUID()
    private var smokeRunner: SmokeTestRunner?

    override init() {
        let testDirectory = ProcessInfo.processInfo.environment["JOT_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? (ProcessInfo.processInfo.arguments.contains("--smoke-test") ? FileManager.default.temporaryDirectory.appendingPathComponent("JotSmoke-\(UUID().uuidString)", isDirectory: true) : nil)
        store = NoteStore(directory: testDirectory)
        editor = EditorController(store: store)
        super.init()
        if let saved = UserDefaults.standard.dictionary(forKey: "JotQuickShortcut"),
           let keyCode = saved["keyCode"] as? Int, let modifiers = saved["modifiers"] as? Int,
           let label = saved["label"] as? String, keyCode >= 0, keyCode <= 127, modifiers > 0, modifiers <= Int(UInt32.max) {
            quickShortcut = RecordedShortcut(keyCode: UInt32(keyCode), carbonModifiers: UInt32(modifiers), label: label)
        }
        state.shortcutLabel = quickShortcut.label
        let preferences = UserDefaults.standard
        if preferences.object(forKey: "JotFloating") != nil { state.alwaysOnTop = preferences.bool(forKey: "JotFloating") }
        if preferences.object(forKey: "JotCompact") != nil { state.compact = preferences.bool(forKey: "JotCompact") }
        if preferences.object(forKey: "JotAutoFit") != nil { state.autoFit = preferences.bool(forKey: "JotAutoFit") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenus()
        buildWindow()
        buildStatusItem()
        installHotKey()
        wireActions()
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            let runner = SmokeTestRunner(store: store, editor: editor, state: state, shortcutRegistered: hotKey != nil, shortcutLabel: quickShortcut.label)
            smokeRunner = runner
            runner.run()
        }
    }

    private func buildWindow() {
        panel = NotesPanel(contentRect: NSRect(origin: .zero, size: state.compact ? NSSize(width: 480, height: 560) : librarySize), styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Jot"
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = JotTheme.nsBackground
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = state.alwaysOnTop ? .floating : .normal
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .none
        panel.minSize = NSSize(width: 360, height: 280)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications, .fullScreenDisallowsTiling]
        panel.delegate = self
        let content = NSHostingView(rootView: WorkspaceView(store: store, state: state, editor: editor))
        // The panel controls sizing; SwiftUI must not replace its constraints.
        content.sizingOptions = []
        panel.contentView = content
        panel.center()
        panel.setFrameAutosaveName("JotNotesWindow")
        panel.minSize = NSSize(width: 360, height: 280)
        if panel.frame.width < 360 || panel.frame.height < 280 {
            var frame = panel.frame
            frame.size = NSSize(width: max(360, frame.width), height: max(280, frame.height))
            panel.setFrame(frame, display: false)
        }
        panel.escape = { [weak self] in self?.escape() }
        panel.shortcut = { [weak self] event in self?.handlePanelShortcut(event) ?? false }
    }

    private func wireActions() {
        state.toggleCompact = { [weak self] in
            guard let self else { return }
            self.setCompact(!self.state.compact, animate: true)
        }
        state.toggleFloating = { [weak self] in self?.toggleFloating(nil) }
        state.fitWindow = { [weak self] in self?.fitWindow(nil) }
        state.exportNote = { [weak self] in self?.exportNote(nil) }
        state.importNote = { [weak self] in self?.importNote(nil) }
        state.hideWindow = { [weak self] in self?.hideWindow() }
        state.trashNote = { [weak self] id in self?.moveToTrash(id) }
        state.configureShortcut = { [weak self] in self?.changeShortcut(nil) }
        state.overlayDidChange = { [weak self] overlay in
            guard let self else { return }
            self.editor.setModalPresented(overlay != nil)
            if overlay == nil { self.store.query = ""; self.editor.focus() }
        }
        editor.onHeight = { [weak self] height in
            guard let self else { return }
            self.lastEditorHeight = height
            if self.state.compact && self.state.autoFit { self.resizeToContent(animate: false) }
        }
    }

    private func buildMenus() {
        let menu = NSMenu()
        let appMenu = NSMenu(title: "Jot")
        appMenu.addItem(item("About Jot", #selector(about(_:))))
        appMenu.addItem(item("Settings…", #selector(showSettings(_:)), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Hide Jot", #selector(NSApplication.hide(_:)), key: "h", target: NSApplication.shared))
        appMenu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option], target: NSApplication.shared))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Quit Jot", #selector(NSApplication.terminate(_:)), key: "q", target: NSApplication.shared))
        addMenu(appMenu, to: menu)

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(item("New Note", #selector(newNote(_:)), key: "n"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item("Import Markdown…", #selector(importNote(_:)), key: "o"))
        fileMenu.addItem(item("Export Markdown…", #selector(exportNote(_:)), key: "e", modifiers: [.command, .shift]))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item("Move to Recently Deleted", #selector(trashNote(_:)), key: "\u{08}"))
        fileMenu.addItem(item("Close Window", #selector(closeWindow(_:)), key: "w"))
        addMenu(fileMenu, to: menu)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(item("Undo", Selector(("undo:")), key: "z", target: nil))
        editMenu.addItem(item("Redo", Selector(("redo:")), key: "z", modifiers: [.command, .shift], target: nil))
        editMenu.addItem(.separator())
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(item(title, Selector(selector), key: key, target: nil))
        }
        editMenu.addItem(.separator())
        editMenu.addItem(item("Search Notes", #selector(searchNotes(_:)), key: "f"))
        editMenu.addItem(item("Find in Note", #selector(findInNote(_:)), key: "f", modifiers: [.command, .shift]))
        addMenu(editMenu, to: menu)

        let formatMenu = NSMenu(title: "Format")
        for (title, command, key) in [("Bold", "toggleBold", "b"), ("Italic", "toggleItalic", "i"), ("Strikethrough", "toggleStrike", ""), ("Inline Code", "toggleCode", ""), ("Bullet List", "toggleBulletList", ""), ("Numbered List", "toggleOrderedList", ""), ("Checklist", "toggleTaskList", ""), ("Code Block", "toggleCodeBlock", "")] {
            let entry = item(title, #selector(formatNote(_:)), key: key)
            entry.representedObject = command
            formatMenu.addItem(entry)
        }
        addMenu(formatMenu, to: menu)

        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(item("Browse Notes", #selector(browseNotes(_:)), key: "p"))
        viewMenu.addItem(item("Compact Window", #selector(toggleCompact(_:)), key: "m", modifiers: [.command, .shift]))
        viewMenu.addItem(item("Keep Window on Top", #selector(toggleFloating(_:)), key: "p", modifiers: [.command, .shift]))
        viewMenu.addItem(item("Fit Window to Note", #selector(fitWindow(_:))))
        addMenu(viewMenu, to: menu)
        NSApplication.shared.mainMenu = menu
    }

    private func item(_ title: String, _ selector: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target ?? self
        // Standard editing commands follow the responder chain into WebKit or a title field.
        if ["undo:", "redo:", "cut:", "copy:", "paste:", "selectAll:"].contains(NSStringFromSelector(selector)) { item.target = nil }
        return item
    }

    private func addMenu(_ submenu: NSMenu, to menu: NSMenu) {
        let parent = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = JotIcon.nativeImage("square.and.pencil")
        statusItem.button?.toolTip = "Jot · \(quickShortcut.label)"
        let menu = NSMenu()
        menu.addItem(item("Show / Hide Notes", #selector(toggleWindow(_:))))
        menu.addItem(item("New Note", #selector(newNote(_:))))
        menu.addItem(.separator())
        let shortcut = NSMenuItem(title: "Quick toggle: \(quickShortcut.label)", action: nil, keyEquivalent: "")
        shortcut.isEnabled = false
        shortcut.representedObject = "shortcutInfo"
        menu.addItem(shortcut)
        menu.addItem(item("Settings…", #selector(showSettings(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quit Jot", #selector(NSApplication.terminate(_:)), target: NSApplication.shared))
        statusItem.menu = menu
    }

    private func installHotKey() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let handler: EventHandlerUPP = { _, _, data in
            guard let data else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
            MainActor.assumeIsolated { delegate.toggleWindow(nil) }
            return noErr
        }
        let handlerResult = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &event, pointer, &hotKeyHandler)
        guard handlerResult == noErr else {
            state.notice = "The quick-toggle shortcut couldn’t be enabled. You can still open Jot from the menu bar."
            return
        }
        if !registerShortcut(quickShortcut) {
            state.notice = "The shortcut \(quickShortcut.label) is in use. Choose another in Settings."
        }
    }

    private func registerShortcut(_ shortcut: RecordedShortcut) -> Bool {
        let identifier = EventHotKeyID(signature: 0x4A4F5420, id: 1)
        return RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, identifier, GetApplicationEventTarget(), UInt32(kEventHotKeyExclusive), &hotKey) == noErr
    }

    @objc func changeShortcut(_ sender: Any?) {
        showWindow(sender)
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        let previous = quickShortcut
        ShortcutRecorderPresenter.present(for: panel, currentLabel: previous.label) { [weak self] recorded in
            guard let self else { return }
            if let recorded, self.registerShortcut(recorded) {
                self.quickShortcut = recorded
                self.state.shortcutLabel = recorded.label
                self.state.notice = nil
                UserDefaults.standard.set(["keyCode": Int(recorded.keyCode), "modifiers": Int(recorded.carbonModifiers), "label": recorded.label], forKey: "JotQuickShortcut")
                self.statusItem.button?.toolTip = "Jot · \(recorded.label)"
                self.statusItem.menu?.items.first(where: { $0.representedObject as? String == "shortcutInfo" })?.title = "Quick toggle: \(recorded.label)"
            } else {
                let restored = self.registerShortcut(previous)
                if recorded != nil { self.state.notice = "That shortcut is already in use. \(restored ? "Your previous shortcut is still active." : "Choose another shortcut from the menu bar.")" }
                else if !restored { self.state.notice = "Your previous shortcut is unavailable. Choose another from the menu bar." }
            }
        }
    }

    @objc func showWindow(_ sender: Any?) {
        NSApplication.shared.unhideWithoutActivation()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    @objc func toggleWindow(_ sender: Any?) {
        if panel.isVisible && panel.isKeyWindow { hideWindow() } else { showWindow(sender) }
    }

    private func hideWindow() {
        editor.captureSnapshot { [weak self] in self?.store.flush() }
        panel.orderOut(nil)
    }

    @objc func closeWindow(_ sender: Any?) { hideWindow() }

    @objc func newNote(_ sender: Any?) {
        state.overlay = nil
        _ = store.createNote()
        showWindow(sender)
        DispatchQueue.main.async { [weak self] in self?.editor.focus() }
    }

    @objc func searchNotes(_ sender: Any?) {
        showWindow(sender)
        store.query = ""; store.showingTrash = false
        state.showSearch()
    }
    @objc func browseNotes(_ sender: Any?) { searchNotes(sender) }
    @objc func showSettings(_ sender: Any?) { showWindow(sender); state.overlay = .settings }
    @objc func findInNote(_ sender: Any?) { state.overlay = nil; state.findVisible = true }
    @objc func trashNote(_ sender: Any?) { if let id = store.selectedID { moveToTrash(id) } }
    private func moveToTrash(_ id: UUID) {
        editor.captureSnapshot { [weak self] in self?.store.moveToTrash(id) }
    }
    @objc func formatNote(_ sender: NSMenuItem) { if let command = sender.representedObject as? String { editor.command(command) } }
    @objc func toggleCompact(_ sender: Any?) { setCompact(!state.compact, animate: false) }
    @objc func toggleFloating(_ sender: Any?) {
        state.alwaysOnTop.toggle()
        panel.level = state.alwaysOnTop ? .floating : .normal
        UserDefaults.standard.set(state.alwaysOnTop, forKey: "JotFloating")
    }
    @objc func fitWindow(_ sender: Any?) { state.autoFit = true; if state.compact { resizeToContent(animate: false) } }

    private func setCompact(_ compact: Bool, animate: Bool) {
        if compact {
            librarySize = panel.frame.size
            panel.minSize = NSSize(width: 360, height: 280)
            state.compact = true
            state.alwaysOnTop = true
            panel.level = .floating
            state.autoFit = true
            resizeToContent(animate: animate)
        } else {
            panel.minSize = NSSize(width: 420, height: 320)
            state.compact = false
            resizeWindow(to: librarySize, animate: animate)
        }
        UserDefaults.standard.set(compact, forKey: "JotCompact")
    }

    private func resizeToContent(animate: Bool) {
        let maxHeight = min(760.0, (panel.screen?.visibleFrame.height ?? 900) - 60)
        let height = min(maxHeight, max(300, lastEditorHeight + 135))
        resizeWindow(to: NSSize(width: 480, height: height), animate: animate)
    }

    private func resizeWindow(to size: NSSize, animate: Bool) {
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        if let visible = panel.screen?.visibleFrame {
            frame.origin.x = min(max(frame.origin.x, visible.minX), max(visible.minX, visible.maxX - frame.width))
            frame.origin.y = min(max(frame.origin.y, visible.minY), max(visible.minY, visible.maxY - frame.height))
        }
        if animate && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = MotionTokens.disclosureResponse
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 0.72, 0, 1)
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
    }

    private func escape() {
        if state.overlay != nil { state.overlay = nil; editor.focus() }
        else if state.findVisible { state.findVisible = false }
        else if !store.query.isEmpty { store.query = ""; editor.focus() }
        else { hideWindow() }
    }

    /// Non-activating panels keep the other app's menu bar. Route Jot's own
    /// keyboard commands through its key window rather than that app's menu.
    private func handlePanelShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53, modifiers.intersection([.command, .control, .option]).isEmpty {
            escape(); return true
        }
        if state.overlay == .browse, modifiers.intersection([.command, .control, .option]).isEmpty {
            let notes = store.visibleNotes
            if event.keyCode == 125 || event.keyCode == 126 {
                guard !notes.isEmpty else { return true }
                let current = notes.firstIndex(where: { $0.id == state.browseSelection }) ?? 0
                let next = min(notes.count - 1, max(0, current + (event.keyCode == 125 ? 1 : -1)))
                state.browseSelectionUsesKeyboard = true
                state.browseSelection = notes[next].id
                return true
            }
            if event.keyCode == 36, let id = state.browseSelection ?? notes.first?.id {
                store.select(id); state.overlay = nil; editor.focus(); return true
            }
        }
        guard modifiers.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        guard !modifiers.contains(.control), !modifiers.contains(.option) else { return false }
        let shifted = modifiers.contains(.shift)
        switch key {
        case "n" where !shifted: newNote(nil)
        case "f": shifted ? findInNote(nil) : searchNotes(nil)
        case "m" where shifted: toggleCompact(nil)
        case "p" where shifted: toggleFloating(nil)
        case "p" where !shifted: browseNotes(nil)
        case "," where !shifted: showSettings(nil)
        case "e" where shifted: exportNote(nil)
        case "o" where !shifted: importNote(nil)
        case "w" where !shifted: hideWindow()
        case "q" where !shifted: NSApplication.shared.terminate(nil)
        case "\u{08}", "\u{7F}": trashNote(nil)
        case "b", "i", "z":
            guard let responder = panel.firstResponder as? NSView, let webView = editor.webView,
                  responder === webView || responder.isDescendant(of: webView) else { return false }
            editor.command(key == "b" ? "toggleBold" : key == "i" ? "toggleItalic" : shifted ? "redo" : "undo")
        default: return false
        }
        return true
    }

    @objc func exportNote(_ sender: Any?) {
        guard store.selectedNote != nil else { return }
        editor.captureSnapshot { [weak self] in self?.presentExport() }
    }

    private func presentExport() {
        guard let note = store.selectedNote else { return }
        let dialog = NSSavePanel()
        dialog.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        let safeTitle = note.displayTitle.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        dialog.nameFieldStringValue = "\(safeTitle).md"
        dialog.beginSheetModal(for: panel) { [weak self] response in
            guard response == .OK, let url = dialog.url else { return }
            do { try note.markdown.write(to: url, atomically: true, encoding: .utf8) }
            catch { self?.state.notice = "Couldn’t export this note. \(error.localizedDescription)" }
        }
    }

    @objc func importNote(_ sender: Any?) {
        showWindow(sender)
        let dialog = NSOpenPanel()
        dialog.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText]
        dialog.allowsMultipleSelection = true
        dialog.canChooseDirectories = false
        dialog.beginSheetModal(for: panel) { [weak self] response in
            guard response == .OK, let self else { return }
            for url in dialog.urls {
                do {
                    let size = (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
                    guard size <= 10_000_000 else { self.state.notice = "\(url.lastPathComponent) is too large. Import notes smaller than 10 MB."; continue }
                    let markdown = try String(contentsOf: url, encoding: .utf8)
                    let id = self.store.createNote()
                    self.store.updateTitle(id: id, title: url.deletingPathExtension().lastPathComponent)
                    self.store.updateContent(id: id, document: "", plainText: markdown, markdown: markdown)
                } catch { self.state.notice = "Couldn’t import \(url.lastPathComponent). \(error.localizedDescription)" }
            }
        }
    }

    @objc func about(_ sender: Any?) {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.applicationName: "Jot", .applicationVersion: "1.0", .credits: NSAttributedString(string: "A little room to think.\nNotes saved on your Mac.")])
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { hideWindow(); return false }
    func windowWillStartLiveResize(_ notification: Notification) { if state.compact { state.autoFit = false } }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(nil); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if allowUnsavedQuit { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true
        let attempt = UUID()
        terminationAttempt = attempt
        editor.captureSnapshot { [weak self] in
            guard let self, self.terminationAttempt == attempt else { return }
            self.finishTermination()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.terminationAttempt == attempt else { return }
            self.finishTermination()
        }
        return .terminateLater
    }
    private func finishTermination() {
        guard terminating, !terminationReplySent else { return }
        terminationReplySent = true
        if store.flush() {
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        } else {
            NSApplication.shared.reply(toApplicationShouldTerminate: false)
            terminating = false
            terminationReplySent = false
            showWindow(nil)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Your latest edits couldn’t be saved"
            alert.informativeText = "Keep Jot open to preserve your edits, or try saving again. Quitting without saving will lose changes since the last successful save."
            alert.addButton(withTitle: "Retry Save")
            alert.addButton(withTitle: "Keep Jot Open")
            alert.addButton(withTitle: "Quit Without Saving")
            alert.beginSheetModal(for: panel) { [weak self] response in
                guard let self else { return }
                if response == .alertFirstButtonReturn {
                    if self.store.flush() { NSApplication.shared.terminate(nil) }
                } else if response == .alertThirdButtonReturn {
                    self.allowUnsavedQuit = true
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    }
}
