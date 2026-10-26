import Foundation

/// Counts and shapes of an answer. List markers are not words, headings are not sentences, and a
/// heading on its own is not a paragraph.
enum TextMeasure {
    static let terminators: Set<Character> = [".", "!", "?", "…"]
    static let closers: Set<Character> = ["\"", "'", ")", "”", "’", "*", "_", "]"]
    static let abbreviations: Set<String> = [
        "eg", "ie", "vs", "mr", "mrs", "ms", "dr", "prof", "st", "jr", "sr", "approx", "fig", "cf", "al"
    ]

    static func count(_ unit: LengthUnit, in text: String) -> Int {
        switch unit {
        case .words: lines(text).reduce(0) { $0 + words(in: withoutMarker($1)) }
        case .sentences: lines(text).reduce(0) { $0 + sentences(in: $1) }
        case .paragraphs: paragraphs(text)
        case .items: lines(text).filter { listStyle(of: $0) != nil }.count
        case .characters: text.count
        }
    }

    static func lines(_ text: String) -> [Substring] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
    }

    static func items(_ style: ListStyle, in text: String) -> Int {
        lines(text).filter { listStyle(of: $0) == style }.count
    }

    static func words(in text: Substring) -> Int {
        let chars = Array(text)
        var count = 0
        var inWord = false
        for (index, char) in chars.enumerated() {
            if char.isLetter || char.isNumber {
                if !inWord { count += 1 }
                inWord = true
            } else if inWord, "'’-".contains(char), index + 1 < chars.count,
                      chars[index + 1].isLetter || chars[index + 1].isNumber {
                continue
            } else {
                inWord = false
            }
        }
        return count
    }

    static func sentences(in line: Substring) -> Int {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isHeading(trimmed), !isDivider(trimmed), !isTableRule(trimmed) else { return 0 }
        let chars = Array(withoutMarker(line))
        var count = 0
        var pending = false
        var index = 0
        while index < chars.count {
            let char = chars[index]
            pending = pending || char.isLetter || char.isNumber
            guard terminators.contains(char) else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < chars.count, terminators.contains(chars[end + 1]) || closers.contains(chars[end + 1]) {
                end += 1
            }
            let atBreak = end + 1 == chars.count || chars[end + 1].isWhitespace
            if atBreak, pending, !(char == "." && isAbbreviation(chars, before: index)) {
                count += 1
                pending = false
            }
            index = end + 1
        }
        return count + (pending ? 1 : 0)
    }

    /// "e.g.", "Dr.", a single initial.
    static func isAbbreviation(_ chars: [Character], before index: Int) -> Bool {
        var start = index
        while start > 0, chars[start - 1].isLetter || chars[start - 1] == "." { start -= 1 }
        let word = String(chars[start..<index]).lowercased().replacingOccurrences(of: ".", with: "")
        return word.count == 1 || abbreviations.contains(word)
    }

    static func paragraphs(_ text: String) -> Int {
        var count = 0
        var content = false
        for line in lines(text) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || isDivider(trimmed) {
                count += content ? 1 : 0
                content = false
            } else if !isHeading(trimmed), trimmed.contains(where: { $0.isLetter || $0.isNumber }) {
                content = true
            }
        }
        return count + (content ? 1 : 0)
    }

    static func listStyle(of line: Substring) -> ListStyle? {
        let trimmed = line.drop { $0 == " " || $0 == "\t" }
        guard let first = trimmed.first, !isDivider(trimmed.trimmingCharacters(in: .whitespaces)) else { return nil }
        if "-*•+".contains(first) { return trimmed.dropFirst().first == " " ? .bulleted : nil }
        let digits = trimmed.prefix(while: \.isNumber)
        let rest = trimmed.dropFirst(digits.count)
        guard (1...3).contains(digits.count), let mark = rest.first, mark == "." || mark == ")" else { return nil }
        return rest.dropFirst().first == " " ? .numbered : nil
    }

    static func withoutMarker(_ line: Substring) -> Substring {
        guard listStyle(of: line) != nil else { return line }
        let trimmed = line.drop { $0 == " " || $0 == "\t" }
        return trimmed.drop { $0 != " " }
    }

    static func isHeading(_ trimmed: String) -> Bool {
        let hashes = trimmed.prefix(while: { $0 == "#" }).count
        return (1...6).contains(hashes) && trimmed.dropFirst(hashes).first == " "
    }

    /// `---`, `***`, `* * *`.
    static func isDivider(_ trimmed: String) -> Bool {
        trimmed.allSatisfy { "-*_ ".contains($0) } && trimmed.filter { $0 != " " }.count >= 3
    }

    /// `|---|:---:|`.
    static func isTableRule(_ trimmed: String) -> Bool {
        trimmed.contains("|") && trimmed.contains("---") && trimmed.allSatisfy { "|-: ".contains($0) }
    }

    static func hasTable(_ text: String) -> Bool {
        let rows = lines(text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.contains("|") }
        return rows.contains(where: isTableRule) && rows.count >= 2
    }

    /// Parses as a JSON object or array. A surrounding code fence is set aside: a client strips it
    /// before parsing.
    static func isJSON(_ text: String) -> Bool {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("```"), body.hasSuffix("```"), body.count > 6 {
            body = String(body.dropFirst(3).dropLast(3).drop { $0 != "\n" })
        }
        return (try? JSONSerialization.jsonObject(with: Data(body.utf8))) != nil
    }

    static func markdown(in text: String) -> [String] {
        var used: [String] = []
        let headed = lines(text).contains { isHeading($0.trimmingCharacters(in: .whitespaces)) }
        if headed { used.append("heading") }
        if text.contains("**") || text.contains("__") { used.append("bold") }
        if text.contains("```") { used.append("code fence") }
        if hasTable(text) { used.append("table") }
        if text.contains("](") { used.append("link") }
        return used
    }

    /// The last character that is not whitespace, a closing quote, bracket or emphasis mark.
    static func lastSignificant(_ text: String) -> Character? {
        text.last { !$0.isWhitespace && !closers.contains($0) }
    }
}
