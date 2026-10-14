import SwiftUI

// MOTION STORYBOARD
//   0ms  Keyboard commands and note switching respond immediately.
//   0ms  Pointer press scales a control 1 → 0.97.
//   0ms  Browse Notes and Settings open and dismiss immediately.
// Reduce Motion removes spatial movement. Values live in MotionTokens.
enum MotionTokens {
    static let controlResponse = 0.12
    static let disclosureResponse = 0.18
    static let pressedScale = 0.97
    static let disclosure = Animation.spring(response: disclosureResponse, dampingFraction: 1)
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(JotTheme.mutedForeground)
            .padding(6)
            .background(configuration.isPressed ? JotTheme.accent : .clear, in: RoundedRectangle(cornerRadius: JotTheme.smallRadius))
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? MotionTokens.pressedScale : 1)
            .animation(reduceMotion ? nil : .spring(response: MotionTokens.controlResponse, dampingFraction: 1), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct WorkspaceView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var state: AppState
    @ObservedObject var editor: EditorController
    @FocusState private var findFocused: Bool
    @State private var pendingDeletion: UUID?
    @State private var formattingVisible = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    windowToolbar
                    noteDetail.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let error = store.saveError {
                        HStack(spacing: 8) {
                            JotIcon("triangle-alert", color: .orange)
                            Text(error).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button("Retry save") { if store.flush() { store.clearError() } }.controlSize(.small)
                        }.padding(12).background(JotTheme.card)
                    }
                    if let notice = state.notice {
                        HStack(spacing: 8) {
                            JotIcon("info")
                            Text(notice).font(.system(size: 11))
                            Spacer()
                            Button { state.notice = nil } label: { JotIcon("x") }
                                .buttonStyle(QuietButtonStyle()).accessibilityLabel("Dismiss message")
                        }.padding(.horizontal, 12).padding(.vertical, 4).background(JotTheme.card)
                    }
                }
                .allowsHitTesting(state.overlay == nil)
                .disabled(state.overlay != nil)
                .accessibilityHidden(state.overlay != nil)

                if let overlay = state.overlay {
                    Color.black.opacity(ModalStyle.scrimOpacity)
                        .contentShape(Rectangle()).ignoresSafeArea()
                        .onTapGesture { dismissOverlay() }.accessibilityHidden(true)
                    Group {
                        switch overlay {
                        case .browse: browseNotes
                        case .settings: settings
                        }
                    }
                    .frame(width: min(430, max(280, geometry.size.width - 36)))
                    .frame(height: min(max(210, geometry.size.height - 66), overlay == .browse ? min(500, max(230, CGFloat(store.showingTrash ? store.trashCount : store.activeCount) * 66 + 144)) : 410))
                    .background { ModalSurface() }
                    .clipShape(RoundedRectangle(cornerRadius: ModalStyle.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: ModalStyle.cornerRadius)
                            .stroke(LinearGradient(colors: [JotTheme.foreground.opacity(ModalStyle.rimTopOpacity), JotTheme.foreground.opacity(ModalStyle.rimBottomOpacity)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .shadow(color: .black.opacity(ModalStyle.shadowOpacity), radius: ModalStyle.shadowRadius, y: ModalStyle.shadowOffset)
                    .padding(.top, 20)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(overlay == .browse ? "Browse Notes" : "Settings")
                }
            }
            .background(JotTheme.background)
        }
        .foregroundStyle(JotTheme.foreground)
        .tint(JotTheme.primary)
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: state.findVisible) { _, visible in
            if visible { findFocused = true } else { state.findQuery = ""; editor.find("") }
        }
        .onChange(of: state.findQuery) { _, value in editor.find(value) }
        .onChange(of: store.selectedID) { _, _ in if state.findVisible { editor.find(state.findQuery) } }
        .onChange(of: formattingVisible) { _, visible in editor.showFormatting(visible) }
        .onChange(of: store.query) { _, _ in state.browseSelection = store.visibleNotes.first?.id }
        .onExitCommand {
            if state.overlay != nil { dismissOverlay() }
            else if state.findVisible { state.findVisible = false }
            else { state.hideWindow?() }
        }
        .alert("Delete this note permanently?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete Permanently", role: .destructive) {
                if let id = pendingDeletion { store.permanentlyDelete(id) }
                pendingDeletion = nil
            }
        } message: { Text("This note will be removed from Jot and can’t be restored.") }
    }

    private var windowToolbar: some View {
        HStack(spacing: 5) {
            Text(store.selectedNote?.displayTitle ?? "Jot")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(JotTheme.mutedForeground)
                .lineLimit(1).frame(maxWidth: .infinity)
            Menu {
                Button("Settings…", jotIcon: "settings-2") { open(.settings) }
                Button(state.alwaysOnTop ? "Stop Floating" : "Keep on Top", jotIcon: "pin") { state.toggleFloating?() }
                Button(state.compact ? "Expand Window" : "Compact Window", jotIcon: state.compact ? "maximize-2" : "minimize-2") { state.toggleCompact?() }
                Button(formattingVisible ? "Hide Formatting" : "Show Formatting", jotIcon: "type") { formattingVisible.toggle() }
                Button("Find in Note", jotIcon: "search") { state.findVisible = true }
                if let note = store.selectedNote, !note.isDeleted, !note.usesAutomaticTitle {
                    Button("Use Automatic Title", jotIcon: "type") { store.useAutomaticTitle(note.id) }
                }
                Divider()
                Button("Import Markdown…", jotIcon: "download") { state.importNote?() }
                Button("Export Markdown…", jotIcon: "upload") { state.exportNote?() }
                if let note = store.selectedNote, !note.isDeleted {
                    Button("Move to Recently Deleted", jotIcon: "trash-2", role: .destructive) { state.trashNote?(note.id) }
                }
            } label: { JotIcon("command", preservesColor: true).frame(width: 28, height: 28) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Actions and settings").accessibilityLabel("Actions and settings")
            Button { open(.browse) } label: { JotIcon("notebook-text", size: 16) }
                .buttonStyle(QuietButtonStyle()).help("Browse Notes · ⌘P").accessibilityLabel("Browse Notes")
            Button { _ = store.createNote(); editor.focus() } label: { JotIcon("plus") }
                .buttonStyle(QuietButtonStyle()).help("New note · ⌘N").accessibilityLabel("New note")
        }
        .padding(.leading, 78).padding(.trailing, 10).frame(height: 42)
    }

    @ViewBuilder private var noteDetail: some View {
        if let note = store.selectedNote {
            VStack(spacing: 0) {
                TextField("Untitled", text: Binding(get: { store.selectedNote?.title ?? "" }, set: { if state.overlay == nil { store.updateTitle(id: note.id, title: $0) } }))
                    .textFieldStyle(.plain).font(.system(size: 21, weight: .medium)).disabled(note.isDeleted)
                    .onSubmit { editor.focus() }.accessibilityLabel("Note title")
                    .help(note.usesAutomaticTitle ? "Named from the opening text. Edit to set your own title." : "Custom title. Choose Use Automatic Title from Actions to name it from the opening text.")
                    .accessibilityHint(note.usesAutomaticTitle ? "Updates from the opening text until you edit this title." : "Custom title. Your edits to the note body won’t change it.")
                    .padding(.horizontal, 24).padding(.top, 13).padding(.bottom, 16)
                if note.isDeleted {
                    HStack {
                        Label("Recently deleted", jotIcon: "trash-2").font(.system(size: 11))
                        Spacer()
                        Button("Restore") { store.restore(note.id) }.controlSize(.small)
                    }.padding(.horizontal, 24).padding(.vertical, 8).background(JotTheme.card)
                }
                if state.findVisible {
                    HStack(spacing: 8) {
                        JotIcon("search")
                        TextField("Find in this note", text: $state.findQuery).textFieldStyle(.plain).focused($findFocused).onSubmit { editor.nextMatch() }
                        if !state.findQuery.isEmpty { Text(editor.matchCount == 0 ? "No matches" : "\(editor.matchCount)").font(.system(size: 10)) }
                        Button { editor.nextMatch() } label: { JotIcon("chevron-down") }.buttonStyle(QuietButtonStyle()).accessibilityLabel("Next match")
                        Button { state.findVisible = false } label: { JotIcon("x") }.buttonStyle(QuietButtonStyle()).accessibilityLabel("Close find")
                    }.font(.system(size: 12)).foregroundStyle(JotTheme.mutedForeground)
                        .padding(.horizontal, 18).padding(.vertical, 4).background(JotTheme.card)
                }
                ZStack {
                    NativeEditor(note: note, controller: editor)
                    if let error = editor.failure {
                        VStack(spacing: 12) {
                            JotIcon("triangle-alert", size: 24, color: .orange)
                            Text(error).font(.system(size: 12)).multilineTextAlignment(.center)
                            Button("Reload editor") { editor.retry() }
                        }.padding(24).frame(maxWidth: 320).background(JotTheme.popover, in: RoundedRectangle(cornerRadius: 12))
                    } else if !editor.isReady { ProgressView().controlSize(.small) }
                }
                footer(note)
            }
        } else {
            VStack(spacing: 14) {
                JotIcon("square-pen", size: 28).foregroundStyle(JotTheme.mutedForeground)
                Text("Make space for a thought.").font(.system(size: 20, weight: .medium))
                Button("New note   ⌘N") { _ = store.createNote() }
                    .buttonStyle(.borderedProminent).foregroundStyle(JotTheme.primaryForeground)
                Button("Browse notes") { open(.browse) }.buttonStyle(.link)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func footer(_ note: Note) -> some View {
        HStack(spacing: 8) {
            Circle().fill(store.saveError == nil ? (store.isSaving ? JotTheme.mutedForeground : Color.green.opacity(0.6)) : .orange).frame(width: 4, height: 4)
                .help(store.saveError != nil ? "Couldn’t save" : store.isSaving ? "Saving…" : "Saved on this Mac")
            Spacer()
            Text("\(note.plainText.split(whereSeparator: \.isWhitespace).count) words").font(.system(size: 11)).monospacedDigit()
            Spacer()
            Button { formattingVisible.toggle() } label: { JotIcon("type") }
                .buttonStyle(QuietButtonStyle()).help("Formatting").accessibilityLabel("Toggle formatting toolbar")
                .background(formattingVisible ? JotTheme.accent : .clear, in: RoundedRectangle(cornerRadius: JotTheme.smallRadius))
                .accessibilityValue(formattingVisible ? "Shown" : "Hidden")
        }.foregroundStyle(JotTheme.mutedForeground).padding(.leading, 24).padding(.trailing, 12).frame(height: 35)
            .overlay(alignment: .top) { Rectangle().fill(JotTheme.border).frame(height: 1) }
            .accessibilityElement(children: .contain)
    }

    private var browseNotes: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                JotIcon("search", size: 16).foregroundStyle(JotTheme.mutedForeground)
                NotesSearchField(text: $store.query, focusToken: state.focusSearchToken,
                    submit: { choose(state.browseSelection ?? store.visibleNotes.first?.id) },
                    move: moveBrowseSelection, dismiss: dismissOverlay)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("notesSearch")
                Button { dismissOverlay() } label: { JotIcon("x") }.buttonStyle(QuietButtonStyle()).accessibilityLabel("Close Browse Notes")
            }.padding(.horizontal, 17).padding(.vertical, 14)
            Rectangle().fill(JotTheme.border).frame(height: 1)
            HStack {
                Text(store.showingTrash ? "Recently deleted" : "Notes").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(browseCountLabel).font(.system(size: 11)).monospacedDigit()
            }.foregroundStyle(JotTheme.mutedForeground).padding(.horizontal, 19).padding(.top, 14).padding(.bottom, 8)
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(store.visibleNotes) { note in
                            browserRow(note).id(note.id)
                        }
                        if store.visibleNotes.isEmpty {
                            VStack(spacing: 9) {
                                JotIcon("file-text", size: 24)
                                Text(store.query.isEmpty ? "No notes here yet" : "No matching notes").font(.system(size: 13))
                                if !store.query.isEmpty {
                                    Button("Clear search") { store.query = ""; state.focusSearchToken += 1 }.buttonStyle(.link)
                                }
                            }.foregroundStyle(JotTheme.mutedForeground).frame(maxWidth: .infinity).padding(.vertical, 35)
                        }
                    }.padding(.horizontal, 9).padding(.bottom, 10)
                }
                .onChange(of: state.browseSelection) { _, id in if let id { scroll.scrollTo(id, anchor: .center) } }
            }
            Rectangle().fill(JotTheme.border).frame(height: 1)
            HStack {
                Button {
                    store.showingTrash.toggle(); store.query = ""
                    state.browseSelection = store.visibleNotes.first?.id
                } label: { Label(store.showingTrash ? "All notes" : "Recently deleted", jotIcon: store.showingTrash ? "arrow-left" : "trash-2") }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
                Text("↑↓ navigate  ↩ open").foregroundStyle(JotTheme.mutedForeground)
            }.font(.system(size: 10)).padding(.horizontal, 10).padding(.vertical, 6)
        }
        .onAppear {
            state.browseSelection = store.visibleNotes.contains(where: { $0.id == store.selectedID }) ? store.selectedID : store.visibleNotes.first?.id
        }
    }

    private func browserRow(_ note: Note) -> some View {
        HStack(spacing: 8) {
            Button { choose(note.id) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(note.displayTitle).font(.system(size: 14, weight: .medium)).lineLimit(1)
                    HStack(spacing: 5) {
                        if store.selectedID == note.id { Circle().fill(JotTheme.sidebarPrimary).frame(width: 5, height: 5) }
                        Text("\(store.selectedID == note.id ? "Current" : "Edited " + note.modifiedAt.formatted(.dateTime.month(.abbreviated).day())) · \(note.plainText.count.formatted()) characters\(note.pinned ? " · Pinned" : "")")
                            .font(.system(size: 11)).foregroundStyle(state.browseSelection == note.id ? JotTheme.foreground : JotTheme.mutedForeground).lineLimit(1)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if note.isDeleted {
                Button { store.restore(note.id) } label: { JotIcon("undo-2") }.buttonStyle(QuietButtonStyle()).help("Restore note").accessibilityLabel("Restore note")
                Button { pendingDeletion = note.id } label: { JotIcon("trash-2") }.buttonStyle(QuietButtonStyle()).help("Delete permanently").accessibilityLabel("Delete permanently")
            } else {
                Button { store.togglePin(note.id) } label: { JotIcon("pin") }
                    .buttonStyle(QuietButtonStyle()).help(note.pinned ? "Unpin note" : "Pin note").accessibilityLabel(note.pinned ? "Unpin note" : "Pin note")
                    .background(note.pinned ? JotTheme.accent : .clear, in: RoundedRectangle(cornerRadius: JotTheme.smallRadius))
                Button { state.trashNote?(note.id) } label: { JotIcon("trash-2") }.buttonStyle(QuietButtonStyle()).help("Move to recently deleted").accessibilityLabel("Move to recently deleted")
            }
        }.padding(.horizontal, 12).padding(.vertical, 12)
            .background(state.browseSelection == note.id ? JotTheme.accent : .clear, in: RoundedRectangle(cornerRadius: JotTheme.radius))
            .contextMenu {
                if !note.isDeleted {
                    Button(note.pinned ? "Unpin" : "Pin", jotIcon: "pin") { store.togglePin(note.id) }
                    Button("Move to Recently Deleted", jotIcon: "trash-2", role: .destructive) { state.trashNote?(note.id) }
                }
            }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button { dismissOverlay() } label: { JotIcon("x") }.buttonStyle(QuietButtonStyle()).accessibilityLabel("Close Settings")
            }.padding(.horizontal, 21).padding(.top, 17).padding(.bottom, 12)
            Rectangle().fill(JotTheme.border).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("QUICK CAPTURE").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(JotTheme.mutedForeground)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Global shortcut").font(.system(size: 13, weight: .medium))
                                Text("Show or hide Jot from any app.").font(.system(size: 11)).foregroundStyle(JotTheme.mutedForeground)
                            }
                            Spacer(minLength: 10)
                            Button { state.configureShortcut?() } label: {
                                Text(state.shortcutLabel).font(.system(size: 13, weight: .medium)).monospaced()
                                    .padding(.horizontal, 11).padding(.vertical, 8)
                                    .background(JotTheme.secondary, in: RoundedRectangle(cornerRadius: JotTheme.smallRadius))
                                    .overlay { RoundedRectangle(cornerRadius: JotTheme.smallRadius).stroke(JotTheme.input, lineWidth: 1) }
                            }.buttonStyle(.plain).help("Change keyboard shortcut").accessibilityLabel("Change global keyboard shortcut")
                        }
                        if let notice = state.notice {
                            Text(notice).font(.system(size: 11)).foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WINDOW").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(JotTheme.mutedForeground)
                        Toggle("Keep above other windows", isOn: Binding(get: { state.alwaysOnTop }, set: { if $0 != state.alwaysOnTop { state.toggleFloating?() } }))
                        Toggle("Automatically fit note height", isOn: Binding(get: { state.autoFit }, set: { value in state.autoFit = value; if value { state.fitWindow?() } }))
                    }.font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("APPEARANCE").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(JotTheme.mutedForeground)
                        HStack { Text("Dark").font(.system(size: 13)); Spacer(); JotIcon("check") }
                    }
                    Text("Notes stay on this Mac and save automatically. Keep Jot running in the menu bar to use the global shortcut.")
                        .font(.system(size: 11)).foregroundStyle(JotTheme.mutedForeground).fixedSize(horizontal: false, vertical: true)
                }.padding(22)
            }
        }
    }

    private func open(_ overlay: WorkspaceOverlay) {
        if overlay == .browse { store.query = ""; store.showingTrash = false }
        state.overlay = overlay
    }
    private func dismissOverlay() {
        state.overlay = nil
        editor.focus()
    }
    private func choose(_ id: UUID?) {
        guard let id else { return }
        store.select(id); state.overlay = nil; editor.focus()
    }

    private var browseCountLabel: String {
        let count = store.visibleNotes.count
        return store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(count.formatted()) \(count == 1 ? "note" : "notes")"
            : "\(count.formatted()) \(count == 1 ? "result" : "results")"
    }

    private func moveBrowseSelection(_ direction: Int) {
        let notes = store.visibleNotes
        guard !notes.isEmpty else { return }
        let current = notes.firstIndex(where: { $0.id == state.browseSelection }) ?? 0
        state.browseSelection = notes[min(notes.count - 1, max(0, current + direction))].id
    }
}
