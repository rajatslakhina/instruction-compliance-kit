/// Length bounds: "under 120 words", "no more than two paragraphs", "3 to 5 bullet points",
/// "a 100-word limit", "in one sentence".
extension DirectiveReader {
    static let unitNouns: [String: LengthUnit] = [
        "word": .words, "words": .words, "sentence": .sentences, "sentences": .sentences,
        "paragraph": .paragraphs, "paragraphs": .paragraphs, "character": .characters,
        "characters": .characters, "chars": .characters, "bullet": .items, "bullets": .items
    ]
    static let itemNouns: Set<String> = ["items", "item", "points", "point", "steps", "step"]
    static let listCues: Set<String> = ["list", "bullet", "bullets", "bulleted", "numbered"]
    static let adjectives: Set<String> = [
        "short", "brief", "concise", "long", "full", "complete", "total", "separate", "distinct", "clear",
        "simple", "key", "main", "quick", "detailed", "bulleted", "numbered"
    ]
    /// A number after one of these describes the material, not the answer: "this 2,000-word report".
    static let sourceCues: Set<String> = [
        "this", "that", "these", "those", "the", "my", "our", "his", "her", "their", "its", "attached",
        "following", "above", "below", "is", "was", "are", "were", "has", "have", "had", "contains"
    ]
    static let limitCues: Set<String> = [
        "limit", "keep", "cap", "trim", "cut", "shorten", "restrict", "condense", "reduce"
    ]
    static let answerNouns: Set<String> = ["answer", "answers", "response", "responses", "reply", "replies"]

    func lengthKinds(_ tokens: [RequestToken]) -> [DirectiveKind] {
        tokens.indices.compactMap { index in
            guard let unit = unit(at: index, in: tokens), let bound = bound(for: unit, at: index, in: tokens) else {
                return nil
            }
            return .length(unit, bound)
        }
    }

    func unit(at index: Int, in tokens: [RequestToken]) -> LengthUnit? {
        guard let word = tokens[index].word else { return nil }
        if let unit = Self.unitNouns[word] { return unit }
        let previous = tokens.word(at: index - 1)
        guard Self.itemNouns.contains(word), previous != "bullet", previous != "bullets",
              tokens.containsWord(in: Self.listCues) else { return nil }
        return .items
    }

    func bound(for unit: LengthUnit, at index: Int, in tokens: [RequestToken]) -> Bound? {
        var position = index - 1
        while position > index - 3, let word = tokens.word(at: position), Self.adjectives.contains(word) {
            position -= 1
        }
        let after = Self.itemNouns.contains(tokens.word(at: index + 1) ?? "") ? index + 2 : index + 1
        guard position >= 0, !describesSource(tokens, before: position),
              !isPerPart(tokens, number: position, after: after) else { return nil }
        switch tokens[position] {
        case let .range(low, high):
            return .between(min(low, high), max(low, high))
        case let .number(value):
            return joinedRange(tokens, number: position, value: value)
                ?? boundBefore(tokens, number: position, value: value)
                ?? boundAfter(tokens, at: after, value: value)
                ?? (unit == .words || unit == .characters ? .atMost(value) : .exactly(value))
        case .word("a"), .word("an"):
            let inside = ["in", "into", "within"].contains(tokens.word(at: position - 1) ?? "")
            return inside && (unit == .sentences || unit == .paragraphs) ? .exactly(1) : nil
        default:
            return nil
        }
    }

    func describesSource(_ tokens: [RequestToken], before position: Int) -> Bool {
        Self.sourceCues.contains(tokens.word(at: position - 1) ?? "")
    }

    /// "each under 50 words", "10 words per bullet": a bound on every part, which a whole-answer count
    /// cannot check. "each answer" is a standing marker, not a part.
    func isPerPart(_ tokens: [RequestToken], number position: Int, after: Int) -> Bool {
        let around = Array((max(0, position - 4)..<position)) + [after]
        return around.contains { index in
            guard let word = tokens.word(at: index), word == "each" || word == "per" else { return false }
            return !Self.answerNouns.contains(tokens.word(at: index + 1) ?? "")
        }
    }

