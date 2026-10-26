import Foundation

/// Splits a request into clauses and tokens. Quoted text stays whole, so `end with "Any questions?"`
/// does not end its clause at the question mark.
enum RequestScanner {
    static let numberWords: [String: Int] = [
        "zero": 0, "one": 1, "single": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
        "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
        "hundred": 100
    ]
    static let marks: Set<Character> = [",", ":", "(", ")", "—", "–"]
    static let dashes: Set<Character> = ["-", "–", "—"]

    static func clauses(in request: String) -> [RequestClause] {
        let chars = Array(request)
        var clauses: [RequestClause] = []
        var tokens: [RequestToken] = []
        var start = 0
        var index = 0
        func flush(_ end: Int) {
            let text = String(chars[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tokens.isEmpty { clauses.append(RequestClause(text: text, tokens: mergingNumbers(tokens))) }
            tokens = []
            start = end
        }
        while index < chars.count {
            let char = chars[index]
            if let end = quoteEnd(in: chars, from: index) {
                let text = String(chars[(index + 1)..<end]).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { tokens.append(.quote(text)) }
                index = end + 1
            } else if char.isLetter || char.isNumber {
                let (token, next) = word(in: chars, from: index)
                tokens.append(token)
                index = next
            } else {
                if marks.contains(char) { tokens.append(.mark) }
                index += 1
                if endsClause(chars, at: index - 1) { flush(index) }
            }
        }
        flush(chars.count)
        return clauses
    }

    static func endsClause(_ chars: [Character], at index: Int) -> Bool {
        switch chars[index] {
        case "!", "?", ";", "\n": true
        case ".": index + 1 == chars.count || chars[index + 1].isWhitespace
        default: false
        }
    }

    /// The index of the closing quote, when a quote opens here and closes on the same line.
    static func quoteEnd(in chars: [Character], from index: Int) -> Int? {
        let closer: Character
        switch chars[index] {
        case "\"": closer = "\""
        case "“": closer = "”"
        case "‘": closer = "’"
        case "'":
            guard index == 0 || !isWordCharacter(chars[index - 1]) else { return nil }
            closer = "'"
        default: return nil
        }
        var end = index + 1
        while end < chars.count, chars[end] != "\n" {
            let closesHere = chars[end] == closer
                && (closer != "'" || end + 1 == chars.count || !isWordCharacter(chars[end + 1]))
            if closesHere { return end }
            end += 1
        }
        return nil
    }

    static func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber
    }

    /// Reads a word or a number starting at `start`. Digits grouped with commas read as one number,
    /// and `50-100` reads as a range.
    static func word(in chars: [Character], from start: Int) -> (RequestToken, Int) {
        var text = ""
        var end = start
        while end < chars.count {
            let char = chars[end]
            if isWordCharacter(char) {
                text.append(char)
            } else if char == "'" || char == "’", end + 1 < chars.count, chars[end + 1].isLetter {
                text.append("'")
            } else if char == ",", isGroupedDigits(chars, after: end, text: text) {
                end += 1
                continue
            } else {
                break
            }
            end += 1
        }
        guard text.allSatisfy(\.isNumber), let value = Int(text) else { return (.word(text.lowercased()), end) }
        if end + 1 < chars.count, dashes.contains(chars[end]), chars[end + 1].isNumber {
            let digits = chars[(end + 1)...].prefix(while: \.isNumber)
            if let upper = Int(String(digits)) { return (.range(value, upper), end + 1 + digits.count) }
        }
        return (.number(value), end)
    }

    /// `1,000`: a comma after digits, followed by exactly three digits.
    static func isGroupedDigits(_ chars: [Character], after comma: Int, text: String) -> Bool {
        guard text.allSatisfy(\.isNumber), comma + 3 < chars.count else { return false }
        let group = chars[(comma + 1)...].prefix(4)
        let digits = group.prefix(while: \.isNumber).count
        return digits == 3
    }

    /// Number words become numbers: "twenty five" is 25, "two hundred" is 200.
    static func mergingNumbers(_ tokens: [RequestToken]) -> [RequestToken] {
        var merged: [RequestToken] = []
        for token in tokens {
            guard let word = token.word, let value = numberWords[word] else {
                merged.append(token)
                continue
            }
            if let previous = merged.last?.number, let combined = combine(previous, value) {
                merged[merged.count - 1] = .number(combined)
            } else {
                merged.append(.number(value))
            }
        }
        return merged
    }

    static func combine(_ previous: Int, _ value: Int) -> Int? {
        if value == 100, (1...9).contains(previous) { return previous * 100 }
        if (20...90).contains(previous), previous % 10 == 0, (1...9).contains(value) { return previous + value }
        return nil
    }
}
