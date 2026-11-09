import SwiftUI

/// Native link field, shown below the title when the editor asks for a link
/// (⌘K, the Link command, or the formatting strip). Uses a standard rounded
/// macOS text field. Return or Apply sets the link, Remove clears an existing
/// one, and Esc or the close button cancels. Bare domains get https://, and an
/// email address gets mailto:.
struct LinkEditor: View {
    @Environment(\.secondaryText) private var secondaryText
    let request: EditorController.LinkRequest
    @ObservedObject var editor: EditorController
    let surface: SurfaceStyle
    @State private var address: String
    @State private var invalid = false
    @FocusState private var focused: Bool

    init(request: EditorController.LinkRequest, editor: EditorController, surface: SurfaceStyle) {
        self.request = request
        self.editor = editor
        self.surface = surface
        _address = State(initialValue: request.href)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                JotIcon("link", color: secondaryText)
                TextField("Link address", text: $address, prompt: Text("https://example.com"))
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(apply)
                    .onChange(of: address) { _, _ in invalid = false }
                    .accessibilityLabel("Link address")
                Button { editor.cancelLink() } label: { JotIcon("x") }
                    .buttonStyle(QuietButtonStyle())
                    .help("Close · Esc").accessibilityLabel("Close link editor")
            }
            HStack(spacing: 8) {
                Text(invalid ? "Use a web address, email, or phone link." : request.href.isEmpty ? (request.hasSelection ? "Links the selected text." : "Inserts the address as a link.") : "Edits the link at the cursor.")
                    .font(ModalTypography.caption)
                    .foregroundStyle(invalid ? Color.orange : secondaryText)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if !request.href.isEmpty {
                    Button("Remove", role: .destructive) { editor.removeLink() }
                        .help("Remove this link and keep its text")
                }
                Button("Apply", action: apply)
                    .modifier(ProminentAction(style: surface))
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .controlSize(.small)
            .padding(.leading, 24)
        }
        .padding(.horizontal, surface == .glass ? 12 : NoteLayout.inset).padding(.vertical, 10)
        .modifier(GlassBar(style: surface))
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onExitCommand { editor.cancelLink() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Link")
    }

    private func apply() {
        guard let href = Self.normalized(address) else { invalid = true; return }
        editor.applyLink(href)
    }

    /// Accepts web, email, and phone links, matching the editor's own rules.
    static func normalized(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        if !text.contains(":") {
            if text.contains("@") { text = "mailto:" + text }
            else if text.contains(".") { text = "https://" + text }
            else { return nil }
        }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased() else { return nil }
        switch scheme {
        case "http", "https": return url.host?.isEmpty == false ? text : nil
        case "mailto", "tel": return text.count > scheme.count + 1 ? text : nil
        default: return nil
        }
    }
}
