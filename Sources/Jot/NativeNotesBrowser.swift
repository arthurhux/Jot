import AppKit
import SwiftUI

/// One stable row identity per note, even when it moves between sections.
/// AppKit owns virtualization and accessibility scrolling; SwiftUI draws cells.
enum BrowserListItem: Equatable, Identifiable {
    enum ID: Hashable { case header(String), note(UUID) }
    case header(kind: String, title: String, count: Int)
    case note(UUID)

    var id: ID {
        switch self {
        case .header(let kind, _, _): return .header(kind)
        case .note(let id): return .note(id)
        }
    }
    var noteID: UUID? { if case .note(let id) = self { return id }; return nil }

    static func rows(in sections: [NoteStore.BrowserSection]) -> [BrowserListItem] {
        sections.flatMap { section in
            [.header(kind: section.kind.rawValue, title: section.title, count: section.notes.count)]
                + section.notes.map { .note($0.id) }
        }
    }
}

struct NativeNotesBrowser: NSViewRepresentable {
    @ObservedObject var store: NoteStore
    @ObservedObject var state: AppState
    let choose: (UUID) -> Void
    let requestPermanentDeletion: (UUID) -> Void
    let move: (Int) -> Void
    let dismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 4, left: 9, bottom: 10, right: 9)
        let table = NotesTableView()
        table.autoresizingMask = [.width]
        table.headerView = nil
        table.style = .plain
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .none
        table.focusRingType = .none
        table.intercellSpacing = NSSize(width: 0, height: 3)
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false
        table.allowsTypeSelect = false
        table.floatsGroupRows = false
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
        column.minWidth = 0
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.setAccessibilityLabel("Notes list")
        table.setAccessibilityIdentifier("notesList")
        table.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Scroll to first note") { [weak table] in
                guard let table, table.numberOfRows > 1 else { return false }
                table.scrollRowToVisible(0)
                return true
            },
            NSAccessibilityCustomAction(name: "Scroll to last note") { [weak table] in
                guard let table, table.numberOfRows > 1 else { return false }
                table.scrollRowToVisible(table.numberOfRows - 1)
                return true
            }
        ])
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.didLayout = { [weak coordinator = context.coordinator, weak table] in
            if let table { coordinator?.revealSelection(in: table) }
        }
        table.command = { [weak coordinator = context.coordinator] keyCode in
            guard let coordinator else { return false }
            switch keyCode {
            case 125: coordinator.parent.move(1)
            case 126: coordinator.parent.move(-1)
            case 36, 76:
                if let id = coordinator.parent.state.browseSelection { coordinator.parent.choose(id) }
            case 53: coordinator.parent.dismiss()
            default: return false
            }
            return true
        }
        scroll.documentView = table
        context.coordinator.update(self, table: table)
        return scroll
    }

    func updateNSView(_ view: NSScrollView, context: Context) {
        guard let table = view.documentView as? NSTableView else { return }
        context.coordinator.update(self, table: table)
    }

    static func dismantleNSView(_ view: NSScrollView, coordinator: Coordinator) {
        guard let table = view.documentView as? NotesTableView else { return }
        table.command = nil
        table.didLayout = nil
        table.delegate = nil
        table.dataSource = nil
    }

    @MainActor final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativeNotesBrowser
        private var rows: [BrowserListItem] = []
        private var syncingSelection = false
        private var lastSelection: UUID?
        private var usedKeyboard = false
        private var pendingReveal: Int?
        private var lastQuery: String?

        init(_ parent: NativeNotesBrowser) { self.parent = parent }

        func update(_ parent: NativeNotesBrowser, table: NSTableView) {
            self.parent = parent
            let queryChanged = lastQuery != nil && lastQuery != parent.store.query
            lastQuery = parent.store.query
            let updated = BrowserListItem.rows(in: parent.store.browserSections)
            let identitiesChanged = rows.map(\.id) != updated.map(\.id)
            rows = updated
            syncingSelection = true
            defer { syncingSelection = false }
            if identitiesChanged { table.reloadData() }
            // Header counts and the note values can change without new IDs.
            let visible = table.rows(in: table.visibleRect)
            if visible.location != NSNotFound {
                for row in visible.location..<min(rows.count, NSMaxRange(visible)) {
                    if let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false) as? BrowserTableCell {
                        cell.content.rootView = content(for: row)
                    }
                }
            }
            let selection = parent.state.browseSelection
            if !parent.state.browseSelectionUsesKeyboard || selection == nil { pendingReveal = nil }
            let index = rows.firstIndex { $0.noteID == selection && selection != nil }
            let selected = index.map { IndexSet(integer: $0) } ?? IndexSet()
            if table.selectedRowIndexes != selected { table.selectRowIndexes(selected, byExtendingSelection: false) }
            if parent.state.browseSelectionUsesKeyboard, let index,
               identitiesChanged || queryChanged || lastSelection != selection || !usedKeyboard {
                pendingReveal = index
                table.needsLayout = true
                revealSelection(in: table)
            }
            lastSelection = selection
            usedKeyboard = parent.state.browseSelectionUsesKeyboard
        }

        func revealSelection(in table: NSTableView) {
            // A zero-sized representable can scroll away the section heading
            // before its first layout. Defer until the viewport is attached.
            guard let index = pendingReveal, table.window != nil, table.visibleRect.height > 1,
                  rows.indices.contains(index) else { return }
            pendingReveal = nil
            table.scrollRowToVisible(index)
            if index > 0, rows[index - 1].noteID == nil,
               table.visibleRect.height >= ModalLayout.noteRowHeight + ModalLayout.sectionHeaderHeight + 3 {
                table.scrollRowToVisible(index - 1)
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            rows[row].noteID == nil ? ModalLayout.sectionHeaderHeight : ModalLayout.noteRowHeight
        }
        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { rows[row].noteID != nil }
        func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool { rows[row].noteID == nil }
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !syncingSelection, let table = notification.object as? NSTableView,
                  rows.indices.contains(table.selectedRow), let id = rows[table.selectedRow].noteID,
                  parent.state.browseSelection != id else { return }
            parent.state.browseSelectionUsesKeyboard = true
            parent.state.browseSelection = id
        }
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            BrowserTableRow()
        }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let identifier = NSUserInterfaceItemIdentifier("browserCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? BrowserTableCell
                ?? BrowserTableCell(content: content(for: row))
            cell.identifier = identifier
            cell.content.rootView = content(for: row)
            return cell
        }

        private func content(for row: Int) -> BrowserCellContent {
            BrowserCellContent(item: rows[row], store: parent.store, state: parent.state,
                choose: parent.choose, requestPermanentDeletion: parent.requestPermanentDeletion)
        }
    }
}

