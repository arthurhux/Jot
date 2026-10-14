import AppKit
import Carbon

struct RecordedShortcut: Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let label: String

    static let defaultShortcut = RecordedShortcut(
        keyCode: UInt32(kVK_ANSI_J),
        carbonModifiers: UInt32(controlKey | optionKey),
        label: "⌃⌥J"
    )
}

@MainActor
enum ShortcutRecorderPresenter {
    static func present(
        for window: NSWindow,
        currentLabel: String,
        completion: @escaping (RecordedShortcut?) -> Void
    ) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Keyboard Shortcut"
        alert.informativeText = "Show or hide Jot from any app. Press a key together with Control, Option, or Command.\n\nCurrent shortcut: \(currentLabel)"
        let save = alert.addButton(withTitle: "Save")
        save.isEnabled = false
        // Return and Escape are recorded only when modified. While the recorder
        // has focus, it consumes those unmodified keys rather than saving a sheet.
        save.keyEquivalent = ""
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Use Default")
        let recorder = ShortcutRecorderView(frame: NSRect(x: 0, y: 0, width: 340, height: 82))
        recorder.onChange = { [weak save] shortcut in save?.isEnabled = shortcut != nil }
        alert.accessoryView = recorder
        alert.window.initialFirstResponder = recorder
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn: completion(recorder.shortcut)
            case .alertThirdButtonReturn: completion(.defaultShortcut)
            default: completion(nil)
            }
        }
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(recorder)
        }
    }
}

@MainActor
private final class ShortcutRecorderView: NSView {
    private(set) var shortcut: RecordedShortcut?
    var onChange: ((RecordedShortcut?) -> Void)?
    private let keyLabel = NSTextField(labelWithString: "Press your shortcut")
    private let hintLabel = NSTextField(labelWithString: "Include ⌃, ⌥, or ⌘ and another key.")

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        keyLabel.alignment = .center
        keyLabel.font = .systemFont(ofSize: 19, weight: .medium)
        keyLabel.frame = NSRect(x: 10, y: 40, width: frameRect.width - 20, height: 26)
        keyLabel.autoresizingMask = [.width]
        hintLabel.alignment = .center
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.frame = NSRect(x: 8, y: 10, width: frameRect.width - 16, height: 18)
        hintLabel.autoresizingMask = [.width]
        addSubview(keyLabel)
        addSubview(hintLabel)
        setAccessibilityElement(true)
        setAccessibilityRole(.textField)
        setAccessibilityLabel("Record keyboard shortcut")
        setAccessibilityHelp("Press a key with Control, Option, or Command. Click Save when finished.")
        setAccessibilityIdentifier("shortcutRecorder")
        // Native drawing is immediate; recording never moves or animates views.
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        border.fill()
        (window?.firstResponder === self ? NSColor.keyboardFocusIndicatorColor : NSColor.separatorColor).setStroke()
        border.lineWidth = window?.firstResponder === self ? 2 : 1
        border.stroke()
    }

    override func becomeFirstResponder() -> Bool { needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) { record(event) }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        record(event)
        return true
    }

    private func record(_ event: NSEvent) {
        // Modifier keys alone never form a shortcut, even if sent as keyDown.
        let modifierKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        guard !modifierKeys.contains(event.keyCode) else { return }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // Unmodified Tab remains native focus navigation. Modified Tab can be
        // recorded when it includes Control, Option, or Command.
        if event.keyCode == UInt16(kVK_Tab), flags.intersection([.command, .option, .control]).isEmpty {
            if flags.contains(.shift) { window?.selectPreviousKeyView(self) }
            else { window?.selectNextKeyView(self) }
            return
        }
        guard !flags.intersection([.command, .option, .control]).isEmpty else {
            hintLabel.stringValue = "Add Control, Option, or Command to this key."
            hintLabel.textColor = .systemOrange
            return
        }
        guard let key = Self.keyLabel(for: event) else {
            hintLabel.stringValue = "Choose a letter, number, or another named key."
            hintLabel.textColor = .systemOrange
            return
        }
        var carbon: UInt32 = 0
        var glyphs = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); glyphs += "⌃" }
        if flags.contains(.option) { carbon |= UInt32(optionKey); glyphs += "⌥" }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey); glyphs += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey); glyphs += "⌘" }
        let recorded = RecordedShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbon, label: glyphs + key)
        shortcut = recorded
        keyLabel.stringValue = recorded.label
        hintLabel.stringValue = "Click Save, or press a different shortcut."
        hintLabel.textColor = .secondaryLabelColor
        setAccessibilityValue(recorded.label)
        onChange?(recorded)
    }

    private static func keyLabel(for event: NSEvent) -> String? {
        let namedKeys: [UInt16: String] = [
            UInt16(kVK_Space): "Space", UInt16(kVK_Return): "↩", UInt16(kVK_Tab): "⇥",
            UInt16(kVK_Delete): "⌫", UInt16(kVK_ForwardDelete): "⌦", UInt16(kVK_Escape): "⎋",
            UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
            UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓",
            UInt16(kVK_Home): "↖", UInt16(kVK_End): "↘",
            UInt16(kVK_PageUp): "⇞", UInt16(kVK_PageDown): "⇟", UInt16(kVK_ANSI_KeypadEnter): "⌤",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4",
            UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6", UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8",
            UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
            UInt16(kVK_F13): "F13", UInt16(kVK_F14): "F14", UInt16(kVK_F15): "F15", UInt16(kVK_F16): "F16",
            UInt16(kVK_F17): "F17", UInt16(kVK_F18): "F18", UInt16(kVK_F19): "F19", UInt16(kVK_F20): "F20"
        ]
        if let named = namedKeys[event.keyCode] { return named }
        guard let characters = event.charactersIgnoringModifiers,
              !characters.isEmpty,
              characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return characters.uppercased()
    }
}
