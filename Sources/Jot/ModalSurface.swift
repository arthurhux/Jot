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

/// Frost only the card; the surrounding note stays sharp beneath the scrim.
struct ModalSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency {
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
    var submit: () -> Void
    var move: (Int) -> Void
    var dismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> ModalTextField {
        let field = ModalTextField()
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.font = .systemFont(ofSize: 15)
        field.textColor = NSColor(JotTheme.foreground)
        field.placeholderAttributedString = NSAttributedString(string: "Search for notes…", attributes: [.foregroundColor: NSColor(JotTheme.mutedForeground)])
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.identifier = NSUserInterfaceItemIdentifier("notesSearch")
        field.setAccessibilityLabel("Search notes")
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateNSView(_ field: ModalTextField, context: Context) {
        context.coordinator.parent = self
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