private struct BrowserCellContent: View {
    let item: BrowserListItem
    @ObservedObject var store: NoteStore
    @ObservedObject var state: AppState
    let choose: (UUID) -> Void
    let requestPermanentDeletion: (UUID) -> Void

    var body: some View {
        Group {
            switch item {
            case .header(_, let title, let count):
                HStack {
                    Text(title).font(ModalTypography.section)
                    Spacer()
                    Text(countLabel(count)).font(ModalTypography.caption).monospacedDigit()
                }
                .foregroundStyle(JotTheme.mutedForeground)
                .padding(.horizontal, 12)
                .frame(height: ModalLayout.sectionHeaderHeight)
                .accessibilityAddTraits(.isHeader)
            case .note(let id):
                BrowserNoteRow(noteID: id, store: store, state: state, choose: choose,
                    requestPermanentDeletion: requestPermanentDeletion)
            }
        }
        .foregroundStyle(JotTheme.foreground)
        .tint(JotTheme.primary)
        .environment(\.colorScheme, .dark)
        .id(item.id)
    }

    private func countLabel(_ count: Int) -> String {
        let searching = !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let noun = searching ? (count == 1 ? "result" : "results") : (count == 1 ? "note" : "notes")
        return "\(count.formatted()) \(noun)"
    }
}

private final class BrowserTableCell: NSTableCellView {
    let content: NSHostingView<BrowserCellContent>
    init(content rootView: BrowserCellContent) {
        content = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        content.sizingOptions = []
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor), content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor), content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

private final class BrowserTableRow: NSTableRowView {
    override func drawBackground(in dirtyRect: NSRect) {}
    override func drawSelection(in dirtyRect: NSRect) {}
}

private final class NotesTableView: NSTableView {
    var command: ((UInt16) -> Bool)?
    var didLayout: (() -> Void)?
    override func layout() {
        super.layout()
        didLayout?()
    }
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           command?(event.keyCode) == true { return }
        super.keyDown(with: event)
    }
}
