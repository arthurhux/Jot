import AppKit
import SwiftUI
import WebKit

@MainActor
final class EditorController: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var failure: String?
    @Published var matchCount = 0
    weak var webView: WKWebView?
    let store: NoteStore
    var onHeight: ((Double) -> Void)?
    private var pendingNote: Note?
    private var loadedID: UUID?
    private var loadedDeleted = false
    private var dark = false
    private var searchQuery = ""
    private var modalPresented = false

    init(store: NoteStore) { self.store = store }

    func load(_ note: Note?, dark: Bool) {
        self.dark = dark
        pendingNote = note
        guard isReady, let note else { return }
        execute("window.jot.setAppearance(\(dark ? "true" : "false"))")
        guard loadedID != note.id || loadedDeleted != note.isDeleted else { return }
        loadedID = note.id
        loadedDeleted = note.isDeleted
        var payload: [String: Any] = [
            "id": note.id.uuidString, "markdown": note.markdown, "plainText": note.plainText,
            "caretFrom": note.caretFrom, "caretTo": note.caretTo, "scrollTop": note.scrollTop,
            "editable": !note.isDeleted && !modalPresented
        ]
        payload["json"] = note.document.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? NSNull()
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) else { return }
        execute("window.jot.loadNote(\(json))")
        if !note.isDeleted && !modalPresented { execute("window.jot.focus()") }
        if !searchQuery.isEmpty { find(searchQuery) }
    }

    func command(_ name: String, value: Any? = nil) {
        guard isReady, !modalPresented else { return }
        let args: [Any] = [name, value ?? NSNull()]
        guard let data = try? JSONSerialization.data(withJSONObject: args), let json = String(data: data, encoding: .utf8) else { return }
        execute("window.jot.runCommand(...\(json))")
    }

    func focus() { if !modalPresented { execute("window.jot.focus()") } }

    func setModalPresented(_ presented: Bool) {
        modalPresented = presented
        (webView as? EditorWebView)?.allowsEditorFocus = !presented
        if presented { webView?.window?.makeFirstResponder(nil) }
        if isReady { execute("window.jot.setEditable(\(!presented && pendingNote?.isDeleted == false ? "true" : "false"))") }
    }

    func find(_ query: String) {
        searchQuery = query
        guard let data = try? JSONSerialization.data(withJSONObject: [query]), let json = String(data: data, encoding: .utf8) else { return }
        execute("window.jot.find(...\(json))")
    }

    func nextMatch() { execute("window.jot.nextMatch()") }
    func showFormatting(_ visible: Bool) { execute("window.jot.setToolbarVisible(\(visible ? "true" : "false"))") }

    func captureSnapshot(completion: @escaping @MainActor () -> Void) {
        guard isReady, let webView else { Task { @MainActor in completion() }; return }
        webView.evaluateJavaScript("window.jot.getSnapshot()") { [weak self] result, _ in
            if let message = result as? [String: Any] { self?.applyContent(message) }
            completion()
        }
    }

    func retry() {
        failure = nil
        isReady = false
        loadedID = nil
        webView?.reload()
    }

    private func execute(_ source: String) {
        webView?.evaluateJavaScript(source) { [weak self] _, error in
            if let error { self?.failure = "The editor couldn’t complete that action. \(error.localizedDescription)" }
        }
    }

    func receive(_ message: [String: Any]) {
        switch message["type"] as? String {
        case "ready":
            isReady = true
            failure = nil
            loadedID = nil
            load(pendingNote, dark: dark)
        case "content": applyContent(message)
        case "selection":
            guard let id = id(from: message) else { return }
            store.updatePosition(id: id, from: message["from"] as? Int ?? 1, to: message["to"] as? Int ?? 1)
        case "scroll":
            guard let id = id(from: message) else { return }
            store.updateScroll(id: id, top: message["top"] as? Double ?? 0)
        case "height": onHeight?(message["value"] as? Double ?? 360)
        case "search": matchCount = message["count"] as? Int ?? 0
        case "error": failure = message["message"] as? String ?? "The editor encountered an error."
        default: break
        }
    }

    private func id(from message: [String: Any]) -> UUID? {
        (message["id"] as? String).flatMap(UUID.init(uuidString:))
    }

    private func applyContent(_ message: [String: Any]) {
        guard let id = id(from: message), let document = message["json"],
              JSONSerialization.isValidJSONObject(document),
              let data = try? JSONSerialization.data(withJSONObject: document, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return }
        store.updateContent(id: id, document: json, plainText: message["plainText"] as? String ?? "", markdown: message["markdown"] as? String ?? "")
        if let from = message["caretFrom"] as? Int {
            store.updatePosition(id: id, from: from, to: message["caretTo"] as? Int ?? from)
        }
        if let top = message["scrollTop"] as? Double { store.updateScroll(id: id, top: top) }
    }
}

struct NativeEditor: NSViewRepresentable {
    var note: Note?
    @ObservedObject var controller: EditorController
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(controller) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "jot")
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = EditorWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.isInspectable = ProcessInfo.processInfo.arguments.contains("--inspect-editor")
        controller.webView = webView
        let packaged = Bundle.main.resourceURL?.appendingPathComponent("Editor/index.html")
        let resource = packaged.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            ?? Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Editor")
        if let resource {
            webView.loadFileURL(resource, allowingReadAccessTo: resource.deletingLastPathComponent())
        } else {
            controller.failure = "Editor files are missing. Rebuild Jot with scripts/build-app.sh."
        }
        controller.load(note, dark: colorScheme == .dark)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        controller.load(note, dark: colorScheme == .dark)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "jot")
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let controller: EditorController
        init(_ controller: EditorController) { self.controller = controller }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let payload = message.body as? [String: Any] else { return }
            controller.receive(payload)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(url.isFileURL || url.absoluteString == "about:blank" ? .allow : .cancel)
            }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            controller.failure = "Couldn’t load the editor. \(error.localizedDescription)"
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { controller.retry() }
    }
}

final class EditorWebView: WKWebView {
    var allowsEditorFocus = true
    override var acceptsFirstResponder: Bool { allowsEditorFocus && super.acceptsFirstResponder }
    override func becomeFirstResponder() -> Bool { allowsEditorFocus && super.becomeFirstResponder() }
}
