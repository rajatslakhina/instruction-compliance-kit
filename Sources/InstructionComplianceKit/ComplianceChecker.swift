import Foundation

public enum ComplianceStatus: String, Sendable, Hashable {
    case met
    /// Met once a one-line preamble or sign-off is set aside, or asterisks are removed.
    case metLoosely
    case violated
}

/// One instruction, checked.
public struct DirectiveResult: Sendable, Hashable {
    public let directive: Directive
    public let metStrictly: Bool
    /// Met strictly, or met on one of the loose readings.
    public let metLoosely: Bool
    /// What the whole answer shows: "143 words", "uses \"delve\" twice", "ends with \".\"".
    public let observed: String

    public var status: ComplianceStatus {
        metStrictly ? .met : (metLoosely ? .metLoosely : .violated)
    }
}

/// Checks an answer against instructions, strictly and loosely, the way IFEval scores instruction
/// following: the loose reading also accepts the answer without its first line, its last line or
/// both, and without asterisks, so "Sure! Here's a summary:" does not fail a word limit on its own.
///
/// Two departures from IFEval: a line that is a list item is never set aside (it is content, not a
/// preamble), and asterisks are not removed for instructions about lists or markdown, which the
/// asterisks are part of.
public struct ComplianceChecker: Sendable {
    public let detector: ConflictDetector

    public init(detector: ConflictDetector = ConflictDetector()) {
        self.detector = detector
    }

    public func report(answer: String, directives: [Directive]) -> ComplianceReport {
        ComplianceReport(
            answer: answer,
            results: directives.map { check(answer, against: $0) },
            conflicts: detector.conflicts(in: directives)
        )
    }

    public func check(_ answer: String, against directive: Directive) -> DirectiveResult {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let strict = evaluate(directive.kind, on: text)
        let readings = Self.looseReadings(of: text, unstarring: Self.allowsUnstarring(directive.kind))
        let loose = strict.met || readings.contains { evaluate(directive.kind, on: $0).met }
        return DirectiveResult(
            directive: directive, metStrictly: strict.met, metLoosely: loose, observed: strict.observed
        )
    }

    static func looseReadings(of text: String, unstarring: Bool) -> [String] {
        let lines = text.components(separatedBy: "\n")
        let dropFirst = lines.count > 1 && TextMeasure.listStyle(of: Substring(lines[0])) == nil
        let dropLast = lines.count > 1 && TextMeasure.listStyle(of: Substring(lines[lines.count - 1])) == nil
        var readings: [String] = [text]
        if dropFirst { readings.append(lines.dropFirst().joined(separator: "\n")) }
        if dropLast { readings.append(lines.dropLast().joined(separator: "\n")) }
        if dropFirst, dropLast, lines.count > 2 {
            readings.append(lines.dropFirst().dropLast().joined(separator: "\n"))
        }
        let unstarred = unstarring ? readings.map { $0.replacingOccurrences(of: "*", with: "") } : []
        return (readings + unstarred).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Asterisks are list markers and markdown, so removing them would excuse the very thing a list or
    /// plain-text instruction is about.
    static func allowsUnstarring(_ kind: DirectiveKind) -> Bool {
        switch kind {
        case .list, .noList, .length(.items, _), .format(.plainText): false
        default: true
        }
    }

    func evaluate(_ kind: DirectiveKind, on text: String) -> (met: Bool, observed: String) {
        switch kind {
        case let .length(unit, bound):
            let count = TextMeasure.count(unit, in: text)
            return (bound.admits(count), "\(count) \(unit.noun(for: count))")
        case let .list(style):
            let count = TextMeasure.items(style, in: text)
            let observed = count == 0 ? "no \(style.rawValue) items" : "\(count) \(style.rawValue) \(items(count))"
            return (count > 0, observed)
        case .noList:
            let count = TextMeasure.count(.items, in: text)
            return (count == 0, count == 0 ? "no list items" : "\(count) list \(items(count))")
        case let .include(term), let .exclude(term):
            return evaluate(term: term, required: kind == .include(term), on: text)
        case let .startsWith(options), let .endsWith(options):
            return evaluate(edge: options, opening: kind == .startsWith(options), on: text)
        case let .letterCase(letterCase):
            let met = letterCase == .lowercase ? text == text.lowercased() : text == text.uppercased()
            let other = letterCase == .lowercase ? "capital" : "lowercase"
            return (met, met ? "all \(letterCase.rawValue)" : "has \(other) letters")
        case .endsWithQuestion:
            guard let last = TextMeasure.lastSignificant(text) else { return (false, "is empty") }
            return (last == "?", last == "?" ? "ends with a question" : "ends with \"\(last)\"")
        case let .format(format):
            return evaluate(format, on: text)
        case .noCommas:
            let count = text.filter { $0 == "," || $0 == "，" }.count
            return (count == 0, count == 0 ? "no commas" : "\(count) \(count == 1 ? "comma" : "commas")")
        }
    }

    /// A word or phrase the answer has to use, or must not.
    func evaluate(term: String, required: Bool, on text: String) -> (met: Bool, observed: String) {
        let count = TextMatch.count(of: term, in: text)
        if required { return (count > 0, count > 0 ? "uses \"\(term)\"" : "no \"\(term)\"") }
        return (count == 0, count == 0 ? "no \"\(term)\"" : "uses \"\(term)\" \(times(count))")
    }

    /// The text an answer has to open or close with.
    func evaluate(edge options: [String], opening: Bool, on text: String) -> (met: Bool, observed: String) {
        let excerpt = Self.excerpt(text, fromEnd: !opening)
        if opening { return (options.contains { TextMatch.starts(text, with: $0) }, "starts \"\(excerpt)\"") }
        return (options.contains { TextMatch.ends(text, with: $0) }, "ends \"\(excerpt)\"")
    }

    func evaluate(_ format: TextFormat, on text: String) -> (met: Bool, observed: String) {
        switch format {
        case .json:
            let met = TextMeasure.isJSON(text)
            return (met, met ? "valid JSON" : "not valid JSON")
        case .table:
            let met = TextMeasure.hasTable(text)
            return (met, met ? "has a table" : "no table")
        case .plainText:
            let used = TextMeasure.markdown(in: text)
            let observed = used.isEmpty ? "no markdown" : "uses markdown: " + used.joined(separator: ", ")
            return (used.isEmpty, observed)
        }
    }

    func items(_ count: Int) -> String {
        count == 1 ? "item" : "items"
    }

    func times(_ count: Int) -> String {
        switch count {
        case 1: "once"
        case 2: "twice"
        default: "\(count) times"
        }
    }

    /// The first or last 24 characters, on one line.
    static func excerpt(_ text: String, fromEnd: Bool) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        guard flat.count > 24 else { return flat }
        return fromEnd ? "…" + String(flat.suffix(24)) : String(flat.prefix(24)) + "…"
    }
}
