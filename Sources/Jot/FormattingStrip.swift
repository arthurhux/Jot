import SwiftUI

// MOTION STORYBOARD · formatting strip (macOS 26+, Liquid Glass)
//   0ms   T is pressed. Its glass circle takes the selected tint.
//   0ms   The command nearest T morphs out of T's glass (glassEffectID).
//  +30ms  Each further command follows, right to left: liquid poured from T.
//  close  Commands fold back into T in reverse order, 30ms apart.
// Spring: Apple-style duration 0.5, bounce 0.2. Each step retargets, so a
// second press mid-animation reverses from wherever the strip is.
// Reduce Motion: no morph or stagger. Every command materializes in place.

enum FormattingCommand: String, CaseIterable, Identifiable {
    case toggleBold, toggleItalic, toggleStrike, toggleCode, link
    case toggleBulletList, toggleOrderedList, toggleTaskList, toggleCodeBlock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleBold: "Bold"
        case .toggleItalic: "Italic"
        case .toggleStrike: "Strikethrough"
        case .toggleCode: "Inline code"
        case .link: "Link"
        case .toggleBulletList: "Bulleted list"
        case .toggleOrderedList: "Numbered list"
        case .toggleTaskList: "Checklist"
        case .toggleCodeBlock: "Code block"
        }
    }

    var icon: String {
        switch self {
        case .toggleBold: "bold"
        case .toggleItalic: "italic"
        case .toggleStrike: "strikethrough"
        case .toggleCode: "code"
        case .link: "link"
        case .toggleBulletList: "list"
        case .toggleOrderedList: "list-ordered"
        case .toggleTaskList: "list-todo"
        case .toggleCodeBlock: "square-code"
        }
    }

    var help: String {
        switch self {
        case .toggleBold: "Bold · ⌘B"
        case .toggleItalic: "Italic · ⌘I"
        case .link: "Link · ⌘K"
        default: title
        }
    }
}

extension MotionTokens {
    /// Apple-style spring for glass morphs.
    static let glassMorph = Animation.spring(duration: 0.5, bounce: 0.2)
    /// Delay between neighbouring commands as the strip opens or closes.
    static let glassStagger: UInt64 = 30_000_000
    /// Materialize without movement when Reduce Motion is on.
    static let glassFade = Animation.easeOut(duration: 0.2)
}

/// The footer's T button and, when open, a row of glass formatting commands
/// that grows from it toward the leading edge. `capacity` is how many command
/// slots fit; extra commands move into a final More menu.
@available(macOS 26, *)
struct GlassFormattingStrip: View {
    @Environment(\.secondaryText) private var secondaryText
    @Binding var isExpanded: Bool
    @ObservedObject var editor: EditorController
    let capacity: Int

    @Namespace private var glass
    @State private var shown = 0
    @State private var stagger: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: (inline: [FormattingCommand], overflow: [FormattingCommand]) {
        let all = FormattingCommand.allCases
        guard capacity < all.count else { return (all, []) }
        let inline = max(0, capacity - 1)
        return (Array(all.prefix(inline)), Array(all.dropFirst(inline)))
    }

    private var slotCount: Int { layout.inline.count + (layout.overflow.isEmpty ? 0 : 1) }

    var body: some View {
        let layout = layout
        GlassEffectContainer(spacing: GlassTokens.commandSpacing) {
            HStack(spacing: GlassTokens.commandSpacing) {
                ForEach(Array(layout.inline.enumerated()), id: \.element.id) { index, command in
                    // Slots fill from the right, so the command next to T shows first.
                    if index >= slotCount - shown { commandButton(command) }
                }
                if !layout.overflow.isEmpty, shown >= 1 { overflowMenu(layout.overflow) }
                toggle
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Formatting")
        .onAppear { shown = isExpanded ? slotCount : 0 }
        .onChange(of: isExpanded) { _, expanded in run(to: expanded ? slotCount : 0) }
        .onChange(of: capacity) { _, _ in if isExpanded { shown = slotCount } }
        .onDisappear { stagger?.cancel() }
    }

    private var toggle: some View {
        Button { isExpanded.toggle() } label: { JotIcon("type") }
            .buttonStyle(GlassIconButtonStyle(isOn: isExpanded))
            .glassEffect(isExpanded ? .regular.tint(JotTheme.foreground.opacity(GlassTokens.selectedFill)).interactive() : .regular.interactive(), in: .circle)
            .glassEffectID("toggle", in: glass)
            .help(isExpanded ? "Hide formatting" : "Formatting")
            .accessibilityLabel("Formatting")
            .accessibilityValue(isExpanded ? "Shown" : "Hidden")
    }

    private func commandButton(_ command: FormattingCommand) -> some View {
        let active = editor.formatting[command.rawValue] == true
        return Button { editor.command(command.rawValue) } label: { JotIcon(command.icon) }
            .buttonStyle(GlassIconButtonStyle(isOn: active))
            .glassEffect(active ? .regular.tint(JotTheme.foreground.opacity(GlassTokens.selectedFill)).interactive() : .regular.interactive(), in: .circle)
            .glassEffectID(command.id, in: glass)
            .glassEffectTransition(reduceMotion ? .materialize : .matchedGeometry)
            .disabled(!editor.formattingEditable)
            .help(command.help)
            .accessibilityLabel(command.title)
            .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func overflowMenu(_ commands: [FormattingCommand]) -> some View {
        Menu {
            ForEach(commands) { command in
                Button(command.title, jotIcon: command.icon) { editor.command(command.rawValue) }
            }
        } label: {
            // AppKit draws a borderless menu label as a template image tinted with
            // the accent; bake in the muted color so it matches its neighbours.
            JotIcon("ellipsis", color: secondaryText, preservesColor: true)
        }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .frame(width: GlassTokens.glassIconSize, height: GlassTokens.glassIconSize)
            .contentShape(Circle())
            .glassEffect(.regular.interactive(), in: .circle)
            .glassEffectID("more", in: glass)
            .glassEffectTransition(reduceMotion ? .materialize : .matchedGeometry)
            .disabled(!editor.formattingEditable)
            .help("More formatting")
            .accessibilityLabel("More formatting")
    }

    /// Steps `shown` toward `target` one command at a time. Cancelling the
    /// previous run lets a second press reverse from the current state.
    private func run(to target: Int) {
        stagger?.cancel()
        if reduceMotion {
            withAnimation(MotionTokens.glassFade) { shown = target }
            return
        }
        stagger = Task { @MainActor in
            while shown != target, !Task.isCancelled {
                withAnimation(MotionTokens.glassMorph) { shown += target > shown ? 1 : -1 }
                try? await Task.sleep(nanoseconds: MotionTokens.glassStagger)
            }
        }
    }
}
