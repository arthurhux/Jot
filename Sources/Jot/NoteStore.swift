import Combine
import Foundation

struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    // Optional for snapshots written before automatic titles existed.
    var titleIsAutomatic: Bool?
    var document: String
    var plainText: String
    var markdown: String
    var createdAt: Date
    var modifiedAt: Date
    var pinned: Bool
    var caretFrom: Int
    var caretTo: Int
    var scrollTop: Double
    var deletedAt: Date?

    var isDeleted: Bool { deletedAt != nil }
    var usesAutomaticTitle: Bool { titleIsAutomatic ?? title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        titleIsAutomatic: Bool? = nil,
        document: String = "",
        plainText: String = "",
        markdown: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        pinned: Bool = false,
        caretFrom: Int = 1,
        caretTo: Int = 1,
        scrollTop: Double = 0,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.titleIsAutomatic = titleIsAutomatic ?? title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.document = document
        self.plainText = plainText
        self.markdown = markdown
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.pinned = pinned
        self.caretFrom = caretFrom
        self.caretTo = caretTo
        self.scrollTop = scrollTop
        self.deletedAt = deletedAt
    }
}

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedID: UUID? {
        didSet {
            if !isLoading, selectedID != oldValue { scheduleSave() }
        }
    }
    @Published var query = ""
    @Published var showingTrash = false
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving = false

    private struct Snapshot: Codable {
        var version: Int
        var notes: [Note]
        var selectedID: UUID?
    }

    private enum StorageError: LocalizedError {
        case unsupportedVersion(Int)
        case duplicateIdentifiers

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "This notes file uses an unsupported format (version \(version))."
            case .duplicateIdentifiers:
                return "This notes file contains duplicate note identifiers."
            }
        }
    }

    private let directory: URL
    private let now: () -> Date
    private let debounceInterval: TimeInterval
    private let trashRetentionInterval: TimeInterval?
    private var pendingSave: Task<Void, Never>?
    private var isLoading = true
    private var hasRecoveryNotice = false

    private var fileURL: URL { directory.appendingPathComponent("notes.json") }
    private var backupURL: URL { directory.appendingPathComponent("notes.backup.json") }

    var selectedNote: Note? {
        notes.first { $0.id == selectedID }
    }

    var visibleNotes: [Note] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            guard note.isDeleted == showingTrash else { return false }
            return search.isEmpty || note.title.localizedStandardContains(search)
                || note.plainText.localizedStandardContains(search)
                || note.markdown.localizedStandardContains(search)
        }.sorted(by: Self.sortNotes)
    }

    var activeCount: Int { notes.filter { !$0.isDeleted }.count }
    var trashCount: Int { notes.filter(\.isDeleted).count }

    init(
        directory: URL? = nil,
        now: @escaping () -> Date = Date.init,
        debounceInterval: TimeInterval = 0.35,
        trashRetentionInterval: TimeInterval? = 60 * 24 * 60 * 60
    ) {
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Jot", isDirectory: true)
        self.now = now
        self.debounceInterval = debounceInterval
        self.trashRetentionInterval = trashRetentionInterval
        loadFromDisk()
        isLoading = false
    }

    @discardableResult
    func createNote() -> UUID {
        let timestamp = now()
        let note = Note(createdAt: timestamp, modifiedAt: timestamp)
        notes.append(note)
        showingTrash = false
        query = ""
        selectedID = note.id
        scheduleSave()
        return note.id
    }

    func select(_ id: UUID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    func updateContent(id: UUID, document: String, plainText: String, markdown: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isDeleted else { return }
        guard notes[index].document != document || notes[index].plainText != plainText
                || notes[index].markdown != markdown else { return }
        notes[index].document = document
        notes[index].plainText = plainText
        notes[index].markdown = markdown
        if notes[index].usesAutomaticTitle {
            notes[index].title = NoteTitleRules.title(from: plainText)
            notes[index].titleIsAutomatic = true
        }
        notes[index].modifiedAt = now()
        scheduleSave()
    }

    func updateTitle(id: UUID, title: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isDeleted,
              notes[index].title != title else { return }
        notes[index].title = title
        notes[index].titleIsAutomatic = false
        notes[index].modifiedAt = now()
        scheduleSave()
    }

    func useAutomaticTitle(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isDeleted else { return }
        notes[index].titleIsAutomatic = true
        notes[index].title = NoteTitleRules.title(from: notes[index].plainText)
        notes[index].modifiedAt = now()
        scheduleSave()
    }

    func updatePosition(id: UUID, from: Int, to: Int) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let from = max(0, from)
        let to = max(from, to)
        guard notes[index].caretFrom != from || notes[index].caretTo != to else { return }
        notes[index].caretFrom = from
        notes[index].caretTo = to
        scheduleSave()
    }

    func updateScroll(id: UUID, top: Double) {
        guard top.isFinite, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let top = max(0, top)
        guard notes[index].scrollTop != top else { return }
        notes[index].scrollTop = top
        scheduleSave()
    }

    func togglePin(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isDeleted else { return }
        notes[index].pinned.toggle()
        scheduleSave()
    }

    func moveToTrash(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isDeleted else { return }
        notes[index].deletedAt = now()
        chooseFallbackSelection(ifRemoving: id)
        scheduleSave()
    }

    func restore(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].isDeleted else { return }
        notes[index].deletedAt = nil
        chooseFallbackSelection(ifRemoving: id)
        scheduleSave()
    }

    func permanentlyDelete(_ id: UUID) {
        guard notes.contains(where: { $0.id == id && $0.isDeleted }) else { return }
        notes.removeAll { $0.id == id }
        chooseFallbackSelection(ifRemoving: id)
        scheduleSave()
    }

    /// Commits the latest in-memory state immediately; call when the app terminates.
    /// The result reports this write independently of any recovery notice.
    @discardableResult
    func flush() -> Bool {
        pendingSave?.cancel()
        pendingSave = nil
        return persist()
    }

    func clearError() {
        saveError = nil
        hasRecoveryNotice = false
    }

    private static func sortNotes(_ lhs: Note, _ rhs: Note) -> Bool {
        if lhs.pinned != rhs.pinned { return lhs.pinned }
        if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func chooseFallbackSelection(ifRemoving id: UUID) {
        guard selectedID == id else { return }
        selectedID = visibleNotes.first?.id
    }

    private func scheduleSave() {
        guard !isLoading else { return }
        pendingSave?.cancel()
        isSaving = true
        let delay = UInt64(max(0, debounceInterval) * 1_000_000_000)
        pendingSave = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.pendingSave = nil
            self?.persist()
        }
    }

    private func decode(_ data: Data) throws -> Snapshot {
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        guard snapshot.version == 1 else { throw StorageError.unsupportedVersion(snapshot.version) }
        guard Set(snapshot.notes.map(\.id)).count == snapshot.notes.count else {
            throw StorageError.duplicateIdentifiers
        }
        return snapshot
    }

    private func loadFromDisk() {
        let manager = FileManager.default
        let primaryExists = manager.fileExists(atPath: fileURL.path)
        let backupExists = manager.fileExists(atPath: backupURL.path)

        if !primaryExists && !backupExists {
            let timestamp = now()
            let welcome = Note(
                title: "Welcome to Jot",
                plainText: "Capture the idea before it disappears. A little space for your thoughts, lists, and things worth keeping.",
                markdown: Self.welcomeMarkdown,
                createdAt: timestamp,
                modifiedAt: timestamp
            )
            notes = [welcome]
            selectedID = welcome.id
            // Write the first-launch note now so a second window or a quick exit
            // cannot create another welcome note.
            persist()
            return
        }

        var snapshot: Snapshot?
        var recoveryMessages: [String] = []
        if primaryExists {
            do {
                snapshot = try decode(Data(contentsOf: fileURL))
            } catch {
                do {
                    let preserved = try preserveUnreadableFile(at: fileURL)
                    recoveryMessages.append("The unreadable notes file was preserved as \(preserved.lastPathComponent).")
                } catch {
                    recoveryMessages.append("The notes file could not be read or preserved: \(error.localizedDescription)")
                }
            }
        }

        if snapshot == nil, backupExists {
            do {
                snapshot = try decode(Data(contentsOf: backupURL))
                recoveryMessages.insert("Your notes were recovered from the backup.", at: 0)
            } catch {
                do {
                    let preserved = try preserveUnreadableFile(at: backupURL)
                    recoveryMessages.append("The unreadable backup was preserved as \(preserved.lastPathComponent).")
                } catch {
                    recoveryMessages.append("The backup could not be read or preserved: \(error.localizedDescription)")
                }
            }
        }

        if let snapshot {
            notes = snapshot.notes
            for index in notes.indices where notes[index].titleIsAutomatic == nil {
                let automatic = notes[index].usesAutomaticTitle
                notes[index].titleIsAutomatic = automatic
                if automatic && !notes[index].isDeleted {
                    notes[index].title = NoteTitleRules.title(from: notes[index].plainText)
                }
            }
            if let retention = trashRetentionInterval {
                let cutoff = now().addingTimeInterval(-max(0, retention))
                notes.removeAll { note in
                    if let deletedAt = note.deletedAt { return deletedAt < cutoff }
                    return false
                }
            }
            if let savedID = snapshot.selectedID, let selected = notes.first(where: { $0.id == savedID }) {
                selectedID = savedID
                showingTrash = selected.isDeleted
            } else {
                selectedID = notes.filter { !$0.isDeleted }.sorted(by: Self.sortNotes).first?.id
            }
            if notes != snapshot.notes || !primaryExists || !recoveryMessages.isEmpty {
                persist()
            }
        } else {
            notes = []
            selectedID = nil
            recoveryMessages.insert("Jot could not load your saved notes. You can create a new note; the original files have been kept for recovery.", at: 0)
        }

        if !recoveryMessages.isEmpty {
            hasRecoveryNotice = true
            saveError = recoveryMessages.joined(separator: " ")
        }
    }

    /// Moves bytes intact to a unique recovery file before a path can be reused.
    @discardableResult
    private func preserveUnreadableFile(at url: URL) throws -> URL {
        let stem = url.deletingPathExtension().lastPathComponent
        let preserved = directory.appendingPathComponent("\(stem).corrupt-\(UUID().uuidString).json")
        try FileManager.default.moveItem(at: url, to: preserved)
        return preserved
    }

    @discardableResult
    private func persist() -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let manager = FileManager.default
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Snapshot(version: 1, notes: notes, selectedID: selectedID))

            var previousData: Data?
            if manager.fileExists(atPath: fileURL.path) {
                let existing = try Data(contentsOf: fileURL)
                do {
                    _ = try decode(existing)
                    previousData = existing
                } catch {
                    let preserved = try preserveUnreadableFile(at: fileURL)
                    hasRecoveryNotice = true
                    saveError = "An unreadable notes file was preserved as \(preserved.lastPathComponent). Your current notes are safe."
                }
            }
            if manager.fileExists(atPath: backupURL.path) {
                let existing = try Data(contentsOf: backupURL)
                do {
                    _ = try decode(existing)
                } catch {
                    let preserved = try preserveUnreadableFile(at: backupURL)
                    hasRecoveryNotice = true
                    saveError = "An unreadable backup was preserved as \(preserved.lastPathComponent). Your current notes are safe."
                }
            }

            if let previousData { try previousData.write(to: backupURL, options: .atomic) }
            try data.write(to: fileURL, options: .atomic)
            if previousData == nil, !manager.fileExists(atPath: backupURL.path) {
                try data.write(to: backupURL, options: .atomic)
            }
            if !hasRecoveryNotice { saveError = nil }
            return true
        } catch {
            saveError = "Jot couldn't save your notes: \(error.localizedDescription) Your edits are still available in this window."
            return false
        }
    }

    private static let welcomeMarkdown = """
    # A little space for your thoughts

    Welcome to **Jot**. Capture the idea before it disappears.

    ## Make yourself at home

    - Create a note with **⌘N**.
    - Give it a title, or leave it untitled.
    - Search across all your notes with **⌘F**.
    - Pin the notes you want to keep close.

    ## Write the way you think

    Use the formatting toolbar, or type Markdown shortcuts: `# ` for a heading, `- ` for a list, and `> ` for a quote. Add links, code blocks, and checklists as you go.

    - [x] Find a quiet place to write
    - [ ] Capture your first idea
    - [ ] Make something worth keeping

    > Good ideas often start with one unfinished sentence.

    Your notes save automatically on this Mac. Deleted notes stay in Trash for 60 days, where you can restore them.
    """
}
