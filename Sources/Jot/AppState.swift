import AppKit
import Combine

enum WorkspaceOverlay: Equatable { case browse, settings }

@MainActor
final class AppState: ObservableObject {
    @Published var compact = true
    @Published var alwaysOnTop = true
    @Published var autoFit = true {
        didSet { UserDefaults.standard.set(autoFit, forKey: "JotAutoFit") }
    }
    @Published var findVisible = false
    @Published var findQuery = ""
    @Published var focusSearchToken = 0
    @Published var notice: String?
    @Published var shortcutLabel = "⌃⌥J"
    @Published var overlay: WorkspaceOverlay? {
        didSet { if overlay != oldValue { overlayDidChange?(overlay) } }
    }
    @Published var browseSelection: UUID?
    var toggleCompact: (() -> Void)?
    var toggleFloating: (() -> Void)?
    var fitWindow: (() -> Void)?
    var exportNote: (() -> Void)?
    var importNote: (() -> Void)?
    var hideWindow: (() -> Void)?
    var trashNote: ((UUID) -> Void)?
    var configureShortcut: (() -> Void)?
    var overlayDidChange: ((WorkspaceOverlay?) -> Void)?

    func showSearch() {
        overlay = .browse
        focusSearchToken += 1
    }
}
