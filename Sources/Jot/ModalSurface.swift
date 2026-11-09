import AppKit
import SwiftUI

enum ModalStyle {
    static let cornerRadius = 16.0
    static let scrimOpacity = 0.38
    static let tintOpacity = 0.32
    static let rimTopOpacity = 0.18
    static let rimBottomOpacity = 0.07
    static let shadowOpacity = 0.38
    static let shadowRadius = 20.0
    static let shadowOffset = 8.0
}

/// Native point sizes for the compact utility modals; captions stay at 12pt.
enum ModalTypography {
    static let title = Font.system(size: 17, weight: .semibold)
    /// HIG macOS Headline: 13 pt bold, the window-title weight.
    static let windowTitle = Font.system(size: 13, weight: .semibold)
    /// The note's own title: HIG macOS Title 1 (22 pt), bold like Raycast Notes.
    static let noteHeading = Font.system(size: 22, weight: .bold)
    static let label = Font.system(size: 13, weight: .medium)
    static let section = Font.system(size: 12, weight: .semibold)
    static let caption = Font.system(size: 12)
    static let noteTitle = Font.system(size: 14, weight: .medium)
    static let shortcut = Font.system(size: 14, weight: .medium)
    static let descriptionLineSpacing = 3.0
    static let referenceWindowTitle = Font.system(size: 14, weight: .semibold)
    static let referenceEditorTitle = Font.system(size: 22, weight: .bold)
    static let referenceNoteTitle = Font.system(size: 14, weight: .semibold)
    static let referenceMetadata = Font.system(size: 14, weight: .medium)
    static let referenceSearch = NSFont.systemFont(ofSize: 14, weight: .medium)
}

enum ModalLayout {
    static let noteRowHeight = 64.0
    static let sectionHeaderHeight = 36.0
    static let browserChromeHeight = 108.0
    static let emptyResultsHeight = 110.0
    static let minimumBrowserHeight = 240.0
    static let maximumBrowserHeight = 500.0
    static let settingsHeight = 400.0
    static let settingsInset = 22.0
    static let settingsSectionSpacing = 24.0
    static let settingsRowHeight = 40.0
    static let shortcutSpacing = 6.0
}

/// The macOS 14–15 modal card: frost only the card while the note stays sharp
/// beneath the scrim. `solid` replaces the material for Reduce Transparency.
/// macOS 26+ uses system Liquid Glass instead (see `ModalCard`).
struct ModalSurface: View {
    var solid = false

    var body: some View {
        ZStack {
            if solid {
                JotTheme.popover
            } else {
                ModalMaterial()
                JotTheme.popover.opacity(ModalStyle.tintOpacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ModalStyle.cornerRadius))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ModalMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.material = .hudWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        view.wantsLayer = true
        view.layer?.cornerRadius = ModalStyle.cornerRadius
        view.layer?.masksToBounds = true
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// The non-activating panel needs a real AppKit first responder on presentation.
struct NotesSearchField: NSViewRepresentable {
    @Binding var text: String
    var focusToken: Int
    var placeholder = "Search for notes…"
    var placeholderColor = NSColor(JotTheme.mutedForeground)
    var label = "Search notes"
    var referenceTypography = false
    var submit: () -> Void
    var move: (Int) -> Void
    var dismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> ModalTextField {
        let field = ModalTextField()
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        // Search retains its native first responder and caret without the
        // default blue rectangle competing with the modal's search surface.
        field.focusRingType = .none
        field.cell?.focusRingType = .none
        field.textColor = NSColor(JotTheme.foreground)
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.identifier = NSUserInterfaceItemIdentifier("notesSearch")
        field.setAccessibilityLabel(label)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateNSView(_ field: ModalTextField, context: Context) {
        context.coordinator.parent = self
        if field.placeholderAttributedString?.string != placeholder || context.coordinator.placeholderColor != placeholderColor {
            context.coordinator.placeholderColor = placeholderColor
            field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [.foregroundColor: placeholderColor])
        }
        let font = referenceTypography ? ModalTypography.referenceSearch : .systemFont(ofSize: 15)
        if field.font != font {
            field.font = font
            (field.currentEditor() as? NSTextView)?.font = font
        }
        if field.stringValue != text { field.stringValue = text }
        if context.coordinator.focusToken != focusToken {
            context.coordinator.focusToken = focusToken
            field.requestFocus()
        }
    }

    final class ModalTextField: NSTextField {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            requestFocus()
        }
        func requestFocus() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                window.makeFirstResponder(self)
            }
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NotesSearchField
        var focusToken: Int?
        var placeholderColor: NSColor?
        init(_ parent: NotesSearchField) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch NSStringFromSelector(commandSelector) {
            case "moveDown:": parent.move(1)
            case "moveUp:": parent.move(-1)
            case "insertNewline:": parent.submit()
            case "cancelOperation:": parent.dismiss()
            default: return false
            }
            return true
        }
    }
}