    /// "3 to 5", "2 or 3", "between 50 and 100".
    func joinedRange(_ tokens: [RequestToken], number position: Int, value: Int) -> Bound? {
        guard let joiner = tokens.word(at: position - 1), position >= 2, let other = tokens[position - 2].number else {
            return nil
        }
        guard joiner == "to" || joiner == "or" || (joiner == "and" && tokens.word(at: position - 3) == "between") else {
            return nil
        }
        return .between(min(other, value), max(other, value))
    }

    func boundBefore(_ tokens: [RequestToken], number position: Int, value: Int) -> Bound? {
        guard let previous = tokens.word(at: position - 1) else { return nil }
        let earlier = tokens.word(at: position - 2)
        switch previous {
        case "most" where earlier == "at", "within", "max", "maximum": return .atMost(value)
        case "least" where earlier == "at", "min", "minimum": return .atLeast(value)
        case "exactly", "precisely": return .exactly(value)
        case "about", "around", "roughly", "approximately": return .around(value)
        case "over", "above", "exceed", "exceeds", "exceeding", "under", "below", "than":
            return comparativeBound(tokens, number: position, value: value)
        case "of", "to": return phrasedBound(tokens, number: position, value: value)
        default: return nil
        }
    }

    /// "a maximum of 3", "a minimum of 300", "up to 5", "keep it to 2".
    func phrasedBound(_ tokens: [RequestToken], number position: Int, value: Int) -> Bound? {
        let earlier = tokens.word(at: position - 2) ?? ""
        if tokens.word(at: position - 1) == "of" {
            if ["maximum", "max", "limit", "cap"].contains(earlier) { return .atMost(value) }
            return ["minimum", "min"].contains(earlier) ? .atLeast(value) : nil
        }
        let limited = earlier == "up" || tokens[..<position].containsWord(in: Self.limitCues)
        return limited ? .atMost(value) : nil
    }

    /// "over 100", "under 50", "more than 100", "no fewer than 5", "do not exceed 100".
    func comparativeBound(_ tokens: [RequestToken], number position: Int, value: Int) -> Bound? {
        let directions = [
            "over": true, "above": true, "exceed": true, "exceeds": true, "exceeding": true, "under": false,
            "below": false, "more": true, "longer": true, "fewer": false, "less": false, "shorter": false
        ]
        let previous = tokens.word(at: position - 1)
        let word = previous == "than" ? tokens.word(at: position - 2) : previous
        guard let word, let over = directions[word] else { return nil }
        let wordIndex = previous == "than" ? position - 2 : position - 1
        return comparative(over: over, value: value, negated: tokens.hasNegator(before: wordIndex))
    }

    /// "more than 100" is at least 101, "no more than 100" at most 100; "under 50" is at most 49.
    func comparative(over: Bool, value: Int, negated: Bool) -> Bound {
        switch (over, negated) {
        case (true, false): .atLeast(value + 1)
        case (true, true): .atMost(value)
        case (false, false): .atMost(max(value - 1, 0))
        case (false, true): .atLeast(value)
        }
    }

    /// "100 words or less", "300 words minimum", "a 100-word limit".
    func boundAfter(_ tokens: [RequestToken], at index: Int, value: Int) -> Bound? {
        guard let next = tokens.word(at: index) else { return nil }
        let following = tokens.word(at: index + 1) ?? ""
        switch next {
        case "or" where ["less", "fewer", "under", "shorter"].contains(following): return .atMost(value)
        case "or" where ["more", "longer", "over"].contains(following): return .atLeast(value)
        case "at" where following == "most": return .atMost(value)
        case "at" where following == "least": return .atLeast(value)
        case "max", "maximum", "tops", "limit", "cap": return .atMost(value)
        case "min", "minimum": return .atLeast(value)
        default: return nil
        }
    }
}

extension ArraySlice where Element == RequestToken {
    func containsWord(in words: Set<String>) -> Bool {
        contains { $0.word.map(words.contains) ?? false }
    }
}
