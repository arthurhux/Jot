import Foundation
import XCTest
@testable import Jot

@MainActor
final class NoteStoreTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func testBrowserGroupsPinnedNotesAfterFilteringAndKeepsNavigationOrder() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory)
        let pinned = store.createNote()
        store.updateTitle(id: pinned, title: "Launch PinOnlyFixtureZeta")
        store.togglePin(pinned)
        let regular = store.createNote()
        store.updateTitle(id: regular, title: "Launch RegularOnlyFixtureZeta")

        XCTAssertEqual(store.browserSections.map(\.kind), [.pinned, .notes])
        XCTAssertEqual(store.browserSections.first?.notes.map(\.id), [pinned])
        XCTAssertEqual(store.browserSections.flatMap(\.notes).map(\.id), store.visibleNotes.map(\.id))

        store.query = "Launch"
        XCTAssertEqual(store.browserSections.flatMap(\.notes).map(\.id), [pinned, regular])
        store.query = "PinOnlyFixtureZeta"
        XCTAssertEqual(store.browserSections.map(\.kind), [.pinned])
        store.query = "RegularOnlyFixtureZeta"
        XCTAssertEqual(store.browserSections.map(\.kind), [.notes])
        XCTAssertEqual(store.browserSections.first?.notes.map(\.id), [regular])
        store.query = "No matching note"
        XCTAssertEqual(store.browserSections.map(\.kind), [.notes])
        XCTAssertTrue(store.browserSections.first?.notes.isEmpty == true)

        store.query = ""
        store.togglePin(pinned)
        XCTAssertEqual(store.browserSections.map(\.kind), [.notes])
        store.togglePin(pinned)
        store.moveToTrash(pinned)
        XCTAssertEqual(store.browserSections.map(\.kind), [.notes])
        store.showingTrash = true
        XCTAssertEqual(store.browserSections.map(\.kind), [.trash])
        XCTAssertEqual(store.browserSections.first?.notes.map(\.id), [pinned])
    }

    func testLibraryKeepsOneHundredNotesAcrossSaveAndReload() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory)
        var created: [UUID] = []
        for number in 1...100 {
            let id = store.createNote()
            created.append(id)
            store.updateContent(id: id, document: "", plainText: "Thought \(number)", markdown: "Thought \(number)")
        }
        XCTAssertTrue(store.flush())
        let reloaded = NoteStore(directory: directory)
        XCTAssertEqual(reloaded.activeCount, 101) // Includes the first-launch welcome note.
        for (offset, id) in created.enumerated() {
            XCTAssertEqual(reloaded.notes.first(where: { $0.id == id })?.plainText, "Thought \(offset + 1)")
        }
        reloaded.select(try XCTUnwrap(created.first))
        XCTAssertEqual(reloaded.selectedNote?.title, "Thought 1")
        reloaded.select(try XCTUnwrap(created.last))
        XCTAssertEqual(reloaded.selectedNote?.title, "Thought 100")
    }

    func testAutomaticTitleFollowsOpeningTextAndManualRenameWins() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory)
        let id = store.createNote()
        // SwiftUI can echo a binding's unchanged value when it gains focus.
        store.updateTitle(id: id, title: "")
        XCTAssertTrue(store.selectedNote?.usesAutomaticTitle == true)
        store.updateContent(id: id, document: "", plainText: "Meeting with Ana\nDiscuss launch", markdown: "Meeting with Ana\nDiscuss launch")
        XCTAssertEqual(store.selectedNote?.title, "Meeting with Ana")
        XCTAssertTrue(store.selectedNote?.usesAutomaticTitle == true)
        store.updateTitle(id: id, title: "Meeting with Ana")
        XCTAssertTrue(store.selectedNote?.usesAutomaticTitle == true)
        store.updateContent(id: id, document: "", plainText: "Launch plan\nDiscuss launch", markdown: "Launch plan\nDiscuss launch")
        XCTAssertEqual(store.selectedNote?.title, "Launch plan")
        store.updateTitle(id: id, title: "Q4 planning")
        store.updateContent(id: id, document: "", plainText: "A different opening", markdown: "A different opening")
        XCTAssertEqual(store.selectedNote?.title, "Q4 planning")
        store.flush()
        let reloaded = NoteStore(directory: directory)
        reloaded.updateContent(id: id, document: "", plainText: "Changed after restart", markdown: "Changed after restart")
        XCTAssertEqual(reloaded.selectedNote?.title, "Q4 planning")
        reloaded.useAutomaticTitle(id)
        XCTAssertEqual(reloaded.selectedNote?.title, "Changed after restart")
        reloaded.flush()
        XCTAssertTrue(NoteStore(directory: directory).selectedNote?.usesAutomaticTitle == true)
    }

    func testAutomaticTitleUsesMeaningfulMarkdownTextAndUnicodeSafely() {
        XCTAssertEqual(NoteTitleRules.title(from: "\n  # Launch checklist\nMore content"), "Launch checklist")
        XCTAssertEqual(NoteTitleRules.title(from: "- [ ] Buy milk\n- [x] Bread"), "Buy milk")
        XCTAssertEqual(NoteTitleRules.title(from: "> 1. **Discuss** [release](https://example.com)"), "Discuss release")
        XCTAssertEqual(NoteTitleRules.title(from: "---\n```swift\nlet answer = 42"), "let answer = 42")
        XCTAssertEqual(NoteTitleRules.title(from: "  \n\t"), "")
        XCTAssertEqual(NoteTitleRules.title(from: "Reunião com João 👨‍👩‍👧‍👦"), "Reunião com João 👨‍👩‍👧‍👦")
        let long = NoteTitleRules.title(from: String(repeating: "👨‍👩‍👧‍👦", count: 80))
        XCTAssertEqual(long.count, NoteTitleRules.maximumLength)
        XCTAssertTrue(long.hasSuffix("…"))
        let words = NoteTitleRules.title(from: String(repeating: "A useful thought ", count: 12))
        XCTAssertLessThanOrEqual(words.count, NoteTitleRules.maximumLength)
        XCTAssertFalse(words.hasSuffix("thou…"))
    }

    func testAutomaticTitleClearsWithContentButManualTitleAndTrashStaySafe() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory)
        let id = store.createNote()
        store.updateContent(id: id, document: "", plainText: "An idea", markdown: "An idea")
        store.updateContent(id: id, document: "", plainText: "", markdown: "")
        XCTAssertEqual(store.selectedNote?.displayTitle, "Untitled")
        store.updateTitle(id: id, title: "Keep this name")
        store.moveToTrash(id)
        store.useAutomaticTitle(id)
        store.updateContent(id: id, document: "", plainText: "Blocked change", markdown: "Blocked change")
        XCTAssertEqual(store.notes.first(where: { $0.id == id })?.title, "Keep this name")
    }

    func testLegacyTitlesMigrateWithoutOverwritingExistingNames() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory, now: { self.fixedDate })
        let named = store.createNote()
        store.updateTitle(id: named, title: "My chosen name")
        store.updateContent(id: named, document: "", plainText: "Different text", markdown: "Different text")
        let unnamed = store.createNote()
        store.updateContent(id: unnamed, document: "", plainText: "A useful old note", markdown: "A useful old note")
        store.flush()
        let file = directory.appendingPathComponent("notes.json")
        var snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var notes = try XCTUnwrap(snapshot["notes"] as? [[String: Any]])
        for index in notes.indices {
            notes[index].removeValue(forKey: "titleIsAutomatic")
            if notes[index]["id"] as? String == unnamed.uuidString { notes[index]["title"] = "" }
        }
        snapshot["notes"] = notes
        try JSONSerialization.data(withJSONObject: snapshot).write(to: file, options: .atomic)
        let reloaded = NoteStore(directory: directory)
        XCTAssertEqual(reloaded.notes.first(where: { $0.id == named })?.title, "My chosen name")
        XCTAssertFalse(reloaded.notes.first(where: { $0.id == named })?.usesAutomaticTitle ?? true)
        XCTAssertEqual(reloaded.selectedNote?.title, "A useful old note")
        XCTAssertEqual(reloaded.selectedNote?.modifiedAt, fixedDate)
        XCTAssertNil(reloaded.saveError)
    }

    func testRoundTripPreservesContentAndEditorPosition() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory, now: { self.fixedDate })
        let id = store.createNote()
        store.updateTitle(id: id, title: "A useful idea")
        store.updateContent(
            id: id,
            document: #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Keep this"}]}]}"#,
            plainText: "Keep this",
            markdown: "**Keep this**"
        )
        store.togglePin(id)
        store.updatePosition(id: id, from: 3, to: 8)
        store.updateScroll(id: id, top: 124.5)
        store.flush()

        let reloaded = NoteStore(directory: directory, now: { self.fixedDate })
        XCTAssertEqual(reloaded.notes, store.notes)
        XCTAssertEqual(reloaded.selectedID, id)
        XCTAssertEqual(reloaded.selectedNote?.caretFrom, 3)
        XCTAssertEqual(reloaded.selectedNote?.caretTo, 8)
        XCTAssertEqual(reloaded.selectedNote?.scrollTop, 124.5)
        XCTAssertEqual(reloaded.selectedNote?.displayTitle, "A useful idea")
        XCTAssertNil(reloaded.saveError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("notes.backup.json").path))
    }

    func testTrashRestoreAndPermanentDeletion() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory, now: { self.fixedDate })
        let initialCount = store.activeCount
        let id = store.createNote()
        store.updateTitle(id: id, title: "Recover me")
        store.togglePin(id)
        store.moveToTrash(id)

        XCTAssertEqual(store.activeCount, initialCount)
        XCTAssertEqual(store.trashCount, 1)
        XCTAssertNotEqual(store.selectedID, id)
        XCTAssertFalse(store.visibleNotes.contains { $0.id == id })
        store.showingTrash = true
        XCTAssertEqual(store.visibleNotes.map(\.id), [id])
        store.select(id)
        store.restore(id)
        XCTAssertEqual(store.trashCount, 0)
        XCTAssertNil(store.selectedID)
        store.showingTrash = false
        XCTAssertEqual(store.visibleNotes.first?.id, id)
        XCTAssertTrue(store.notes.first(where: { $0.id == id })?.pinned == true)

        store.permanentlyDelete(id)
        XCTAssertTrue(store.notes.contains { $0.id == id }, "Permanent deletion is restricted to Trash.")
        store.moveToTrash(id)
        store.permanentlyDelete(id)
        store.flush()
        let reloaded = NoteStore(directory: directory, now: { self.fixedDate })
        XCTAssertFalse(reloaded.notes.contains { $0.id == id })
    }

    func testSearchAndPinnedThenModifiedSorting() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var timestamp = fixedDate
        let store = NoteStore(directory: directory, now: { timestamp })
        let first = store.createNote()
        store.updateTitle(id: first, title: "Shared old note")
        store.updateContent(id: first, document: "", plainText: "A café idea", markdown: "Hidden **needle**")
        timestamp = timestamp.addingTimeInterval(10)
        let second = store.createNote()
        store.updateTitle(id: second, title: "Shared newest note")
        store.query = "shared"
        XCTAssertEqual(store.visibleNotes.map(\.id), [second, first])
        store.togglePin(first)
        XCTAssertEqual(store.visibleNotes.map(\.id), [first, second])
        store.query = "CAFE"
        XCTAssertEqual(store.visibleNotes.map(\.id), [first])
        store.query = "needle"
        XCTAssertEqual(store.visibleNotes.map(\.id), [first])
        store.moveToTrash(first)
        XCTAssertTrue(store.visibleNotes.isEmpty)
        store.showingTrash = true
        XCTAssertEqual(store.visibleNotes.map(\.id), [first])
    }

    func testCorruptPrimaryRecoversBackupAndPreservesOriginalBytes() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory, now: { self.fixedDate })
        let id = store.createNote()
        store.updateTitle(id: id, title: "Saved safely")
        store.flush()
        store.flush() // The previous valid snapshot is now also the latest snapshot.
        let corrupt = Data("{broken original data".utf8)
        try corrupt.write(to: directory.appendingPathComponent("notes.json"), options: .atomic)

        let reloaded = NoteStore(directory: directory, now: { self.fixedDate })
        XCTAssertEqual(reloaded.selectedNote?.id, id)
        XCTAssertEqual(reloaded.selectedNote?.title, "Saved safely")
        XCTAssertTrue(reloaded.saveError?.contains("recovered from the backup") == true)
        let preserved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("notes.corrupt-") }
        XCTAssertEqual(preserved.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(preserved.first)), corrupt)
        reloaded.flush()
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(preserved.first)), corrupt)
        XCTAssertNil(NoteStore(directory: directory, now: { self.fixedDate }).saveError)
    }

    func testCorruptStoreWithoutBackupDoesNotSeedOrDiscardOriginal() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let corrupt = Data("unreadable notes".utf8)
        try corrupt.write(to: directory.appendingPathComponent("notes.json"))
        let store = NoteStore(directory: directory, now: { self.fixedDate })
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertNotNil(store.saveError)
        let id = store.createNote()
        store.updateTitle(id: id, title: "Start again")
        store.flush()
        let preserved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("notes.corrupt-") }
        XCTAssertEqual(preserved.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(preserved.first)), corrupt)
        XCTAssertEqual(NoteStore(directory: directory, now: { self.fixedDate }).activeCount, 1)
    }

    func testMissingSelectionFallsBackToFirstActiveNoteAndTrashSelectionRestores() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory, now: { self.fixedDate })
        let id = store.createNote()
        store.togglePin(id)
        store.flush()
        let fileURL = directory.appendingPathComponent("notes.json")
        var snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        snapshot["selectedID"] = UUID().uuidString
        try JSONSerialization.data(withJSONObject: snapshot).write(to: fileURL, options: .atomic)
        let reloaded = NoteStore(directory: directory, now: { self.fixedDate })
        XCTAssertEqual(reloaded.selectedID, id)

        reloaded.moveToTrash(id)
        reloaded.showingTrash = true
        reloaded.select(id)
        reloaded.flush()
        let trashReloaded = NoteStore(directory: directory, now: { self.fixedDate })
        XCTAssertEqual(trashReloaded.selectedID, id)
        XCTAssertTrue(trashReloaded.showingTrash)
        XCTAssertEqual(trashReloaded.selectedNote?.isDeleted, true)
    }

    func testOldTrashExpiresAndWelcomeAppearsOnlyOnFirstLaunch() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var timestamp = fixedDate
        let store = NoteStore(directory: directory, now: { timestamp })
        XCTAssertEqual(store.notes.count, 1)
        let welcome = try XCTUnwrap(store.notes.first)
        store.moveToTrash(welcome.id)
        store.flush()
        timestamp = timestamp.addingTimeInterval(61 * 24 * 60 * 60)
        let reloaded = NoteStore(directory: directory, now: { timestamp })
        XCTAssertTrue(reloaded.notes.isEmpty)
        reloaded.flush()
        XCTAssertTrue(NoteStore(directory: directory, now: { timestamp }).notes.isEmpty)
    }

    func testFailedSaveKeepsMemoryAndSucceedsAfterStoragePathIsFixed() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let blockedDirectory = directory.appendingPathComponent("blocked", isDirectory: true)
        try Data("This file blocks directory creation.".utf8).write(to: blockedDirectory)
        let store = NoteStore(directory: blockedDirectory, now: { self.fixedDate })
        let id = store.createNote()
        store.updateTitle(id: id, title: "Keep my unsaved changes")
        store.updateContent(id: id, document: "", plainText: "Still here", markdown: "**Still here**")
        XCTAssertFalse(store.flush())
        XCTAssertNotNil(store.saveError)
        XCTAssertEqual(store.selectedNote?.title, "Keep my unsaved changes")
        XCTAssertEqual(store.selectedNote?.markdown, "**Still here**")

        try FileManager.default.removeItem(at: blockedDirectory)
        XCTAssertTrue(store.flush())
        XCTAssertNil(store.saveError)
        let reloaded = NoteStore(directory: blockedDirectory, now: { self.fixedDate })
        XCTAssertEqual(reloaded.selectedNote?.title, "Keep my unsaved changes")
        XCTAssertEqual(reloaded.selectedNote?.markdown, "**Still here**")
    }

    func testCorruptFileIsNotOverwrittenWhenPreservationFails() throws {
        let directory = try temporaryDirectory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = NoteStore(directory: directory, now: { self.fixedDate })
        store.flush()
        let primary = directory.appendingPathComponent("notes.json")
        let corrupt = Data("unpreserved original".utf8)
        try corrupt.write(to: primary, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)

        let reloaded = NoteStore(directory: directory, now: { self.fixedDate })
        XCTAssertFalse(reloaded.flush())
        XCTAssertNotNil(reloaded.saveError)
        XCTAssertEqual(try Data(contentsOf: primary), corrupt)

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        XCTAssertTrue(reloaded.flush(), "A recovery notice must not make a successful write report failure.")
        let preserved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("notes.corrupt-") }
        XCTAssertEqual(preserved.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(preserved.first)), corrupt)
    }
}
