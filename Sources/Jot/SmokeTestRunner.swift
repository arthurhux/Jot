import AppKit
import Foundation
import WebKit

/// Exercises the real bundled editor and native bridge in an isolated data directory.
/// Run the packaged executable with --smoke-test; it prints a result and exits.
@MainActor
final class SmokeTestRunner {
    private let store: NoteStore
    private let editor: EditorController
    private let state: AppState
    private let shortcutRegistered: Bool
    private let shortcutLabel: String
    init(store: NoteStore, editor: EditorController, state: AppState, shortcutRegistered: Bool, shortcutLabel: String) {
        self.store = store; self.editor = editor
        self.state = state
        self.shortcutRegistered = shortcutRegistered; self.shortcutLabel = shortcutLabel
    }

    func run() {
        Task { @MainActor in
            do {
                try require(shortcutRegistered, "macOS rejected the global shortcut \(shortcutLabel)")
                for _ in 0..<200 {
                    if editor.isReady { break }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                try require(editor.isReady, "Bundled WebKit editor did not become ready: \(editor.failure ?? "timeout")")
                let first = store.createNote()
                store.updateTitle(id: first, title: "Integration test")
                try await pause()
                _ = try await js("window.jot.runCommand('insertMarkdown', 'Hello **world**\\n\\n- [ ] Keep this thought\\n\\n```swift\\nlet answer = 42\\n```')")
                try await pause()
                try require(store.selectedNote?.plainText.contains("Hello world") == true, "Editor content did not reach native storage")
                try require(store.selectedNote?.markdown.contains("**world**") == true, "Bold Markdown did not serialize")
                try require(store.selectedNote?.markdown.contains("- [ ]") == true, "Checklist did not serialize")
                let snapshot = try await js("window.jot.getSnapshot()") as? [String: Any]
                try require(snapshot?["id"] as? String == first.uuidString, "Editor uses the wrong note ID")
                let document = store.selectedNote?.document
                let second = store.createNote()
                try await pause()
                _ = try await js("window.jot.runCommand('insertMarkdown', 'Second note')")
                try await pause()
                try require(store.selectedNote?.plainText.contains("Second note") == true, "Second note failed to save")
                try require(store.selectedNote?.title == "Second note", "Opening text did not automatically name the note")
                try require(store.notes.first(where: { $0.id == first })?.title == "Integration test", "Automatic title overwrote a manual name")
                store.select(first)
                try await pause()
                let restored = try await js("window.jot.getSnapshot()") as? [String: Any]
                try require(restored?["plainText"] as? String == store.selectedNote?.plainText, "Switching notes lost content")
                try require(store.selectedNote?.document == document, "Loading a note unexpectedly changed its document")
                let found = try await js("window.jot.find('world')") as? [String: Any]
                try require(found?["count"] as? Int == 1, "Find did not locate formatted text")
                store.togglePin(first)
                store.moveToTrash(second)
                try require(store.trashCount == 1, "Deleted note was not recoverable")
                store.restore(second)
                try require(store.trashCount == 0, "Restore did not recover note")
                store.flush()
                state.showSearch()
                try await pause()
                guard let window = editor.webView?.window,
                      let search = searchField(in: window.contentView) else { throw Failure("Native modal search field is missing") }
                try require(window.firstResponder === search.currentEditor(), "Notes modal did not take keyboard focus")
                let blocked = try await js("window.jot.runCommand('insertMarkdown', 'Blocked modal edit')") as? Bool
                try require(blocked == false, "The note behind the modal is still editable")
                state.overlay = nil
                try await pause()
                let editable = try await js("document.querySelector('.document:not([hidden]) [contenteditable]')?.getAttribute('contenteditable')") as? String
                try require(editable == "true", "Closing the modal did not restore editing")
                _ = try await js("window.jot.runCommand('insertMarkdown', 'After modal')")
                try await pause()
                try require(store.selectedNote?.plainText.contains("After modal") == true, "Editing after modal dismissal did not reach storage")
                print("JOT_SMOKE_TEST_PASS: global shortcut \(shortcutLabel) registered; WebKit ready; modal focus and edit protection, automatic titles, manual rename protection, Markdown, bold, tasks, code, native autosave, note switching, find, pin, trash, restore")
                fflush(stdout)
                NSApplication.shared.terminate(nil)
            } catch {
                fputs("JOT_SMOKE_TEST_FAIL: \(error.localizedDescription)\n", stderr)
                fflush(stderr)
                exit(1)
            }
        }
    }

    private func js(_ source: String) async throws -> Any? {
        guard let webView = editor.webView else { throw Failure("Web view is missing") }
        return try await webView.evaluateJavaScript(source)
    }
    private func pause() async throws { try await Task.sleep(nanoseconds: 250_000_000) }
    private func searchField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.identifier?.rawValue == "notesSearch" { return field }
        for child in view.subviews { if let field = searchField(in: child) { return field } }
        return nil
    }
    private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw Failure(message) }
    }
    private struct Failure: LocalizedError {
        var errorDescription: String? { message }
        let message: String
        init(_ message: String) { self.message = message }
    }
}
