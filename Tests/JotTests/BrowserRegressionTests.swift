import Foundation
import Testing
@testable import Jot

@Suite("Notes browser regressions")
@MainActor
struct BrowserRegressionTests {
    @Test("Displayed fallback titles are searchable in active notes and trash")
    func fallbackTitleSearch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("JotBrowserTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // An existing empty library avoids the welcome note, whose instructions
        // themselves mention “Untitled” and legitimately match the search.
        try Data(#"{"version":1,"notes":[]}"#.utf8).write(to: directory.appendingPathComponent("notes.json"))
        let store = NoteStore(directory: directory, trashRetentionInterval: nil)
        let blank = store.createNote()
        let whitespace = store.createNote()
        store.updateTitle(id: whitespace, title: " \t ")
        store.query = "  UNTITLED  "
        #expect(Set(store.visibleNotes.map(\.id)) == [blank, whitespace])
        store.moveToTrash(blank)
        #expect(store.visibleNotes.map(\.id) == [whitespace])
        store.showingTrash = true
        #expect(store.visibleNotes.map(\.id) == [blank])
        #expect(store.flush())
        let reloaded = NoteStore(directory: directory, trashRetentionInterval: nil)
        reloaded.query = "Untitled"
        #expect(reloaded.visibleNotes.map(\.id) == [whitespace])
    }

    @Test("Flat table identities survive pinning, filtering, and empty sections")
    func tableIdentities() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("JotBrowserTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory)
        let first = store.createNote()
        store.updateTitle(id: first, title: "Common first")
        let second = store.createNote()
        store.updateTitle(id: second, title: "Common second")
        store.query = "Common"
        let before = BrowserListItem.rows(in: store.browserSections)
        store.togglePin(first)
        let after = BrowserListItem.rows(in: store.browserSections)
        #expect(before.contains(.note(first)) && after.contains(.note(first)))
        #expect(after.compactMap(\.noteID) == store.visibleNotes.map(\.id))
        #expect(Set(after.map(\.id)).count == after.count)
        #expect(after.first == .header(kind: "pinned", title: "Pinned", count: 1))
        store.query = "second"
        #expect(BrowserListItem.rows(in: store.browserSections) == [
            .header(kind: "notes", title: "Notes", count: 1), .note(second)
        ])
        store.query = "No match"
        #expect(BrowserListItem.rows(in: store.browserSections) == [.header(kind: "notes", title: "Notes", count: 0)])
    }

    @Test("Older dates include the year using the display calendar at New Year")
    func editedDateBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: -8 * 3600))
        let locale = Locale(identifier: "en_US")
        let now = try #require(ISO8601DateFormatter().date(from: "2026-01-01T01:00:00Z"))
        let sameLocalYear = try #require(ISO8601DateFormatter().date(from: "2025-10-17T12:00:00Z"))
        let nextLocalYear = try #require(ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z"))
        let same = BrowserNoteDate.formatted(sameLocalYear, relativeTo: now, calendar: calendar, locale: locale)
        #expect(!same.contains("2025"))
        let different = BrowserNoteDate.formatted(nextLocalYear, relativeTo: now, calendar: calendar, locale: locale)
        #expect(different.contains("2026"))
        #expect(BrowserNoteDate.formatted(Date(timeIntervalSince1970: 0), relativeTo: now, calendar: calendar, locale: locale).contains("1969"))
    }
}
