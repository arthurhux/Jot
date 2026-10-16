#if DEBUG
import Foundation

enum BreakUIDataset: String, CaseIterable, Identifiable {
    case demo = "Demo data", worst = "Worst case", empty = "Empty", one = "One", huge = "1,284 notes", corrupt = "Read error"
    var id: String { rawValue }

    func notes() -> [Note] {
        let date = Date(timeIntervalSince1970: 1_792_152_000)
        func note(_ title: String, _ text: String, index: Int, pinned: Bool = false, deleted: Bool = false) -> Note {
            let paragraphs: [[String: Any]] = text.components(separatedBy: "\n").map { line in
                line.isEmpty ? ["type": "paragraph"] : ["type": "paragraph", "content": [["type": "text", "text": line]]]
            }
            let document = String(data: try! JSONSerialization.data(withJSONObject: ["type": "doc", "content": paragraphs]), encoding: .utf8)!
            return Note(title: title, titleIsAutomatic: title.isEmpty, document: document, plainText: text, markdown: text,
                        createdAt: date.addingTimeInterval(-Double(index) * 86_400),
                        modifiedAt: date.addingTimeInterval(-Double(index) * 86_400), pinned: pinned,
                        deletedAt: deleted ? date.addingTimeInterval(-86_400) : nil)
        }
        switch self {
        case .empty, .corrupt: return []
        case .one: return [note("J", "J", index: 0)]
        case .demo:
            return [note("Launch checklist", "Confirm the release date.\nAsk Jo to review the installation guide.", index: 0, pinned: true),
                    note("Friday ideas", "A little room to think.\nKeep the capture flow quick.", index: 1),
                    note("Meeting notes", "Review feedback and agree on the next step.", index: 2)]
        case .worst:
            let longTitle = "Q3 Board Deck — FINAL (revised) v12 [approved by Aleksandra Wiśniewska-Kowalczyk, Platform Infrastructure and Enterprise Onboarding] — implementation follow-up and outstanding launch decisions"
            let email = "bartholomew.fitzgerald@northwind-industries-holdings.example.com"
            let url = "https://example.com/workspaces/acme/projects/q3-launch/docs/9f8e7d6c5b4a?tab=comments&filter=unresolved"
            let description = (1...18).map { "Decision \($0): confirm the owner, document the accessibility review, and ask the enterprise onboarding team to approve the release notes before Friday." }.joined(separator: " ")
            let transcript = (1...1284).map { "[\($0 / 60):\(String(format: "%02d", $0 % 60))] Aleksandra: Review the customer feedback, confirm the owner for this action, and record the next step for the platform launch." }.joined(separator: "\n")
            var cases = [note(longTitle, "\(email)\n\n\(url)\n\nBenachrichtigungseinstellungen\n\n\(description)", index: 0, pinned: true),
                    note(email, "Plus addressing: first.last+billing-notifications@example.com", index: 1),
                    note("J", "J", index: 2),
                    note("Đặng Thị Ngọc Hân — đánh giá khả năng tiếp cận", "Đặng Thị Ngọc Hân\nภาษาไทยและเครื่องหมายกำกับเสียง\n王秀英 — 会议记录与产品发布计划", index: 3),
                    note("نور الهدى عبد الرحمن — ملاحظات الاجتماع", "نور الهدى عبد الرحمن\nمراجعة تصميم الواجهة وخطة الإطلاق لعام 2026.\nContact: \(email)", index: 4),
                    note("👩🏽‍💻 Priya · 🦊 Fox · family 👨‍👩‍👧‍👦", "👩🏽‍💻 🦊 👨‍👩‍👧‍👦\nSeán O'Brien-Ó Súilleabháin\n  Sam   Lee ", index: 5),
                    note("", "", index: 6),
                    note("   ", "   ", index: 7),
                    note("Q3 Board Deck — FINAL (revised) v11 [approved by legal].pdf", "The version before the final review.", index: 8),
                    note("Q3 Board Deck — FINAL (revised) v12 [approved by legal].pdf", "The version after the final review.", index: 9),
                    note("Weekly review", "An older review with the same title.", index: 400),
                    note("Weekly review", "A newer review with the same title.", index: 11),
                    note("Literal code & Markdown", "<script>alert(1)</script>\n&amp;\n**bold**\nLine one\nLine two", index: 12),
                    note("Customer interview transcript — 21 minutes", transcript, index: 13),
                    note("Archived draft", "Read-only content in Recently deleted.", index: 14, deleted: true)]
            cases.append(note("Board review\nRelease decision", "A pasted title with a newline.", index: 15))
            var future = note("Imported draft — clock three days ahead", "An imported file can have a future modification date.", index: 16)
            future.modifiedAt = date.addingTimeInterval(3 * 86_400)
            var epoch = note("Migrated archive — Unix epoch timestamp", "A legacy import with a zero timestamp.", index: 17)
            epoch.modifiedAt = Date(timeIntervalSince1970: 0)
            var old = note("Launch retrospective — three years ago", "An older note that should remain readable and searchable.", index: 18)
            old.modifiedAt = date.addingTimeInterval(-3 * 365 * 86_400)
            cases.append(contentsOf: [future, epoch, old])
            return cases
        case .huge:
            return (0..<1284).map { index in
                note("Customer interview \(index + 1) — enterprise onboarding feedback", "Interview \(index + 1).\nRecord the next step with the owner and follow up on Friday.", index: index, pinned: index < 12)
            }
        }
    }
}
#endif
