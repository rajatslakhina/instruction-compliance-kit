import Foundation

/// Whole-word, case-insensitive matching. A term also matches its plural: "price" matches "prices".
enum TextMatch {
    static func count(of term: String, in text: String) -> Int {
        let needle = folded(term)
        let haystack = folded(text)
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var from = haystack.startIndex
        while let found = haystack.range(of: needle, range: from..<haystack.endIndex) {
            if startsWord(at: found.lowerBound, in: haystack), endsWord(at: found.upperBound, in: haystack) {
                count += 1
            }
            from = found.upperBound
        }
        return count
    }

    static func folded(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    static func startsWord(at index: String.Index, in text: String) -> Bool {
        index == text.startIndex || !isWordCharacter(text[text.index(before: index)])
    }

    static func endsWord(at index: String.Index, in text: String) -> Bool {
        ["", "s", "es"].contains { suffix in
            guard text[index...].hasPrefix(suffix) else { return false }
            let end = text.index(index, offsetBy: suffix.count)
            return end == text.endIndex || !isWordCharacter(text[end])
        }
    }

    static func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber
    }

    /// Case-insensitive; an option without closing punctuation also matches an answer that adds a full
    /// stop or an exclamation mark after it.
    static func ends(_ text: String, with option: String) -> Bool {
        let answer = folded(text).trimmingCharacters(in: .whitespacesAndNewlines)
        let wanted = folded(option).trimmingCharacters(in: .whitespacesAndNewlines)
        if answer.hasSuffix(wanted) { return true }
        guard let last = wanted.last, !".!?".contains(last) else { return false }
        return String(answer.reversed().drop { ".!".contains($0) }.reversed()).hasSuffix(wanted)
    }

    static func starts(_ text: String, with option: String) -> Bool {
        let answer = folded(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return answer.hasPrefix(folded(option).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
