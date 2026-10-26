/// List shape, letter case, formats, commas and "end with a question".
extension DirectiveReader {
    static let endVerbs: Set<String> = ["end", "ends", "ending", "finish", "close", "conclude", "wrap"]

    /// A clause that asks for a style keeps it, even when it also turns another style down:
    /// "don't use a numbered list, use bullets" is a bulleted list, not "no lists".
    func listKinds(_ tokens: [RequestToken]) -> [DirectiveKind] {
        var styles: [ListStyle] = []
        var refused = false
        for (index, token) in tokens.enumerated() {
            let style: ListStyle?
            switch token.word {
            case "bullet", "bullets", "bulleted": style = .bulleted
            case "numbered": style = .numbered
            case "list", "lists": style = nil
            case "prose" where ["in", "as"].contains(tokens.word(at: index - 1) ?? ""):
                refused = true
                continue
            default: continue
            }
            if tokens.hasNegator(before: index, within: 4) {
                refused = true
            } else if let style, !styles.contains(style) {
                styles.append(style)
            }
        }
        if !styles.isEmpty { return styles.map(DirectiveKind.list) }
        return refused ? [.noList] : []
    }

    func letterCaseKinds(_ tokens: [RequestToken]) -> [DirectiveKind] {
        var kinds: [DirectiveKind] = []
        for (index, token) in tokens.enumerated() {
            guard let word = token.word else { continue }
            let next = tokens.word(at: index + 1)
            let previous = tokens.word(at: index - 1) ?? ""
            let negated = tokens.hasNegator(before: index, within: 4)
            let kind: LetterCase?
            switch word {
            case "lowercase", "lowercased":
                kind = negated ? nil : .lowercase
            case "lower" where next == "case":
                kind = negated ? nil : .lowercase
            case "uppercase":
                kind = negated ? .lowercase : .uppercase
            case "upper" where next == "case":
                kind = negated ? .lowercase : .uppercase
            case "caps", "capitals":
                kind = negated ? .lowercase : (["all", "in"].contains(previous) ? .uppercase : nil)
            case "capital" where next == "letters" || next == "letter":
                kind = negated ? .lowercase : (["all", "in", "only", "entirely"].contains(previous) ? .uppercase : nil)
            default:
                kind = nil
            }
            if let kind, !kinds.contains(.letterCase(kind)) { kinds.append(.letterCase(kind)) }
        }
        return kinds
    }

    func formatKinds(_ tokens: [RequestToken]) -> [DirectiveKind] {
        var kinds: [DirectiveKind] = []
        for (index, token) in tokens.enumerated() {
            guard let word = token.word else { continue }
            let negated = tokens.hasNegator(before: index, within: 4)
            let next = tokens.word(at: index + 1)
            let previous = tokens.word(at: index - 1) ?? ""
            let kind: DirectiveKind?
            switch word {
            case "json": kind = negated ? nil : .format(.json)
            case "tabular": kind = negated ? nil : .format(.table)
            case "table" where next != "of":
                let framed = ["a", "as", "in", "markdown"].contains(previous) || next == "format" || next == "form"
                kind = !negated && framed ? .format(.table) : nil
            case "plain" where next == "text": kind = negated ? nil : .format(.plainText)
            case "markdown", "formatting": kind = negated ? .format(.plainText) : nil
            case "commas", "comma": kind = negated ? .noCommas : nil
            default: kind = nil
            }
            if let kind, !kinds.contains(kind) { kinds.append(kind) }
        }
        return kinds
    }

    /// "end with a question", "finish by asking a follow-up question", "ask a question at the end".
    func endingKinds(_ tokens: [RequestToken]) -> [DirectiveKind] {
        for (index, token) in tokens.enumerated() {
            guard let word = token.word, Self.endVerbs.contains(word) else { continue }
            let window = tokens[(index + 1)..<min(tokens.count, index + 8)]
            let ahead = window.prefix { if case .word = $0 { true } else { false } }
            let behind = tokens[max(0, index - 5)..<index]
            if ahead.contains(.word("question")) || (word == "end" && behind.contains(.word("question"))) {
                return [.endsWithQuestion]
            }
        }
        return []
    }
}
