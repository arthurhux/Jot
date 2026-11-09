import SwiftUI

// MOTION STORYBOARD
//   0ms  Keyboard commands and note switching respond immediately.
//   0ms  Keyboard selection moves the notes highlight immediately.
//   0ms  Pointer press scales a control 1 → 0.97.
//   0ms  Browse Notes and Settings open and dismiss immediately.
// 120ms  Pointer hover fades a control's or row's highlight in and out
//        (color and opacity only, CSS `ease`; kept under Reduce Motion).
//   …    Formatting strip morph: FormattingStrip.swift.
// Reduce Motion removes spatial movement. Values live in MotionTokens.
enum MotionTokens {
    static let controlResponse = 0.12
    static let disclosureResponse = 0.18
    static let pressedScale = 0.97
    static let disclosure = Animation.spring(response: disclosureResponse, dampingFraction: 1)
    /// Pointer hover: near-imperceptible fade, CSS `ease` (0.25, 0.1, 0.25, 1).
    static let hover = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: controlResponse)
    static let press = Animation.spring(response: controlResponse, dampingFraction: 1)
    /// Toolbar, window controls, and backdrop when Jot gains or loses focus or
    /// the pointer: frequent, so short and color/opacity only.
    static let chromeDuration = 0.18
    static let chrome = Animation.easeOut(duration: chromeDuration)
    /// Modals opened with the pointer: strong ease-out in, quicker out.
    /// Keyboard-opened modals appear instantly.
    static let modalIn = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
    static let modalOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.16)
}

