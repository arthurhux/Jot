import AppKit
import SwiftUI

// LAYERS (Apple HIG · Materials, macOS 26)
//   Content  The note and its window background use a standard material, never
//            Liquid Glass, so writing stays legible on any desktop. People pick
//            its tone and transparency in Settings (WindowAppearance).
//   Controls Toolbar groups, the footer toggle, find bar, banners, and modal
//            cards float above the note in Liquid Glass.
//   Inside a glass card, controls use vibrant fills rather than more glass, so
//            glass is never stacked on glass.
// macOS 14–15 use the same window material with the shipped frosted modal card.
// Reduce Transparency uses opaque surfaces on every version.

/// How Jot draws its window, chrome, and modal surfaces.
enum SurfaceStyle: String, CaseIterable, Identifiable, Sendable {
    /// macOS 26+: Liquid Glass chrome over a translucent window material.
    case glass = "Liquid Glass"
    /// macOS 14–15: the shipped look with a frosted modal card.
    case classic = "macOS 14–15"
    /// Reduce Transparency: opaque theme surfaces everywhere.
    case solid = "Reduce Transparency"

    var id: String { rawValue }

    static var supportsLiquidGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The system preference wins over a developer preview, except that the UI
    /// Lab may explicitly preview the solid fallback.
    static func resolve(reduceTransparency: Bool, override: SurfaceStyle?) -> SurfaceStyle {
        if reduceTransparency { return .solid }
        if let override { return override == .glass && !supportsLiquidGlass ? .classic : override }
        return supportsLiquidGlass ? .glass : .classic
    }

    /// The window material is a standard material, available on every
    /// supported macOS; only Reduce Transparency makes the window opaque.
    var translucentWindow: Bool { self != .solid }
}

private struct SurfaceStyleKey: EnvironmentKey {
    static let defaultValue: SurfaceStyle = .classic
}

private struct SecondaryTextKey: EnvironmentKey {
    static let defaultValue = JotTheme.mutedForeground
}

extension EnvironmentValues {
    /// Captions, counts, hints, placeholders, and quiet icons. Brightened over
    /// a translucent window to keep WCAG AA (WindowAppearance.secondaryText).
    var secondaryText: Color {
        get { self[SecondaryTextKey.self] }
        set { self[SecondaryTextKey.self] = newValue }
    }
    var surfaceStyle: SurfaceStyle {
        get { self[SurfaceStyleKey.self] }
        set { self[SurfaceStyleKey.self] = newValue }
    }
}

enum WindowShape {
    /// Matches macOS 26 toolbar windows; nested glass (toolbar capsule, T)
    /// sits close enough to the corners to read as concentric.
    static let cornerRadius = 26.0
}

/// The note's text column. Title and body share one leading inset; the body
/// starts just below the title, as in Raycast Notes.
enum NoteLayout {
    static let inset = 30.0
    static let titleTop = 14.0
    static let titleBottom = 2.0
}

/// Shows the toolbar and formatting button only while Jot is in use: the
/// window is key, the pointer is over it, or a modal is open (like Raycast).
/// Fades with `MotionTokens.chrome`; hidden controls can't be clicked.
struct ChromeFade: ViewModifier {
    let visible: Bool
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .animation(MotionTokens.chrome, value: visible)
    }
}

enum GlassTokens {
    /// Vibrant fills used on glass instead of opaque theme grays.
    static let hoverFill = 0.08
    static let pressedFill = 0.16
    static let selectedFill = 0.12
    static let hairline = 0.10
    static let toolbarGroupSpacing = 6.0
    /// HIG (macOS): 28×28 pt is the default control size, 20×20 pt the minimum.
    static let controlSize = 28.0
    /// Toolbar slots are a little wider than tall and touch, so the group's
    /// hit regions are contiguous.
    static let toolbarItemWidth = 32.0
    /// A glass icon button: 16 pt icon plus 7 pt padding each side.
    static let glassIconSize = 30.0
    static let commandSpacing = 6.0
    /// Inset between the toolbar capsule and its items, so item highlights
    /// stay concentric with the capsule (18 pt radius − 4 = 14 pt).
    static let groupInset = 4.0
}

/// The accent for controls (switch on-state, links, the prominent action).
/// Follows the person's System Settings accent color, which is blue by default.
/// Apple's dark-mode system blue keeps 4.5:1 contrast on Jot's dark backgrounds,
/// so it remains readable as link text.
enum JotAccent {
    static var control: Color { Color(nsColor: .controlAccentColor) }
}

