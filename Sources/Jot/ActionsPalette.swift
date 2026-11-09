import SwiftUI

/// One command in the Actions palette. Every action here also exists in the
/// menu bar, as the HIG asks of toolbar commands.
struct JotAction: Identifiable {
    let id: String
    let section: String
    let title: String
    let icon: String
    var shortcut: String?
    var destructive = false
    let perform: () -> Void
}

/// The ⌘ toolbar button and ⌘J open this searchable modal list of actions,
/// in the same glass card and motion as Browse Notes. Pointer hover and arrow
/// keys share one highlight; Return or a click runs the action.
struct ActionsPalette: View {
    @Environment(\.secondaryText) private var secondaryText
    @ObservedObject var state: AppState
    let actions: [JotAction]
    /// Runs an action. `animated` is true for pointer-initiated runs.
    let run: (JotAction, Bool) -> Void
    let dismiss: (Bool) -> Void
    @Environment(\.surfaceStyle) private var surface
    @State private var keyboardSelection = true

    static let rowHeight = 36.0
    static let headerHeight = 28.0
    static let chromeHeight = 104.0

    static func height(for actions: [JotAction]) -> CGFloat {
        let sections = Set(actions.map(\.section)).count
        return chromeHeight + Double(actions.count) * (rowHeight + 2) + Double(sections) * headerHeight
    }

    private var filtered: [JotAction] {
        let query = state.actionsQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return actions }
        return actions.filter { $0.title.localizedStandardContains(query) || $0.section.localizedStandardContains(query) }
    }

    var body: some View {
        let items = filtered
        let showsSections = state.actionsQuery.trimmingCharacters(in: .whitespaces).isEmpty
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                JotIcon("command", size: 16, color: secondaryText)
                NotesSearchField(text: $state.actionsQuery, focusToken: state.focusSearchToken,
                    placeholder: "Search actions…", placeholderColor: NSColor(secondaryText), label: "Search actions",
                    submit: { if items.indices.contains(state.actionSelection) { run(items[state.actionSelection], false) } },
                    move: { move($0, count: items.count) }, dismiss: { dismiss(false) })
                    .frame(maxWidth: .infinity)
                Button { dismiss(true) } label: { JotIcon("x") }.buttonStyle(QuietButtonStyle())
                    .help("Close · Esc").accessibilityLabel("Close Actions")
            }.padding(.horizontal, 17).padding(.vertical, 14)
            Rectangle().fill(surface.hairline).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, action in
                            if showsSections, index == 0 || items[index - 1].section != action.section {
                                Text(action.section).font(ModalTypography.section).foregroundStyle(secondaryText)
                                    .padding(.horizontal, 12).frame(height: Self.headerHeight, alignment: .bottomLeading)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            ActionRow(action: action, selected: index == state.actionSelection, animated: !keyboardSelection,
                                      hover: { keyboardSelection = false; state.actionSelection = index },
                                      run: { run(action, true) })
                                .id(action.id)
                        }
                        if items.isEmpty {
                            Text("No matching actions").font(ModalTypography.label).foregroundStyle(secondaryText)
                                .frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                    }
                    .padding(9)
                }
                .scrollIndicators(.automatic)
                .onChange(of: state.actionSelection) { _, index in
                    // Only keyboard moves scroll; the pointer is already there.
                    if keyboardSelection, items.indices.contains(index) { proxy.scrollTo(items[index].id) }
                }
            }
            Rectangle().fill(surface.hairline).frame(height: 1)
            HStack {
                Spacer()
                Text("↑↓ navigate  ↩ run").foregroundStyle(secondaryText)
                    .accessibilityLabel("Up and Down Arrow move through actions. Return runs the selected action.")
            }.font(ModalTypography.caption).padding(.horizontal, 14).frame(height: 32)
        }
    }

    private func move(_ direction: Int, count: Int) {
        guard count > 0 else { return }
        keyboardSelection = true
        state.actionSelection = min(count - 1, max(0, state.actionSelection + direction))
    }
}

private struct ActionRow: View {
    @Environment(\.secondaryText) private var secondaryText
    let action: JotAction
    let selected: Bool
    /// Pointer hover fades the highlight; keyboard selection moves instantly.
    let animated: Bool
    let hover: () -> Void
    let run: () -> Void
    @Environment(\.surfaceStyle) private var surface

    var body: some View {
        Button(action: run) {
            HStack(spacing: 10) {
                JotIcon(action.icon, color: action.destructive ? JotTheme.destructive : selected ? JotTheme.foreground : secondaryText)
                Text(action.title).font(ModalTypography.label)
                    .foregroundStyle(action.destructive ? JotTheme.destructive : JotTheme.foreground)
                Spacer(minLength: 8)
                if let shortcut = action.shortcut {
                    Text(shortcut).font(ModalTypography.caption).monospacedDigit().foregroundStyle(secondaryText)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: ActionsPalette.rowHeight)
            .background(selected ? surface.selectedFill : .clear, in: RoundedRectangle(cornerRadius: JotTheme.radius, style: .continuous))
            .animation(animated ? MotionTokens.hover : nil, value: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { if $0 { hover() } }
        .accessibilityLabel(action.title)
        .accessibilityValue(action.shortcut.map { "Shortcut \($0)" } ?? "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
