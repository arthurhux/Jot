import AppKit
import SwiftUI

/// Lucide geometry, generated from the same pinned package as the editor.
/// Scale the path, then stroke in display points so weight never scales.
struct JotIcon: View {
    let name: String
    var size: CGFloat
    var color: Color
    var preservesColor: Bool
    nonisolated init(_ name: String, size: CGFloat = LucideGeometry.controlSize, color: Color = JotTheme.mutedForeground, preservesColor: Bool = false) { self.name = name; self.size = size; self.color = color; self.preservesColor = preservesColor }
    var body: some View {
        Group {
            if let image = Self.nativeImage(name, size: size, color: preservesColor ? NSColor(color) : nil) {
                Image(nsImage: image).renderingMode(preservesColor ? .original : .template)
            } else { Color.clear }
        }.foregroundStyle(color).frame(width: size, height: size).accessibilityHidden(true)
    }

    private static func vectorPath(_ name: String) -> CGPath? { LucideGeometry.paths[aliases[name] ?? name] }

    static func nativeImage(_ name: String, size: CGFloat = LucideGeometry.controlSize, color: NSColor? = nil) -> NSImage? {
        guard let path = vectorPath(name) else { return nil }
        // A vector-backed NSImage also works in native menu labels, where a
        // SwiftUI Shape label can be omitted by AppKit's menu representation.
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            var transform = CGAffineTransform(a: rect.width / LucideGeometry.viewBox, b: 0, c: 0, d: rect.height / LucideGeometry.viewBox, tx: rect.minX, ty: rect.minY)
            guard let context = NSGraphicsContext.current?.cgContext, let scaled = path.copy(using: &transform) else { return false }
            context.saveGState()
            context.addPath(scaled)
            context.setStrokeColor((color ?? .black).cgColor)
            context.setLineWidth(LucideGeometry.strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
            context.restoreGState()
            return true
        }
        image.isTemplate = color == nil
        return image
    }

    private static let aliases: [String: String] = [
        "sidebar.left": "panel-left", "pin.fill": "pin", "pin.slash": "pin-off",
        "arrow.up.left.and.arrow.down.right": "maximize-2", "arrow.down.right.and.arrow.up.left": "minimize-2",
        "square.and.pencil": "square-pen", "magnifyingglass": "search", "xmark.circle.fill": "circle-x",
        "note.text": "file-text", "trash": "trash-2", "arrow.left": "arrow-left",
        "square.and.arrow.down": "download", "square.and.arrow.up": "upload",
        "arrow.uturn.backward": "undo-2", "chevron.down": "chevron-down", "xmark": "x",
        "exclamationmark.triangle": "triangle-alert", "info.circle": "info",
    ]
}

extension Label where Title == Text, Icon == JotIcon {
    init(_ title: String, jotIcon: String) { self.init { Text(title) } icon: { JotIcon(jotIcon) } }
}

extension Button where Label == SwiftUI.Label<Text, JotIcon> {
    init(_ title: String, jotIcon: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { SwiftUI.Label(title, jotIcon: jotIcon) }
    }
}
