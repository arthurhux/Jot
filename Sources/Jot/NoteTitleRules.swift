import Foundation

/// The opening line carries the note's intent: a heading, task, or thought.
/// Keep its own words, without inventing a summary or sending content elsewhere.
enum NoteTitleRules {
    static let maximumLength = 72

    static func title(from plainText: String) -> String {
        for rawLine in plainText.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            // Fences and thematic breaks don't describe a note.
            if line.hasPrefix("```") || line.hasPrefix("~~~") { continue }
            if line.count >= 3, line.allSatisfy({ "-*_ ".contains($0) }) { continue }
            line = line.replacingOccurrences(of: #"^(?:\s*(?:#{1,6}\s+|>\s*|[-+*]\s+|\d+[.)]\s+|\[[ xX]\]\s+))+"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"!?\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            line = line.replacingOccurrences(of: #"(`+)(.*?)\1"#, with: "$2", options: .regularExpression)
            line = line.replacingOccurrences(of: #"(\*\*|__|~~)(.*?)\1"#, with: "$2", options: .regularExpression)
            line = line.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            guard !line.isEmpty else { continue }
            guard line.count > maximumLength else { return line }
            let prefix = String(line.prefix(maximumLength - 1))
            // Keep a whole word when that doesn't discard most of the title.
            if let space = prefix.lastIndex(of: " "), prefix.distance(from: prefix.startIndex, to: space) >= maximumLength / 2 {
                return String(prefix[..<space]) + "…"
            }
            return prefix + "…"
        }
        return ""
    }
}
