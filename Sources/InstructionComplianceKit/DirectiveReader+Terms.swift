/// Quoted text the answer has to open with, close with, use or avoid, and unquoted words it must not
/// mention.
extension DirectiveReader {
    static let startVerbs: Set<String> = [
        "start", "starts", "starting", "begin", "begins", "beginning", "open", "opens", "opening"
    ]
    static let closeVerbs: Set<String> = [
        "end", "ends", "ending", "finish", "finishes", "close", "closes", "conclude", "sign"
    ]
    static let useVerbs: Set<String> = [
        "mention", "mentions", "mentioning", "include", "includes", "including", "use", "using", "say",
        "saying", "contain", "containing", "feature", "add", "incorporate", "write"
    ]
    static let avoidVerbs: Set<String> = ["avoid", "exclude", "omit", "skip", "without", "ban", "remove"]
    static let mentionVerbs: Set<String> = [
        "mention", "mentioning", "discuss", "discussing", "reference", "referencing", "name", "naming"
    ]
    static let fillers: Set<String> = [
        "the", "word", "words", "phrase", "phrases", "term", "terms", "keyword", "keywords", "exact", "exactly",
        "following", "string", "with", "by", "off", "your", "answer", "response", "reply", "it", "a", "any", "of"
    ]
    static let termStops: Set<String> = [
        "in", "at", "when", "because", "unless", "since", "if", "to", "for", "with", "while", "as", "please",
        "again", "anymore", "either", "and", "or", "nor", "but", "so", "anywhere", "here", "there", "now"
    ]
    static let articles: Set<String> = ["the", "a", "an", "any", "my", "our", "your", "their", "its"]
    static let notTerms: Set<String> = ["count", "limit", "length", "choice", "order", "budget"]

    enum QuoteRole: Equatable {
        case opening, closing, use, avoid
    }

    func quoteKinds(_ tokens: [RequestToken]) -> [DirectiveKind] {
        var kinds: [DirectiveKind] = []
        for (index, token) in tokens.enumerated() {
            guard case let .quote(text) = token, let role = quoteRole(tokens, at: index) else { continue }
            let alternative = previousMeaningful(tokens, before: index) == .word("or")
            switch role {
            case .opening:
                if alternative, case let .startsWith(options)? = kinds.last {
                    kinds[kinds.count - 1] = .startsWith(options + [text])
                } else {
                    kinds.append(.startsWith([text]))
                }
            case .closing:
                if alternative, case let .endsWith(options)? = kinds.last {
                    kinds[kinds.count - 1] = .endsWith(options + [text])
                } else {
                    kinds.append(.endsWith([text]))
                }
            case .use:
                kinds.append(.include(Self.normalized(text)))
            case .avoid:
                kinds.append(.exclude(Self.normalized(text)))
            }
        }
        return kinds
    }

    /// Looks back past fillers, other quotes, "and", "or" and marks for the verb that governs a quote.
    func quoteRole(_ tokens: [RequestToken], at index: Int) -> QuoteRole? {
        var position = index - 1
        var looked = 0
        while position >= 0, looked < 6 {
            defer { position -= 1 }
            guard let word = tokens[position].word else { continue }
            if Self.fillers.contains(word) || word == "and" || word == "or" { continue }
            looked += 1
            if Self.startVerbs.contains(word) { return .opening }
            if Self.closeVerbs.contains(word) { return .closing }
            if Self.avoidVerbs.contains(word) { return .avoid }
            if Self.useVerbs.contains(word) { return tokens.hasNegator(before: position) ? .avoid : .use }
        }
        return nil
    }

    func previousMeaningful(_ tokens: [RequestToken], before index: Int) -> RequestToken? {
        tokens[..<index].last { $0 != .mark }
    }

    /// "don't mention competitors or pricing", "no mention of the vendor", "never use the word synergy".
    func unquotedTermKinds(_ tokens: [RequestToken]) -> [DirectiveKind] {
        var kinds: [DirectiveKind] = []
        for (index, token) in tokens.enumerated() {
            guard let word = token.word else { continue }
            var start: Int?
            var polarity: QuoteRole?
            if Self.mentionVerbs.contains(word), tokens.hasNegator(before: index) {
                start = tokens.word(at: index + 1) == "of" ? index + 2 : index + 1
                polarity = .avoid
            } else if ["word", "term", "keyword"].contains(word), tokens.word(at: index - 1) == "the" {
                start = index + 1
                polarity = quoteRole(tokens, at: index)
            }
            guard let start, let polarity, polarity == .use || polarity == .avoid else { continue }
            let single = !Self.mentionVerbs.contains(word)
            for term in terms(tokens, from: start, single: single) {
                let kind: DirectiveKind = polarity == .use ? .include(term) : .exclude(term)
                if !kinds.contains(kind) { kinds.append(kind) }
            }
        }
        return kinds
    }

    /// Up to three words per term, split on "or", "and" and "nor", stopping at a mark or a word that
    /// starts a new thought. `single` reads one word ("the word synergy"), and drops the words that make
    /// "the word count" or "the word limit" a phrase about length rather than a term.
    func terms(_ tokens: [RequestToken], from start: Int, single: Bool) -> [String] {
        var terms: [String] = []
        var current: [String] = []
        var index = start
        while index < tokens.count, let word = tokens[index].word {
            let joins = ["or", "and", "nor"].contains(word)
            if Self.termStops.contains(word) && !joins { break }
            if joins {
                if !current.isEmpty { terms.append(current.joined(separator: " ")) }
                current = []
            } else if !(current.isEmpty && Self.articles.contains(word)) {
                current.append(word)
                if current.count == 3 || single { break }
            }
            index += 1
        }
        if !current.isEmpty { terms.append(current.joined(separator: " ")) }
        return single ? terms.filter { !Self.notTerms.contains($0) } : terms
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