/// Borderless icon or text control. Hover brightens the label and fills a
/// highlight; `isOn` keeps the fill for toggle buttons (HIG Toggles: a toggle
/// button shows its state with its background). At least 28×28 pt, the macOS
/// default control size. Highlights are capsules on glass, rounded elsewhere.
struct QuietButtonStyle: ButtonStyle {
    var isOn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.surfaceStyle) private var surface
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let hovered = isHovered && isEnabled
        let fill: Color = configuration.isPressed ? surface.pressedFill
            : isOn ? surface.selectedFill : hovered ? surface.hoverFill : .clear
        return configuration.label
            .foregroundStyle(isOn || hovered || configuration.isPressed ? JotTheme.foreground : JotTheme.mutedForeground)
            .padding(6)
            .frame(minWidth: GlassTokens.controlSize, minHeight: GlassTokens.controlSize)
            .background(fill, in: surface.highlightShape)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? MotionTokens.pressedScale : 1)
            .animation(MotionTokens.hover, value: hovered)
            .animation(MotionTokens.hover, value: isOn)
            .animation(reduceMotion ? nil : MotionTokens.press, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

/// A toolbar item inside the glass group: a fixed 32×28 pt slot with no gaps
/// between neighbours (HIG Pointing devices: contiguous hit regions, highlight
/// within a Liquid Glass group).
struct ToolbarItemStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.surfaceStyle) private var surface
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(ToolbarItemChrome(hovered: isHovered, pressed: configuration.isPressed))
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? MotionTokens.pressedScale : 1)
            .animation(reduceMotion ? nil : MotionTokens.press, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ToolbarItemChrome: ViewModifier {
    let hovered: Bool
    var pressed = false
    @Environment(\.surfaceStyle) private var surface

    func body(content: Content) -> some View {
        content
            .foregroundStyle(hovered || pressed ? JotTheme.foreground : JotTheme.mutedForeground)
            .frame(width: GlassTokens.toolbarItemWidth, height: GlassTokens.controlSize)
            .background(pressed ? surface.pressedFill : hovered ? surface.hoverFill : .clear, in: surface.highlightShape)
            .contentShape(Rectangle())
            .animation(MotionTokens.hover, value: hovered)
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
            .animation(reduceMotion ? nil : MotionTokens.press, value: configuration.isPressed)
            .animation(MotionTokens.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct WorkspaceView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var state: AppState
    @ObservedObject var editor: EditorController
    @FocusState private var findFocused: Bool
    @State private var pendingDeletion: UUID?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Liquid Glass on macOS 26+, the shipped look on 14–15, opaque surfaces
    /// with Reduce Transparency. The UI Lab can preview the others.
    private var surface: SurfaceStyle {
        .resolve(reduceTransparency: reduceTransparency, override: state.surfaceOverride)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    windowToolbar
                    noteDetail(width: geometry.size.width).frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let error = store.saveError {
                        HStack(spacing: 8) {
                            JotIcon("triangle-alert", color: .orange)
                            Text(error).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button("Retry save") { if store.flush() { store.clearError() } }.controlSize(.small)
                        }.padding(12).modifier(GlassBar(style: surface, tint: .orange.opacity(0.3)))
                    }
                    if let notice = state.notice {
                        HStack(spacing: 8) {
                            JotIcon("info", color: JotTheme.mutedForeground)
                            Text(notice).font(.system(size: 11))
                            Spacer()
                            Button { state.notice = nil } label: { JotIcon("x") }
                                .buttonStyle(QuietButtonStyle()).accessibilityLabel("Dismiss message")
                        }.padding(.horizontal, 12).padding(.vertical, 4).modifier(GlassBar(style: surface))
                    }
                }
                .allowsHitTesting(state.overlay == nil)
                .disabled(state.overlay != nil)
                .accessibilityHidden(state.overlay != nil)

                if let overlay = state.overlay {
                    Color.black.opacity(ModalStyle.scrimOpacity)
                        .contentShape(Rectangle()).ignoresSafeArea()
                        .onTapGesture { dismissOverlay(animated: true) }.accessibilityHidden(true)
                        .transition(.opacity)
                    Group {
                        switch overlay {
                        case .browse: browseNotes
                        case .settings: settings
                        case .actions: actionsPalette
                        }
                    }
                    .frame(width: min(430, max(280, geometry.size.width - 36)))
                    // Stay clear of the titlebar and the footer.
                    .frame(height: min(max(210, geometry.size.height - state.titlebarHeight - 64), modalHeight(overlay)))
                    .modifier(ModalCard(style: surface))
                    .padding(.top, 20)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(overlay == .browse ? "Browse Notes" : overlay == .settings ? "Settings" : "Actions")
                    .id(overlay)
                    .transition(modalTransition)
                }
            }
            .background { WindowBackdrop(style: surface, appearance: state.windowAppearance, active: state.windowIsKey || state.pointerInside) }
        }
        .environment(\.surfaceStyle, surface)
        .transformEnvironment(\.controlActiveState) { if state.forcesKeyAppearance { $0 = .key } }
        .foregroundStyle(JotTheme.foreground)
        // Switches, links, and the prominent action use the system accent.
        .tint(JotAccent.control)
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: state.findVisible) { _, visible in
            if visible { findFocused = true } else { state.findQuery = ""; editor.find("") }
        }
        .onChange(of: state.findQuery) { _, value in editor.find(value) }
        .onChange(of: store.selectedID) { _, _ in
            if state.findVisible { editor.find(state.findQuery) }
            editor.cancelLink()
        }
        .onChange(of: state.chromeVisible) { _, visible in state.setWindowControlsVisible?(visible) }
        .onChange(of: state.actionsQuery) { _, _ in state.actionSelection = 0 }
        .onChange(of: state.formattingVisible) { _, _ in syncFormatting() }
        .onChange(of: surface) { _, _ in syncFormatting() }
        .onChange(of: store.query) { _, _ in
            state.browseSelectionUsesKeyboard = true
            state.browseSelection = store.visibleNotes.first?.id
        }
        .onExitCommand {
            if editor.linkRequest != nil { editor.cancelLink() }
            else if state.overlay != nil { dismissOverlay() }
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
        HStack(spacing: 8) {
            Text(store.selectedNote?.displayTitle ?? "Jot")
                .font(state.usesReferenceTypography ? ModalTypography.referenceWindowTitle : ModalTypography.windowTitle).foregroundStyle(JotTheme.mutedForeground)
                .lineLimit(1).frame(maxWidth: .infinity)
                .help(store.selectedNote?.displayTitle ?? "Jot")
            HStack(spacing: 0) {
                Button { open(.actions) } label: { JotIcon("command") }
                    .buttonStyle(ToolbarItemStyle()).help("Actions · ⌘J").accessibilityLabel("Actions")
                Button { open(.browse) } label: { JotIcon("notebook-text") }
                    .buttonStyle(ToolbarItemStyle()).help("Browse Notes · ⌘P").accessibilityLabel("Browse Notes")
                Button { _ = store.createNote(); editor.focus() } label: { JotIcon("plus") }
                    .buttonStyle(ToolbarItemStyle()).help("New note · ⌘N").accessibilityLabel("New note")
            }
            .modifier(GlassGroup(style: surface))
            .modifier(ChromeFade(visible: state.chromeVisible))
        }
        // Sized to the window's titlebar so the group centers on the window controls.
        .padding(.leading, state.titlebarLeadingInset).padding(.trailing, 10).frame(height: state.titlebarHeight)
    }

    /// macOS 26+ glass: T opens native glass commands in the footer.
    /// Elsewhere it shows the editor's own formatting toolbar.
    private var usesGlassStrip: Bool { surface == .glass }

    private func syncFormatting() {
        editor.showFormatting(state.formattingVisible && !usesGlassStrip)
    }

    @ViewBuilder private func noteDetail(width: CGFloat) -> some View {
        if let note = store.selectedNote {
            VStack(spacing: 0) {
                TextField("Untitled", text: Binding(get: { store.selectedNote?.title ?? "" }, set: { if state.overlay == nil { store.updateTitle(id: note.id, title: $0) } }))
                    .textFieldStyle(.plain).font(ModalTypography.noteHeading).disabled(note.isDeleted)
                    .onSubmit { editor.focus() }.accessibilityLabel("Note title")
                    .help(note.usesAutomaticTitle ? "Named from the opening text. Edit to set your own title." : "Custom title. Choose Use Automatic Title from Actions to name it from the opening text.")
                    .accessibilityHint(note.usesAutomaticTitle ? "Updates from the opening text until you edit this title." : "Custom title. Your edits to the note body won’t change it.")
                    // Shares the editor's 30 pt inset; the body follows closely below.
                    .padding(.horizontal, NoteLayout.inset).padding(.top, NoteLayout.titleTop).padding(.bottom, NoteLayout.titleBottom)
                if note.isDeleted {
                    HStack {
                        Label("Recently deleted", jotIcon: "trash-2").font(.system(size: 11))
                        Spacer()
                        Button("Restore") { store.restore(note.id) }.controlSize(.small)
                    }.padding(.horizontal, surface == .glass ? 14 : 24).padding(.vertical, 8).modifier(GlassBar(style: surface))
                }
                if let request = editor.linkRequest {
                    LinkEditor(request: request, editor: editor, surface: surface)
                        .id(request.id)
                }
                if state.findVisible {
                    HStack(spacing: 8) {
                        JotIcon("search")
                        TextField("Find in this note", text: $state.findQuery).textFieldStyle(.plain).focused($findFocused).onSubmit { editor.nextMatch() }
                        if !state.findQuery.isEmpty { Text(editor.matchCount == 0 ? "No matches" : "\(editor.matchCount)").font(.system(size: 10)) }
                        Button { editor.nextMatch() } label: { JotIcon("chevron-down") }.buttonStyle(QuietButtonStyle()).accessibilityLabel("Next match")
                        Button { state.findVisible = false } label: { JotIcon("x") }.buttonStyle(QuietButtonStyle()).accessibilityLabel("Close find")
                    }.font(.system(size: 12)).foregroundStyle(JotTheme.mutedForeground)
                        .padding(.horizontal, surface == .glass ? 12 : 18).padding(.vertical, 4).modifier(GlassBar(style: surface))
                }
                ZStack {
                    // The page never paints its own paper; WindowBackdrop shows through.
                    NativeEditor(note: note, controller: editor, translucent: true)
                    if let error = editor.failure {
                        VStack(spacing: 12) {
                            JotIcon("triangle-alert", size: 24, color: .orange)
                            Text(error).font(.system(size: 12)).multilineTextAlignment(.center)
                            Button("Reload editor") { editor.retry() }
                        }.padding(24).frame(maxWidth: 320)
                            .modifier(GlassBar(style: surface, fallback: JotTheme.popover, cornerRadius: 12, fullWidthFallback: false))
                    } else if !editor.isReady { ProgressView().controlSize(.small) }
                }
                footer(note, width: width)
            }
        } else {
            VStack(spacing: 14) {
                JotIcon("square-pen", size: 28).foregroundStyle(JotTheme.mutedForeground)
                Text("Make space for a thought.").font(.system(size: 20, weight: .medium))
                Button("New note   ⌘N") { _ = store.createNote() }
                    .modifier(ProminentAction(style: surface))
                Button("Browse notes") { open(.browse) }.buttonStyle(.link)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func footer(_ note: Note, width: CGFloat) -> some View {
        let wordCount = note.plainText.split(whereSeparator: \.isWhitespace).count
        let saveStatus = store.saveError != nil ? "Couldn’t save" : store.isSaving ? "Saving…" : "Saved on this Mac"
        let stripOpen = usesGlassStrip && state.formattingVisible
        return HStack(spacing: 8) {
            Circle().fill(store.saveError == nil ? (store.isSaving ? JotTheme.mutedForeground : Color.green.opacity(0.6)) : .orange).frame(width: 4, height: 4)
                .help(saveStatus)
                .accessibilityElement().accessibilityLabel(saveStatus)
            Spacer(minLength: 8)
            if !stripOpen {
                // Gives way to the commands while the strip is open.
                Text("\(wordCount.formatted()) \(wordCount == 1 ? "word" : "words")").font(.system(size: 11)).monospacedDigit()
                    .transition(.opacity)
                Spacer(minLength: 8)
            }
            formattingControl(width: width)
                .modifier(ChromeFade(visible: state.chromeVisible || state.formattingVisible))
        }
        .animation(MotionTokens.glassFade, value: stripOpen)
        .foregroundStyle(JotTheme.mutedForeground).padding(.leading, 20).padding(.trailing, usesGlassStrip ? 7 : 12)
        .frame(height: usesGlassStrip ? 44 : 35)
        .overlay(alignment: .top) { Rectangle().fill(surface.hairline).frame(height: 1) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func formattingControl(width: CGFloat) -> some View {
        if #available(macOS 26, *), usesGlassStrip {
            GlassFormattingStrip(isExpanded: $state.formattingVisible, editor: editor, capacity: Self.commandCapacity(width: width))
        } else {
            Button { state.formattingVisible.toggle() } label: { JotIcon("type") }
                .buttonStyle(QuietButtonStyle(isOn: state.formattingVisible))
                .help("Formatting").accessibilityLabel("Formatting")
                .accessibilityValue(state.formattingVisible ? "Shown" : "Hidden")
        }
    }

    /// How many 30 pt glass command slots fit beside the save status and T.
    static func commandCapacity(width: CGFloat) -> Int {
        let slot = GlassTokens.glassIconSize + GlassTokens.commandSpacing
        let reserved = 20 + 4 + 16 + GlassTokens.glassIconSize + 7
        return max(1, Int((width - reserved) / slot))
    }

    private var browseNotes: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                JotIcon("search", size: 16).foregroundStyle(JotTheme.mutedForeground)
                NotesSearchField(text: $store.query, focusToken: state.focusSearchToken,
                    referenceTypography: state.usesReferenceTypography,
                    submit: { choose(state.browseSelection ?? store.visibleNotes.first?.id, animated: false) },
                    move: moveBrowseSelection, dismiss: { dismissOverlay() })
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("notesSearch")
                // Inside the glass card: a vibrant control, not more glass.
                Button { dismissOverlay(animated: true) } label: { JotIcon("x") }.buttonStyle(QuietButtonStyle())
                    .help("Close · Esc").accessibilityLabel("Close Browse Notes")
            }.padding(.horizontal, 17).padding(.vertical, 14)
            Rectangle().fill(surface.hairline).frame(height: 1)
            ZStack(alignment: .top) {
                NativeNotesBrowser(store: store, state: state, surface: surface, choose: { choose($0, animated: true) },
                    requestPermanentDeletion: { pendingDeletion = $0 }, move: moveBrowseSelection, dismiss: { dismissOverlay() })
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
            Rectangle().fill(surface.hairline).frame(height: 1)
            HStack {
                recentlyDeletedToggle
                Spacer()
                Text("↑↓ navigate  ↩ open").foregroundStyle(JotTheme.mutedForeground)
                    .accessibilityLabel("Up and Down Arrow move through notes. Return opens the selected note.")
            }.font(ModalTypography.caption).padding(.horizontal, 10).padding(.vertical, 6)
        }
        .onAppear {
            state.browseSelectionUsesKeyboard = true
            state.browseSelection = store.visibleNotes.contains(where: { $0.id == store.selectedID }) ? store.selectedID : store.visibleNotes.first?.id
        }
    }

    /// A toggle button (HIG Toggles): the background shows when Recently
    /// Deleted is the current view; pressing it again returns to all notes.
    /// The label stays a constant noun, and the count is announced as a value.
    private var recentlyDeletedToggle: some View {
        let deletedCount = store.notes.filter(\.isDeleted).count
        return Button {
            store.showingTrash.toggle(); store.query = ""
            state.browseSelectionUsesKeyboard = true
            state.browseSelection = store.visibleNotes.first?.id
        } label: {
            HStack(spacing: 6) {
                JotIcon("trash-2")
                Text("Recently Deleted")
                if deletedCount > 0 {
                    Text(deletedCount.formatted()).monospacedDigit().opacity(0.75)
                }
            }
            .padding(.horizontal, 2)
        }
        .buttonStyle(QuietButtonStyle(isOn: store.showingTrash))
        .help(store.showingTrash ? "Back to all notes" : "Notes deleted in the last 60 days")
        .accessibilityLabel("Recently Deleted")
        .accessibilityValue(store.showingTrash ? "Selected" : "\(deletedCount) \(deletedCount == 1 ? "note" : "notes")")
        .accessibilityHint(store.showingTrash ? "Returns to all notes." : "Shows notes deleted in the last 60 days, which you can restore.")
        .accessibilityAddTraits(store.showingTrash ? .isSelected : [])
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings").font(ModalTypography.title)
                Spacer()
                Button { dismissOverlay(animated: true) } label: { JotIcon("x") }.buttonStyle(QuietButtonStyle()).help("Close · Esc").accessibilityLabel("Close Settings")
            }.padding(.horizontal, ModalLayout.settingsInset).padding(.top, 17).padding(.bottom, 12)
            Rectangle().fill(surface.hairline).frame(height: 1)
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
                                    .background(surface == .glass ? surface.hoverFill : JotTheme.secondary, in: RoundedRectangle(cornerRadius: JotTheme.smallRadius))
                                    .overlay { RoundedRectangle(cornerRadius: JotTheme.smallRadius).stroke(surface == .glass ? surface.hairline : JotTheme.input, lineWidth: 1) }
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Keep Jot running to use the shortcut. Notes save automatically on this Mac, and Jot doesn’t collect any data.")
                            .font(ModalTypography.caption).lineSpacing(ModalTypography.descriptionLineSpacing)
                            .foregroundStyle(JotTheme.mutedForeground).fixedSize(horizontal: false, vertical: true)
                        // App Review 5.1.1(i): the privacy policy is reachable inside the app.
                        if let policy = AppInfo.privacyPolicyURL {
                            Link("Privacy Policy", destination: policy).font(ModalTypography.caption)
                                .help(policy.absoluteString)
                        }
                    }
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

    // MOTION STORYBOARD · modals
    //   pointer open   scrim fades in; card scales 0.96 → 1 and fades in, 220 ms
    //                  strong ease-out, centered (modals aren't anchored)
    //   pointer close  card scales to 0.98 and fades out, 160 ms; scrim fades
    //   keyboard       ⌘P, ⌘J, ⌘,, Esc, and Return open and close instantly
    //   Reduce Motion  fades only

    /// Opens a modal from a pointer action, with the entrance motion.
    private func open(_ overlay: WorkspaceOverlay) {
        if overlay == .browse { store.query = ""; store.showingTrash = false }
        if overlay == .actions { state.actionsQuery = ""; state.actionSelection = 0 }
        editor.cancelLink()
        withAnimation(MotionTokens.modalIn) { state.overlay = overlay }
    }
    private func dismissOverlay(animated: Bool = false) {
        if animated { withAnimation(MotionTokens.modalOut) { state.overlay = nil } } else { state.overlay = nil }
        editor.focus()
    }
    private func choose(_ id: UUID?, animated: Bool) {
        guard let id else { return }
        store.select(id)
        dismissOverlay(animated: animated)
    }

    private var modalTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity))
    }

    private func modalHeight(_ overlay: WorkspaceOverlay) -> CGFloat {
        switch overlay {
        case .browse: browserHeight
        case .settings: ModalLayout.settingsHeight
        case .actions: actionsHeight
        }
    }

    private var actionsPalette: some View {
        ActionsPalette(state: state, actions: actions, run: { action, animated in
            // Actions that open another modal replace this one; the rest close it first.
            if action.id == "browse" || action.id == "settings" { action.perform(); return }
            dismissOverlay(animated: animated)
            action.perform()
        }, dismiss: { dismissOverlay(animated: $0) })
    }

    private var actionsHeight: CGFloat { min(ModalLayout.maximumBrowserHeight + 20, ActionsPalette.height(for: actions)) }

    /// Mirrors the menu bar: Note, Window, and File commands.
    private var actions: [JotAction] {
        var list: [JotAction] = [
            JotAction(id: "new", section: "Note", title: "New Note", icon: "plus", shortcut: "⌘N") { _ = store.createNote(); editor.focus() },
            JotAction(id: "find", section: "Note", title: "Find in Note", icon: "search", shortcut: "⇧⌘F") { state.findVisible = true },
            JotAction(id: "formatting", section: "Note", title: state.formattingVisible ? "Hide Formatting" : "Show Formatting", icon: "type") { state.formattingVisible.toggle() },
        ]
        if let note = store.selectedNote, !note.isDeleted, !note.usesAutomaticTitle {
            list.append(JotAction(id: "autotitle", section: "Note", title: "Use Automatic Title", icon: "type") { store.useAutomaticTitle(note.id) })
        }
        if let note = store.selectedNote, !note.isDeleted {
            list.append(JotAction(id: "trash", section: "Note", title: "Move to Recently Deleted", icon: "trash-2", shortcut: "⌘⌫", destructive: true) { state.trashNote?(note.id) })
        }
        list += [
            JotAction(id: "browse", section: "Window", title: "Browse Notes", icon: "notebook-text", shortcut: "⌘P") {
                store.query = ""; store.showingTrash = false; state.focusSearchToken += 1
                state.overlay = .browse
            },
            JotAction(id: "float", section: "Window", title: state.alwaysOnTop ? "Stop Floating" : "Keep on Top", icon: "pin", shortcut: "⇧⌘P") { state.toggleFloating?() },
            JotAction(id: "compact", section: "Window", title: state.compact ? "Expand Window" : "Compact Window", icon: state.compact ? "maximize-2" : "minimize-2", shortcut: "⇧⌘M") { state.toggleCompact?() },
            JotAction(id: "settings", section: "Window", title: "Settings…", icon: "settings-2", shortcut: "⌘,") { state.overlay = .settings },
            JotAction(id: "import", section: "File", title: "Import Markdown…", icon: "download", shortcut: "⌘O") { state.importNote?() },
            JotAction(id: "export", section: "File", title: "Export Markdown…", icon: "upload", shortcut: "⇧⌘E") { state.exportNote?() },
        ]
        return list
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
