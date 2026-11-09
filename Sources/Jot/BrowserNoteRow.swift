import SwiftUI

/// Resolve the live note by ID so reparenting between sections cannot retain
/// an old value for the pin action, title, or metadata.
struct BrowserNoteRow: View {
    @Environment(\.secondaryText) private var secondaryText
    let noteID: UUID
    @ObservedObject var store: NoteStore
    @ObservedObject var state: AppState
    let choose: (UUID) -> Void
    let requestPermanentDeletion: (UUID) -> Void
    @Environment(\.surfaceStyle) private var surface

    var body: some View {
        if let note = store.notes.first(where: { $0.id == noteID }) {
            HStack(spacing: 8) {
                Button { choose(note.id) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(note.displayTitle).font(state.usesReferenceTypography ? ModalTypography.referenceNoteTitle : ModalTypography.noteTitle).lineLimit(1).help(note.displayTitle)
                        HStack(spacing: 5) {
                            if store.selectedID == note.id {
                                Circle().fill(JotTheme.sidebarPrimary).frame(width: 5, height: 5)
                                    .accessibilityHidden(true)
                            }
                            Text(metadata(note))
                                .font(state.usesReferenceTypography ? ModalTypography.referenceMetadata : ModalTypography.caption.monospacedDigit())
                                .foregroundStyle(isSelected && !state.usesReferenceTypography ? JotTheme.foreground : secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: ModalLayout.noteRowHeight, alignment: .leading)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(note.displayTitle)
                    .accessibilityValue(metadata(note))
                HStack(spacing: 8) {
                    if note.isDeleted {
                        Button { store.restore(note.id) } label: { JotIcon("undo-2") }
                            .buttonStyle(QuietButtonStyle()).help("Restore note").accessibilityLabel("Restore note")
                        Button { requestPermanentDeletion(note.id) } label: { JotIcon("trash-2") }
                            .buttonStyle(QuietButtonStyle()).help("Delete permanently").accessibilityLabel("Delete permanently")
                    } else {
                        Button { store.togglePin(note.id) } label: { JotIcon(note.pinned ? "pin-off" : "pin") }
                            .buttonStyle(QuietButtonStyle()).help(note.pinned ? "Unpin note" : "Pin note")
                            .accessibilityLabel(note.pinned ? "Unpin note" : "Pin note")
                        Button { state.trashNote?(note.id) } label: { JotIcon("trash-2") }
                            .buttonStyle(QuietButtonStyle()).help("Move to recently deleted").accessibilityLabel("Move to recently deleted")
                    }
                }
                .opacity(isSelected ? 1 : 0)
                .animation(highlightAnimation, value: isSelected)
                .allowsHitTesting(isSelected)
                .disabled(!isSelected)
                .accessibilityHidden(!isSelected)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: ModalLayout.noteRowHeight)
            .background(isSelected ? surface.selectedFill : .clear, in: RoundedRectangle(cornerRadius: JotTheme.radius))
            .animation(highlightAnimation, value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: JotTheme.radius))
            .onHover { inside in
                if inside {
                    state.browseSelectionUsesKeyboard = false
                    state.browseSelection = note.id
                }
            }
            // Every hover-only action is also in the context menu (HIG Pointing
            // devices: hidden controls need another way in).
            .contextMenu {
                if note.isDeleted {
                    Button("Restore", jotIcon: "undo-2") { store.restore(note.id) }
                    Button("Delete Permanently…", jotIcon: "trash-2", role: .destructive) { requestPermanentDeletion(note.id) }
                } else {
                    Button(note.pinned ? "Unpin" : "Pin", jotIcon: note.pinned ? "pin-off" : "pin") { store.togglePin(note.id) }
                    Button("Move to Recently Deleted", jotIcon: "trash-2", role: .destructive) { state.trashNote?(note.id) }
                }
            }
        }
    }

    private var isSelected: Bool { state.browseSelection == noteID }

    /// Pointer hover fades the highlight (tens of times a day: fast and
    /// subtle). Keyboard selection moves it instantly.
    private var highlightAnimation: Animation? {
        state.browseSelectionUsesKeyboard ? nil : MotionTokens.hover
    }

    private func metadata(_ note: Note) -> String {
        let status = store.selectedID == note.id ? "Current" : "Edited " + BrowserNoteDate.formatted(note.modifiedAt)
        let count = note.plainText.count
        return "\(status) · \(count.formatted()) \(count == 1 ? "character" : "characters")"
    }
}

enum BrowserNoteDate {
    /// Compare and format in the same calendar/time zone, including at New Year.
    static func formatted(_ date: Date, relativeTo now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated).day()
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) { style = style.year() }
        return date.formatted(style)
    }
}
