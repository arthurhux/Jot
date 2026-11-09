import AppKit
import SwiftUI

/// The note window's tone and how much of the blurred desktop shows through.
/// Like Raycast, Jot is darker while you work in it and more see-through when
/// another app is active; its controls hide then too (see WorkspaceView).
/// These values ship as `standard`. They are tuned in the UI Lab, which keeps
/// its own copy in the lab's preferences; there is no user-facing setting.
struct WindowAppearance: Equatable {
    var tone: NSColor
    /// Share of the window material visible while Jot is the key window.
    var activeTransparency: Double
    /// Share visible while another app is active and the pointer is outside.
    var inactiveTransparency: Double

    var color: Color { Color(nsColor: tone) }

    func transparency(active: Bool) -> Double { active ? activeTransparency : inactiveTransparency }

    /// Chosen in the UI Lab: 60% while active, 85% while inactive. Measured over
    /// the lab's bright backdrop, muted captions (#A1A1A1) stay above WCAG AA
    /// (4.5:1) up to about 50% active, so at 60% they read a little below AA on
    /// very bright desktops; body text stays well above. See AppStore/README.md.
    static let standard = WindowAppearance(tone: NSColor(hex: "#0A0A0A")!, activeTransparency: 0.6, inactiveTransparency: 0.85)

    /// The UI Lab's slider range. Values above the active limit trade contrast
    /// for translucency; the lab shows the measured limit beside the slider.
    static let labRange = 0.0...0.85
    static let measuredActiveLimit = 0.5

    /// Darkest-first presets for the lab.
    static let presets: [(name: String, hex: String)] = [
        ("Black", "#0A0A0A"),
        ("Graphite", "#1C1C1E"),
        ("Midnight", "#141B2D"),
        ("Slate", "#1B2128"),
        ("Plum", "#221A26"),
        ("Forest", "#16201B"),
    ]

    /// Highest relative luminance a tone may have before light text loses
    /// contrast on it; lighter picks are darkened toward this.
    static let maximumToneLuminance = 0.015

    static func legible(_ color: NSColor) -> NSColor {
        guard var rgb = color.usingColorSpace(.sRGB) else { return color }
        var steps = 0
        while rgb.relativeLuminance > maximumToneLuminance, steps < 80 {
            rgb = NSColor(srgbRed: rgb.redComponent * 0.94, green: rgb.greenComponent * 0.94, blue: rgb.blueComponent * 0.94, alpha: 1)
            steps += 1
        }
        return NSColor(srgbRed: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: 1)
    }

    func isPreset(_ hex: String) -> Bool { tone.hexString == NSColor(hex: hex)?.hexString }

    // SECONDARY TEXT · WCAG AA over a translucent window
    // Measured in the UI Lab over its bright backdrop (90th-percentile
    // luminance behind text), on Black:
    //   window   36% → 0.0244   50% → 0.0369   60% → 0.0466   85% → 0.0759
    //   modal    60% → 0.0722 (glass cards sit about 0.026 lighter)
    // A line through the window points (slightly conservative) predicts the
    // window's worst case; modals add the measured offset. Secondary text is
    // the darkest gray keeping 4.8:1 there (AA is 4.5:1), never darker than
    // #A1A1A1. Shipped: window 60% → #B0B0B0, modal → #C5C5C5, 85% → #C7C7C7.
    static let contrastTarget = 4.8
    static let modalLuminanceOffset = 0.026

    /// Highest background luminance expected behind text at this transparency.
    func worstBackgroundLuminance(transparency t: Double, inModal: Bool = false) -> Double {
        let measuredOnBlack = max(0, -0.0156 + 0.1112 * t)
        let toneLift = max(0, tone.relativeLuminance - 0.003) * (1 - t)
        return max(tone.relativeLuminance, measuredOnBlack + toneLift) + (inModal ? Self.modalLuminanceOffset : 0)
    }

    /// Secondary text (captions, counts, hints, placeholders, quiet icons).
    func secondaryText(transparency t: Double, inModal: Bool = false) -> NSColor {
        let required = Self.contrastTarget * (worstBackgroundLuminance(transparency: t, inModal: inModal) + 0.05) - 0.05
        let luminance = min(0.9, max(NSColor(hex: "#A1A1A1")!.relativeLuminance, required))
        let linear = luminance <= 0.0031308 ? luminance * 12.92 : 1.055 * pow(luminance, 1 / 2.4) - 0.055
        return NSColor(srgbRed: linear, green: linear, blue: linear, alpha: 1)
    }

    /// Increase Contrast keeps the window close to opaque.
    static let increasedContrastTransparency = 0.2

    /// Swift source for `standard`, so tuned lab values can be pasted back.
    var swiftLiteral: String {
        String(format: "WindowAppearance(tone: NSColor(hex: \"%@\")!, activeTransparency: %.2f, inactiveTransparency: %.2f)",
               tone.hexString, activeTransparency, inactiveTransparency)
    }

#if DEBUG
    static func loadLab(from defaults: UserDefaults = .standard) -> WindowAppearance {
        var appearance = standard
        if let hex = defaults.string(forKey: "JotLabTone"), let tone = NSColor(hex: hex) { appearance.tone = legible(tone) }
        if defaults.object(forKey: "JotLabActiveTransparency") != nil { appearance.activeTransparency = defaults.double(forKey: "JotLabActiveTransparency") }
        if defaults.object(forKey: "JotLabInactiveTransparency") != nil { appearance.inactiveTransparency = defaults.double(forKey: "JotLabInactiveTransparency") }
        return appearance
    }

    func saveLab(to defaults: UserDefaults = .standard) {
        defaults.set(tone.hexString, forKey: "JotLabTone")
        defaults.set(activeTransparency, forKey: "JotLabActiveTransparency")
        defaults.set(inactiveTransparency, forKey: "JotLabInactiveTransparency")
    }
#endif
}

extension NSColor {
    convenience init?(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#0A0A0A" }
        func byte(_ component: CGFloat) -> Int { Int((min(1, max(0, component)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(rgb.redComponent), byte(rgb.greenComponent), byte(rgb.blueComponent))
    }

    /// WCAG relative luminance of an sRGB color.
    var relativeLuminance: Double {
        guard let rgb = usingColorSpace(.sRGB) else { return 0 }
        func linear(_ c: CGFloat) -> Double {
            let value = Double(c)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
    }
}
