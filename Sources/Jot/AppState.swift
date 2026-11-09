import AppKit
import Combine

enum WorkspaceOverlay: Equatable, Hashable { case browse, settings, actions }

@MainActor
final class AppState: ObservableObject {
#if DEBUG
    /// UI Lab only: preview another surface style or the reference type scale.
    @Published var labSurface: SurfaceStyle?
    @Published var labReferenceTypography = false
    /// Snapshots from a background launch can't make the window key; draw
    /// controls as they appear in the key window instead.
    @Published var labForcesKeyAppearance = false
    /// Preview Increase Contrast without changing System Settings.
    @Published var labIncreasedContrast = false
#endif
    var surfaceOverride: SurfaceStyle? {
#if DEBUG
        labSurface
#else
        nil
#endif
    }
    var forcesIncreasedContrast: Bool {
#if DEBUG
        labIncreasedContrast
#else
        false
#endif
    }
    var forcesKeyAppearance: Bool {
#if DEBUG
        labForcesKeyAppearance
#else
        false
#endif
    }
    var usesReferenceTypography: Bool {
#if DEBUG
        labReferenceTypography
#else
        false
#endif
    }

    /// Window tone and transparency. Ships as `standard`; the UI Lab tunes it.
    @Published var windowAppearance = WindowAppearance.standard
    /// Jot's panel is the key window. With `pointerInside`, decides whether
    /// the toolbar, window controls, and formatting button are shown.
    @Published var windowIsKey = true
    @Published var pointerInside = false
    var chromeVisible: Bool { windowIsKey || pointerInside || overlay != nil }
    var setWindowControlsVisible: ((Bool) -> Void)?
    /// Actions palette search and keyboard selection.
    @Published var actionsQuery = ""
    @Published var actionSelection = 0
    /// Height of the titlebar region (window controls + Jot's toolbar row).
    @Published var titlebarHeight: CGFloat = 42
    /// Leading space reserved for the window controls.
    @Published var titlebarLeadingInset: CGFloat = 78

    @Published var compact = true
    @Published var alwaysOnTop = true
    @Published var autoFit = true {
        didSet { UserDefaults.standard.set(autoFit, forKey: "JotAutoFit") }
    }
    /// Formatting controls: glass commands in the footer on macOS 26+, the
    /// editor's toolbar elsewhere.
    @Published var formattingVisible = false
    @Published var findVisible = false
    @Published var findQuery = ""
    @Published var focusSearchToken = 0
    @Published var notice: String?
    @Published var shortcutLabel = "⌃⌥J"
    @Published var overlay: WorkspaceOverlay? {
        didSet { if overlay != oldValue { overlayDidChange?(overlay) } }
    }
    @Published var browseSelection: UUID?
    var browseSelectionUsesKeyboard = true
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

enum AppInfo {
    /// The hosted privacy policy (App Review 5.1.1). Set JotPrivacyPolicyURL in
    /// Info.plist; the Settings link is hidden when it's missing.
    static var privacyPolicyURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "JotPrivacyPolicyURL") as? String).flatMap(URL.init(string:))
    }
}