// MARK: - Window (content layer)

/// The panel background: a standard behind-window material under the chosen
/// tone, or the tone alone when opaque or with Reduce Transparency.
struct WindowBackdrop: View {
    let style: SurfaceStyle
    let appearance: WindowAppearance
    /// Darker while Jot is in use, more see-through otherwise; capped under
    /// Increase Contrast.
    let transparency: Double

    var body: some View {
        Group {
            if style.translucentWindow {
                ZStack {
                    WindowMaterial()
                    appearance.color.opacity(1 - transparency)
                        .animation(MotionTokens.chrome, value: transparency)
                }
            } else {
                appearance.color
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct WindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        // Stay translucent while another app is frontmost: the panel floats
        // over other apps and is often not key.
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

// MARK: - Modal cards (control layer)

struct ModalCard: ViewModifier {
    let style: SurfaceStyle

    func body(content: Content) -> some View {
        if #available(macOS 26, *), style == .glass {
            // System glass supplies its own edge highlight and shadow.
            content.glassEffect(.regular, in: .rect(cornerRadius: ModalStyle.cornerRadius))
        } else {
            content
                .background { ModalSurface(solid: style == .solid) }
                .clipShape(RoundedRectangle(cornerRadius: ModalStyle.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: ModalStyle.cornerRadius)
                        .stroke(LinearGradient(colors: [JotTheme.foreground.opacity(ModalStyle.rimTopOpacity), JotTheme.foreground.opacity(ModalStyle.rimBottomOpacity)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(ModalStyle.shadowOpacity), radius: ModalStyle.shadowRadius, y: ModalStyle.shadowOffset)
        }
    }
}

// MARK: - Floating chrome (control layer)

/// A capsule of neighboring actions, like a macOS 26 toolbar item group.
/// Falls back to the plain row on earlier systems.
struct GlassGroup: ViewModifier {
    let style: SurfaceStyle

    func body(content: Content) -> some View {
        if #available(macOS 26, *), style == .glass {
            GlassEffectContainer(spacing: GlassTokens.toolbarGroupSpacing) {
                content
                    .padding(GlassTokens.groupInset)
                    .glassEffect(.regular, in: .capsule)
            }
        } else {
            content
        }
    }
}

/// A floating bar or card over the note (find, notices, errors, the editor
/// failure card). `tint` marks status, such as a failed save, never decoration.
/// Earlier systems keep the opaque theme fill they shipped with.
struct GlassBar: ViewModifier {
    let style: SurfaceStyle
    var tint: Color? = nil
    var fallback: Color = JotTheme.card
    var cornerRadius: CGFloat = JotTheme.radius + 4
    /// Full-width strips on earlier systems become inset floating bars on glass.
    var fullWidthFallback = true

    func body(content: Content) -> some View {
        if #available(macOS 26, *), style == .glass {
            content
                .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                .padding(.horizontal, fullWidthFallback ? 10 : 0).padding(.vertical, fullWidthFallback ? 4 : 0)
        } else if fullWidthFallback {
            content.background(fallback)
        } else {
            content.background(fallback, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// The label inside an interactive glass circle. The glass itself supplies the
/// press response, so this style only sets size, color, and hit shape.
struct GlassIconButtonStyle: ButtonStyle {
    @Environment(\.secondaryText) private var secondaryText
    let isOn: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isOn ? JotTheme.foreground : secondaryText)
            .padding(7)
            .contentShape(Circle())
    }
}

/// The empty-state primary action: prominent glass on macOS 26+.
struct ProminentAction: ViewModifier {
    let style: SurfaceStyle

    func body(content: Content) -> some View {
        if #available(macOS 26, *), style == .glass {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

extension SurfaceStyle {
    /// Hairlines inside glass cards are vibrant rather than opaque gray.
    var hairline: Color { self == .glass ? JotTheme.foreground.opacity(GlassTokens.hairline) : JotTheme.border }
    /// Row selection inside a glass card lets the glass show through.
    var selectedFill: Color { self == .glass ? JotTheme.foreground.opacity(GlassTokens.selectedFill) : JotTheme.accent }
    var hoverFill: Color { JotTheme.foreground.opacity(GlassTokens.hoverFill) }
    var pressedFill: Color { self == .glass ? JotTheme.foreground.opacity(GlassTokens.pressedFill) : JotTheme.accent }
    /// Hover and selection highlights: capsules inside glass, rounded elsewhere.
    var highlightShape: AnyShape {
        self == .glass ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: JotTheme.smallRadius))
    }
}
