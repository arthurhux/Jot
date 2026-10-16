import SwiftUI

// MOTION STORYBOARD
//   0ms  Keyboard commands and note switching respond immediately.
//   0ms  Pointer press scales a control 1 → 0.97.
//   0ms  Browse Notes and Settings open and dismiss immediately.
//   0ms  Row hover and keyboard selection update the same highlight instantly.
// Reduce Motion removes spatial movement. Values live in MotionTokens.
enum MotionTokens {
    static let controlResponse = 0.12
    static let disclosureResponse = 0.18
    static let pressedScale = 0.97
    static let disclosure = Animation.spring(response: disclosureResponse, dampingFraction: 1)
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(JotTheme.mutedForeground)
            .padding(6)
            .background(configuration.isPressed ? JotTheme.accent : isHovered ? JotTheme.foreground.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: JotTheme.smallRadius))
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? MotionTokens.pressedScale : 1)
            .animation(reduceMotion ? nil : .spring(response: MotionTokens.controlResponse, dampingFraction: 1), value: configuration.isPressed)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

struct ShortcutButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: JotTheme.smallRadius)
                    .fill(JotTheme.foreground.opacity(isHovered || configuration.isPressed ? 0.08 : 0))
                    .allowsHitTesting(false)
            }
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? MotionTokens.pressedScale : 1)
            .animation(reduceMotion ? nil : .spring(response: MotionTokens.controlResponse, dampingFraction: 1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
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
                    .frame(height: min(max(210, geometry.size.height - 66), overlay == .browse ? browserHeight : ModalLayout.settingsHeight))
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
        .onChange(of: store.query) { _, _ in
            state.browseSelectionUsesKeyboard = true
            state.browseSelection = store.visibleNotes.first?.id
        }
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
        let wordCount = note.plainText.split(whereSeparator: \.isWhitespace).count
        return HStack(spacing: 8) {
            Circle().fill(store.saveError == nil ? (store.isSaving ? JotTheme.mutedForeground : Color.green.opacity(0.6)) : .orange).frame(width: 4, height: 4)
                .help(store.saveError != nil ? "Couldn’t save" : store.isSaving ? "Saving…" : "Saved on this Mac")
            Spacer()
            Text("\(wordCount.formatted()) \(wordCount == 1 ? "word" : "words")").font(.system(size: 11)).monospacedDigit()
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
            ZStack(alignment: .top) {
                NativeNotesBrowser(store: store, state: state, choose: { choose($0) },
                    requestPermanentDeletion: { pendingDeletion = $0 }, move: moveBrowseSelection, dismiss: dismissOverlay)
                if store.visibleNotes.isEmpty {
                    VStack(spacing: 9) {
                        JotIcon("file-text", size: 24)
                        Text(store.query.isEmpty ? "No notes here yet" : "No matching notes").font(ModalTypography.label)
                        if !store.query.isEmpty {
                            Button("Clear search") { store.query = ""; state.focusSearchToken += 1 }.buttonStyle(.link)
                        }
                    }.foregroundStyle(JotTheme.mutedForeground).frame(maxWidth: .infinity)
                        .padding(.vertical, 24).padding(.top, ModalLayout.sectionHeaderHeight + 4)
                }
            }
            Rectangle().fill(JotTheme.border).frame(height: 1)
            HStack {
                Button {
                    store.showingTrash.toggle(); store.query = ""
                    state.browseSelectionUsesKeyboard = true
                    state.browseSelection = store.visibleNotes.first?.id
                } label: { Label(store.showingTrash ? "All notes" : "Recently deleted", jotIcon: store.showingTrash ? "arrow-left" : "trash-2") }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
                Text("↑↓ navigate  ↩ open").foregroundStyle(JotTheme.mutedForeground)
            }.font(ModalTypography.caption).padding(.horizontal, 10).padding(.vertical, 6)
        }
        .onAppear {
            state.browseSelectionUsesKeyboard = true
            state.browseSelection = store.visibleNotes.contains(where: { $0.id == store.selectedID }) ? store.selectedID : store.visibleNotes.first?.id
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings").font(ModalTypography.title)
                Spacer()
                Button { dismissOverlay() } label: { JotIcon("x") }.buttonStyle(QuietButtonStyle()).accessibilityLabel("Close Settings")
            }.padding(.horizontal, ModalLayout.settingsInset).padding(.top, 17).padding(.bottom, 12)
            Rectangle().fill(JotTheme.border).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: ModalLayout.settingsSectionSpacing) {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsSectionTitle("Quick capture")
                        settingsRow("Global shortcut", detail: "Show or hide Jot from any app.") {
                            Button { state.configureShortcut?() } label: {
                                HStack(spacing: ModalLayout.shortcutSpacing) {
                                    ForEach(Array(ShortcutPresentation.keycaps(for: state.shortcutLabel).enumerated()), id: \.offset) { _, key in
                                        Text(key).frame(minWidth: 14)
                                    }
                                }
                                    .font(ModalTypography.shortcut)
                                    .padding(.horizontal, 11).padding(.vertical, 8)
                                    .background(JotTheme.secondary, in: RoundedRectangle(cornerRadius: JotTheme.smallRadius))
                                    .overlay { RoundedRectangle(cornerRadius: JotTheme.smallRadius).stroke(JotTheme.input, lineWidth: 1) }
                            }
                            .buttonStyle(ShortcutButtonStyle())
                            .help("Change keyboard shortcut")
                            .accessibilityLabel("Change global keyboard shortcut")
                            .accessibilityValue(state.shortcutLabel)
                        }
                        if let notice = state.notice {
                            Text(notice).font(ModalTypography.caption).lineSpacing(ModalTypography.descriptionLineSpacing).foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        settingsSectionTitle("Window")
                        settingsRow("Keep above other windows") {
                            Toggle("Keep above other windows", isOn: Binding(get: { state.alwaysOnTop }, set: { if $0 != state.alwaysOnTop { state.toggleFloating?() } }))
                                .labelsHidden().accessibilityLabel("Keep above other windows")
                        }
                        settingsRow("Automatically fit note height") {
                            Toggle("Automatically fit note height", isOn: Binding(get: { state.autoFit }, set: { value in state.autoFit = value; if value { state.fitWindow?() } }))
                                .labelsHidden().accessibilityLabel("Automatically fit note height")
                        }
                    }
                    .toggleStyle(.switch).controlSize(.small)
                    Text("Keep Jot running to use the shortcut. Notes save automatically on this Mac.")
                        .font(ModalTypography.caption).lineSpacing(ModalTypography.descriptionLineSpacing)
                        .foregroundStyle(JotTheme.mutedForeground).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ModalLayout.settingsInset)
            }
        }
    }

    private func settingsSectionTitle(_ title: String) -> some View {
        Text(title).font(ModalTypography.section).foregroundStyle(JotTheme.mutedForeground)
            .accessibilityAddTraits(.isHeader)
    }

    private func settingsRow<Control: View>(_ title: String, detail: String? = nil, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(ModalTypography.label)
                if let detail {
                    Text(detail).font(ModalTypography.caption).lineSpacing(ModalTypography.descriptionLineSpacing)
                        .foregroundStyle(JotTheme.mutedForeground)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            control().fixedSize()
        }.frame(minHeight: ModalLayout.settingsRowHeight)
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

    private var browserHeight: CGFloat {
        let rows = store.visibleNotes.isEmpty ? ModalLayout.emptyResultsHeight : Double(store.visibleNotes.count) * (ModalLayout.noteRowHeight + 3)
        let headers = Double(store.browserSections.count) * ModalLayout.sectionHeaderHeight
        return min(ModalLayout.maximumBrowserHeight, max(ModalLayout.minimumBrowserHeight, rows + headers + ModalLayout.browserChromeHeight))
    }

    private func moveBrowseSelection(_ direction: Int) {
        let notes = store.visibleNotes
        guard !notes.isEmpty else { return }
        state.browseSelectionUsesKeyboard = true
        let current = notes.firstIndex(where: { $0.id == state.browseSelection }) ?? 0
        state.browseSelection = notes[min(notes.count - 1, max(0, current + direction))].id
    }
}
