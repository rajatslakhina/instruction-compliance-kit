/// What one request asks for.
public struct RequestReading: Sendable, Hashable {
    public let directives: [Directive]
    /// Families the request lifts ("forget the word limit", "ignore my formatting rules").
    public let released: Set<DirectiveFamily>
}

/// Reads the instructions in a user's request that a program can check: length limits, list shape,
/// words to use or avoid, letter case, how the answer opens and closes, JSON, tables, plain text and
/// commas. Everything else in the request is left alone.
///
/// The reading is lexical and deliberately narrow. A count that describes the material ("this 2,000-word
/// report"), a bound on each part ("each under 50 words") and an unquoted word the user wants included
/// are not read, because reading them wrong would report a violation the user never asked about.
public struct DirectiveReader: Sendable {
    static let standingMarkers: [[String]] = [
        ["from", "now", "on"], ["always"], ["going", "forward"], ["for", "the", "rest"], ["from", "here", "on"],
        ["every", "answer"], ["every", "response"], ["every", "reply"], ["each", "answer"], ["each", "response"],
        ["all", "future"], ["all", "your", "answers"], ["all", "your", "responses"], ["every", "time"]
    ]
    static let releaseVerbs: Set<String> = [
        "forget", "ignore", "drop", "lift", "remove", "scrap", "cancel", "disregard"
    ]
    static let releaseCues: [String: [DirectiveFamily]] = [
        "limit": [.length], "length": [.length], "lists": [.list], "list": [.list], "bullets": [.list],
        "bullet": [.list], "lowercase": [.letterCase], "uppercase": [.letterCase], "caps": [.letterCase],
        "format": [.format, .list], "formatting": [.format, .list], "markdown": [.format], "json": [.format],
        "commas": [.punctuation], "instructions": DirectiveFamily.allCases, "rules": DirectiveFamily.allCases,
        "constraints": DirectiveFamily.allCases, "requirements": DirectiveFamily.allCases
    ]

    public init() {}

    public func read(_ request: String) -> RequestReading {
        var directives: [Directive] = []
        var released: Set<DirectiveFamily> = []
        for clause in RequestScanner.clauses(in: request) {
            if let families = releasedFamilies(clause.tokens) {
                released.formUnion(families)
                continue
            }
            let scope: DirectiveScope = isStanding(clause.tokens) ? .standing : .turn
            for kind in kinds(in: clause.tokens) where !directives.contains(where: { $0.kind == kind }) {
                directives.append(Directive(kind: kind, scope: scope, phrase: clause.text))
            }
        }
        return RequestReading(directives: directives, released: released)
    }

    func kinds(in tokens: [RequestToken]) -> [DirectiveKind] {
        lengthKinds(tokens) + listKinds(tokens) + letterCaseKinds(tokens) + formatKinds(tokens)
            + endingKinds(tokens) + quoteKinds(tokens) + unquotedTermKinds(tokens)
    }

    func isStanding(_ tokens: [RequestToken]) -> Bool {
        Self.standingMarkers.contains { tokens.containsSequence($0) }
    }

    /// The families a clause lifts, when it uses a release verb ("forget", "ignore") or "no longer"
    /// about something it names.
    func releasedFamilies(_ tokens: [RequestToken]) -> Set<DirectiveFamily>? {
        let releases = tokens.containsWord(in: Self.releaseVerbs)
            || tokens.containsSequence(["no", "longer"]) || tokens.containsSequence(["no", "need"])
        guard releases else { return nil }
        let families = Set(tokens.compactMap(\.word).flatMap { Self.releaseCues[$0] ?? [] })
        return families.isEmpty ? nil : families
    }
}
